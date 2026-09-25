-- Active Match Controller & View for Play vs Computer
local ui = require("ui")
local Engine = require("engine")
local json = require("json")

local gameView = {
    game = nil,
    playerColor = "w",
    difficulty = 2,
    manualFlip = false,
    selectedSq = -1,
    legalDests = {},
    statusMsg = "Your turn - Tap a piece to move",
    computerThinking = 0,
    lastMoveUci = "",
    hasSavedGame = false
}

function gameView.saveState()
    if not gameView.game then return end
    local data = {
        fen = Engine.toFen(gameView.game),
        playerColor = gameView.playerColor,
        difficulty = gameView.difficulty,
        lastMoveUci = gameView.lastMoveUci,
        manualFlip = gameView.manualFlip
    }
    local encoded = json.encode(data)
    if encoded then
        storage.writeFile("game.json", encoded)
        gameView.hasSavedGame = true
    end
end

function gameView.checkSaved()
    local content = storage.readFile("game.json")
    if not content or content == "" then
        gameView.hasSavedGame = false
        return false
    end
    local parsed = json.decode(content)
    if parsed and parsed.fen and parsed.fen ~= "" then
        gameView.hasSavedGame = true
        return true
    end
    gameView.hasSavedGame = false
    return false
end

function gameView.loadSaved()
    local content = storage.readFile("game.json")
    if not content then return false end
    local parsed = json.decode(content)
    if parsed and parsed.fen then
        gameView.playerColor = parsed.playerColor or "w"
        gameView.difficulty = parsed.difficulty or 2
        gameView.lastMoveUci = parsed.lastMoveUci or ""
        gameView.manualFlip = parsed.manualFlip or false
        gameView.game = Engine.newGame(parsed.fen)
        gameView.selectedSq = -1
        gameView.legalDests = {}

        local over, winner, reason = Engine.getGameStatus(gameView.game)
        if over then
            if reason == "checkmate" then
                gameView.statusMsg = (winner == gameView.playerColor) and "Checkmate! You won!" or "Checkmate! Computer won."
            else
                gameView.statusMsg = "Game Over: " .. reason
            end
            gameView.computerThinking = 0
        else
            if gameView.game.turn == gameView.playerColor then
                local inCheck = Engine.isInCheck(gameView.game.board, gameView.playerColor)
                gameView.statusMsg = inCheck and "Check! Your turn" or "Your turn"
                gameView.computerThinking = 0
            else
                gameView.statusMsg = "Computer thinking..."
                gameView.computerThinking = 2
            end
        end
        return true
    end
    return false
end

function gameView.startNew(color, diff)
    gameView.playerColor = color
    gameView.difficulty = diff
    gameView.manualFlip = false
    gameView.game = Engine.newGame()
    gameView.selectedSq = -1
    gameView.legalDests = {}
    gameView.lastMoveUci = ""

    if gameView.playerColor == "w" then
        gameView.statusMsg = "New game! You are White. Make your move."
        gameView.computerThinking = 0
    else
        gameView.statusMsg = "New game! Computer is thinking..."
        gameView.computerThinking = 2
    end

    gameView.saveState()
    crosspoint.requestUpdate()
end

function gameView.draw()
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    -- Top bar
    gfx.fillRect(0, 0, w, 36, true)
    gfx.drawText(gfx.FONT_UI_10, 20, 9, "Play vs Computer", false)

    local diffName = (gameView.difficulty == 1 and "Easy") or (gameView.difficulty == 2 and "Medium") or "Hard"
    local modeInfo = "Diff: " .. diffName .. " | You: " .. (gameView.playerColor == "w" and "White" or "Black")
    local mw = gfx.getTextWidth(gfx.FONT_UI_10, modeInfo)
    gfx.drawText(gfx.FONT_UI_10, w - mw - 20, 9, modeInfo, false)

    -- Draw Board (400x400)
    local isFlipped = (gameView.playerColor == "b" and not gameView.manualFlip) or (gameView.playerColor == "w" and gameView.manualFlip)
    local boardData = gameView.game and gameView.game.board or {}
    ui.drawBoard(boardData, 26, 50, 400, isFlipped, gameView.selectedSq, -1, gameView.legalDests)

    -- Side info panel
    local panelX = 445
    local panelW = w - panelX - 20

    gfx.drawText(gfx.FONT_UI_12, panelX, 50, "Chess Game", true)
    gfx.drawLine(panelX, 86, panelX + panelW, 86, 2, true)

    -- Game status card
    local boxY = 100
    local boxH = 135
    gfx.drawRoundedRect(panelX, boxY, panelW, boxH, 8, 2, true)

    local turnLabel = (gameView.game and gameView.game.turn == gameView.playerColor) and "Your Turn" or "Computer's Turn"
    gfx.drawText(gfx.FONT_UI_10, panelX + 16, boxY + 16, turnLabel, true)

    local moveLabel = "Move " .. tostring(gameView.game and gameView.game.fullmove or 1)
    if gameView.lastMoveUci and gameView.lastMoveUci ~= "" then
        moveLabel = moveLabel .. " (Last: " .. gameView.lastMoveUci .. ")"
    end
    gfx.drawText(gfx.FONT_SMALL, panelX + 16, boxY + 48, moveLabel, true)

    local stMsg = ui.truncateText(gfx.FONT_SMALL, gameView.statusMsg, panelW - 32)
    gfx.drawText(gfx.FONT_SMALL, panelX + 16, boxY + 80, stMsg, true)

    -- Buttons
    local col1X = 445
    local col2X = 620
    local btnW = 160
    local btnH = 44
    local row1Y = 270
    local row2Y = 326

    ui.drawButton(col1X, row1Y, btnW, btnH, "Undo", false)
    ui.drawButton(col2X, row1Y, btnW, btnH, "New Game", false)
    ui.drawButton(col1X, row2Y, btnW, btnH, "Flip Board", false)
    ui.drawButton(col2X, row2Y, btnW, btnH, "< Menu", false)

    -- Footer hints
    gfx.drawText(gfx.FONT_SMALL, panelX, 405, "Tap piece to view legal moves.", true)
    gfx.drawText(gfx.FONT_SMALL, panelX, 428, "Swipe left edge or tap Menu to return.", true)
end

function gameView.handleSquareTap(sq)
    if not gameView.game or gameView.computerThinking > 0 or sq < 0 or sq > 63 then return end

    local over = Engine.getGameStatus(gameView.game)
    if over then return end

    if gameView.game.turn ~= gameView.playerColor then return end

    local p = gameView.game.board[sq]

    -- Case 1: Tapping already-selected square: deselect
    if sq == gameView.selectedSq then
        gameView.selectedSq = -1
        gameView.legalDests = {}
        crosspoint.requestUpdate()
        return
    end

    -- Case 2: Tapping a legal destination square
    if gameView.selectedSq ~= -1 and gameView.legalDests[sq] then
        local chosenMove = gameView.legalDests[sq]
        local fromP = gameView.game.board[gameView.selectedSq]
        local _, toRank = Engine.squareToFileRank(sq)
        if ((fromP == "P" and toRank == 7) or (fromP == "p" and toRank == 0)) and not chosenMove.promo then
            chosenMove.promo = "q"
        end

        local ok = Engine.makeMove(gameView.game, chosenMove)
        if ok then
            gameView.lastMoveUci = Engine.moveToUci(chosenMove)
            gameView.selectedSq = -1
            gameView.legalDests = {}

            local isOver, winner, reason = Engine.getGameStatus(gameView.game)
            if isOver then
                if reason == "checkmate" then
                    gameView.statusMsg = "Checkmate! You win!"
                else
                    gameView.statusMsg = "Game Over: " .. reason
                end
                gameView.saveState()
            else
                gameView.statusMsg = "Computer is thinking..."
                gameView.computerThinking = 2
            end
            crosspoint.requestUpdate()
            return
        end
    end

    -- Case 3: Tapping own piece: select and calculate legal moves
    if Engine.isColorPiece(p, gameView.playerColor) then
        gameView.selectedSq = sq
        gameView.legalDests = {}
        local legals = Engine.getLegalMoves(gameView.game, sq)
        for _, m in ipairs(legals) do
            if not gameView.legalDests[m.to] or m.promo == "q" then
                gameView.legalDests[m.to] = m
            end
        end
        crosspoint.requestUpdate()
        return
    end

    -- Deselect
    gameView.selectedSq = -1
    gameView.legalDests = {}
    crosspoint.requestUpdate()
end

function gameView.undo()
    if gameView.computerThinking == 0 and gameView.game and #gameView.game.history > 0 then
        if gameView.game.turn == gameView.playerColor then
            Engine.undoMove(gameView.game)
            if #gameView.game.history > 0 and gameView.game.turn ~= gameView.playerColor then
                Engine.undoMove(gameView.game)
            end
        else
            Engine.undoMove(gameView.game)
        end
        gameView.selectedSq = -1
        gameView.legalDests = {}
        if gameView.game.turn == gameView.playerColor then
            local inCheck = Engine.isInCheck(gameView.game.board, gameView.playerColor)
            gameView.statusMsg = inCheck and "Check! Move taken back" or "Move taken back. Your turn!"
            gameView.computerThinking = 0
        else
            gameView.statusMsg = "Computer thinking..."
            gameView.computerThinking = 2
        end
        gameView.saveState()
        crosspoint.requestUpdate()
    end
end

function gameView.onTouch(x, y)
    local col1X = 445
    local col2X = 620
    local btnW = 160
    local btnH = 44
    local row1Y = 270
    local row2Y = 326

    -- Undo button
    if x >= col1X and x <= col1X + btnW and y >= row1Y and y <= row1Y + btnH then
        gameView.undo()
        return "undo"
    end

    -- New Game button
    if x >= col2X and x <= col2X + btnW and y >= row1Y and y <= row1Y + btnH then
        return "new_game"
    end

    -- Flip Board button
    if x >= col1X and x <= col1X + btnW and y >= row2Y and y <= row2Y + btnH then
        gameView.manualFlip = not gameView.manualFlip
        gameView.saveState()
        crosspoint.requestUpdate()
        return "flip"
    end

    -- Menu button
    if x >= col2X and x <= col2X + btnW and y >= row2Y and y <= row2Y + btnH then
        return "menu"
    end

    -- Board Tap
    local isFlipped = (gameView.playerColor == "b" and not gameView.manualFlip) or (gameView.playerColor == "w" and gameView.manualFlip)
    local sq = ui.screenToSquare(x, y, 26, 50, 400, isFlipped)
    if sq >= 0 then
        gameView.handleSquareTap(sq)
        return "square"
    end

    return nil
end

function gameView.onUpdate(dt)
    if gameView.computerThinking > 0 and gameView.game then
        if gameView.computerThinking > 1 then
            gameView.computerThinking = gameView.computerThinking - 1
            crosspoint.requestUpdate()
            return
        end
        gameView.computerThinking = 0

        local bestMove = Engine.getBestMove(gameView.game, gameView.difficulty)
        if bestMove then
            local moveObj = Engine.uciToMove(bestMove)
            Engine.makeMove(gameView.game, moveObj)
            gameView.lastMoveUci = bestMove

            local over, winner, reason = Engine.getGameStatus(gameView.game)
            if over then
                if reason == "checkmate" then
                    gameView.statusMsg = "Checkmate! Computer wins."
                else
                    gameView.statusMsg = "Draw (" .. reason .. ")"
                end
            else
                local inCheck = Engine.isInCheck(gameView.game.board, gameView.playerColor)
                if inCheck then
                    gameView.statusMsg = "Check! Computer played " .. bestMove
                else
                    gameView.statusMsg = "Computer played " .. bestMove .. ". Your turn!"
                end
            end
            gameView.saveState()
        else
            gameView.statusMsg = "Computer has no legal moves."
        end
        crosspoint.requestUpdate()
    end
end

return gameView
