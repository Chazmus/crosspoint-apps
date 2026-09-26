-- ============================================================================
-- Spell Counter - Modal Dialog Manager & Tools Coordinator
-- Manages active modals, dialog rendering, and tool actions (dice, coin, first).
-- ============================================================================

local stateEngine = require("state")
local playerModal = require("views.player_modal")
local toolsModal = require("views.tools_modal")
local settingsModal = require("views.settings_modal")

local modalManager = {}

local function safeInt(n, def)
    local v = tonumber(n)
    return (v ~= nil) and math.floor(v) or (def or 0)
end

-- Internal runtime modal state
local uiState = {
    modal = nil,             -- nil, "player_detail", "tools", "reset", "player_count"
    detailPlayer = 1,
    linkCmdrDamage = true,
    toolsTab = "dice",       -- "dice", "tokens", "history"
    diceResult = nil,
    firstPlayerResult = nil,
}

modalManager.ui = uiState

function modalManager.init(defaultPlayer)
    uiState.modal = nil
    uiState.detailPlayer = defaultPlayer or 1
    uiState.toolsTab = "dice"
    uiState.diceResult = nil
    uiState.firstPlayerResult = nil
end

function modalManager.isOpen()
    return uiState.modal ~= nil
end

function modalManager.getActive()
    return uiState.modal
end

function modalManager.open(name, detailPlayer)
    uiState.modal = name
    if detailPlayer ~= nil then
        uiState.detailPlayer = detailPlayer
    end
    if name == "tools" and not uiState.toolsTab then
        uiState.toolsTab = "dice"
    end
    if crosspoint and crosspoint.requestUpdate then
        crosspoint.requestUpdate()
    end
end

function modalManager.close()
    uiState.modal = nil
    if crosspoint and crosspoint.requestUpdate then
        crosspoint.requestUpdate()
    end
end

function modalManager.draw(w, h, st)
    if not uiState.modal then return end

    if uiState.modal == "player_detail" then
        playerModal.draw(w, h, st, uiState.detailPlayer, uiState.linkCmdrDamage)
    elseif uiState.modal == "tools" then
        toolsModal.draw(w, h, st, uiState.toolsTab, uiState.diceResult, uiState.firstPlayerResult)
    elseif uiState.modal == "reset" then
        settingsModal.drawReset(w, h)
    elseif uiState.modal == "player_count" then
        settingsModal.drawPlayerCount(w, h, st.playerCount)
    end
end

function modalManager.handleTouch(x, y, w, h, st)
    if not uiState.modal then
        return false
    end

    local pc = math.max(1, math.min(4, safeInt(st.playerCount, 4)))

    if uiState.modal == "player_detail" then
        local handled = playerModal.handleTouch(
            x, y, w, h, st, uiState.detailPlayer, uiState.linkCmdrDamage,
            function() -- onClose
                uiState.modal = nil
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function() -- onToggleLink
                uiState.linkCmdrDamage = not uiState.linkCmdrDamage
                stateEngine.saveState()
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end
        )
        if handled and crosspoint and crosspoint.requestUpdate then
            crosspoint.requestUpdate()
        end
        return true
    end

    if uiState.modal == "tools" then
        local handled = toolsModal.handleTouch(
            x, y, w, h, st, uiState.toolsTab,
            function(newTab) -- onSwitchTab
                uiState.toolsTab = newTab
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function() -- onClose
                uiState.modal = nil
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function(sides) -- onRollDice
                math.randomseed((crosspoint and crosspoint.millis and crosspoint.millis()) or 12345)
                local roll = math.random(1, sides)
                uiState.diceResult = {type = "D" .. sides, val = roll}
                uiState.firstPlayerResult = nil
                stateEngine.addHistory("D" .. sides .. " roll: " .. roll)
                stateEngine.saveState()
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function() -- onFlipCoin
                math.randomseed((crosspoint and crosspoint.millis and crosspoint.millis()) or 12345)
                local flip = (math.random(1, 2) == 1) and "HEADS" or "TAILS"
                uiState.diceResult = {type = "COIN", val = flip}
                uiState.firstPlayerResult = nil
                stateEngine.addHistory("Coin flip: " .. flip)
                stateEngine.saveState()
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function() -- onPickFirst
                math.randomseed((crosspoint and crosspoint.millis and crosspoint.millis()) or 12345)
                local fp = math.random(1, pc)
                uiState.firstPlayerResult = fp
                uiState.diceResult = nil
                local fpPlayer = stateEngine.ensurePlayer(st.players[fp], fp, st.startingLife)
                stateEngine.addHistory("First player: " .. (fpPlayer.name or ("P" .. fp)))
                stateEngine.saveState()
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end
        )
        if handled and crosspoint and crosspoint.requestUpdate then
            crosspoint.requestUpdate()
        end
        return true
    end

    if uiState.modal == "reset" then
        local handled = settingsModal.handleResetTouch(
            x, y, w, h,
            function(life) -- onSelectLife
                stateEngine.initNewGame(life, st.playerCount)
                uiState.modal = nil
                stateEngine.saveState()
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function() -- onCancel
                uiState.modal = nil
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end
        )
        if handled and crosspoint and crosspoint.requestUpdate then
            crosspoint.requestUpdate()
        end
        return true
    end

    if uiState.modal == "player_count" then
        local handled = settingsModal.handlePlayerCountTouch(
            x, y, w, h,
            function(count) -- onSelectCount
                st.playerCount = count
                st.selectedPlayer = math.min(safeInt(st.selectedPlayer, 1), count)
                uiState.modal = nil
                stateEngine.saveState()
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end,
            function() -- onCancel
                uiState.modal = nil
                if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            end
        )
        if handled and crosspoint and crosspoint.requestUpdate then
            crosspoint.requestUpdate()
        end
        return true
    end

    return false
end

return modalManager
