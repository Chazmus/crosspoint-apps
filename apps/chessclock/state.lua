-- ============================================================================
-- Chess Clock - Game & Clock State Engine
-- Pure logic + persistence. No drawing calls: safe to unit test headlessly.
-- Time is tracked internally in whole milliseconds (integer domain only:
-- firmware builds with LUA_32BITS, so 24-bit float mantissa / signed 32-bit
-- ints apply; 180 min = 10,800,000 ms fits comfortably). Live remaining time
-- is derived as `remaining - (millis() - turnStartMs)` so the display is
-- exact without writing storage every second.
-- ============================================================================

local json = require("json")

local state = {}

state.PRESETS = {
    { mins = 1,  inc = 0, label = "1+0 BULLET" },
    { mins = 2,  inc = 1, label = "2+1 BULLET" },
    { mins = 3,  inc = 0, label = "3+0 BLITZ" },
    { mins = 3,  inc = 2, label = "3+2 BLITZ" },
    { mins = 5,  inc = 0, label = "5+0 BLITZ" },
    { mins = 5,  inc = 3, label = "5+3 BLITZ" },
    { mins = 10, inc = 0, label = "10+0 RAPID" },
    { mins = 10, inc = 5, label = "10+5 RAPID" },
    { mins = 15, inc = 10, label = "15+10 RAPID" },
    { mins = 30, inc = 0, label = "30+0 CLASSIC" },
}

local SAVE_FILE = "gamestate.json"
local MAX_MINUTES = 180
local MAX_INCREMENT = 60
local MAX_REMAINING_MS = MAX_MINUTES * 60 * 1000
local MAX_MOVES = 100000

-- millis() wraps every ~49.7 days and elapsed deltas can be garbage across
-- the wrap or across app restarts. Anything outside this window re-baselines
-- the turn instead of charging phantom time.
local MAX_TRUSTED_ELAPSED_MS = 86400000 -- 24h
-- Commit elapsed think time to storage at least this often while running,
-- so a dead battery mid-game loses at most ~10s instead of the whole turn.
local COMMIT_INTERVAL_MS = 10000

state.control = { mins = 5, inc = 3, label = "5+3 BLITZ" }
state.custom = { mins = 5, inc = 3 }
state.phase = "ready"         -- "ready" | "running" | "paused" | "flagged"
state.whiteTop = false        -- false: White panel at bottom (near player)
state.active = "white"        -- whose clock is running
state.flaggedSide = nil       -- side that ran out of time
state.players = {
    white = { remaining = 300000, moves = 0 },
    black = { remaining = 300000, moves = 0 },
}
state.turnStartMs = 0         -- millis() snapshot at turn (re)start

local lastCommitMs = 0        -- last periodic storage commit while running
local lastDisplayBucket = nil -- cached display bucket for change detection

local function safeInt(n, def)
    local v = tonumber(n)
    return (v ~= nil) and math.floor(v) or (def or 0)
end

local function safeText(s, def)
    if s == nil then return def or "" end
    return tostring(s)
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--- Public so the setup view and tests share one clamp definition.
function state.clampCustom(mins, inc)
    return clamp(safeInt(mins, 5), 1, MAX_MINUTES), clamp(safeInt(inc, 0), 0, MAX_INCREMENT)
end

--- Trusted elapsed ms since the turn baseline (wrap/staleness guarded).
local function trustedElapsed(nowMs)
    local elapsed = safeInt(nowMs, 0) - state.turnStartMs
    if elapsed < 0 or elapsed > MAX_TRUSTED_ELAPSED_MS then
        return nil
    end
    return elapsed
end

--- Fold elapsed live time into `remaining` and re-baseline the turn clock.
--- Used by pause(), periodic commits, and switchTurn().
local function commitElapsed(nowMs)
    local elapsed = trustedElapsed(nowMs)
    if elapsed then
        local p = state.players[state.active]
        p.remaining = p.remaining - elapsed
        if p.remaining < 0 then p.remaining = 0 end
    end
    state.turnStartMs = safeInt(nowMs, 0)
    lastCommitMs = state.turnStartMs
end

--- Live remaining milliseconds for a side (integer math only).
--- Note: can briefly go negative for the active side before tick() flags it;
--- the display path clamps. Tolerates nil fields from a corrupted state table.
function state.remainingMs(side, nowMs)
    local p = state.players[side]
    if not p then return 0 end
    local base = p.remaining
    if type(base) ~= "number" then base = 0 end
    if state.phase == "running" and state.active == side then
        local elapsed = trustedElapsed(nowMs)
        if not elapsed then elapsed = 0 end
        return base - elapsed
    end
    return base
end

--- Fresh game with the given control; phase "ready" waits for the first tap.
function state.newGame(mins, inc, label, whiteTop)
    mins, inc = state.clampCustom(mins, inc)
    state.control = { mins = mins, inc = inc, label = safeText(label, mins .. "+" .. inc) }
    if whiteTop ~= nil then state.whiteTop = (whiteTop == true) end
    state.phase = "ready"
    state.active = "white"
    state.flaggedSide = nil
    state.players = {
        white = { remaining = mins * 60000, moves = 0 },
        black = { remaining = mins * 60000, moves = 0 },
    }
    state.turnStartMs = 0
    lastCommitMs = 0
    lastDisplayBucket = nil
    state.save()
end

--- First tap after "ready": White's clock starts running.
function state.startGame(nowMs)
    if state.phase ~= "ready" then return false end
    state.phase = "running"
    state.active = "white"
    state.turnStartMs = safeInt(nowMs, 0)
    lastCommitMs = state.turnStartMs
    lastDisplayBucket = nil
    state.save()
    return true
end

--- Standard Fischer increment: the player who just completed a move gains
--- the increment, then the turn passes. Elapsed think time for the finished
--- move is charged exactly (ms domain).
function state.switchTurn(nowMs)
    if state.phase ~= "running" then return false end
    commitElapsed(nowMs)
    local inc = state.control.inc
    if inc > 0 then
        local p = state.players[state.active]
        p.remaining = p.remaining + inc * 1000
    end
    state.players[state.active].moves = state.players[state.active].moves + 1
    state.active = (state.active == "white") and "black" or "white"
    lastDisplayBucket = nil
    state.save()
    return true
end

--- Tap on a panel. `side` is the owner of the tapped panel ("white"/"black").
--- In "ready" the first tap (either panel) starts White's clock.
function state.tapPanel(side, nowMs)
    if state.phase == "ready" then
        return state.startGame(nowMs)
    elseif state.phase == "running" then
        if side == state.active then
            return state.switchTurn(nowMs)
        end
        return false
    elseif state.phase == "paused" then
        return state.resume(nowMs)
    end
    return false
end

function state.pause()
    if state.phase ~= "running" then return false end
    commitElapsed(crosspoint and crosspoint.millis and crosspoint.millis() or 0)
    state.phase = "paused"
    lastDisplayBucket = nil
    state.save()
    return true
end

function state.resume(nowMs)
    if state.phase ~= "paused" then return false end
    state.phase = "running"
    state.turnStartMs = safeInt(nowMs, 0)
    lastCommitMs = state.turnStartMs
    lastDisplayBucket = nil
    state.save()
    return true
end

function state.rematch()
    state.newGame(state.control.mins, state.control.inc, state.control.label)
end

--- Advance the running clock. Returns what changed so the caller can decide
--- whether to request a screen update: nil | "sec" | "tenth" | "flag".
function state.tick(nowMs)
    if state.phase ~= "running" then return nil end
    nowMs = safeInt(nowMs, 0)

    -- Flag check on live time.
    if (state.remainingMs(state.active, nowMs)) <= 0 then
        local p = state.players[state.active]
        p.remaining = 0
        state.flaggedSide = state.active
        state.phase = "flagged"
        state.turnStartMs = nowMs
        lastDisplayBucket = nil
        state.save()
        return "flag"
    end

    local dirty = nil

    -- Periodic commit: fold elapsed into remaining and persist, so a dead
    -- battery never resurrects more than ~10s of free time.
    if lastCommitMs == 0 or nowMs - lastCommitMs >= COMMIT_INTERVAL_MS then
        local elapsed = trustedElapsed(nowMs)
        if elapsed then
            state.players[state.active].remaining = state.remainingMs(state.active, nowMs)
            state.turnStartMs = nowMs
            lastCommitMs = nowMs
            state.save()
        else
            -- Wrap/garbage baseline: re-baseline without charging.
            state.turnStartMs = nowMs
            lastCommitMs = nowMs
        end
    end

    -- Display bucket: tenths (100ms) under 10s, whole seconds above.
    local live = state.remainingMs(state.active, nowMs)
    if live < 0 then live = 0 end
    local bucket = (live < 10000) and (live // 100) or (live // 1000)
    if bucket ~= (lastDisplayBucket or -1) then
        dirty = (live < 10000) and "tenth" or "sec"
    end
    lastDisplayBucket = bucket
    return dirty
end

--- Formats whole seconds as "M:SS", "MM:SS" or "H:MM:SS".
function state.formatTime(totalSecs)
    totalSecs = safeInt(totalSecs, 0)
    if totalSecs < 0 then totalSecs = 0 end
    local h = totalSecs // 3600
    local m = (totalSecs % 3600) // 60
    local s = totalSecs % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%d:%02d", m, s)
end

--- Display string for a panel: switches to tenths under 10s when live.
--- Tolerates a corrupted state table (nil phase/remaining) without erroring.
function state.panelTimeText(side, nowMs)
    local ms = state.remainingMs(side, nowMs)
    if type(ms) ~= "number" then ms = 0 end
    if ms < 0 then ms = 0 end
    if state.phase == "running" and state.active == side and ms < 10000 then
        local tenths = ms // 100 -- 0..99
        return string.format("%d.%d", tenths // 10, tenths % 10)
    end
    return state.formatTime(ms // 1000)
end

function state.save()
    if not storage or not storage.writeFile then return end
    local data = {
        phase = state.phase,
        control = state.control,
        custom = state.custom,
        whiteTop = state.whiteTop,
        active = state.active,
        flaggedSide = state.flaggedSide,
        players = state.players,
    }
    storage.writeFile(SAVE_FILE, json.encode(data))
end

--- Loads a saved game. A save in phase "running" becomes "paused": the device
--- may have been off/sleeping for an unknown duration, so the clock must not
--- silently resume charging time. The player explicitly resumes.
function state.load()
    if not storage or not storage.readFile then return false end
    local content = storage.readFile(SAVE_FILE)
    if not content or content == "" then return false end

    local ok, data = pcall(function() return json.decode(content) end)
    -- Structural guard: corrupt/garbage input sometimes decodes to a partial
    -- table instead of erroring. A genuine save always carries a phase string.
    if not ok or type(data) ~= "table" or type(data.phase) ~= "string" or type(data.players) ~= "table" then
        if log and log.warn then log.warn("STATE", "Corrupt gamestate.json, ignoring") end
        return false
    end

    local phase = data.phase
    if phase ~= "ready" and phase ~= "running" and phase ~= "paused" and phase ~= "flagged" then
        phase = "ready"
    end

    local c = data.control
    if type(c) ~= "table" then c = {} end
    local mins, inc = state.clampCustom(c.mins, c.inc)
    state.control = { mins = mins, inc = inc, label = safeText(c.label, mins .. "+" .. inc) }

    local cu = data.custom
    if type(cu) ~= "table" then cu = {} end
    local cuMins, cuInc = state.clampCustom(cu.mins, cu.inc)
    state.custom = { mins = cuMins, inc = cuInc }

    state.whiteTop = (data.whiteTop == true)
    state.active = (data.active == "black") and "black" or "white"
    state.flaggedSide = (data.flaggedSide == "white" or data.flaggedSide == "black") and data.flaggedSide or nil

    local pw = data.players.white
    local pb = data.players.black
    if type(pw) ~= "table" then pw = {} end
    if type(pb) ~= "table" then pb = {} end
    state.players = {
        white = {
            remaining = clamp(safeInt(pw.remaining, mins * 60000), 0, MAX_REMAINING_MS),
            moves = clamp(safeInt(pw.moves, 0), 0, MAX_MOVES),
        },
        black = {
            remaining = clamp(safeInt(pb.remaining, mins * 60000), 0, MAX_REMAINING_MS),
            moves = clamp(safeInt(pb.moves, 0), 0, MAX_MOVES),
        },
    }

    state.phase = (phase == "running") and "paused" or phase
    state.turnStartMs = 0
    lastCommitMs = 0
    lastDisplayBucket = nil
    return true
end

function state.hasResumableGame()
    return state.phase == "paused" or state.phase == "flagged"
end

function state.opponentOf(side)
    return (side == "white") and "black" or "white"
end

return state
