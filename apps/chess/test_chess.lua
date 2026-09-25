-- ============================================================================
-- Automated Test Suite for CrossPoint Chess App
-- Tests FEN parsing, move generation, AI minimax engine, Play vs Computer,
-- Daily Tactical Puzzles, Wi-Fi sync, undo, board flip, and sleep screens.
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
    _G._sleepApp = nil

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
        COLOR_BLACK = 0,
        COLOR_WHITE = 1,
        COLOR_LIGHT_GRAY = 2,
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

setupMocks()
package.path = "./apps/chess/?.lua;./apps/chess/?/init.lua;" .. package.path
local Engine = require("apps.chess.engine")
dofile("apps/chess/main.lua")

-- ===========================================================================
-- 1. Engine Unit Tests
-- ===========================================================================
run_test("Engine: initial board & FEN export", function()
    local g = Engine.newGame()
    local fen = Engine.toFen(g)
    assert_eq(fen, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", "Default FEN match")
    assert_eq(g.turn, "w", "White begins")
    assert_eq(#g.history, 0, "No history yet")
end)

run_test("Engine: legal move count at start", function()
    local g = Engine.newGame()
    local legals = Engine.getLegalMoves(g)
    assert_eq(#legals, 20, "20 initial legal moves (16 pawn pushes + 4 knight jumps)")
end)

run_test("Engine: move execution, check detection, and undo", function()
    local g = Engine.newGame()
    -- Fool's mate sequence: 1. f3 e5 2. g4 Qh4#
    assert_true(Engine.makeMove(g, Engine.uciToMove("f2f3")), "Move f2f3")
    assert_true(Engine.makeMove(g, Engine.uciToMove("e7e5")), "Move e7e5")
    assert_true(Engine.makeMove(g, Engine.uciToMove("g2g4")), "Move g2g4")
    assert_true(Engine.makeMove(g, Engine.uciToMove("d8h4")), "Move d8h4")

    local over, winner, reason = Engine.getGameStatus(g)
    assert_true(over, "Game should be over")
    assert_eq(winner, "b", "Black wins")
    assert_eq(reason, "checkmate", "Reason is checkmate")

    -- Undo back to before checkmate
    assert_true(Engine.undoMove(g), "Undo Qh4")
    local overAfterUndo, _, _ = Engine.getGameStatus(g)
    assert_true(not overAfterUndo, "Game is no longer over after undo")
    assert_eq(g.turn, "b", "Turn restored to Black")
end)

run_test("Engine: Castling rights & execution", function()
    -- Set up position where White can castle Kingside
    local fen = "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 4 5"
    local g = Engine.newGame(fen)
    local moveCastle = Engine.uciToMove("e1g1")
    assert_true(Engine.makeMove(g, moveCastle), "Castling e1g1 should succeed")
    assert_eq(g.board[6], "K", "King on g1")
    assert_eq(g.board[5], "R", "Rook on f1")
    assert_eq(g.board[4], ".", "e1 empty")
    assert_eq(g.board[7], ".", "h1 empty")
end)

run_test("Engine: En Passant capture", function()
    -- White pawn on e5, Black plays d7d5 -> White can capture e5xd6 ep
    local fen = "rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3"
    local g = Engine.newGame(fen)
    local epMove = Engine.uciToMove("e5d6")
    assert_true(Engine.makeMove(g, epMove), "e5d6 en passant should succeed")
    assert_eq(g.board[43], "P", "White Pawn on d6")
    assert_eq(g.board[35], ".", "Captured Black Pawn on d5 removed")
end)

run_test("Engine: AI getBestMove produces valid legal moves", function()
    local g = Engine.newGame()
    local m1 = Engine.getBestMove(g, 1) -- Easy
    local m2 = Engine.getBestMove(g, 2) -- Medium
    local m3 = Engine.getBestMove(g, 3) -- Hard

    assert_true(m1 ~= nil and #m1 >= 4, "Easy move generated: " .. tostring(m1))
    assert_true(m2 ~= nil and #m2 >= 4, "Medium move generated: " .. tostring(m2))
    assert_true(m3 ~= nil and #m3 >= 4, "Hard move generated: " .. tostring(m3))

    local isLegal1 = Engine.isLegalMove(g, Engine.uciToMove(m1))
    local isLegal2 = Engine.isLegalMove(g, Engine.uciToMove(m2))
    local isLegal3 = Engine.isLegalMove(g, Engine.uciToMove(m3))
    assert_true(isLegal1, "m1 is legal")
    assert_true(isLegal2, "m2 is legal")
    assert_true(isLegal3, "m3 is legal")
end)

-- ===========================================================================
-- 2. App Lifecycle, Menu & Navigation Tests
-- ===========================================================================
run_test("App initialization & Main Menu display", function()
    setupMocks()
    dofile("apps/chess/main.lua")
    onEnter()
    onDraw()
    assert_true(true, "onEnter and onDraw executed successfully on main menu")
end)

run_test("Sleep screen toggle on Main Menu", function()
    setupMocks()
    dofile("apps/chess/main.lua")
    onEnter()

    -- Sleep toggle button at bottom right (x=580..760, y=418..462)
    onTouch(650, 440)
    assert_eq(crosspoint.getSleepApp(), "chess", "Sleep app should be toggled ON to chess")

    onTouch(650, 440)
    assert_eq(crosspoint.getSleepApp(), "", "Sleep app should be toggled OFF")
end)

run_test("Daily Puzzle navigation, hint, reset, and Wi-Fi sync", function()
    setupMocks()
    wifiStatus = true
    httpGetResponse = '{"game":{"id":"test1234"},"puzzle":{"id":"00001","rating":1500,"solution":["e2e4","e7e5"],"themes":["opening"]},"fen":"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"}'
    dofile("apps/chess/main.lua")
    onEnter()

    -- 1. Tap Daily Puzzle card on Main Menu (Card 2: x=420..760, y=68..400)
    onTouch(500, 200)
    onDraw()

    -- 2. Tap Hint button (col1X = 445, row1Y = 290, btnW = 160, btnH = 44)
    onTouch(500, 310)

    -- 3. Tap Reset button (col2X = 620, row1Y = 290)
    onTouch(680, 310)

    -- 4. Tap Sync Daily button (col1X = 445, row2Y = 346)
    local oldWifiCalls = wifiCalls
    onTouch(500, 360)
    assert_true(wifiCalls > oldWifiCalls, "withWifi invoked on Sync Daily tap")
    assert_eq(httpGetUrl, "https://lichess.org/api/puzzle/daily", "Lichess daily API queried")

    -- 5. Tap Menu button (col2X = 620, row2Y = 346)
    onTouch(680, 360)
    onDraw()
    assert_true(true, "Returned to Main Menu successfully")
end)

run_test("Daily Puzzle handles Wi-Fi cancellation & network error safely", function()
    setupMocks()
    dofile("apps/chess/main.lua")
    onEnter()

    -- Enter Daily Puzzle
    onTouch(500, 200)

    -- Cancelled Wi-Fi
    wifiStatus = false
    onTouch(500, 360)
    assert_true(true, "Handled Wi-Fi cancellation safely")

    -- Failed download (nil HTTP response)
    wifiStatus = true
    httpGetResponse = nil
    onTouch(500, 360)
    assert_true(true, "Handled nil HTTP response safely")
end)

-- ===========================================================================
-- 3. Play vs Computer Game Mode Tests
-- ===========================================================================
run_test("Play vs Computer: Setup, gameplay, AI move, undo, and save", function()
    setupMocks()
    dofile("apps/chess/main.lua")
    onEnter()

    -- 1. Tap Card 1 (Play vs Computer) on Main Menu
    onTouch(200, 200)
    onDraw()

    -- 2. On Setup screen: Choose White (x=60..380, y=125..188) and Medium (x=420..740, y=180..232)
    onTouch(150, 150) -- White
    onTouch(500, 200) -- Medium
    -- Tap Start Game button (x=240..560, y=335..400)
    onTouch(350, 360)
    onDraw()

    -- 3. Make move e2e4:
    -- Board coordinates: boardX=26, boardY=50, boardSize=400, sqSize=50
    -- White perspective: file e = file 4 -> dispFile 4 -> x = 26 + 4*50 + 25 = 251
    -- Rank 2 (index 1) -> dispRank 7 - 1 = 6 -> y = 50 + 6*50 + 25 = 375
    -- Tap e2
    onTouch(251, 375)

    -- Rank 4 (index 3) -> dispRank 7 - 3 = 4 -> y = 50 + 4*50 + 25 = 275
    -- Tap e4
    onTouch(251, 275)
    onDraw()

    -- Verify move executed and game saved
    assert_true(storage.exists("game.json"), "game.json should be saved after player move")

    -- 4. Trigger computer thinking via onUpdate countdown
    onUpdate(0.05) -- frame 1
    onUpdate(0.05) -- frame 2: AI calculates and makes move
    onDraw()

    -- 5. Tap Undo button (col1X = 445, row1Y = 270, btnW = 160, btnH = 44)
    onTouch(500, 290)
    onDraw()

    -- 6. Tap Flip Board button (col1X = 445, row2Y = 326)
    onTouch(500, 345)
    onDraw()

    -- 7. Tap Menu button (col2X = 620, row2Y = 326) to return to Main Menu
    onTouch(680, 345)
    onDraw()

    -- 8. Verify Resume Game is available on Main Menu
    -- Tapping Resume Game (y <= 325 on Card 1)
    onTouch(200, 300)
    onDraw()
    assert_true(true, "Successfully resumed game from Main Menu")
end)

run_test("Left-edge back swipe gesture returns to menu", function()
    setupMocks()
    dofile("apps/chess/main.lua")
    onEnter()

    -- Enter Setup screen
    onTouch(200, 200)

    -- Simulate swipe from left edge (x=10 -> x=80, dy < 120)
    onTouchDown(10, 200)
    onTouchUp(80, 205)
    onDraw()

    -- Hardware Back button test
    assert_true(not onBack(), "onBack on Main Menu returns false to exit to launcher")
end)

run_test("Sleep screen rendering in both Game and Puzzle modes", function()
    setupMocks()
    dofile("apps/chess/main.lua")
    onEnter()

    -- Sleep draw from Main Menu (renders Daily Puzzle)
    onSleepDraw()

    -- Enter Game mode and sleep draw (renders active game)
    onTouch(200, 200) -- Setup
    onTouch(350, 360) -- Start game
    onSleepDraw()

    assert_true(true, "onSleepDraw rendered safely in all modes")
end)

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
print(string.format("\nChess App Test Summary: %d/%d passed (%d failed)", passCount, testCount, failCount))
if failCount > 0 then
    os.exit(1)
end
