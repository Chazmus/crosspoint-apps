-- ============================================================================
-- Spell Counter - Player Details & Counters Modal View
-- Adjusts life, poison, commander damage, tax, energy, experience, storm.
-- ============================================================================

local ui = require("ui")
local stateEngine = require("state")

local playerModal = {}

local function safeNum(n, def)
    local v = tonumber(n)
    return (v ~= nil) and v or (def or 0)
end

local function safeInt(n, def)
    local v = tonumber(n)
    return (v ~= nil) and math.floor(v) or (def or 0)
end

function playerModal.draw(w, h, state, detailPlayer, linkCmdrDamage)
    w = safeNum(w, 800)
    h = safeNum(h, 480)
    local dIdx = math.max(1, math.min(4, safeInt(detailPlayer, 1)))
    local p = stateEngine.ensurePlayer(state.players[dIdx], dIdx, state.startingLife or 40)
    state.players[dIdx] = p

    local mw = math.min(680, w - 30)
    local mh = math.min(430, h - 20)
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    ui.fillRounded(mx, my, mw, mh, 16, ui.C_WHITE)
    ui.drawRounded(mx, my, mw, mh, 16, 3, ui.C_BLACK)

    -- Header Bar
    if gfx and gfx.fillRect then
        gfx.fillRect(mx + 3, my + 3, mw - 6, 42, ui.C_BLACK)
    end
    local titleText = p.name .. " - COUNTERS & DETAILS"
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_12"), mx + 16, my + 10, titleText, ui.C_WHITE)
    end

    -- Name Cycle button
    local nameBtnW = 110
    local nameBtnX = mx + mw - nameBtnW - 56
    ui.drawButton(nameBtnX, my + 7, nameBtnW, 28, "Cycle Name", ui.getFont("small"), ui.C_WHITE, false)

    -- Close [X] button
    local closeX = mx + mw - 46
    ui.drawButton(closeX, my + 7, 36, 28, "X", ui.getFont("ui_10"), ui.C_WHITE, false)

    local rowY = my + 54

    -- Row 1: Life Controls
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_10"), mx + 20, rowY + 6, "Life Total: " .. safeNum(p.life, 40), ui.C_BLACK)
    end
    local btnX = mx + 200
    local lifeDeltas = {-10, -5, -1, 1, 5, 10}
    for _, delta in ipairs(lifeDeltas) do
        local dStr = (delta > 0 and "+" or "") .. delta
        ui.drawButton(btnX, rowY, 44, 32, dStr, ui.getFont("small"), ui.C_BLACK, false)
        btnX = btnX + 50
    end

    -- Row 2: Poison Counters
    rowY = rowY + 44
    local pCount = safeNum(p.poison, 0)
    local poisStr = "Poison Counters: " .. pCount .. (pCount >= 10 and " [LETHAL!]" or "")
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_10"), mx + 20, rowY + 6, poisStr, ui.C_BLACK)
    end
    btnX = mx + 200
    ui.drawButton(btnX, rowY, 44, 32, "-", ui.getFont("ui_10"), ui.C_BLACK, false)
    ui.drawButton(btnX + 50, rowY, 44, 32, "+", ui.getFont("ui_10"), ui.C_BLACK, false)

    -- Row 3: Commander Damage Received
    rowY = rowY + 44
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_10"), mx + 20, rowY + 6, "Commander Damage:", ui.C_BLACK)
    end
    btnX = mx + 200
    local pc = math.max(1, math.min(4, safeInt(state.playerCount, 4)))
    for opp = 1, pc do
        if opp ~= p.id then
            local dmg = safeNum(p.cmdrDmg and p.cmdrDmg[opp], 0)
            local oppName = "P" .. opp
            local cw = 94
            local isLethal = (dmg >= 21)
            if isLethal then
                ui.fillRounded(btnX, rowY - 2, cw, 34, 6, ui.C_BLACK)
                local valText = oppName .. ":" .. dmg
                local vw = ui.getTextWidth(ui.getFont("small"), valText)
                if gfx and gfx.drawText then
                    gfx.drawText(ui.getFont("small"), btnX + math.floor((cw - vw) / 2), rowY + 6, valText, ui.C_WHITE)
                end
                ui.drawButton(btnX + 3, rowY + 2, 24, 26, "-", ui.getFont("small"), ui.C_WHITE, false)
                ui.drawButton(btnX + cw - 27, rowY + 2, 24, 26, "+", ui.getFont("small"), ui.C_WHITE, false)
            else
                ui.drawRounded(btnX, rowY - 2, cw, 34, 6, 1, ui.C_BLACK)
                local valText = oppName .. ":" .. dmg
                local vw = ui.getTextWidth(ui.getFont("small"), valText)
                if gfx and gfx.drawText then
                    gfx.drawText(ui.getFont("small"), btnX + math.floor((cw - vw) / 2), rowY + 6, valText, ui.C_BLACK)
                end
                ui.drawButton(btnX + 3, rowY + 2, 24, 26, "-", ui.getFont("small"), ui.C_BLACK, false)
                ui.drawButton(btnX + cw - 27, rowY + 2, 24, 26, "+", ui.getFont("small"), ui.C_BLACK, false)
            end
            btnX = btnX + cw + 10
        end
    end

    -- Row 4: Commander Tax, Energy, Experience
    rowY = rowY + 44
    local pTax = safeNum(p.tax, 0)
    local taxLabel = "Tax: " .. pTax .. " (+" .. (pTax * 2) .. ")"
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("small"), mx + 20, rowY + 6, taxLabel, ui.C_BLACK)
    end
    ui.drawButton(mx + 130, rowY, 32, 28, "-", ui.getFont("small"), ui.C_BLACK, false)
    ui.drawButton(mx + 168, rowY, 32, 28, "+", ui.getFont("small"), ui.C_BLACK, false)

    -- Energy
    local energyLabel = "Energy: " .. safeNum(p.energy, 0)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("small"), mx + 224, rowY + 6, energyLabel, ui.C_BLACK)
    end
    ui.drawButton(mx + 314, rowY, 32, 28, "-", ui.getFont("small"), ui.C_BLACK, false)
    ui.drawButton(mx + 352, rowY, 32, 28, "+", ui.getFont("small"), ui.C_BLACK, false)

    -- Experience
    local xpLabel = "XP: " .. safeNum(p.experience, 0)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("small"), mx + 408, rowY + 6, xpLabel, ui.C_BLACK)
    end
    ui.drawButton(mx + 478, rowY, 32, 28, "-", ui.getFont("small"), ui.C_BLACK, false)
    ui.drawButton(mx + 516, rowY, 32, 28, "+", ui.getFont("small"), ui.C_BLACK, false)

    -- Row 5: Storm count, Invert Theme, Link Checkbox
    rowY = rowY + 42
    local stormLabel = "Storm Count: " .. safeNum(p.storm, 0)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("small"), mx + 20, rowY + 6, stormLabel, ui.C_BLACK)
    end
    ui.drawButton(mx + 130, rowY, 32, 28, "-", ui.getFont("small"), ui.C_BLACK, false)
    ui.drawButton(mx + 168, rowY, 32, 28, "+", ui.getFont("small"), ui.C_BLACK, false)
    ui.drawButton(mx + 206, rowY, 84, 28, "Reset Storm", ui.getFont("small"), ui.C_BLACK, false)

    -- Invert Card Color Toggle
    local invText = p.inverted and "Card: Dark" or "Card: Light"
    ui.drawButton(mx + 304, rowY, 130, 28, invText, ui.getFont("small"), ui.C_BLACK, false)

    -- Auto-link Cmdr Damage to Life Checkbox
    local linkText = linkCmdrDamage and "[X] Cmdr Dmg reduces life" or "[ ] Cmdr Dmg reduces life"
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("small"), mx + 450, rowY + 6, linkText, ui.C_BLACK)
    end
end

function playerModal.handleTouch(x, y, w, h, state, detailPlayer, linkCmdrDamage, onClose, onToggleLink)
    local dIdx = math.max(1, math.min(4, safeInt(detailPlayer, 1)))
    local p = stateEngine.ensurePlayer(state.players[dIdx], dIdx, state.startingLife or 40)
    state.players[dIdx] = p

    local mw = math.min(680, w - 30)
    local mh = math.min(430, h - 20)
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    -- Close [X]
    local closeX = mx + mw - 46
    if x >= closeX and x <= closeX + 36 and y >= my + 7 and y <= my + 35 then
        if log and log.info then log.info("MODAL", "Closed player_detail modal") end
        onClose()
        return true
    end

    -- Name Cycle button
    local nameBtnW = 110
    local nameBtnX = mx + mw - nameBtnW - 56
    if x >= nameBtnX and x <= nameBtnX + nameBtnW and y >= my + 7 and y <= my + 35 then
        stateEngine.cyclePlayerName(p.id)
        return true
    end

    local rowY = my + 54

    -- Row 1: Life +/- buttons
    if y >= rowY and y <= rowY + 32 then
        local btnX = mx + 200
        local lifeDeltas = {-10, -5, -1, 1, 5, 10}
        for _, delta in ipairs(lifeDeltas) do
            if x >= btnX and x <= btnX + 44 then
                stateEngine.changeLife(p.id, delta)
                return true
            end
            btnX = btnX + 50
        end
    end

    -- Row 2: Poison +/-
    rowY = rowY + 44
    if y >= rowY and y <= rowY + 32 then
        local btnX = mx + 200
        if x >= btnX and x <= btnX + 44 then
            stateEngine.changePoison(p.id, -1)
            return true
        elseif x >= btnX + 50 and x <= btnX + 94 then
            stateEngine.changePoison(p.id, 1)
            return true
        end
    end

    -- Row 3: Commander Damage from opponents
    rowY = rowY + 44
    local pc = math.max(1, math.min(4, safeInt(state.playerCount, 4)))
    if y >= rowY - 2 and y <= rowY + 32 then
        local btnX = mx + 200
        for opp = 1, pc do
            if opp ~= p.id then
                local cw = 94
                if x >= btnX and x <= btnX + cw then
                    if x <= btnX + 30 then
                        stateEngine.changeCmdrDamage(p.id, opp, -1, linkCmdrDamage)
                    elseif x >= btnX + cw - 30 then
                        stateEngine.changeCmdrDamage(p.id, opp, 1, linkCmdrDamage)
                    end
                    return true
                end
                btnX = btnX + cw + 10
            end
        end
    end

    -- Row 4: Tax, Energy, Experience
    rowY = rowY + 44
    if y >= rowY and y <= rowY + 28 then
        if x >= mx + 130 and x <= mx + 162 then
            p.tax = math.max(0, safeNum(p.tax, 0) - 1)
            stateEngine.saveState()
            return true
        elseif x >= mx + 168 and x <= mx + 200 then
            p.tax = safeNum(p.tax, 0) + 1
            stateEngine.saveState()
            return true
        elseif x >= mx + 314 and x <= mx + 346 then
            p.energy = math.max(0, safeNum(p.energy, 0) - 1)
            stateEngine.saveState()
            return true
        elseif x >= mx + 352 and x <= mx + 384 then
            p.energy = safeNum(p.energy, 0) + 1
            stateEngine.saveState()
            return true
        elseif x >= mx + 478 and x <= mx + 510 then
            p.experience = math.max(0, safeNum(p.experience, 0) - 1)
            stateEngine.saveState()
            return true
        elseif x >= mx + 516 and x <= mx + 548 then
            p.experience = safeNum(p.experience, 0) + 1
            stateEngine.saveState()
            return true
        end
    end

    -- Row 5: Storm, Invert theme, Link toggle
    rowY = rowY + 42
    if y >= rowY and y <= rowY + 28 then
        if x >= mx + 130 and x <= mx + 162 then
            p.storm = math.max(0, safeNum(p.storm, 0) - 1)
            stateEngine.saveState()
            return true
        elseif x >= mx + 168 and x <= mx + 200 then
            p.storm = safeNum(p.storm, 0) + 1
            stateEngine.saveState()
            return true
        elseif x >= mx + 206 and x <= mx + 290 then
            p.storm = 0
            stateEngine.saveState()
            return true
        elseif x >= mx + 304 and x <= mx + 434 then
            p.inverted = not p.inverted
            stateEngine.saveState()
            return true
        elseif x >= mx + 440 and x <= mx + mw - 10 then
            onToggleLink()
            return true
        end
    end

    -- Backdrop tap outside modal closes modal
    if x < mx or x > mx + mw or y < my or y > my + mh then
        onClose()
        return true
    end

    return true -- Consume all touches inside modal
end

return playerModal
