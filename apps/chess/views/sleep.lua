-- Sleep Screen Renderer for CrossPoint Chess
local ui = require("ui")

local sleepView = {}

function sleepView.draw(currentView, gameView, puzzleView)
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    gfx.clearScreen(1)

    -- Top bar (40px high)
    gfx.fillRect(0, 0, w, 40, true)

    if currentView == 3 and gameView and gameView.game then
        -- Render ongoing game sleep screen
        gfx.drawCenteredText(gfx.FONT_UI_10, 11, "CROSSPOINT CHESS - CURRENT GAME", false)
        local isFlipped = (gameView.playerColor == "b" and not gameView.manualFlip) or (gameView.playerColor == "w" and gameView.manualFlip)
        ui.drawBoard(gameView.game.board, 26, 50, 400, isFlipped, -1, -1, nil)

        local panelX = 445
        local panelW = w - panelX - 20
        gfx.drawText(gfx.FONT_UI_12, panelX, 55, "Play vs Computer", true)
        gfx.drawLine(panelX, 90, panelX + panelW, 90, 2, true)

        local diffName = (gameView.difficulty == 1 and "Easy") or (gameView.difficulty == 2 and "Medium") or "Hard"
        gfx.drawText(gfx.FONT_UI_10, panelX, 105, "Difficulty: " .. diffName, true)
        local sideStr = "Playing as " .. (gameView.playerColor == "w" and "White" or "Black")
        gfx.drawText(gfx.FONT_SMALL, panelX, 135, sideStr, true)

        local cardY = 175
        local cardH = 100
        gfx.drawRoundedRect(panelX, cardY, panelW, cardH, 8, 2, true)
        local turnStr = (gameView.game.turn == gameView.playerColor) and "Your Turn to Move" or "Computer's Turn"
        local tLen = gfx.getTextWidth(gfx.FONT_UI_10, turnStr)
        gfx.drawText(gfx.FONT_UI_10, panelX + math.floor((panelW - tLen) / 2), cardY + 22, turnStr, true)

        local mvStr = "Move " .. tostring(gameView.game.fullmove)
        local mLen = gfx.getTextWidth(gfx.FONT_SMALL, mvStr)
        gfx.drawText(gfx.FONT_SMALL, panelX + math.floor((panelW - mLen) / 2), cardY + 54, mvStr, true)
    else
        -- Render Daily Puzzle sleep screen
        if puzzleView and puzzleView.puzzleBoard then
            if not puzzleView.initialFen or puzzleView.initialFen == "" then
                puzzleView.loadPuzzle()
            end
        end

        gfx.drawCenteredText(gfx.FONT_UI_10, 11, "DAILY CHESS PUZZLE", false)
        local flipped = not (puzzleView and puzzleView.playerWhite)
        local boardData = (puzzleView and puzzleView.puzzleBoard) or {}
        ui.drawBoard(boardData, 26, 50, 400, flipped, -1, -1, nil)

        local panelX = 445
        local panelW = w - panelX - 20
        gfx.drawText(gfx.FONT_UI_12, panelX, 55, "Daily Tactics", true)
        gfx.drawLine(panelX, 90, panelX + panelW, 90, 2, true)

        local rating = puzzleView and puzzleView.rating or 1500
        gfx.drawText(gfx.FONT_UI_10, panelX, 105, "Rating: " .. tostring(rating), true)
        local turnStr = (puzzleView and puzzleView.playerWhite) and "White to move" or "Black to move"
        local tw = gfx.getTextWidth(gfx.FONT_UI_10, turnStr)
        gfx.drawText(gfx.FONT_UI_10, panelX + panelW - tw, 105, turnStr, true)

        local themes = puzzleView and puzzleView.themes or "tactics"
        local thmStr = ui.truncateText(gfx.FONT_SMALL, "- Themes: " .. themes, panelW)
        gfx.drawText(gfx.FONT_SMALL, panelX, 135, thmStr, true)

        local cardY = 175
        local cardH = 100
        gfx.drawRoundedRect(panelX, cardY, panelW, cardH, 8, 2, true)
        local tLen = gfx.getTextWidth(gfx.FONT_UI_10, "Winning Move Sequence")
        gfx.drawText(gfx.FONT_UI_10, panelX + math.floor((panelW - tLen) / 2), cardY + 22, "Winning Move Sequence", true)
        local sLen = gfx.getTextWidth(gfx.FONT_SMALL, "Solve when device wakes up!")
        gfx.drawText(gfx.FONT_SMALL, panelX + math.floor((panelW - sLen) / 2), cardY + 54, "Solve when device wakes up!", true)
    end

    local fLen = gfx.getTextWidth(gfx.FONT_SMALL, "Press Power to Wake and Play")
    gfx.drawText(gfx.FONT_SMALL, 445 + math.floor((w - 445 - 20 - fLen) / 2), 430, "Press Power to Wake and Play", true)
end

return sleepView
