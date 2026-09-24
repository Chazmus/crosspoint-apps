-- ============================================================================
-- Spell Counter - Tools & Utilities Modal View
-- Dice rolling (D20, D6), Coin flip, First player picker, Monarch,
-- Initiative, Day/Night tracking, and Game event history log.
-- ============================================================================

local ui = require("ui")
local stateEngine = require("state")

local toolsModal = {}

local function safeNum(n, def)
    local v = tonumber(n)
    return (v ~= nil) and v or (def or 0)
end

local function safeInt(n, def)
    local v = tonumber(n)
    return (v ~= nil) and math.floor(v) or (def or 0)
end

function toolsModal.draw(w, h, state, activeTab, diceResult, firstPlayerResult)
    w = safeNum(w, 800)
    h = safeNum(h, 480)
    local mw = math.min(640, w - 40)
    local mh = math.min(410, h - 30)
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    ui.fillRounded(mx, my, mw, mh, 16, ui.C_WHITE)
    ui.drawRounded(mx, my, mw, mh, 16, 3, ui.C_BLACK)

    -- Header Bar
    if gfx and gfx.fillRect then
        gfx.fillRect(mx + 3, my + 3, mw - 6, 38, ui.C_BLACK)
    end
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_10"), mx + 16, my + 11, "GAME TOOLS & UTILITIES", ui.C_WHITE)
    end

    -- Close [X] button
    local closeX = mx + mw - 46
    ui.drawButton(closeX, my + 7, 36, 28, "X", ui.getFont("ui_10"), ui.C_WHITE, false)

    -- Tabs: [Dice & Coin] | [Tokens & Status] | [Game Log]
    local tabY = my + 48
    local tabW = math.floor((mw - 40) / 3)

    ui.drawButton(mx + 16, tabY, tabW, 30, "Dice & Coin", ui.getFont("small"), ui.C_BLACK, activeTab == "dice")
    ui.drawButton(mx + 20 + tabW, tabY, tabW, 30, "Tokens & Status", ui.getFont("small"), ui.C_BLACK, activeTab == "tokens")
    ui.drawButton(mx + 24 + tabW * 2, tabY, tabW, 30, "Game Log", ui.getFont("small"), ui.C_BLACK, activeTab == "history")

    local contentY = tabY + 42

    -- Tab Content 1: Dice & Coin
    if activeTab == "dice" then
        local btnW = 126
        local btnH = 38
        local bx = mx + 24

        ui.drawButton(bx, contentY, btnW, btnH, "Roll D20", ui.getFont("ui_10"), ui.C_BLACK, false)
        bx = bx + btnW + 16
        ui.drawButton(bx, contentY, btnW, btnH, "Roll D6", ui.getFont("ui_10"), ui.C_BLACK, false)
        bx = bx + btnW + 16
        ui.drawButton(bx, contentY, btnW, btnH, "Flip Coin", ui.getFont("ui_10"), ui.C_BLACK, false)
        bx = bx + btnW + 16
        if bx + btnW <= mx + mw - 16 then
            ui.drawButton(bx, contentY, btnW, btnH, "Who 1st?", ui.getFont("ui_10"), ui.C_BLACK, false)
        end

        -- Big Dice Result Box
        local resBoxY = contentY + btnH + 18
        local resBoxW = mw - 48
        local resBoxH = mh - (resBoxY - my) - 18
        ui.drawRounded(mx + 24, resBoxY, resBoxW, resBoxH, 12, 2, ui.C_BLACK)

        if diceResult then
            local header = (diceResult.type or "DICE") .. " RESULT:"
            local hw = ui.getTextWidth(ui.getFont("small"), header)
            if gfx and gfx.drawText then
                gfx.drawText(ui.getFont("small"), mx + 24 + math.floor((resBoxW - hw) / 2), resBoxY + 16, header, ui.C_BLACK)
            end

            local resStr = tostring(diceResult.val or "?")
            local rw = ui.getTextWidth(ui.getFont("ui_12"), resStr)
            if gfx and gfx.drawText then
                gfx.drawText(ui.getFont("ui_12"), mx + 24 + math.floor((resBoxW - rw) / 2), resBoxY + 48, resStr, ui.C_BLACK)
            end
        elseif firstPlayerResult then
            local fp = math.max(1, math.min(4, safeInt(firstPlayerResult, 1)))
            local fpPlayer = stateEngine.ensurePlayer(state.players[fp], fp, state.startingLife)
            local header = "RANDOM STARTING PLAYER:"
            local hw = ui.getTextWidth(ui.getFont("ui_10"), header)
            if gfx and gfx.drawText then
                gfx.drawText(ui.getFont("ui_10"), mx + 24 + math.floor((resBoxW - hw) / 2), resBoxY + 24, header, ui.C_BLACK)
            end

            local resText = "-> " .. (fpPlayer.name or ("Player " .. fp)) .. " GOES FIRST! <-"
            local rw = ui.getTextWidth(ui.getFont("ui_12"), resText)
            if gfx and gfx.drawText then
                gfx.drawText(ui.getFont("ui_12"), mx + 24 + math.floor((resBoxW - rw) / 2), resBoxY + 54, resText, ui.C_BLACK)
            end
        else
            local hint = "Tap a button above to roll dice or pick starting player"
            local hw = ui.getTextWidth(ui.getFont("small"), hint)
            if gfx and gfx.drawText then
                gfx.drawText(ui.getFont("small"), mx + 24 + math.floor((resBoxW - hw) / 2), resBoxY + math.floor(resBoxH / 2) - 8, hint, ui.C_BLACK)
            end
        end

    -- Tab Content 2: Tokens & Status (Monarch, Initiative, Day/Night)
    elseif activeTab == "tokens" then
        local rowY = contentY + 4
        local pc = math.max(1, math.min(4, safeInt(state.playerCount, 4)))

        -- 1. Monarch
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("ui_10"), mx + 24, rowY + 6, "The Monarch:", ui.C_BLACK)
        end
        local btnX = mx + 160
        for i = 1, pc do
            ui.drawButton(btnX, rowY, 52, 32, "P" .. i, ui.getFont("small"), ui.C_BLACK, state.monarch == i)
            btnX = btnX + 60
        end
        ui.drawButton(btnX, rowY, 68, 32, "Clear", ui.getFont("small"), ui.C_BLACK, false)

        -- 2. Initiative
        rowY = rowY + 48
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("ui_10"), mx + 24, rowY + 6, "Initiative:", ui.C_BLACK)
        end
        btnX = mx + 160
        for i = 1, pc do
            ui.drawButton(btnX, rowY, 52, 32, "P" .. i, ui.getFont("small"), ui.C_BLACK, state.initiative == i)
            btnX = btnX + 60
        end
        ui.drawButton(btnX, rowY, 68, 32, "Clear", ui.getFont("small"), ui.C_BLACK, false)

        -- 3. Day / Night
        rowY = rowY + 48
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("ui_10"), mx + 24, rowY + 6, "Day / Night:", ui.C_BLACK)
        end
        btnX = mx + 160
        local modes = {{"none", "Off"}, {"day", "Day"}, {"night", "Night"}}
        for _, m in ipairs(modes) do
            ui.drawButton(btnX, rowY, 74, 32, m[2], ui.getFont("small"), ui.C_BLACK, state.dayNight == m[1])
            btnX = btnX + 82
        end

    -- Tab Content 3: Game History Log
    elseif activeTab == "history" then
        local logBoxY = contentY
        local logBoxH = mh - (logBoxY - my) - 20
        ui.drawRounded(mx + 20, logBoxY, mw - 40, logBoxH, 10, 1, ui.C_BLACK)

        local lineY = logBoxY + 8
        local maxLines = math.floor((logBoxH - 16) / 20)
        local hList = (type(state.history) == "table") and state.history or {}
        for i = 1, math.min(#hList, maxLines) do
            if gfx and gfx.drawText then
                gfx.drawText(ui.getFont("small"), mx + 32, lineY, tostring(hList[i]), ui.C_BLACK)
            end
            lineY = lineY + 20
        end
        if #hList == 0 then
            local emptyMsg = "No events recorded yet."
            local ew = ui.getTextWidth(ui.getFont("small"), emptyMsg)
            if gfx and gfx.drawText then
                gfx.drawText(ui.getFont("small"), mx + 20 + math.floor((mw - 40 - ew) / 2), logBoxY + 30, emptyMsg, ui.C_BLACK)
            end
        end
    end
end

function toolsModal.handleTouch(x, y, w, h, state, activeTab, onSwitchTab, onClose, onRollDice, onFlipCoin, onPickFirst)
    local mw = math.min(640, w - 40)
    local mh = math.min(410, h - 30)
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)
    local pc = math.max(1, math.min(4, safeInt(state.playerCount, 4)))

    -- Close [X]
    local closeX = mx + mw - 46
    if x >= closeX and x <= closeX + 36 and y >= my + 7 and y <= my + 35 then
        if log and log.info then log.info("MODAL", "Closed tools modal") end
        onClose()
        return true
    end

    -- Tab switching
    local tabY = my + 48
    local tabW = math.floor((mw - 40) / 3)
    if y >= tabY and y <= tabY + 30 then
        if x >= mx + 16 and x <= mx + 16 + tabW then
            onSwitchTab("dice")
            return true
        elseif x >= mx + 20 + tabW and x <= mx + 20 + tabW * 2 then
            onSwitchTab("tokens")
            return true
        elseif x >= mx + 24 + tabW * 2 and x <= mx + 24 + tabW * 3 then
            onSwitchTab("history")
            return true
        end
    end

    local contentY = tabY + 42

    -- Dice tab actions
    if activeTab == "dice" and y >= contentY and y <= contentY + 38 then
        local btnW = 126
        local bx = mx + 24
        if x >= bx and x <= bx + btnW then
            onRollDice(20)
            return true
        end
        bx = bx + btnW + 16
        if x >= bx and x <= bx + btnW then
            onRollDice(6)
            return true
        end
        bx = bx + btnW + 16
        if x >= bx and x <= bx + btnW then
            onFlipCoin()
            return true
        end
        bx = bx + btnW + 16
        if x >= bx and x <= bx + btnW then
            onPickFirst()
            return true
        end
    end

    -- Tokens tab actions
    if activeTab == "tokens" then
        local rowY = contentY + 4

        -- Monarch row
        if y >= rowY and y <= rowY + 32 then
            local btnX = mx + 160
            for i = 1, pc do
                if x >= btnX and x <= btnX + 52 then
                    state.monarch = (state.monarch == i) and nil or i
                    local pP = stateEngine.ensurePlayer(state.players[i], i, state.startingLife)
                    stateEngine.addHistory("Monarch: " .. (state.monarch and pP.name or "None"))
                    stateEngine.saveState()
                    return true
                end
                btnX = btnX + 60
            end
            if x >= btnX and x <= btnX + 68 then
                state.monarch = nil
                stateEngine.addHistory("Monarch cleared")
                stateEngine.saveState()
                return true
            end
        end

        -- Initiative row
        rowY = rowY + 48
        if y >= rowY and y <= rowY + 32 then
            local btnX = mx + 160
            for i = 1, pc do
                if x >= btnX and x <= btnX + 52 then
                    state.initiative = (state.initiative == i) and nil or i
                    local pP = stateEngine.ensurePlayer(state.players[i], i, state.startingLife)
                    stateEngine.addHistory("Initiative: " .. (state.initiative and pP.name or "None"))
                    stateEngine.saveState()
                    return true
                end
                btnX = btnX + 60
            end
            if x >= btnX and x <= btnX + 68 then
                state.initiative = nil
                stateEngine.addHistory("Initiative cleared")
                stateEngine.saveState()
                return true
            end
        end

        -- Day / Night row
        rowY = rowY + 48
        if y >= rowY and y <= rowY + 32 then
            local btnX = mx + 160
            local modes = {"none", "day", "night"}
            for _, m in ipairs(modes) do
                if x >= btnX and x <= btnX + 74 then
                    state.dayNight = m
                    stateEngine.addHistory("Day/Night set to: " .. m)
                    stateEngine.saveState()
                    return true
                end
                btnX = btnX + 82
            end
        end
    end

    -- Backdrop tap outside modal closes modal
    if x < mx or x > mx + mw or y < my or y > my + mh then
        onClose()
        return true
    end

    return true -- Consume all touches inside modal
end

return toolsModal
