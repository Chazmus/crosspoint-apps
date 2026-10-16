-- ============================================================================
-- Chess Clock - Modal Views (Menu, Flag Result, Reset Confirm)
-- Simple dimmed dialogs drawn over the clock panels.
-- ============================================================================

local modals = {}

function modals.drawFrame(w, h, title)
    -- Dim background with light dither, then draw the dialog card.
    gfx.fillRectDither(0, 0, w, h, gfx.COLOR_DARK_GRAY)
    local boxW = math.min(360, w - 40)
    local boxH = math.min(220, h - 80)
    local boxX = math.floor((w - boxW) / 2)
    local boxY = math.floor((h - boxH) / 2)
    gfx.fillRoundedRect(boxX, boxY, boxW, boxH, 12, 1)
    gfx.drawRoundedRect(boxX, boxY, boxW, boxH, 12, 3, 0)

    local titleW = gfx.getTextWidth(gfx.FONT_UI_12, modals.title or "")
    gfx.drawText(gfx.FONT_UI_12, math.floor((w - titleW) / 2), boxY + 14, modals.title or "", 0)

    modals.box = { x = boxX, y = boxY, w = boxW, h = boxH }
    return modals.box
end

local function drawButtons(w, defs)
    -- defs: array of { label, onClickKey } evenly spaced at box bottom.
    local box = modals.box
    local n = #defs
    local gap = 12
    local btnW = math.floor((box.w - 24 - (n - 1) * gap) / n)
    local btnH = 44
    local y = box.y + box.h - btnH - 14
    modals.buttons = {}
    for i, d in ipairs(defs) do
        local x = box.x + 12 + (i - 1) * (btnW + gap)
        gfx.fillRoundedRect(x, y, btnW, btnH, 8, 0)
        gfx.drawRoundedRect(x, y, btnW, btnH, 8, 2, 0)
        local lw = gfx.getTextWidth(gfx.FONT_UI_12, d.label)
        gfx.drawText(gfx.FONT_UI_12, x + math.floor((btnW - lw) / 2), y + 13, d.label, 1)
        modals.buttons[i] = { x = x, y = y, w = btnW, h = btnH, key = d.key }
    end
end

function modals.drawMenu(w, h)
    modals.title = "MENU"
    local box = modals.drawFrame(w, h)
    gfx.drawText(gfx.FONT_UI_10, box.x + 14, box.y + 42, "Control: " .. modals.controlLabel, 0)
    drawButtons(w, {
        { label = "RESUME", key = "close" },
        { label = "NEW GAME", key = "new_game" },
        { label = "SETUP", key = "setup" },
    })
end

function modals.drawFlagged(w, h, winnerCaption)
    modals.title = "FLAG"
    local box = modals.drawFrame(w, h)
    local line = modals.flagText or ""
    local lw = gfx.getTextWidth(gfx.FONT_UI_12, line)
    gfx.drawText(gfx.FONT_UI_12, math.floor((w - lw) / 2), box.y + 46, line, 0)
    local sub = modals.subText or ""
    local sw = gfx.getTextWidth(gfx.FONT_SMALL, sub)
    gfx.drawText(gfx.FONT_SMALL, math.floor((w - sw) / 2), box.y + 70, sub, 0)
    drawButtons(w, {
        { label = "REMATCH", key = "rematch" },
        { label = "SETUP", key = "setup" },
    })
end

function modals.drawResetConfirm(w, h)
    modals.title = "RESET GAME"
    local box = modals.drawFrame(w, h)
    local line = "Restart clock with"
    local lw = gfx.getTextWidth(gfx.FONT_UI_10, line)
    gfx.drawText(gfx.FONT_UI_10, math.floor((w - lw) / 2), box.y + 46, line, 0)
    local sub = modals.controlLabel or ""
    local sw = gfx.getTextWidth(gfx.FONT_UI_12, sub)
    gfx.drawText(gfx.FONT_UI_12, math.floor((w - sw) / 2), box.y + 64, sub, 0)
    drawButtons(w, {
        { label = "CANCEL", key = "close" },
        { label = "RESET", key = "reset" },
    })
end

--- Hit test buttons. Returns the key of a pressed button or nil.
function modals.buttonAt(x, y)
    for _, b in ipairs(modals.buttons or {}) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            return b.key
        end
    end
    return nil
end

--- Touch outside the dialog closes the menu modals (not the confirm dialog).
function modals.tapOutsideCloses(kind)
    return kind == "menu"
end

return modals
