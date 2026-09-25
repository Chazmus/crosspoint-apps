-- Main Menu View for CrossPoint Chess
local ui = require("ui")

local menu = {}

function menu.draw(hasSavedGame, puzzleRating, puzzleThemes, isSleepActive)
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    -- Header banner
    gfx.fillRect(0, 0, w, 44, true)
    gfx.drawText(gfx.FONT_UI_12, 24, 10, "CROSSPOINT CHESS", false)
    local sub = "v1.1.1 - E-Ink Edition"
    local sw = gfx.getTextWidth(gfx.FONT_SMALL, sub)
    gfx.drawText(gfx.FONT_SMALL, w - sw - 24, 14, sub, false)

    -- Card 1: Play vs Computer
    local card1X = 40
    local card1Y = 68
    local cardW = 340
    local cardH = 330
    gfx.drawRoundedRect(card1X, card1Y, cardW, cardH, 10, 3, true)

    gfx.drawText(gfx.FONT_UI_12, card1X + 24, card1Y + 22, "Play vs Computer", true)
    gfx.drawLine(card1X + 24, card1Y + 54, card1X + cardW - 24, card1Y + 54, 2, true)

    gfx.drawText(gfx.FONT_SMALL, card1X + 24, card1Y + 70, "Challenge the built-in chess AI", true)
    gfx.drawText(gfx.FONT_SMALL, card1X + 24, card1Y + 95, "- 3 Difficulty Levels (Easy, Medium, Hard)", true)
    gfx.drawText(gfx.FONT_SMALL, card1X + 24, card1Y + 120, "- Play as White or Black", true)
    gfx.drawText(gfx.FONT_SMALL, card1X + 24, card1Y + 145, "- Full move validation & takebacks", true)

    if hasSavedGame then
        ui.drawButton(card1X + 20, card1Y + 205, cardW - 40, 48, "Resume Game", true)
        ui.drawButton(card1X + 20, card1Y + 265, cardW - 40, 44, "Start New Game", false)
    else
        ui.drawButton(card1X + 20, card1Y + 245, cardW - 40, 56, "Start New Game", true)
    end

    -- Card 2: Daily Puzzle
    local card2X = 420
    local card2Y = 68
    gfx.drawRoundedRect(card2X, card2Y, cardW, cardH, 10, 3, true)

    gfx.drawText(gfx.FONT_UI_12, card2X + 24, card2Y + 22, "Daily Puzzle", true)
    gfx.drawLine(card2X + 24, card2Y + 54, card2X + cardW - 24, card2Y + 54, 2, true)

    gfx.drawText(gfx.FONT_SMALL, card2X + 24, card2Y + 70, "Daily tactical challenge from Lichess", true)
    gfx.drawText(gfx.FONT_SMALL, card2X + 24, card2Y + 95, "- Rating: " .. tostring(puzzleRating), true)
    local pThemes = ui.truncateText(gfx.FONT_SMALL, "- Themes: " .. puzzleThemes, cardW - 48)
    gfx.drawText(gfx.FONT_SMALL, card2X + 24, card2Y + 120, pThemes, true)
    gfx.drawText(gfx.FONT_SMALL, card2X + 24, card2Y + 145, "- Offline fallback & Wi-Fi sync", true)

    ui.drawButton(card2X + 20, card2Y + 245, cardW - 40, 56, "Play Daily Puzzle", true)

    -- Bottom Bar
    gfx.drawText(gfx.FONT_SMALL, 40, 430, "Swipe left edge to exit - Home button returns home", true)
    ui.drawButton(580, 418, 180, 44, isSleepActive and "Sleep Screen: ON" or "Sleep Screen: OFF", isSleepActive)
end

function menu.onTouch(x, y, hasSavedGame)
    -- Card 1: Play vs Computer (x=40..380, y=68..400)
    if x >= 40 and x <= 380 and y >= 68 and y <= 400 then
        if hasSavedGame then
            if y <= 325 then
                return "resume_game"
            else
                return "new_game"
            end
        else
            return "new_game"
        end
    end

    -- Card 2: Daily Puzzle (x=420..760, y=68..400)
    if x >= 420 and x <= 760 and y >= 68 and y <= 400 then
        return "daily_puzzle"
    end

    -- Sleep toggle button (x=580..760, y=418..462)
    if x >= 580 and x <= 760 and y >= 418 and y <= 462 then
        return "toggle_sleep"
    end

    return nil
end

return menu
