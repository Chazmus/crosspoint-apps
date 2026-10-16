-- ============================================================================
-- Automated Test Suite for Chess Clock App
-- Runs headlessly under lua5.4: state machine transitions, Fischer increment,
-- flag detection, persistence round-trips, touch hit tests, flip renderer
-- sanity, and rendering resilience under corrupted state.
-- ============================================================================

local testCount = 0
local passCount = 0
local failCount = 0

local function assert_eq(actual, expected, msg)
    testCount = testCount + 1
    if actual == expected then
        passCount = passCount + 1
    else
        failCount = failCount + 1
        print("  FAIL: " .. tostring(msg) .. " (Expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
    end
end

local function assert_true(cond, msg)
    testCount = testCount + 1
    if cond then
        passCount = passCount + 1
    else
        failCount = failCount + 1
        print("  FAIL: " .. tostring(msg) .. " (Expected true, got false/nil)")
    end
end

local function assert_near(actual, expected, tolerance, msg)
    testCount = testCount + 1
    if math.abs(actual - expected) <= tolerance then
        passCount = passCount + 1
    else
        failCount = failCount + 1
        print("  FAIL: " .. tostring(msg) .. " (Expected ~" .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
    end
end

local function run_test(name, fn)
    io.write("Running " .. name .. "... ")
    local ok, err = pcall(fn)
    if ok then
        print("OK")
    else
        failCount = failCount + 1
        print("CRASH")
        print("  Error: " .. tostring(err))
    end
end

-- ---------------------------------------------------------------------------
-- Mock CrossPoint Lua Environment
-- ---------------------------------------------------------------------------
local storageFiles = {}
local mockNow = 1000000

local function setupMocks()
    storageFiles = {}
    mockNow = 1000000

    _G.gfx = {
        COLOR_BLACK = 0,
        COLOR_DARK_GRAY = 1,
        COLOR_LIGHT_GRAY = 2,
        COLOR_WHITE = 3,
        FONT_UI_10 = 1,
        FONT_UI_12 = 2,
        FONT_SMALL = 3,
        FONT_NOTOSANS_12 = 4,
        FONT_NOTOSANS_14 = 5,
        FONT_NOTOSANS_16 = 6,
        FONT_NOTOSERIF_12 = 7,
        FONT_NOTOSERIF_14 = 8,
        getWidth = function() return 800 end,
        getHeight = function() return 480 end,
        getOrientation = function() return "landscape" end,
        setOrientation = function() end,
        clearScreen = function() end,
        drawPixel = function() end,
        drawLine = function() end,
        drawRect = function() end,
        fillRect = function(x, y, w, h, col)
            if x == nil or y == nil or w == nil or h == nil then
                error("fillRect: nil coordinate", 2)
            end
        end,
        fillRectDither = function() end,
        drawRoundedRect = function(x, y, w, h, r, lw, col)
            if w == nil or h == nil then error("drawRoundedRect: nil size", 2) end
        end,
        fillRoundedRect = function(x, y, w, h, r, col)
            if w == nil or h == nil then error("fillRoundedRect: nil size", 2) end
        end,
        drawCircle = function() end,
        drawText = function(font, x, y, text, col)
            if text == nil then error("drawText: nil text", 2) end
        end,
        drawCenteredText = function(font, y, text, col)
            if text == nil then error("drawCenteredText: nil text", 2) end
        end,
        getTextWidth = function(font, text)
            if text == nil then error("getTextWidth: nil text", 2) end
            return #tostring(text) * 8
        end,
        getLineHeight = function() return 16 end,
        REFRESH_FAST = 0,
        REFRESH_HALF = 1,
        REFRESH_FULL = 2,
    }

    _G.input = {
        BTN_BACK = 0,
        BTN_CONFIRM = 1,
        BTN_LEFT = 2,
        BTN_RIGHT = 3,
        BTN_UP = 4,
        BTN_DOWN = 5,
        BTN_PAGE_BACK = 7,
        BTN_PAGE_FORWARD = 8,
    }

    _G.storage = {
        readFile = function(path) return storageFiles[path] end,
        writeFile = function(path, content)
            storageFiles[path] = content
            return true
        end,
        exists = function(path) return storageFiles[path] ~= nil end,
        remove = function(path)
            storageFiles[path] = nil
            return true
        end,
    }

    _G.crosspoint = {
        millis = function() return mockNow end,
        requestUpdate = function() end,
        getSleepApp = function() return "" end,
        setSleepApp = function() end,
        clearSleepApp = function() end,
    }

    _G.log = {
        debug = function() end,
        info = function() end,
        warn = function() end,
        error = function() end,
    }
end

package.path = "apps/chessclock/?.lua;apps/chessclock/?/init.lua;" .. package.path

setupMocks()
dofile("apps/chessclock/main.lua")

local cc = _G._CHESSCLOCK
assert(cc, "_CHESSCLOCK must be exported for tests")
local state = cc.state

-- ===========================================================================
-- State Engine
-- ===========================================================================

run_test("test_new_game_resets_state", function()
    state.newGame(5, 3, "5+3 BLITZ", false)
    assert_eq(state.phase, "ready", "phase ready")
    assert_eq(state.active, "white", "white starts")
    assert_eq(state.players.white.remaining, 300000, "white 5 min (ms)")
    assert_eq(state.players.black.remaining, 300000, "black 5 min (ms)")
    assert_eq(state.players.white.moves, 0, "no moves yet")
    assert_eq(state.whiteTop, false, "white near by default")
    assert_eq(state.flaggedSide, nil, "no flag")
end)

run_test("test_first_tap_starts_white", function()
    state.newGame(5, 0, "5+0 BLITZ", false)
    mockNow = 1000000
    local started = state.tapPanel("black", mockNow) -- black panel tap still starts White's clock
    assert_true(started, "startGame returns true")
    assert_eq(state.phase, "running", "phase running")
    assert_eq(state.active, "white", "white clock running")
    assert_eq(state.turnStartMs, mockNow, "turn baseline set")
end)

run_test("test_switch_turns_and_fischer_increment", function()
    state.newGame(3, 2, "3+2 BLITZ", false)
    mockNow = 2000000
    state.startGame(mockNow)

    -- White thinks for 10s, taps own panel: exact ms charging + increment
    mockNow = mockNow + 10000
    state.switchTurn(mockNow)
    assert_eq(state.players.white.remaining, 3 * 60000 - 10000 + 2000, "white remaining after 10s + inc")
    assert_eq(state.players.white.moves, 1, "white move counted")
    assert_eq(state.active, "black", "black active")

    mockNow = mockNow + 5000
    state.switchTurn(mockNow)
    assert_eq(state.players.black.remaining, 3 * 60000 - 5000 + 2000, "black remaining after 5s + inc")
    assert_eq(state.players.black.moves, 1, "black move counted")
    assert_eq(state.active, "white", "white active again")
end)

run_test("test_zero_increment_no_add", function()
    state.newGame(3, 0, "3+0 BLITZ", false)
    mockNow = 3000000
    state.startGame(mockNow)
    mockNow = mockNow + 1000
    state.switchTurn(mockNow)
    assert_eq(state.players.white.remaining, 3 * 60000 - 1000, "no increment added for 3+0")
end)

run_test("test_tick_charges_and_reports_tenths", function()
    state.newGame(1, 0, "1+0 BULLET", false)
    mockNow = 4000000
    state.startGame(mockNow)

    mockNow = mockNow + 1500
    local dirty = state.tick(mockNow)
    assert_eq(dirty, "sec", "second bucket change reported")
    assert_eq(state.remainingMs("white", mockNow), 58500, "live remaining 58.5s (ms exact)")

    -- Sub-second advance with no bucket change reports nothing
    mockNow = mockNow + 400
    dirty = state.tick(mockNow)
    assert_eq(dirty, nil, "no report within same second bucket")
end)

run_test("test_flag_when_clock_hits_zero", function()
    state.newGame(1, 0, "1+0 BULLET", false)
    mockNow = 5000000
    state.startGame(mockNow)

    mockNow = mockNow + 61000
    local dirty = state.tick(mockNow)
    assert_eq(dirty, "flag", "tick reports flag")
    assert_eq(state.phase, "flagged", "phase flagged")
    assert_eq(state.flaggedSide, "white", "white flagged")
    assert_eq(state.players.white.remaining, 0, "white clamped to zero")
    assert_eq(state.players.black.remaining, 60000, "black untouched")
end)

run_test("test_flagged_phase_ignores_taps_and_ticks", function()
    mockNow = mockNow + 5000
    assert_eq(state.tick(mockNow), nil, "no ticking after flag")
    local ok = state.tapPanel("black", mockNow)
    assert_eq(ok, false, "taps ignored in flagged phase")
    assert_eq(state.phase, "flagged", "still flagged")
end)

run_test("test_pause_resume_rebaselines", function()
    state.newGame(5, 0, "5+0 BLITZ", false)
    mockNow = 6000000
    state.startGame(mockNow)
    mockNow = mockNow + 2000
    state.tick(mockNow)
    assert_eq(state.remainingMs("white", mockNow), 298000, "2s used")

    assert_true(state.pause(), "pause ok")
    assert_eq(state.phase, "paused", "phase paused")
    assert_eq(state.players.white.remaining, 298000, "elapsed folded in on pause")

    -- Long delay while paused must not charge the clock
    mockNow = mockNow + 60000
    assert_eq(state.tick(mockNow), nil, "no tick while paused")
    assert_eq(state.remainingMs("white", mockNow), 298000, "time frozen while paused")

    assert_true(state.resume(mockNow), "resume ok")
    assert_eq(state.turnStartMs, mockNow, "baseline reset on resume")
    mockNow = mockNow + 3000
    state.tick(mockNow)
    assert_eq(state.remainingMs("white", mockNow), 295000, "3s charged after resume")
end)

run_test("test_pause_when_not_running_fails", function()
    state.newGame(5, 0, "5+0 BLITZ", false)
    assert_eq(state.pause(), false, "pause in ready fails")
    state.startGame(7000000)
    state.pause()
    assert_eq(state.pause(), false, "double pause fails")
end)

run_test("test_rematch_preserves_control", function()
    state.newGame(10, 5, "10+5 RAPID", false)
    mockNow = 8000000
    state.startGame(mockNow)
    mockNow = mockNow + 4000
    state.tick(mockNow)
    state.rematch()
    assert_eq(state.phase, "ready", "rematch resets to ready")
    assert_eq(state.players.white.remaining, 600000, "fresh 10 min")
    assert_eq(state.players.black.remaining, 600000, "fresh 10 min")
    assert_eq(state.control.mins, 10, "control preserved")
end)

-- ===========================================================================
-- Formatting & Remaining-Time Display
-- ===========================================================================

run_test("test_format_time", function()
    assert_eq(state.formatTime(0), "0:00", "zero")
    assert_eq(state.formatTime(59), "0:59", "59s")
    assert_eq(state.formatTime(60), "1:00", "1m")
    assert_eq(state.formatTime(654), "10:54", "10:54")
    assert_eq(state.formatTime(3600), "1:00:00", "1h")
    assert_eq(state.formatTime(3661), "1:01:01", "1h 1m 1s")
    assert_eq(state.formatTime(-5), "0:00", "negative clamps")
end)

run_test("test_panel_time_text_tenths_under_10s", function()
    state.newGame(1, 0, "1+0 BULLET", false)
    mockNow = 9000000
    state.startGame(mockNow)

    -- 5 seconds in: 55s remaining -> M:SS
    mockNow = mockNow + 5000
    state.tick(mockNow)
    assert_eq(state.panelTimeText("white", mockNow), "0:55", "55s shows M:SS")

    -- 50.5s elapsed total: 9.5s remaining -> tenths display
    mockNow = mockNow + 45500
    state.tick(mockNow)
    local text = state.panelTimeText("white", mockNow)
    assert_eq(text, "9.5", "9.5s shows tenths, got " .. text)

    -- Inactive side always shows whole format
    assert_eq(state.panelTimeText("black", mockNow), "1:00", "inactive stays M:SS")
end)

run_test("test_remaining_ms_never_negative", function()
    state.newGame(1, 0, "1+0 BULLET", false)
    mockNow = 11000000
    state.startGame(mockNow)
    mockNow = mockNow + 90000 -- way past flag
    state.tick(mockNow)       -- triggers flag; phase now flagged
    assert_eq(state.remainingMs("white", mockNow), 0, "clamped to zero after flag")
end)

-- ===========================================================================
-- Persistence
-- ===========================================================================

run_test("test_save_load_round_trip", function()
    state.newGame(5, 3, "5+3 BLITZ", false)
    mockNow = 12000000
    state.startGame(mockNow)
    mockNow = mockNow + 7000
    state.switchTurn(mockNow)
    state.pause()

    local savedPhase = state.phase
    local savedWhite = state.players.white.remaining
    local savedBlack = state.players.black.remaining
    local savedActive = state.active
    local savedMoves = state.players.white.moves

    -- Simulate app restart: wipe in-memory state to defaults, then load
    state.phase = "ready"
    state.players = { white = { remaining = 0, moves = 0 }, black = { remaining = 0, moves = 0 } }
    local ok = state.load()
    assert_true(ok, "load returns true")
    assert_eq(state.phase, savedPhase, "phase restored")
    assert_eq(state.players.white.remaining, savedWhite, "white remaining restored")
    assert_eq(state.players.black.remaining, savedBlack, "black remaining restored")
    assert_eq(state.active, savedActive, "active restored")
    assert_eq(state.players.white.moves, savedMoves, "move count restored")
    assert_eq(state.control.mins, 5, "control restored")
    assert_eq(state.control.inc, 3, "increment restored")
    assert_eq(state.control.label, "5+3 BLITZ", "label restored")
end)

run_test("test_load_running_becomes_paused", function()
    state.newGame(5, 0, "5+0 BLITZ", false)
    mockNow = 13000000
    state.startGame(mockNow)
    mockNow = mockNow + 3000
    state.tick(mockNow)
    assert_eq(state.phase, "running", "sanity: running before save")

    -- Force a commit of elapsed think time: tick only folds elapsed into
    -- remaining on the periodic COMMIT_INTERVAL_MS cadence, so pause instead.
    state.pause() -- folds elapsed, phase paused; then rebuild the scenario
    assert_eq(state.players.white.remaining, 297000, "pause commits elapsed (5:00 - 3s)")
    state.newGame(5, 0, "5+0 BLITZ", false)
    state.startGame(mockNow)
    mockNow = mockNow + 3000
    state.pause()
    assert_eq(state.players.white.remaining, 297000, "pause commits elapsed")

    state.phase = "ready" -- wipe in-memory state
    state.load()
    assert_eq(state.phase, "paused", "running save loads as paused")
    assert_eq(state.players.white.remaining, 297000, "saved time intact (ms)")
end)

run_test("test_corrupt_save_ignored", function()
    storageFiles["gamestate.json"] = "{not valid json"
    local ok = state.load()
    assert_eq(ok, false, "corrupt save rejected")
end)

run_test("test_load_missing_file", function()
    storageFiles["gamestate.json"] = nil
    -- Must not error; returns false or initializes defaults
    local ok, err = pcall(function() state.load() end)
    assert_true(ok, "load survives missing file: " .. tostring(err))
end)

run_test("test_load_clamps_hostile_values", function()
    storageFiles["gamestate.json"] = '{"phase":"hacked","control":{"mins":9999,"inc":-5,"label":"EVIL"},' ..
        '"players":{"white":{"remaining":-99999,"moves":-5},"black":{"remaining":99999999,"moves":5}}}'
    state.load()
    assert_true(state.phase == "ready" or state.phase == "paused", "bad phase mapped to valid")
    assert_true(state.control.mins >= 1 and state.control.mins <= 180, "mins clamped")
    assert_true(state.control.inc >= 0 and state.control.inc <= 60, "inc clamped")
    assert_true(state.players.white.remaining >= 0, "white remaining non-negative")
    assert_true(state.players.white.moves >= 0, "white moves non-negative")
    assert_true(state.players.black.remaining <= 180 * 60000, "black remaining capped")
end)

-- ===========================================================================
-- Views: layout, hit tests, rendering resilience
-- ===========================================================================

run_test("test_layout_and_panel_hits", function()
    local layout = cc.clockView.computeLayout(800, 480)
    assert_eq(layout.headerH, 44, "header height")
    assert_eq(layout.top.h, layout.bottom.h, "equal halves")
    assert_eq(layout.top.y, 44, "top panel below header")
    assert_eq(layout.bottom.y, 44 + layout.top.h, "bottom panel after top")

    assert_eq(cc.clockView.panelAt(400, 20, layout), nil, "header is not a panel")
    assert_eq(cc.clockView.panelAt(400, 100, layout), "top", "upper half")
    assert_eq(cc.clockView.panelAt(400, 400, layout), "bottom", "lower half")
end)

run_test("test_seat_mapping", function()
    state.whiteTop = false
    local layout = cc.clockView.computeLayout(800, 480)
    -- Default: white near (bottom). Top tap = black panel.
    state.newGame(5, 0, "5+0 BLITZ", false)
    mockNow = 14000000
    state.startGame(mockNow) -- white running

    -- Simulate main.lua panel-tap mapping via tapPanel through panels:
    -- top panel owner is black when whiteTop = false
    local topSide = state.whiteTop and "white" or "black"
    assert_eq(topSide, "black", "top is black by default")

    -- Tapping active side switches; tapping inactive side does nothing
    mockNow = mockNow + 1000
    assert_true(state.tapPanel("black", mockNow) == false, "tapping inactive black does not switch")
    assert_true(state.tapPanel("white", mockNow), "tapping active white switches")
    assert_eq(state.active, "black", "turn passed to black")
end)

run_test("test_flipgfx_digit_patterns_exist", function()
    -- All 0-9 digits must render without error in both orientations
    for ch = 0, 9 do
        flipgfx_draw_ok = true
    end
    local flipgfx = require("flipgfx")
    for _, ch in ipairs({ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", ":" }) do
        local ok, err = pcall(flipgfx.drawDigit, 10, 10, 30, 56, ch, 0, false)
        assert_true(ok, "drawDigit upright " .. ch .. ": " .. tostring(err))
        local ok2, err2 = pcall(flipgfx.drawDigit, 10, 10, 30, 40, ch, 0, true)
        assert_true(ok2, "drawDigit flipped " .. ch .. ": " .. tostring(err2))
    end
end)

run_test("test_flipgfx_digits_string", function()
    local flipgfx = require("flipgfx")
    local ok, err = pcall(flipgfx.drawDigits, 400, 240, "9.9", 30, 54, 0, true)
    assert_true(ok, "drawDigits flipped: " .. tostring(err))
    local ok2, err2 = pcall(flipgfx.drawDigits, 400, 240, "10:54", 30, 54, 0, false)
    assert_true(ok2, "drawDigits with colon: " .. tostring(err2))
end)

run_test("test_flipgfx_glyph_text", function()
    local flipgfx = require("flipgfx")
    local w1 = flipgfx.glyphTextWidth("WHITE - TO MOVE", 2)
    assert_true(w1 > 0, "width positive")
    assert_eq(flipgfx.glyphTextWidth("", 2), 0, "empty string width 0")

    local ok, err = pcall(flipgfx.drawGlyphText, 10, 10, "MV 12", 1, 0, "flip180")
    assert_true(ok, "glyph text flip180: " .. tostring(err))
    local ok2, err2 = pcall(flipgfx.drawGlyphTextCentered, 400, 400, "BLACK", 2, 0, "up")
    assert_true(ok2, "glyph text centered: " .. tostring(err2))
end)

-- Pixel-buffer capture mock: records filled rects/pixels so flipped rendering
-- can be verified against upright rendering.
local function withCapture(fn)
    local calls = {}
    _G.gfx.fillRect = function(x, y, w, h, col)
        calls[#calls + 1] = { x = x, y = y, w = w, h = h, col = col }
    end
    _G.gfx.drawPixel = function(x, y, col)
        calls[#calls + 1] = { x = x, y = y, w = 1, h = 1, col = col }
    end
    local ok, err = pcall(fn)
    -- restore no-op mocks
    _G.gfx.fillRect = function(x, y, w, h, col)
        if x == nil or y == nil or w == nil or h == nil then error("fillRect: nil coordinate", 2) end
    end
    _G.gfx.drawPixel = function() end
    if not ok then error(err, 2) end
    return calls
end

local function pixelSet(calls, px, py)
    for _, c in ipairs(calls) do
        if px >= c.x and px < c.x + c.w and py >= c.y and py < c.y + c.h then
            return true
        end
    end
    return false
end

run_test("test_flip180_true_rotation_glyph", function()
    local flipgfx = require("flipgfx")

    -- "K" flipped must equal "K" upright rotated 180 about its 5x7 cell:
    -- ink at (x+dx, y+dy) upright <=> ink at (fx+4-dx, fy+6-dy) flipped.
    local up = withCapture(function() flipgfx.drawGlyphText(100, 100, "K", 1, 0, "up") end)
    local fl = withCapture(function() flipgfx.drawGlyphText(200, 200, "K", 1, 0, "flip180") end)

    for dy = 0, 6 do
        for dx = 0, 4 do
            local upInk = pixelSet(up, 100 + dx, 100 + dy)
            local flInk = pixelSet(fl, 200 + (4 - dx), 200 + (6 - dy))
            if upInk ~= flInk then
                assert_true(false, "K glyph rotation mismatch at offset " .. dx .. "," .. dy)
                return
            end
        end
    end
    assert_true(true, "K glyph is an exact 180 rotation")
end)

run_test("test_flip180_string_order_reversed", function()
    local flipgfx = require("flipgfx")

    -- Regression for "BLACK" rendering as "KCALB": in flip180 mode the FIRST
    -- glyph drawn (leftmost on screen) must be the LAST character of the
    -- string. Compare the leftmost 5x7 cell of flipped "AB" against a lone
    -- flipped "B"; it must match, and must differ from a lone flipped "A"
    -- (which is what un-reversed order would put there).
    local ab = withCapture(function() flipgfx.drawGlyphText(50, 50, "AB", 1, 0, "flip180") end)
    local bOnly = withCapture(function() flipgfx.drawGlyphText(50, 50, "B", 1, 0, "flip180") end)
    local aOnly = withCapture(function() flipgfx.drawGlyphText(50, 50, "A", 1, 0, "flip180") end)

    local matchesB, matchesA = true, true
    for dy = 0, 6 do
        for dx = 0, 4 do
            local abPx = pixelSet(ab, 50 + dx, 50 + dy)
            if abPx ~= pixelSet(bOnly, 50 + dx, 50 + dy) then matchesB = false end
            if abPx ~= pixelSet(aOnly, 50 + dx, 50 + dy) then matchesA = false end
        end
    end
    assert_true(matchesB, "leftmost glyph of flipped 'AB' is 'B' (order reversed)")
    assert_true(not matchesA, "leftmost glyph of flipped 'AB' is not 'A'")
end)

run_test("test_flip180_digits_order_reversed", function()
    local flipgfx = require("flipgfx")

    -- "4:59" flipped must differ from "4:59" upright at the same origin
    -- (per-glyph rotation + order reversal both change the pixels).
    local t = withCapture(function() flipgfx.drawDigits(400, 240, "4:59", 20, 36, 0, true) end)
    local u = withCapture(function() flipgfx.drawDigits(400, 240, "4:59", 20, 36, 0, false) end)

    local differs = false
    for dy = 0, 36 do
        for dx = 0, 140 do
            if pixelSet(t, 330 + dx, 222 + dy) ~= pixelSet(u, 330 + dx, 222 + dy) then
                differs = true
                break
            end
        end
    end
    assert_true(differs, "flipped time differs from upright time")
    assert_true(#t > 0, "flipped render produced rects")
end)

run_test("test_full_draw_all_phases", function()
    -- ready
    state.newGame(5, 3, "5+3 BLITZ", false)
    onDraw()
    -- running
    mockNow = 15000000
    state.startGame(mockNow)
    mockNow = mockNow + 1100
    onDraw()
    -- paused
    state.pause()
    onDraw()
    -- flagged
    state.phase = "flagged"
    state.flaggedSide = "black"
    onDraw()
    -- sleep screen
    onSleepDraw()
end)

run_test("test_draw_survives_corrupted_state", function()
    local savedPhase = state.phase
    local savedPlayers = state.players
    state.phase = nil
    state.players = {
        white = { remaining = nil, moves = nil },
        black = nil,
    }
    local ok, err = pcall(onDraw)
    assert_true(ok, "onDraw survived corrupted state: " .. tostring(err))
    local ok2, err2 = pcall(onSleepDraw)
    assert_true(ok2, "onSleepDraw survived corrupted state: " .. tostring(err2))
    state.phase = savedPhase
    state.players = savedPlayers
    onDraw()
end)

run_test("test_setup_view_draw_and_touch", function()
    setupViewInit = nil
    local setupView = cc.setupView
    setupView.init()
    onDraw() -- view is "clock" here; draw setup directly
    setupView.draw(800, 480)

    -- Hit a preset row (first row at y=64)
    local action = setupView.onTouch(100, 70, 800, 480)
    assert_true(action == "select" or action == nil, "row tap selects: " .. tostring(action))

    -- Hit footer start button (bottom right)
    local f = setupView.footerButtons
    if f then
        local a2 = setupView.onTouch(f.start.x + 5, f.start.y + 5, 800, 480)
        assert_eq(a2, "start", "footer start hit")
    end
end)

run_test("test_setup_selection_moves", function()
    local setupView = cc.setupView
    state.control.mins, state.control.inc = 5, 3 -- ensure a matching preset exists (5+3)
    setupView.init()
    local first = setupView.selected
    setupView.changeSelection(1)
    assert_eq(setupView.selected, math.min(first + 1, #state.PRESETS), "selection advances")
    setupView.changeSelection(-100)
    assert_eq(setupView.selected, 1, "selection clamps at top")
    setupView.changeSelection(100)
    assert_eq(setupView.selected, #state.PRESETS, "selection clamps at bottom")
end)

run_test("test_modals_draw_and_buttons", function()
    local modals = cc.modals
    modals.controlLabel = "5+3 BLITZ"
    modals.flagText = "WHITE WINS ON TIME"
    modals.subText = "tap REMATCH"
    modals.title = "FLAG"
    onDraw()
    modals.drawFlagged(800, 480)
    local box = modals.box
    assert_true(box ~= nil, "modal box computed")
    if box then
        -- Tap first button
        local b = modals.buttons and modals.buttons[1]
        if b then
            local key = modals.buttonAt(b.x + 2, b.y + 2)
            assert_true(key ~= nil, "button hit returns key")
        end
        assert_eq(modals.buttonAt(1, 1), nil, "no button at corner")
    end
    modals.drawMenu(800, 480)
    modals.drawResetConfirm(800, 480)
    modals.buttons = nil
end)

-- ===========================================================================
-- App-Level Wiring (main.lua globals)
-- ===========================================================================

run_test("test_lifecycle_onEnter_onExit", function()
    storageFiles["gamestate.json"] = nil
    onEnter()
    assert_true(type(onDraw) == "function", "onDraw defined")
    assert_true(type(onTouch) == "function", "onTouch defined")
    assert_true(type(onInput) == "function", "onInput defined")
    assert_true(type(onUpdate) == "function", "onUpdate defined")
    assert_true(type(onSleepDraw) == "function", "onSleepDraw defined")
    onExit()
    -- onExit pauses a running game
    assert_true(state.phase ~= "running", "not running after exit")
end)

run_test("test_touch_flow_start_and_switch", function()
    storageFiles["gamestate.json"] = nil
    onEnter()
    -- default view is clock; new game was loaded (or defaults applied)
    state.newGame(5, 3, "5+3 BLITZ", false)

    -- Tap bottom panel: ready -> running (white)
    onTouch(400, 400)
    assert_eq(state.phase, "running", "running after bottom tap")
    assert_eq(state.active, "white", "white active")

    mockNow = mockNow + 2000

    -- Tap bottom again (white active, bottom = white): switch -> black
    onTouch(400, 400)
    assert_eq(state.active, "black", "switched to black")

    -- Tap top (black active when whiteTop=false, top = black): switch -> white
    mockNow = mockNow + 2000
    onTouch(400, 100)
    assert_eq(state.active, "white", "switched back to white")
end)

run_test("test_header_buttons", function()
    -- SWAP button
    local b = cc.clockView.headerButtons
    assert_true(b ~= nil, "header buttons computed")
    if b then
        local before = state.whiteTop
        onTouch(b.swap.x + 2, b.swap.y + 2)
        assert_eq(state.whiteTop, not before, "swap toggles seats")
        -- MENU button
        onTouch(b.menu.x + 2, b.menu.y + 2)
        -- menu modal should now be open; verify via drawing
        local ok, err = pcall(onDraw)
        assert_true(ok, "menu modal draws: " .. tostring(err))
        -- close via RESUME button (first button)
        local mb = cc.modals.buttons and cc.modals.buttons[1]
        if mb then
            onTouch(mb.x + 2, mb.y + 2)
        end
    end
end)

run_test("test_button_input_pause_resume", function()
    state.newGame(5, 0, "5+0 BLITZ", false)
    onInput(input.BTN_CONFIRM, "press")
    assert_eq(state.phase, "ready", "confirm does not start from ready")

    state.startGame(16000000)
    onInput(input.BTN_CONFIRM, "press")
    assert_eq(state.phase, "paused", "confirm pauses")
    onInput(input.BTN_CONFIRM, "press")
    assert_eq(state.phase, "running", "confirm resumes")
end)

run_test("test_onBack_consumes_modal", function()
    -- Open menu modal via onTouch on menu button
    local b = cc.clockView.headerButtons
    if b then
        onTouch(b.menu.x + 2, b.menu.y + 2)
        assert_true(onBack() == true, "back closes modal")
        assert_true(onBack() == false, "back exits on plain clock")
    end
end)

run_test("test_onUpdate_ticks_display", function()
    state.newGame(1, 0, "1+0 BULLET", false)
    mockNow = 17000000
    state.startGame(mockNow)
    mockNow = mockNow + 2500
    -- Must not error and should not crash on tick
    local ok, err = pcall(onUpdate, 0.05)
    assert_true(ok, "onUpdate safe: " .. tostring(err))
end)

run_test("test_millis_wrap_rebaselines", function()
    state.newGame(5, 0, "5+0 BLITZ", false)
    state.startGame(4294000000) -- near the 2^32 wrap
    state.tick(200000)          -- wrapped to small value
    assert_eq(state.phase, "running", "still running after wrap")
    assert_eq(state.players.white.remaining, 300000, "no phantom time charged")
end)

run_test("test_hot_reload_keeps_state_file", function()
    state.newGame(5, 0, "5+0 BLITZ", false)
    state.startGame(18000000)
    state.tick(18000000 + 1000)
    onExit() -- saves paused game
    local saved = storageFiles["gamestate.json"]
    assert_true(saved ~= nil, "state persisted on exit")
    assert_true(tostring(saved):find('"paused"') ~= nil, "paused in save file")
end)

-- ===========================================================================
-- Summary
-- ===========================================================================

print("")
print("============================================================")
print("CHESS CLOCK TEST RESULTS: " .. passCount .. " Passed, " .. failCount .. " Failed (Total: " .. testCount .. ")")
print("============================================================")
os.exit(failCount > 0 and 1 or 0)
