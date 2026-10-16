-- ============================================================================
-- Chess Clock - Sleep Screen
-- Static, battery-free board: both clocks, control label, and hint text.
-- Rendered once on sleep (paused clock shows the saved time); no animation.
-- ============================================================================

local state = require("state")

local sleepView = {}

function sleepView.draw(w, h)
    gfx.clearScreen(1)

    -- Header band
    gfx.fillRect(0, 0, w, 50, 0)
    local title = "CHESS CLOCK"
    local tw = gfx.getTextWidth(gfx.FONT_UI_12, title)
    gfx.drawText(gfx.FONT_UI_12, math.floor((w - tw) / 2), 18, title, 1)

    -- Control label
    local label = state.control.label or ""
    local lw = gfx.getTextWidth(gfx.FONT_SMALL, label)
    gfx.drawText(gfx.FONT_SMALL, math.floor((w - lw) / 2), 64, label, 0)

    -- Two static time cards (upright only: the sleep screen is read after wake)
    local cardW = math.min(280, math.floor((w - 80) / 2))
    local cardH = 150
    local gap = 40
    local totalW = cardW * 2 + gap
    local cardY = math.floor(h / 2) - cardH - 10
    local card1X = math.floor((w - totalW) / 2)
    local card2X = card1X + cardW + gap

    local sides = { "white", "black" }
    local cardXs = { card1X, card2X }
    for i = 1, 2 do
        local side = sides[i]
        local x = cardXs[i]
        local p = state.players[side]
        local isFlagged = (state.flaggedSide == side)

        if isFlagged then
            gfx.fillRoundedRect(x, cardY, cardW, cardH, 12, 0)
            gfx.drawRoundedRect(x, cardY, cardW, cardH, 12, 3, 1)
        else
            gfx.drawRoundedRect(x, cardY, cardW, cardH, 12, 3, 0)
        end

        gfx.drawText(gfx.FONT_UI_10, x + 12, cardY + 10, string.upper(side), isFlagged and 1 or 0)

        local timeText = state.formatTime(p and p.remaining or 0)
        local digitH = 64
        local digitW = math.max(16, math.floor(digitH * 0.56))
        local cy = cardY + math.floor(cardH * 0.58)
        local cx = x + math.floor(cardW / 2)
        -- Reuse the 7-segment renderer upright (flipped = false).
        local flipgfx = require("flipgfx")
        flipgfx.drawDigits(cx, cy, timeText, digitW, digitH, isFlagged and 1 or 0, false)
    end

    gfx.drawCenteredText(gfx.FONT_SMALL, h - 40, "Press Power to Wake", 0)
end

return sleepView
