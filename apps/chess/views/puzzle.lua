-- Daily Puzzle Controller & View for CrossPoint Chess
local ui = require("ui")
local Engine = require("engine")
local json = require("json")

local puzzleView = {
    puzzleBoard = {},
    selectedSq = -1,
    hintSq = -1,
    statusMsg = "Daily Puzzle - Loading...",
    rating = 1500,
    themes = "tactics",
    solution = {},
    moveIndex = 1,
    playerWhite = true,
    isSolved = false,
    initialFen = ""
}

local function clearPuzzleBoard()
    for i = 0, 63 do
        puzzleView.puzzleBoard[i] = "."
    end
end

function puzzleView.loadPuzzleFen(fen)
    clearPuzzleBoard()
    if not fen then return end
    local parts = {}
    for p in fen:gmatch("%S+") do table.insert(parts, p) end
    local boardPart = parts[1] or ""

    local rank = 7
    local file = 0
    for i = 1, #boardPart do
        local c = boardPart:sub(i, i)
        if c == '/' then
            rank = rank - 1
            file = 0
        elseif c:match("%d") then
            file = file + tonumber(c)
        else
            if file < 8 and rank >= 0 then
                puzzleView.puzzleBoard[rank * 8 + file] = c
                file = file + 1
            end
        end
    end

    puzzleView.playerWhite = (parts[2] ~= "b")
end

function puzzleView.applyPuzzleMove(moveStr)
    if not moveStr or #moveStr < 4 then return false end
    local fromSq = Engine.notationToSquare(moveStr:sub(1, 2))
    local toSq = Engine.notationToSquare(moveStr:sub(3, 4))
    if fromSq < 0 or toSq < 0 then return false end

    local piece = puzzleView.puzzleBoard[fromSq]
    if not piece or piece == "." then return false end

    -- Castling Rook moves
    if piece == "K" and fromSq == 4 then
        if toSq == 6 then
            puzzleView.puzzleBoard[5] = puzzleView.puzzleBoard[7]
            puzzleView.puzzleBoard[7] = "."
        elseif toSq == 2 then
            puzzleView.puzzleBoard[3] = puzzleView.puzzleBoard[0]
            puzzleView.puzzleBoard[0] = "."
        end
    elseif piece == "k" and fromSq == 60 then
        if toSq == 62 then
            puzzleView.puzzleBoard[61] = puzzleView.puzzleBoard[63]
            puzzleView.puzzleBoard[63] = "."
        elseif toSq == 58 then
            puzzleView.puzzleBoard[59] = puzzleView.puzzleBoard[56]
            puzzleView.puzzleBoard[56] = "."
        end
    end

    -- En passant capture
    local fromFile, _ = Engine.squareToFileRank(fromSq)
    local toFile, _ = Engine.squareToFileRank(toSq)
    if (piece == "P" or piece == "p") and fromFile ~= toFile and puzzleView.puzzleBoard[toSq] == "." then
        if piece == "P" then
            puzzleView.puzzleBoard[toSq - 8] = "."
        else
            puzzleView.puzzleBoard[toSq + 8] = "."
        end
    end

    puzzleView.puzzleBoard[fromSq] = "."

    -- Promotion
    if #moveStr >= 5 then
        local prom = moveStr:sub(5, 5)
        puzzleView.puzzleBoard[toSq] = (piece == piece:upper()) and prom:upper() or prom:lower()
    else
        puzzleView.puzzleBoard[toSq] = piece
    end

    return true
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
    ui.drawBoard(puzzleView.puzzleBoard, 26, 50, 400, flipped, puzzleView.selectedSq, puzzleView.hintSq, nil)

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
    if puzzleView.isSolved or sq < 0 or sq > 63 then return end

    local p = puzzleView.puzzleBoard[sq]
    local isOwn = puzzleView.playerWhite and Engine.isWhitePiece(p) or Engine.isBlackPiece(p)

    -- Case 1: No piece selected
    if puzzleView.selectedSq == -1 then
        if isOwn then
            puzzleView.selectedSq = sq
            puzzleView.hintSq = -1
            crosspoint.requestUpdate()
        end
        return
    end

    -- Case 2: Tapped already-selected square: deselect
    if sq == puzzleView.selectedSq then
        puzzleView.selectedSq = -1
        crosspoint.requestUpdate()
        return
    end

    -- Case 3: Tapped another piece of own color: switch selection
    if isOwn then
        puzzleView.selectedSq = sq
        puzzleView.hintSq = -1
        crosspoint.requestUpdate()
        return
    end

    -- Case 4: Attempting move from selectedSq to sq
    local uci = Engine.squareToNotation(puzzleView.selectedSq) .. Engine.squareToNotation(sq)
    local fromP = puzzleView.puzzleBoard[puzzleView.selectedSq]
    local _, toRank = Engine.squareToFileRank(sq)
    if fromP == "P" and toRank == 7 then uci = uci .. "q" end
    if fromP == "p" and toRank == 0 then uci = uci .. "q" end

    puzzleView.selectedSq = -1

    local expected = puzzleView.solution[puzzleView.moveIndex]
    if expected and uci == expected then
        -- Correct move!
        puzzleView.applyPuzzleMove(uci)
        puzzleView.moveIndex = puzzleView.moveIndex + 1
        puzzleView.hintSq = -1

        if puzzleView.moveIndex > #puzzleView.solution then
            puzzleView.isSolved = true
            puzzleView.statusMsg = "Puzzle Solved! Excellent!"
        else
            -- Opponent response move
            local oppMove = puzzleView.solution[puzzleView.moveIndex]
            puzzleView.applyPuzzleMove(oppMove)
            puzzleView.moveIndex = puzzleView.moveIndex + 1

            if puzzleView.moveIndex > #puzzleView.solution then
                puzzleView.isSolved = true
                puzzleView.statusMsg = "Puzzle Solved!"
            else
                puzzleView.statusMsg = "Opponent played " .. oppMove .. ". Your turn!"
            end
        end
    else
        puzzleView.statusMsg = "Not the best move. Try again!"
    end

    crosspoint.requestUpdate()
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
