-- ============================================================================
-- Chess Clock - Main Application Coordinator
-- Two-player over-the-board chess clock for CrossPoint Reader.
-- Views: clock (game) / setup (time control) / modals / sleep screen.
-- ============================================================================

local state = require("state")
local clockView = require("views.clock")
local setupView = require("views.setup")
local modals = require("views.modals")
local sleepView = require("views.sleep_view")

local view = "clock"      -- "clock" | "setup"
local modalKind = nil     -- nil | "menu" | "flag" | "reset_confirm"

local function nowMs()
    return (crosspoint and crosspoint.millis and crosspoint.millis()) or 0
end

local function requestUpdate()
    if crosspoint and crosspoint.requestUpdate then crosspoint.requestUpdate() end
end

local function save()
    state.save()
end

-- ---------------------------------------------------------------------------
-- Context builders for the clock view
-- ---------------------------------------------------------------------------

local function captionFor(side)
    if state.phase == "flagged" then
        if state.flaggedSide == side then
            return "FLAG"
        end
        return "WINS"
    end
    local name = (side == "white") and "WHITE" or "BLACK"
    if state.phase == "running" and state.active == side then
        return name .. " - TO MOVE"
    end
    return name
end

local function subFor(side)
    local p = state.players[side]
    if not p then return "" end
    local moves = tonumber(p.moves) or 0
    return "MV " .. moves
end

local function buildCtx(layout)
    local ctx = {
        phase = state.phase,
        active = state.active,
        flaggedSide = state.flaggedSide,
        whiteTop = state.whiteTop,
        timeText = function(side) return state.panelTimeText(side, nowMs()) end,
        caption = captionFor,
        sub = subFor,
    }

    if state.phase == "ready" then
        ctx.headerLeft = "READY"
        ctx.headerTitle = state.control.label
    elseif state.phase == "running" then
        ctx.headerLeft = "PAUSE"
        ctx.headerTitle = state.control.label
    elseif state.phase == "paused" then
        ctx.headerLeft = "RESUME"
        ctx.headerTitle = state.control.label .. " (PAUSED)"
    else -- flagged
        local winner = state.opponentOf(state.flaggedSide or "white")
        ctx.headerLeft = ""
        ctx.headerTitle = string.upper(winner) .. " WINS ON TIME"
    end
    return ctx
end

-- ---------------------------------------------------------------------------
-- Modal plumbing
-- ---------------------------------------------------------------------------

local function openModal(kind)
    modalKind = kind
    modals.controlLabel = state.control.label
    if kind == "flag" then
        local loser = state.flaggedSide or "white"
        modals.flagText = string.upper(state.opponentOf(loser)) .. " WINS ON TIME"
        modals.subText = "Tap REMATCH for a new " .. state.control.mins .. "+" .. state.control.inc
    end
    requestUpdate()
end

local function closeModal()
    modalKind = nil
    requestUpdate()
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

local function doPauseResume()
    if state.phase == "running" then
        state.pause()
    elseif state.phase == "paused" then
        state.resume(nowMs())
    end
    requestUpdate()
end

local function doSwapSeats()
    state.whiteTop = not state.whiteTop
    state.save()
    requestUpdate()
end

local function doPanelTap(panel)
    local side = panel == "top"
        and (state.whiteTop and "white" or "black")
        or (state.whiteTop and "black" or "white")
    state.tapPanel(side, nowMs())
    if state.phase == "flagged" then
        openModal("flag")
    else
        requestUpdate()
    end
end

local function doRematch()
    state.rematch()
    modalKind = nil
    requestUpdate()
end

local function doOpenSetup()
    modalKind = nil
    view = "setup"
    setupView.init()
    requestUpdate()
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function onEnter()
    state.load()
    state._lastTenth = nil
    requestUpdate()
end

function onExit()
    state.pause() -- running -> paused so a reload never silently loses time
    state.save()
end

function onBack()
    if modalKind then
        if modalKind == "reset_confirm" then
            modalKind = nil
            requestUpdate()
            return true
        end
        modalKind = nil
        requestUpdate()
        return true
    end
    if view == "setup" then
        view = "clock"
        requestUpdate()
        return true
    end
    return false -- exit to launcher
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function onTouch(x, y)
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    if view == "setup" then
        local action = setupView.onTouch(x, y, w, h)
        if action == "back" then
            view = "clock"
        elseif action == "seat" then
            state.whiteTop = not state.whiteTop
            state.save()
        elseif action == "start" then
            setupView.applyAndStart(state.whiteTop)
            view = "clock"
        elseif action == "custom_mins_minus" then
            state.custom.mins = math.max(1, state.custom.mins - 1)
        elseif action == "custom_mins_plus" then
            state.custom.mins = math.min(180, state.custom.mins + 1)
        elseif action == "custom_inc_minus" then
            state.custom.inc = math.max(0, state.custom.inc - 1)
        elseif action == "custom_inc_plus" then
            state.custom.inc = math.min(60, state.custom.inc + 1)
        end
        requestUpdate()
        return
    end

    -- Modal taps
    if modalKind then
        local key = modals.buttonAt(x, y)
        if key == "close" then
            modalKind = nil
        elseif key == "new_game" then
            doRematch()
        elseif key == "rematch" then
            doRematch()
        elseif key == "setup" then
            doOpenSetup()
            return
        elseif key == "reset" then
            state.rematch()
            modalKind = nil
        elseif modals.tapOutsideCloses(modalKind) then
            modalKind = nil
        end
        requestUpdate()
        return
    end

    local layout = clockView.computeLayout(w, h)

    -- Header buttons
    local hdr = clockView.headerButtonAt(x, y, layout)
    if hdr == "swap" then
        doSwapSeats()
        return
    elseif hdr == "menu" then
        openModal("menu")
        return
    elseif hdr ~= nil then
        return
    end

    -- Header band is otherwise inert.
    if y < layout.headerH then
        if state.phase == "running" then
            state.pause()
            requestUpdate()
        end
        return
    end

    -- Panel taps
    local panel = clockView.panelAt(x, y, layout)
    if panel then
        doPanelTap(panel)
    end
end

function onInput(buttonId, action)
    if action == "release" then return end

    if view == "setup" then
        if buttonId == input.BTN_UP or buttonId == input.BTN_PAGE_BACK then
            setupView.changeSelection(-1)
            requestUpdate()
        elseif buttonId == input.BTN_DOWN or buttonId == input.BTN_PAGE_FORWARD then
            setupView.changeSelection(1)
            requestUpdate()
        elseif buttonId == input.BTN_CONFIRM then
            setupView.applyAndStart(state.whiteTop)
            view = "clock"
            requestUpdate()
        end
        return
    end

    if buttonId == input.BTN_CONFIRM then
        if modalKind then
            modalKind = nil
        elseif state.phase == "running" or state.phase == "paused" then
            doPauseResume()
        end
        requestUpdate()
    elseif buttonId == input.BTN_UP or buttonId == input.BTN_PAGE_BACK then
        -- Page buttons: quick switch turn (physical buttons sit on the side).
        if not modalKind and state.phase == "running" then
            state.switchTurn(nowMs())
            requestUpdate()
        end
    elseif buttonId == input.BTN_DOWN or buttonId == input.BTN_PAGE_FORWARD then
        if not modalKind and state.phase == "running" then
            state.switchTurn(nowMs())
            requestUpdate()
        end
    end
end

function onUpdate(dt)
    local dirty = state.tick(nowMs())
    if dirty then
        requestUpdate()
    end
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------

function onDraw()
    local w = gfx.getWidth()
    local h = gfx.getHeight()
    gfx.clearScreen(1)

    if view == "setup" then
        setupView.draw(w, h)
        return
    end

    local layout = clockView.computeLayout(w, h)
    local ctx = buildCtx(layout)
    clockView.drawPanels(layout, ctx)
    clockView.drawHeader(layout, ctx)

    if modalKind == "menu" then
        modals.drawMenu(w, h)
    elseif modalKind == "flag" then
        modals.drawFlagged(w, h)
    elseif modalKind == "reset_confirm" then
        modals.drawResetConfirm(w, h)
    end
end

function onSleepDraw()
    local w = gfx.getWidth()
    local h = gfx.getHeight()
    sleepView.draw(w, h)
end

-- Test/inspection export (mirrors spellcounter's _SPELLCOUNTER pattern).
if _G then
    _G._CHESSCLOCK = {
        state = state,
        clockView = clockView,
        setupView = setupView,
        modals = modals,
        sleepView = sleepView,
    }
end
