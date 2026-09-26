-- ============================================================================
-- Spell Counter - Main Application Coordinator
-- MTG Life & Commander Companion for CrossPoint Reader
-- ============================================================================

local stateEngine = require("state")
local ui = require("ui")
local grid = require("views.grid")
local sleepView = require("views.sleep_view")
local modalManager = require("modal_manager")
local holdHandler = require("hold_handler")

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
    local defaultSel = math.max(1, math.min(stateEngine.state.playerCount or 4, safeInt(stateEngine.state.selectedPlayer, 1)))
    modalManager.init(defaultSel)

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

    -- Active modal dialog overlay
    modalManager.draw(w, h, st)
end

local function handleTopBarTouch(x, y, w, headerH, pc)
    if y > headerH then return false end

    -- Player Count button (left)
    local pcText = pc .. " Player" .. (pc > 1 and "s" or "")
    local pcW = ui.getTextWidth(ui.getFont("ui_10"), pcText) + 16
    if x >= 10 and x <= 10 + pcW then
        modalManager.open("player_count")
        return true
    end

    -- Right Buttons: [Tools] & [Reset]
    local rightX = w - 10
    local toolsText = "Tools"
    local toolsW = ui.getTextWidth(ui.getFont("ui_10"), toolsText) + 16
    rightX = rightX - toolsW
    if x >= rightX and x <= rightX + toolsW then
        modalManager.open("tools")
        return true
    end

    rightX = rightX - 8
    local resetText = "Reset"
    local resetW = ui.getTextWidth(ui.getFont("ui_10"), resetText) + 16
    rightX = rightX - resetW
    if x >= rightX and x <= rightX + resetW then
        modalManager.open("reset")
        return true
    end

    return true
end

local function handleCardTouch(x, y, pc, rects, st)
    for i = 1, pc do
        local r = rects[i]
        if r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            st.selectedPlayer = i

            -- Card Menu / Counter detail icon [···] top right
            if grid.isMenuButtonTouch(x, y, r) then
                modalManager.open("player_detail", i)
                return true
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
                    return true
                end
                cx = cx + pw + 8

                local cw = 70
                if x >= cx and x <= cx + cw then
                    modalManager.open("player_detail", i)
                    return true
                end

                modalManager.open("player_detail", i)
                return true
            end

            -- Main Life +/- Tap (±1)
            if x < r.x + math.floor(r.w / 2) then
                stateEngine.changeLife(i, -1)
            else
                stateEngine.changeLife(i, 1)
            end
            if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
            return true
        end
    end
    return false
end

function onTouch(x, y)
    if holdHandler.wasTapSuppressed() then
        return
    end
    x = safeNum(x, 0)
    y = safeNum(y, 0)
    local w = (gfx and gfx.getWidth and gfx.getWidth()) or 800
    local h = (gfx and gfx.getHeight and gfx.getHeight()) or 480
    local st = stateEngine.state
    local pc = math.max(1, math.min(4, safeInt(st.playerCount, 4)))

    -- 1. Active Modal Touches
    if modalManager.handleTouch(x, y, w, h, st) then
        return
    end

    -- 2. Top Bar Touches
    local rects, headerH = grid.getCardRects(w, h, pc)
    if handleTopBarTouch(x, y, w, headerH, pc) then
        return
    end

    -- 3. Player Card Touches
    handleCardTouch(x, y, pc, rects, st)
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
        if not modalManager.isOpen() then
            modalManager.open("player_detail", sel)
        else
            modalManager.close()
        end
    elseif input and (button == input.BTN_UP or button == input.BTN_PAGE_BACK) then
        if not modalManager.isOpen() then
            stateEngine.changeLife(sel, 1)
            if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
        end
    elseif input and (button == input.BTN_DOWN or button == input.BTN_PAGE_FORWARD) then
        if not modalManager.isOpen() then
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
    if modalManager.isOpen() then
        modalManager.close()
        return true
    end
    return false
end

function onUpdate(dt)
    dt = safeNum(dt, 0.05)
    local now = (crosspoint and crosspoint.millis and crosspoint.millis()) or 0

    -- 1. Continuous touch hold for ticking life by 10
    holdHandler.onUpdate(dt, stateEngine.state, modalManager.isOpen())

    -- 2. Clear expired floating delta overlays
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
        ui = modalManager.ui,
        appUI = modalManager.ui,
        holdState = holdHandler.holdState,
        getLifeTouchTarget = function(x, y)
            if modalManager.isOpen() then return nil end
            local w = (gfx and gfx.getWidth and gfx.getWidth()) or 800
            local h = (gfx and gfx.getHeight and gfx.getHeight()) or 480
            return holdHandler.getTarget(x, y, w, h, stateEngine.state)
        end,
        modalManager = modalManager,
        holdHandler = holdHandler,
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
