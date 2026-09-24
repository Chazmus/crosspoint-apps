-- ============================================================================
-- Spell Counter - Main Application Coordinator
-- MTG Life & Commander Companion for CrossPoint Reader
-- ============================================================================

local stateEngine = require("state")
local ui = require("ui")
local grid = require("views.grid")
local playerModal = require("views.player_modal")
local toolsModal = require("views.tools_modal")
local settingsModal = require("views.settings_modal")
local sleepView = require("views.sleep_view")

-- Application runtime UI state
local appUI = {
    modal = nil,             -- nil, "player_detail", "tools", "reset", "player_count"
    detailPlayer = 1,
    linkCmdrDamage = true,
    toolsTab = "dice",       -- "dice", "tokens", "history"
    diceResult = nil,
    firstPlayerResult = nil,
}

local function safeNum(n, def)
    local v = tonumber(n)
    return (v ~= nil) and v or (def or 0)
end

local function safeInt(n, def)
    local v = tonumber(n)
    return (v ~= nil) and math.floor(v) or (def or 0)
end

function onEnter()
    stateEngine.loadState()
    appUI.modal = nil
    appUI.detailPlayer = math.max(1, math.min(stateEngine.state.playerCount or 4, safeInt(stateEngine.state.selectedPlayer, 1)))
    appUI.toolsTab = "dice"
    appUI.diceResult = nil
    appUI.firstPlayerResult = nil

    if crosspoint and crosspoint.getSleepApp and crosspoint.setSleepApp then
        local curSleep = crosspoint.getSleepApp()
        if curSleep == "" or curSleep == nil then
            crosspoint.setSleepApp("spellcounter")
        end
    end
    if log and log.info then
        log.info("SPELLCOUNTER", "Started spellcounter (" .. stateEngine.state.playerCount .. " players)")
    end
    if crosspoint and crosspoint.requestUpdate then
        crosspoint.requestUpdate()
    end
end

function onDraw()
    local w = (gfx and gfx.getWidth and gfx.getWidth()) or 800
    local h = (gfx and gfx.getHeight and gfx.getHeight()) or 480
    local st = stateEngine.state
    local pc = math.max(1, math.min(4, safeInt(st.playerCount, 4)))

    if gfx and gfx.clearScreen then
        gfx.clearScreen(1)
    end

    local rects, headerH = grid.getCardRects(w, h, pc)
    grid.drawTopBar(w, headerH, st)

    for i = 1, pc do
        local p = st.players[i]
        local r = rects[i]
        if r and p then
            grid.drawPlayerCard(p, r, i == st.selectedPlayer, st)
        end
    end

    -- Modals overlay
    if appUI.modal == "player_detail" then
        playerModal.draw(w, h, st, appUI.detailPlayer, appUI.linkCmdrDamage)
    elseif appUI.modal == "tools" then
        toolsModal.draw(w, h, st, appUI.toolsTab, appUI.diceResult, appUI.firstPlayerResult)
    elseif appUI.modal == "reset" then
        settingsModal.drawReset(w, h)
    elseif appUI.modal == "player_count" then
        settingsModal.drawPlayerCount(w, h, st.playerCount)
    end
end

function onTouch(x, y)
    x = safeNum(x, 0)
    y = safeNum(y, 0)
    local w = (gfx and gfx.getWidth and gfx.getWidth()) or 800
    local h = (gfx and gfx.getHeight and gfx.getHeight()) or 480
    local st = stateEngine.state
    local pc = math.max(1, math.min(4, safeInt(st.playerCount, 4)))

    -- -----------------------------------------------------------------------
    -- 1. Active Modal Touches
    -- -----------------------------------------------------------------------
    if appUI.modal == "player_detail" then
        local handled = playerModal.handleTouch(
            x, y, w, h, st, appUI.detailPlayer, appUI.linkCmdrDamage,
            function() -- onClose
                appUI.modal = nil
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function() -- onToggleLink
                appUI.linkCmdrDamage = not appUI.linkCmdrDamage
                stateEngine.saveState()
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end
        )
        if handled and crosspoint and crosspoint.requestUpdate then
            crosspoint.requestUpdate()
        end
        return
    end

    if appUI.modal == "tools" then
        local handled = toolsModal.handleTouch(
            x, y, w, h, st, appUI.toolsTab,
            function(newTab) -- onSwitchTab
                appUI.toolsTab = newTab
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function() -- onClose
                appUI.modal = nil
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function(sides) -- onRollDice
                math.randomseed((crosspoint and crosspoint.millis and crosspoint.millis()) or 12345)
                local roll = math.random(1, sides)
                appUI.diceResult = {type = "D" .. sides, val = roll}
                appUI.firstPlayerResult = nil
                stateEngine.addHistory("D" .. sides .. " roll: " .. roll)
                stateEngine.saveState()
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function() -- onFlipCoin
                math.randomseed((crosspoint and crosspoint.millis and crosspoint.millis()) or 12345)
                local flip = (math.random(1, 2) == 1) and "HEADS" or "TAILS"
                appUI.diceResult = {type = "COIN", val = flip}
                appUI.firstPlayerResult = nil
                stateEngine.addHistory("Coin flip: " .. flip)
                stateEngine.saveState()
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function() -- onPickFirst
                math.randomseed((crosspoint and crosspoint.millis and crosspoint.millis()) or 12345)
                local fp = math.random(1, pc)
                appUI.firstPlayerResult = fp
                appUI.diceResult = nil
                local fpPlayer = stateEngine.ensurePlayer(st.players[fp], fp, st.startingLife)
                stateEngine.addHistory("First player: " .. (fpPlayer.name or ("P" .. fp)))
                stateEngine.saveState()
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end
        )
        if handled and crosspoint and crosspoint.requestUpdate then
            crosspoint.requestUpdate()
        end
        return
    end

    if appUI.modal == "reset" then
        local handled = settingsModal.handleResetTouch(
            x, y, w, h,
            function(life) -- onSelectLife
                stateEngine.initNewGame(life, st.playerCount)
                appUI.modal = nil
                stateEngine.saveState()
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function() -- onCancel
                appUI.modal = nil
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end
        )
        if handled and crosspoint and crosspoint.requestUpdate then
            crosspoint.requestUpdate()
        end
        return
    end

    if appUI.modal == "player_count" then
        local handled = settingsModal.handlePlayerCountTouch(
            x, y, w, h,
            function(count) -- onSelectCount
                st.playerCount = count
                st.selectedPlayer = math.min(safeInt(st.selectedPlayer, 1), count)
                appUI.modal = nil
                stateEngine.saveState()
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function() -- onCancel
                appUI.modal = nil
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end
        )
        if handled and crosspoint and crosspoint.requestUpdate then
            crosspoint.requestUpdate()
        end
        return
    end

    -- -----------------------------------------------------------------------
    -- 2. Top Bar Interactions
    -- -----------------------------------------------------------------------
    local rects, headerH = grid.getCardRects(w, h, pc)
    if y <= headerH then
        local pcText = pc .. " Player" .. (pc > 1 and "s" or "")
        local pcW = ui.getTextWidth(ui.getFont("ui_10"), pcText) + 16
        if x >= 10 and x <= 10 + pcW then
            appUI.modal = "player_count"
            if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            return
        end

        local rightX = w - 10
        local toolsText = "Tools"
        local toolsW = ui.getTextWidth(ui.getFont("ui_10"), toolsText) + 16
        rightX = rightX - toolsW
        if x >= rightX and x <= rightX + toolsW then
            appUI.modal = "tools"
            appUI.toolsTab = "dice"
            if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            return
        end

        rightX = rightX - 8
        local resetText = "Reset"
        local resetW = ui.getTextWidth(ui.getFont("ui_10"), resetText) + 16
        rightX = rightX - resetW
        if x >= rightX and x <= rightX + resetW then
            appUI.modal = "reset"
            if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            return
        end
        return
    end

    -- -----------------------------------------------------------------------
    -- 3. Player Card Interactions
    -- -----------------------------------------------------------------------
    for i = 1, pc do
        local r = rects[i]
        if r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            st.selectedPlayer = i

            -- Card Menu / Counter detail icon [···] top right
            local menuBtnW = 44
            local menuBtnH = 24
            local menuBtnX = r.x + r.w - menuBtnW - 8
            local menuBtnY = r.y + 4
            if x >= menuBtnX and x <= menuBtnX + menuBtnW and y >= menuBtnY and y <= menuBtnY + menuBtnH then
                appUI.detailPlayer = i
                appUI.modal = "player_detail"
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
                return
            end

            -- Bottom Counters Strip (Poison, Commander, Tax)
            local stripH = 34
            local stripY = r.y + r.h - stripH - 4
            if y >= stripY then
                local cx = r.x + 12
                local p = stateEngine.ensurePlayer(st.players[i], i, st.startingLife)
                local pStr = "P: " .. safeNum(p.poison, 0)
                local pw = ui.getTextWidth(ui.getFont("small"), pStr) + 16
                if x >= cx and x <= cx + pw then
                    stateEngine.changePoison(i, 1)
                    if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
                    return
                end
                cx = cx + pw + 8

                local cw = 70
                if x >= cx and x <= cx + cw then
                    appUI.detailPlayer = i
                    appUI.modal = "player_detail"
                    if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
                    return
                end

                appUI.detailPlayer = i
                appUI.modal = "player_detail"
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
                return
            end

            -- Quick +/- 5 buttons if card height allows
            local cardHeaderH = 30
            local lifeCenterY = r.y + cardHeaderH + math.floor((r.h - cardHeaderH - 42) / 2)
            local btnSize = math.min(46, math.floor(r.h * 0.28))
            local minusX = r.x + 14
            local plusX = r.x + r.w - btnSize - 14
            local btnY = lifeCenterY - math.floor(btnSize / 2)
            local pillW = 38
            local pillH = 22
            local pillY = btnY + btnSize + 6

            if r.h >= 180 and y >= pillY and y <= pillY + pillH then
                if x >= minusX and x <= minusX + btnSize then
                    stateEngine.changeLife(i, -5)
                    if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
                    return
                elseif x >= plusX and x <= plusX + btnSize then
                    stateEngine.changeLife(i, 5)
                    if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
                    return
                end
            end

            -- Main Life +/- Buttons / Half-card tap
            if x < r.x + math.floor(r.w / 2) then
                stateEngine.changeLife(i, -1)
            else
                stateEngine.changeLife(i, 1)
            end
            if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            return
        end
    end
end

function onInput(button, isDown)
    if not isDown and isDown ~= nil and isDown ~= "press" then
        return
    end

    button = safeNum(button, -1)
    local st = stateEngine.state
    local pc = math.max(1, math.min(4, safeInt(st.playerCount, 4)))
    local sel = math.max(1, math.min(pc, safeInt(st.selectedPlayer, 1)))

    if input and button == input.BTN_CONFIRM then
        if appUI.modal == nil then
            appUI.detailPlayer = sel
            appUI.modal = "player_detail"
            if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
        else
            appUI.modal = nil
            if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
        end
    elseif input and (button == input.BTN_UP or button == input.BTN_PAGE_BACK) then
        if appUI.modal == nil then
            stateEngine.changeLife(sel, 1)
            if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
        end
    elseif input and (button == input.BTN_DOWN or button == input.BTN_PAGE_FORWARD) then
        if appUI.modal == nil then
            stateEngine.changeLife(sel, -1)
            if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
        end
    elseif input and button == input.BTN_RIGHT then
        st.selectedPlayer = (sel % pc) + 1
        stateEngine.saveState()
        if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
    elseif input and button == input.BTN_LEFT then
        st.selectedPlayer = ((sel - 2 + pc) % pc) + 1
        stateEngine.saveState()
        if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
    end
end

function onBack()
    if appUI.modal ~= nil then
        appUI.modal = nil
        if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
        return true
    end
    return false
end

function onUpdate(dt)
    local now = (crosspoint and crosspoint.millis and crosspoint.millis()) or 0
    if stateEngine.clearExpiredDeltas(now) then
        if crosspoint and crosspoint.requestUpdate then
            crosspoint.requestUpdate()
        end
    end
end

function onSleepDraw()
    local w = (gfx and gfx.getWidth and gfx.getWidth()) or 800
    local h = (gfx and gfx.getHeight and gfx.getHeight()) or 480
    sleepView.draw(w, h, stateEngine.state)
end

function onExit()
    stateEngine.saveState()
    if log and log.info then
        log.info("SPELLCOUNTER", "Exiting spellcounter")
    end
end

-- Export for automated testing and inspection
if _G then
    _G._SPELLCOUNTER = {
        state = stateEngine.state,
        ui = appUI,
        appUI = appUI,
        stateEngine = stateEngine,
        drawUI = ui,
        saveState = stateEngine.saveState,
        loadState = stateEngine.loadState,
        initNewGame = stateEngine.initNewGame,
        ensurePlayer = stateEngine.ensurePlayer,
        changeLife = stateEngine.changeLife,
        changePoison = stateEngine.changePoison,
        changeCmdrDamage = stateEngine.changeCmdrDamage,
    }
end
