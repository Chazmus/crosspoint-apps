-- ============================================================================
-- Spell Counter - E-Ink Persistent Lockscreen View
-- Preserves current game scores and state on the reflective e-ink panel.
-- ============================================================================

local ui = require("ui")
local stateEngine = require("state")

local sleepView = {}

local function safeNum(n, def)
    local v = tonumber(n)
    return (v ~= nil) and v or (def or 0)
end

local function safeInt(n, def)
    local v = tonumber(n)
    return (v ~= nil) and math.floor(v) or (def or 0)
end

function sleepView.draw(w, h, state)
    w = safeNum(w, 800)
    h = safeNum(h, 480)

    if gfx and gfx.clearScreen then
        gfx.clearScreen(1)
    end

    if gfx and gfx.fillRect then
        gfx.fillRect(0, 0, w, 44, ui.C_BLACK)
    end
    local headerText = "SPELL COUNTER - GAME PAUSED"
    local hw = ui.getTextWidth(ui.getFont("ui_12"), headerText)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_12"), math.floor((w - hw) / 2), 8, headerText, ui.C_WHITE)
    end

    local subText = "Match state preserved on E-Ink display | Press power button to resume"
    local sw = ui.getTextWidth(ui.getFont("small"), subText)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("small"), math.floor((w - sw) / 2), 50, subText, ui.C_BLACK)
    end

    local count = math.max(1, math.min(4, safeInt(state.playerCount, 4)))
    local availY = 74
    local availH = h - availY - 30

    local colW = math.floor((w - 24) / (count >= 2 and 2 or 1))
    local rowH = math.floor((availH - 16) / (count >= 3 and 2 or 1))

    for i = 1, count do
        local p = stateEngine.ensurePlayer(state.players[i], i, state.startingLife)
        local cCol = ((i - 1) % 2)
        local cRow = math.floor((i - 1) / 2)
        local px = 8 + cCol * (colW + 8)
        local py = availY + cRow * (rowH + 8)

        ui.drawRounded(px, py, colW, rowH, 12, 2, ui.C_BLACK)

        local pName = p.name or ("Player " .. i)
        if state.monarch == i then pName = pName .. " [CROWN]" end
        if state.initiative == i then pName = pName .. " [INIT]" end
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("ui_10"), px + 12, py + 8, pName, ui.C_BLACK)
        end

        local lifeY = py + math.floor(rowH / 2)
        local lifeX = px + math.floor(colW / 2)
        local digitH = math.min(52, rowH - 46)
        local digitW = math.floor(digitH * 0.55)
        local strokeW = 6
        ui.drawBigNumber(lifeX, lifeY, p.life, digitW, digitH, strokeW, ui.C_BLACK)

        local statStr = "Poison: " .. safeNum(p.poison, 0)
        local maxCmdr = 0
        for _, d in ipairs(p.cmdrDmg or {}) do
            local val = safeNum(d, 0)
            if val > maxCmdr then maxCmdr = val end
        end
        if maxCmdr > 0 then statStr = statStr .. "  |  Cmdr: " .. maxCmdr end
        local pTax = safeNum(p.tax, 0)
        if pTax > 0 then statStr = statStr .. "  |  Tax: +" .. (pTax * 2) end
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("small"), px + 12, py + rowH - 22, statStr, ui.C_BLACK)
        end
    end

    local footText = "CrossPoint Reader Ecosystem"
    local fw = ui.getTextWidth(ui.getFont("small"), footText)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("small"), math.floor((w - fw) / 2), h - 22, footText, ui.C_BLACK)
    end
end

return sleepView
