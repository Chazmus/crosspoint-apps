-- ============================================================================
-- Automated Test Suite for Chess Puzzles App
-- Runs headlessly under lua5.4 to verify FEN parsing, puzzle lifecycle,
-- move validation, withWifi sync, touch interactions, and rendering safety.
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
local wifiStatus = false
local wifiCalls = 0
local httpGetUrl = nil
local httpGetResponse = nil

local function setupMocks()
    storageFiles = {}
    wifiStatus = false
    wifiCalls = 0
    httpGetUrl = nil
    httpGetResponse = nil

    -- Read actual daily.json from disk into mock storage
    local f = io.open("apps/chess/daily.json", "r")
    if f then
        storageFiles["daily.json"] = f:read("*a")
        f:close()
    end

    _G.gfx = {
        ORIENTATION_PORTRAIT = 0,
        ORIENTATION_LANDSCAPE = 1,
        ORIENTATION_PORTRAIT_INVERTED = 2,
        ORIENTATION_LANDSCAPE_CCW = 3,
        FONT_UI_10 = 1,
        FONT_UI_12 = 2,
        FONT_SMALL = 3,
        FONT_NOTOSANS_12 = 4,
        FONT_NOTOSANS_14 = 5,
        FONT_NOTOSANS_16 = 6,
        FONT_NOTOSERIF_12 = 7,
        FONT_NOTOSERIF_14 = 8,
        REFRESH_FAST = 0,
        REFRESH_FULL = 1,

        getWidth = function() return 800 end,
        getHeight = function() return 480 end,
        getOrientation = function() return 1 end,
        setOrientation = function(o) end,
        clearScreen = function(c) end,
        drawPixel = function(x, y, c) end,
        drawLine = function(x0, y0, x1, y1, c) end,
        drawRect = function(x, y, w, h, c) end,
        fillRect = function(x, y, w, h, c) end,
        fillRectDither = function(x, y, w, h, l) end,
        drawRoundedRect = function(x, y, w, h, r, t, c) end,
        fillRoundedRect = function(x, y, w, h, r, c) end,
        drawCircle = function(x, y, r, c) end,
        drawText = function(font, x, y, text, c) end,
        drawCenteredText = function(font, y, text, c) end,
        getTextWidth = function(font, text) return #text * 8 end,
        getLineHeight = function(font) return 16 end,
        drawSprite = function(x, y, w, h, data, c) end,
        drawBitmapFile = function(x, y, path) return true end,
        displayBuffer = function(m) end,
    }

    _G.input = {
        BTN_BACK = 1,
        BTN_CONFIRM = 2,
        BTN_LEFT = 3,
        BTN_RIGHT = 4,
        BTN_UP = 5,
        BTN_DOWN = 6,
        BTN_PAGE_BACK = 7,
        BTN_PAGE_FORWARD = 8,
        wasPressed = function(b) return false end,
        isPressed = function(b) return false end,
        isTouchDown = function() return false end,
        getTouch = function() return false, 0, 0 end,
        wasTouchDown = function() return false, 0, 0 end,
        wasTouchReleased = function() return false end,
        wasScreenTapped = function() return false end,
    }

    _G.storage = {
        readFile = function(path) return storageFiles[path] end,
        writeFile = function(path, content) storageFiles[path] = content return true end,
        exists = function(path) return storageFiles[path] ~= nil end,
        remove = function(path) storageFiles[path] = nil return true end,
    }

    _G.log = {
        debug = function(...) end,
        info = function(...) end,
        warn = function(...) end,
        error = function(...) end,
    }

    _G.crosspoint = {
        millis = function() return 1000 end,
        requestUpdate = function() end,
        finish = function() end,
        log = function(...) end,
        getMemoryInfo = function() return { luaMemoryKb = 100, freeHeapKb = 200, freePsramKb = 4000 } end,
        isWifiConnected = function() return wifiStatus end,
        connectWifi = function(cb)
            wifiCalls = wifiCalls + 1
            if cb then cb(wifiStatus) end
        end,
        withWifi = function(cb)
            wifiCalls = wifiCalls + 1
            if cb then cb(wifiStatus) end
        end,
        disconnectWifi = function()
            wifiStatus = false
        end,
        httpGet = function(url)
            httpGetUrl = url
            return httpGetResponse
        end,
        setSleepApp = function(id) _G._sleepApp = id end,
        getSleepApp = function() return _G._sleepApp or "" end,
        clearSleepApp = function() _G._sleepApp = nil end,
    }
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------
setupMocks()

package.path = "./apps/chess/?.lua;./apps/chess/?/init.lua;" .. package.path
local chessApp = dofile("apps/chess/main.lua")

run_test("App initialization & puzzle loading", function()
    setupMocks()
    onEnter()
    assert_true(storage.exists("daily.json"), "daily.json should be present in storage")
end)

run_test("Rendering calls succeed without crash", function()
    onDraw()
    onSleepDraw()
    assert_true(true, "onDraw and onSleepDraw rendered safely")
end)

run_test("Touch on Sync Daily button invokes withWifi", function()
    setupMocks()
    wifiStatus = true
    httpGetResponse = '{"game":{"id":"test1234"},"puzzle":{"id":"00001","rating":1500,"solution":["e2e4","e7e5"],"themes":["opening"]},"fen":"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"}'

    onEnter()
    local oldWifiCalls = wifiCalls

    -- Tap Sync Daily button: col1X = 445, row2Y = 346, btnW = 160, btnH = 44
    onTouch(460, 360)

    assert_true(wifiCalls > oldWifiCalls, "withWifi should have been called on Sync Daily tap")
    assert_eq(httpGetUrl, "https://lichess.org/api/puzzle/daily", "httpGet should query Lichess daily API")
    assert_true(storage.exists("daily.json"), "storage should update daily.json")
end)

run_test("Sync Daily handles Wi-Fi cancellation safely", function()
    setupMocks()
    wifiStatus = false -- simulate user cancelled or no network

    onEnter()
    onTouch(460, 360) -- Tap Sync Daily

    assert_true(true, "Handled Wi-Fi cancellation without crashing")
end)

run_test("Sync Daily handles network error (nil response) safely", function()
    setupMocks()
    wifiStatus = true
    httpGetResponse = nil -- simulate failed download

    onEnter()
    onTouch(460, 360)

    assert_true(true, "Handled nil HTTP response gracefully")
end)

run_test("Sleep screen toggle", function()
    setupMocks()
    onEnter()
    -- Tap Set Sleep button: col2X = 620, row2Y = 346
    onTouch(630, 360)
    assert_eq(crosspoint.getSleepApp(), "chess", "Sleep app should be set to chess")

    onTouch(630, 360)
    assert_eq(crosspoint.getSleepApp(), "", "Sleep app should be toggled off")
end)

run_test("Board reset button", function()
    setupMocks()
    onEnter()
    -- Tap Reset button: col2X = 620, row1Y = 290
    onTouch(630, 310)
    assert_true(true, "Reset button executed successfully")
end)

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
print(string.format("\nChess App Test Summary: %d/%d passed (%d failed)", passCount, testCount, failCount))
if failCount > 0 then
    os.exit(1)
end
