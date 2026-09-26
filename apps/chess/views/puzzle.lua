-- Daily Puzzle Controller & View for CrossPoint Chess
local ui = require("ui")
local Engine = require("engine")
local json = require("json")

local puzzleView = {
    game = nil,
    puzzleBoard = {},
    playerColor = "w",
    selectedSq = -1,
    hintSq = -1,
    legalDests = {},
    statusMsg = "Daily Puzzle - Loading...",
    rating = 1500,
    themes = "tactics",
    solution = {},
    moveIndex = 1,
    playerWhite = true,
    isSolved = false,
    initialFen = ""
}

function puzzleView.loadPuzzleFen(fen)
    if not fen or fen == "" then return end
    puzzleView.game = Engine.newGame(fen)
    puzzleView.puzzleBoard = puzzleView.game.board
    puzzleView.playerColor = puzzleView.game.turn
    puzzleView.playerWhite = (puzzleView.playerColor == "w")
    puzzleView.selectedSq = -1
    puzzleView.hintSq = -1
    puzzleView.legalDests = {}
end

function puzzleView.applyPuzzleMove(moveStr)
    if not puzzleView.game or not moveStr or #moveStr < 4 then return false end
    local m = Engine.uciToMove(moveStr)
    if not m then return false end
    local ok = Engine.makeMove(puzzleView.game, m)
    if ok then
        puzzleView.puzzleBoard = puzzleView.game.board
    end
    return ok
end

function puzzleView.loadPuzzle()
    local data = storage.readFile("daily.json")
    if not data then
        puzzleView.initialFen = "r1bqkb1r/pppp1ppp/2n5/4p3/2B1n3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 5"
        puzzleView.loadPuzzleFen(puzzleView.initialFen)
        puzzleView.solution = {"d2d4"}
        puzzleView.moveIndex = 1
        puzzleView.rating = 1500
        puzzleView.themes = "tactics"
        puzzleView.statusMsg = "Sample puzzle loaded. White to move"
        return
    end

    local parsed = json.decode(data)
    if parsed and parsed.puzzle then
        puzzleView.rating = parsed.puzzle.rating or 1500
        puzzleView.themes = (parsed.puzzle.themes and table.concat(parsed.puzzle.themes, ", ")) or "tactics"
        puzzleView.solution = parsed.puzzle.solution or {}
        puzzleView.moveIndex = 1
        puzzleView.isSolved = false

        if parsed.puzzle.fen and parsed.puzzle.fen ~= "" then
            puzzleView.initialFen = parsed.puzzle.fen
        else
            puzzleView.initialFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        end

        puzzleView.loadPuzzleFen(puzzleView.initialFen)

        if #puzzleView.solution > 0 then
            puzzleView.statusMsg = puzzleView.playerWhite and "White to move - Find the best move!" or "Black to move - Find the best move!"
        else
            puzzleView.statusMsg = "Puzzle loaded - Free play"
        end
    else
        puzzleView.initialFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        puzzleView.loadPuzzleFen(puzzleView.initialFen)
        puzzleView.statusMsg = "Standard board loaded"
    end
end

function puzzleView.reset()
    if puzzleView.initialFen and puzzleView.initialFen ~= "" then
        puzzleView.loadPuzzleFen(puzzleView.initialFen)
        puzzleView.moveIndex = 1
        puzzleView.selectedSq = -1
        puzzleView.hintSq = -1
        puzzleView.isSolved = false
        puzzleView.statusMsg = puzzleView.playerWhite and "Puzzle reset. White to move" or "Puzzle reset. Black to move"
        crosspoint.requestUpdate()
    end
end

function puzzleView.showHint()
    if puzzleView.isSolved or puzzleView.moveIndex > #puzzleView.solution then return end
    local nextMove = puzzleView.solution[puzzleView.moveIndex]
    if nextMove and #nextMove >= 2 then
        puzzleView.hintSq = Engine.notationToSquare(nextMove:sub(1, 2))
        puzzleView.statusMsg = "Hint: move the highlighted piece"
        crosspoint.requestUpdate()
    end
end

function puzzleView.fetchDaily()
    puzzleView.statusMsg = "Connecting to Wi-Fi..."
    crosspoint.requestUpdate()

    crosspoint.withWifi(function(connected)
        if not connected then
            puzzleView.statusMsg = "Wi-Fi connection cancelled"
            crosspoint.requestUpdate()
            return
        end

        puzzleView.statusMsg = "Downloading daily puzzle..."
        crosspoint.requestUpdate()

        local online = crosspoint.httpGet("https://lichess.org/api/puzzle/daily")
        if online and online ~= "" then
            storage.writeFile("daily.json", online)
            puzzleView.loadPuzzle()
            puzzleView.statusMsg = "New puzzle loaded! " .. (puzzleView.playerWhite and "White" or "Black") .. " to move"
        else
            puzzleView.statusMsg = "Failed to download puzzle"
        end
        crosspoint.requestUpdate()
    end)
end

function puzzleView.draw()
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    -- Top bar
    gfx.fillRect(0, 0, w, 36, true)
    gfx.drawText(gfx.FONT_UI_10, 20, 9, "Daily Chess Puzzles (Lichess)", false)

    local turnBadge = puzzleView.playerWhite and "Turn: White" or "Turn: Black"
    local bw = gfx.getTextWidth(gfx.FONT_UI_10, turnBadge)
    gfx.drawText(gfx.FONT_UI_10, w - bw - 20, 9, turnBadge, false)

    -- Draw Board (400x400)
    local flipped = not puzzleView.playerWhite
    local boardData = (puzzleView.game and puzzleView.game.board) or puzzleView.puzzleBoard or {}
    ui.drawBoard(boardData, 26, 50, 400, flipped, puzzleView.selectedSq, puzzleView.hintSq, puzzleView.legalDests)

    -- Side info panel
    local panelX = 445
    local panelW = w - panelX - 20

    gfx.drawText(gfx.FONT_UI_12, panelX, 50, "Daily Tactics", true)
    gfx.drawLine(panelX, 86, panelX + panelW, 86, 2, true)

    gfx.drawText(gfx.FONT_UI_10, panelX, 98, "Rating: " .. tostring(puzzleView.rating), true)
    local turnStr = puzzleView.playerWhite and "White to move" or "Black to move"
    local tw = gfx.getTextWidth(gfx.FONT_UI_10, turnStr)
    gfx.drawText(gfx.FONT_UI_10, panelX + panelW - tw, 98, turnStr, true)

    local thmStr = ui.truncateText(gfx.FONT_SMALL, "- Themes: " .. puzzleView.themes, panelW)
    gfx.drawText(gfx.FONT_SMALL, panelX, 126, thmStr, true)

    -- Status message box
    local boxY = 155
    local boxH = 110
    gfx.drawRoundedRect(panelX, boxY, panelW, boxH, 8, 2, true)
    local msgW = gfx.getTextWidth(gfx.FONT_SMALL, puzzleView.statusMsg)
    local msgH = gfx.getLineHeight(gfx.FONT_SMALL)
    local msgX = math.max(panelX + 8, panelX + math.floor((panelW - msgW) / 2))
    local msgY = boxY + math.floor((boxH - msgH) / 2)
    gfx.drawText(gfx.FONT_SMALL, msgX, msgY, puzzleView.statusMsg, true)

    -- Buttons
    local col1X = 445
    local col2X = 620
    local btnW = 160
    local btnH = 44
    local row1Y = 290
    local row2Y = 346

    ui.drawButton(col1X, row1Y, btnW, btnH, "Hint", false)
    ui.drawButton(col2X, row1Y, btnW, btnH, "Reset", false)
    ui.drawButton(col1X, row2Y, btnW, btnH, "Sync Daily", false)
    ui.drawButton(col2X, row2Y, btnW, btnH, "< Menu", false)

    -- Navigation hints
    gfx.drawText(gfx.FONT_SMALL, panelX, 415, "Tap piece to select, tap target to move.", true)
    gfx.drawText(gfx.FONT_SMALL, panelX, 435, "Swipe left edge or tap Menu to return.", true)
end

function puzzleView.handleSquareTap(sq)
    if puzzleView.isSolved or not puzzleView.game or sq < 0 or sq > 63 then return end

    local p = puzzleView.game.board[sq]
    local playerColor = puzzleView.playerColor

    -- Case 1: Tapping already-selected square: deselect
    if sq == puzzleView.selectedSq then
        puzzleView.selectedSq = -1
        puzzleView.legalDests = {}
        crosspoint.requestUpdate()
        return
    end

    -- Case 2: Tapping a legal destination square for currently selected piece
    if puzzleView.selectedSq ~= -1 and puzzleView.legalDests[sq] then
        local chosenMove = puzzleView.legalDests[sq]
        local fromP = puzzleView.game.board[puzzleView.selectedSq]
        local _, toRank = Engine.squareToFileRank(sq)
        if ((fromP == "P" and toRank == 7) or (fromP == "p" and toRank == 0)) and not chosenMove.promo then
            chosenMove.promo = "q"
        end

        local uci = Engine.moveToUci(chosenMove)
        local expected = puzzleView.solution[puzzleView.moveIndex]

        if expected and (uci == expected or uci:lower() == expected:lower()) then
            -- Correct move! Make the player move on the game board
            Engine.makeMove(puzzleView.game, chosenMove)
            puzzleView.puzzleBoard = puzzleView.game.board
            puzzleView.moveIndex = puzzleView.moveIndex + 1
            puzzleView.selectedSq = -1
            puzzleView.legalDests = {}
            puzzleView.hintSq = -1

            if puzzleView.moveIndex > #puzzleView.solution then
                puzzleView.isSolved = true
                puzzleView.statusMsg = "Puzzle Solved! Excellent!"
            else
                -- Opponent response move
                local oppUci = puzzleView.solution[puzzleView.moveIndex]
                local oppMoveObj = Engine.uciToMove(oppUci)
                if oppMoveObj then
                    Engine.makeMove(puzzleView.game, oppMoveObj)
                    puzzleView.puzzleBoard = puzzleView.game.board
                end
                puzzleView.moveIndex = puzzleView.moveIndex + 1

                if puzzleView.moveIndex > #puzzleView.solution then
                    puzzleView.isSolved = true
                    puzzleView.statusMsg = "Puzzle Solved!"
                else
                    puzzleView.statusMsg = "Opponent played " .. oppUci .. ". Your turn!"
                end
            end
        else
            -- Legal move, but not the puzzle solution
            puzzleView.statusMsg = "Not the best move. Try again!"
            puzzleView.selectedSq = -1
            puzzleView.legalDests = {}
        end
        crosspoint.requestUpdate()
        return
    end

    -- Case 3: Tapping own piece of player color: select and calculate legal moves
    if Engine.isColorPiece(p, playerColor) then
        puzzleView.selectedSq = sq
        puzzleView.hintSq = -1
        puzzleView.legalDests = {}
        local legals = Engine.getLegalMoves(puzzleView.game, sq)
        for _, m in ipairs(legals) do
            if not puzzleView.legalDests[m.to] or m.promo == "q" then
                puzzleView.legalDests[m.to] = m
            end
        end
        crosspoint.requestUpdate()
        return
    end

    -- Case 4: Tapped enemy piece or empty square that is not a legal destination: deselect
    if puzzleView.selectedSq ~= -1 then
        puzzleView.selectedSq = -1
        puzzleView.legalDests = {}
        crosspoint.requestUpdate()
    end
end

function puzzleView.onTouch(x, y)
    local col1X = 445
    local col2X = 620
    local btnW = 160
    local btnH = 44
    local row1Y = 290
    local row2Y = 346

    -- Hint button
    if x >= col1X and x <= col1X + btnW and y >= row1Y and y <= row1Y + btnH then
        puzzleView.showHint()
        return "hint"
    end

    -- Reset button
    if x >= col2X and x <= col2X + btnW and y >= row1Y and y <= row1Y + btnH then
        puzzleView.reset()
        return "reset"
    end

    -- Sync Daily button
    if x >= col1X and x <= col1X + btnW and y >= row2Y and y <= row2Y + btnH then
        puzzleView.fetchDaily()
        return "sync"
    end

    -- Menu button
    if x >= col2X and x <= col2X + btnW and y >= row2Y and y <= row2Y + btnH then
        return "menu"
    end

    -- Board Tap
    local flipped = not puzzleView.playerWhite
    local sq = ui.screenToSquare(x, y, 26, 50, 400, flipped)
    if sq >= 0 then
        puzzleView.handleSquareTap(sq)
        return "square"
    end

    return nil
end

return puzzleView
