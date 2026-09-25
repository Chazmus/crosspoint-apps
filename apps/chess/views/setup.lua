-- Game Setup View for CrossPoint Chess (Play vs Computer)
local ui = require("ui")

local setup = {}

function setup.draw(selectedColor, selectedDifficulty)
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    -- Header
    gfx.fillRect(0, 0, w, 44, true)
    gfx.drawText(gfx.FONT_UI_12, 140, 10, "NEW GAME SETUP", false)
    ui.drawButton(20, 6, 95, 32, "< Menu", false)

    -- Panel 1: Side selection
    local p1X = 60
    local p1Y = 70
    local p1W = 320
    local p1H = 240
    gfx.drawRoundedRect(p1X, p1Y, p1W, p1H, 8, 2, true)
    gfx.drawText(gfx.FONT_UI_10, p1X + 20, p1Y + 20, "Choose Your Side:", true)

    ui.drawButton(p1X + 20, p1Y + 60, p1W - 40, 54, "White (You move first)", selectedColor == "w")
    ui.drawButton(p1X + 20, p1Y + 130, p1W - 40, 54, "Black (Computer moves first)", selectedColor == "b")

    -- Panel 2: Difficulty selection
    local p2X = 420
    local p2Y = 70
    local p2W = 320
    local p2H = 240
    gfx.drawRoundedRect(p2X, p2Y, p2W, p2H, 8, 2, true)
    gfx.drawText(gfx.FONT_UI_10, p2X + 20, p2Y + 20, "Choose Difficulty:", true)

    ui.drawButton(p2X + 20, p2Y + 60, p2W - 40, 44, "Easy (~1000 Elo)", selectedDifficulty == 1)
    ui.drawButton(p2X + 20, p2Y + 114, p2W - 40, 44, "Medium (~1350 Elo)", selectedDifficulty == 2)
    ui.drawButton(p2X + 20, p2Y + 168, p2W - 40, 44, "Hard (~1600 Elo)", selectedDifficulty == 3)

    -- Start button
    ui.drawButton(240, 340, 320, 56, "Start Game", true)
    gfx.drawCenteredText(gfx.FONT_SMALL, 430, "Swipe left edge or tap Menu to cancel", true)
end

function setup.onTouch(x, y)
    -- Back button (x=20, y=6, w=95, h=32)
    if x >= 15 and x <= 125 and y >= 4 and y <= 44 then
        return "back"
    end

    -- Side selection: White (x=60..380, y=130..184)
    if x >= 60 and x <= 380 and y >= 125 and y <= 188 then
        return "color_w"
    end

    -- Side selection: Black (x=60..380, y=200..254)
    if x >= 60 and x <= 380 and y >= 195 and y <= 258 then
        return "color_b"
    end

    -- Difficulty selection: Easy (x=420..740, y=130..174)
    if x >= 420 and x <= 740 and y >= 125 and y <= 178 then
        return "diff_1"
    end

    -- Difficulty selection: Medium (x=420..740, y=184..228)
    if x >= 420 and x <= 740 and y >= 180 and y <= 232 then
        return "diff_2"
    end

    -- Difficulty selection: Hard (x=420..740, y=238..282)
    if x >= 420 and x <= 740 and y >= 234 and y <= 286 then
        return "diff_3"
    end

    -- Start Game button (x=240..560, y=340..396)
    if x >= 240 and x <= 560 and y >= 335 and y <= 400 then
        return "start_game"
    end

    return nil
end

return setup
