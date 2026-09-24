-- ============================================================================
-- Spell Counter - Settings & Configuration Modals View
-- Reset game confirmation modal & Player count selection modal.
-- ============================================================================

local ui = require("ui")

local settingsModal = {}

local function safeNum(n, def)
    local v = tonumber(n)
    return (v ~= nil) and v or (def or 0)
end

local function safeInt(n, def)
    local v = tonumber(n)
    return (v ~= nil) and math.floor(v) or (def or 0)
end

-- ---------------------------------------------------------------------------
-- Reset Confirmation Modal
-- ---------------------------------------------------------------------------
function settingsModal.drawReset(w, h)
    w = safeNum(w, 800)
    h = safeNum(h, 480)
    local mw = 440
    local mh = 280
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    ui.fillRounded(mx, my, mw, mh, 16, ui.C_WHITE)
    ui.drawRounded(mx, my, mw, mh, 16, 3, ui.C_BLACK)

    -- Title
    if gfx and gfx.fillRect then
        gfx.fillRect(mx + 3, my + 3, mw - 6, 38, ui.C_BLACK)
    end
    local title = "RESET GAME"
    local tw = ui.getTextWidth(ui.getFont("ui_10"), title)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_10"), mx + math.floor((mw - tw) / 2), my + 11, title, ui.C_WHITE)
    end

    local cy = my + 54
    local subtitle = "Select starting life total for all players:"
    local sw = ui.getTextWidth(ui.getFont("small"), subtitle)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("small"), mx + math.floor((mw - sw) / 2), cy, subtitle, ui.C_BLACK)
    end

    cy = cy + 28
    local btnW = 340
    local btnH = 40
    local bx = mx + math.floor((mw - btnW) / 2)

    ui.drawButton(bx, cy, btnW, btnH, "40 Life - Commander / EDH", ui.getFont("ui_10"), ui.C_BLACK, false)
    cy = cy + 48
    ui.drawButton(bx, cy, btnW, btnH, "20 Life - Standard / Modern", ui.getFont("ui_10"), ui.C_BLACK, false)
    cy = cy + 48
    ui.drawButton(bx, cy, btnW, btnH, "30 Life - Brawl / 2HG", ui.getFont("ui_10"), ui.C_BLACK, false)
    cy = cy + 48
    ui.drawButton(bx, cy, btnW, 34, "Cancel", ui.getFont("small"), ui.C_BLACK, false)
end

function settingsModal.handleResetTouch(x, y, w, h, onSelectLife, onCancel)
    local mw = 440
    local mh = 280
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)
    local btnW = 340
    local bx = mx + math.floor((mw - btnW) / 2)
    local cy = my + 82

    if x >= bx and x <= bx + btnW and y >= cy and y <= cy + 40 then
        onSelectLife(40)
        return true
    end
    cy = cy + 48
    if x >= bx and x <= bx + btnW and y >= cy and y <= cy + 40 then
        onSelectLife(20)
        return true
    end
    cy = cy + 48
    if x >= bx and x <= bx + btnW and y >= cy and y <= cy + 40 then
        onSelectLife(30)
        return true
    end
    cy = cy + 48
    if x >= bx and x <= bx + btnW and y >= cy and y <= cy + 34 then
        onCancel()
        return true
    end

    -- Backdrop tap outside modal closes modal
    if x < mx or x > mx + mw or y < my or y > my + mh then
        onCancel()
        return true
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Player Count Selector Modal
-- ---------------------------------------------------------------------------
function settingsModal.drawPlayerCount(w, h, currentCount)
    w = safeNum(w, 800)
    h = safeNum(h, 480)
    local mw = 360
    local mh = 260
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    ui.fillRounded(mx, my, mw, mh, 16, ui.C_WHITE)
    ui.drawRounded(mx, my, mw, mh, 16, 3, ui.C_BLACK)

    if gfx and gfx.fillRect then
        gfx.fillRect(mx + 3, my + 3, mw - 6, 38, ui.C_BLACK)
    end
    local title = "SELECT PLAYERS"
    local tw = ui.getTextWidth(ui.getFont("ui_10"), title)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_10"), mx + math.floor((mw - tw) / 2), my + 11, title, ui.C_WHITE)
    end

    local cy = my + 54
    local btnW = 280
    local btnH = 38
    local bx = mx + math.floor((mw - btnW) / 2)

    local curPc = math.max(1, math.min(4, safeInt(currentCount, 4)))
    for c = 1, 4 do
        local label = c .. " Player" .. (c > 1 and "s" or "")
        if curPc == c then
            ui.drawButton(bx, cy, btnW, btnH, label .. " (Active)", ui.getFont("ui_10"), ui.C_BLACK, true)
        else
            ui.drawButton(bx, cy, btnW, btnH, label, ui.getFont("ui_10"), ui.C_BLACK, false)
        end
        cy = cy + 44
    end

    ui.drawButton(bx, cy, btnW, 30, "Close", ui.getFont("small"), ui.C_BLACK, false)
end

function settingsModal.handlePlayerCountTouch(x, y, w, h, onSelectCount, onCancel)
    local mw = 360
    local mh = 260
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)
    local btnW = 280
    local bx = mx + math.floor((mw - btnW) / 2)
    local cy = my + 54

    for c = 1, 4 do
        if x >= bx and x <= bx + btnW and y >= cy and y <= cy + 38 then
            onSelectCount(c)
            return true
        end
        cy = cy + 44
    end

    if x >= bx and x <= bx + btnW and y >= cy and y <= cy + 30 then
        onCancel()
        return true
    end

    -- Backdrop tap outside modal closes modal
    if x < mx or x > mx + mw or y < my or y > my + mh then
        onCancel()
        return true
    end

    return true
end

return settingsModal
