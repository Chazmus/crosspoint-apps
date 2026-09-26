-- ============================================================================
-- Automated Test Suite for Spell Counter MTG App
-- Runs headlessly under lua5.4 to verify nil-safety, state persistence,
-- touch handling, hardware buttons, modal lifecycle, and rendering resilience.
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

local function setupMocks()
    storageFiles = {}

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
        getWidth = function() return 800 end,
        getHeight = function() return 480 end,
        clearScreen = function(c) end,
        fillRect = function(x, y, w, h, col) end,
        drawRect = function(x, y, w, h, lw, col) end,
        fillRoundedRect = function(x, y, w, h, r, col)
            if type(col) ~= "number" then
                error("bad argument #6 to fillRoundedRect (number expected, got " .. type(col) .. ")", 2)
            end
        end,
        drawRoundedRect = function(x, y, w, h, r, lw, col) end,
        drawLine = function(x1, y1, x2, y2, lw, col) end,
        drawCircle = function(x, y, r, lw, col) end,
        drawText = function(font, x, y, text, col)
            if text == nil then
                error("bad argument #4 to drawText (string expected, got nil)", 2)
            end
        end,
        drawCenteredText = function(font, y, text, col)
            if text == nil then
                error("bad argument #3 to drawCenteredText (string expected, got nil)", 2)
            end
        end,
        getTextWidth = function(font, text)
            if text == nil then
                error("bad argument #2 to getTextWidth (string expected, got nil)", 2)
            end
            return #tostring(text) * 8
        end,
        getLineHeight = function(font) return 16 end,
    }

    local mockTouch = {
        down = false,
        x = 0,
        y = 0,
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
        isTouchDown = function() return mockTouch.down end,
        getTouch = function()
            if mockTouch.down then
                return true, mockTouch.x, mockTouch.y
            end
            return false
        end,
        setMockTouch = function(down, x, y)
            mockTouch.down = down
            mockTouch.x = x or 0
            mockTouch.y = y or 0
        end,
    }

    _G.storage = {
        readFile = function(path)
            if storageFiles[path] ~= nil then
                return storageFiles[path]
            end
            local f = io.open("apps/spellcounter/" .. path, "r")
            if f then
                local content = f:read("*a")
                f:close()
                return content
            end
            return nil
        end,
        writeFile = function(path, content)
            storageFiles[path] = content
            return true
        end,
        exists = function(path)
            return storageFiles[path] ~= nil
        end,
        remove = function(path)
            storageFiles[path] = nil
            return true
        end,
    }

    _G.crosspoint = {
        millis = function() return 1000 end,
        requestUpdate = function() end,
        getSleepApp = function() return "" end,
        setSleepApp = function(id) end,
        clearSleepApp = function() end,
        log = function(msg) end,
    }

    _G.log = {
        debug = function(tag, msg) end,
        info = function(tag, msg) end,
        warn = function(tag, msg) end,
        error = function(tag, msg) end,
    }
end

package.path = "apps/spellcounter/?.lua;apps/spellcounter/?/init.lua;" .. package.path

-- ---------------------------------------------------------------------------
-- Load App Script
-- ---------------------------------------------------------------------------
setupMocks()
dofile("apps/spellcounter/main.lua")

local sc = _G._SPELLCOUNTER
assert(sc, "_SPELLCOUNTER must be exported for tests")
local state = sc.state
local ui = sc.ui
local saveState = sc.saveState
local loadState = sc.loadState
local ensurePlayer = sc.ensurePlayer

-- ===========================================================================
-- Test Cases
-- ===========================================================================

-- 1. Initial State Test
run_test("test_initial_state", function()
    setupMocks()
    onEnter()
    assert_true(type(onDraw) == "function", "onDraw is defined")
    assert_true(type(onTouch) == "function", "onTouch is defined")
    assert_true(type(onInput) == "function", "onInput is defined")
    assert_true(type(onSleepDraw) == "function", "onSleepDraw is defined")
    assert_eq(state.playerCount, 4, "Default 4 players")
    assert_eq(state.startingLife, 40, "Default 40 life")
    assert_eq(#state.players, 4, "4 players present")
    onDraw()
end)

-- 2. Nil Safety in onDraw with Corrupted Data
run_test("test_nil_safety_drawing", function()
    onDraw()

    -- Simulate partially nil players and broken state
    local origPlayers = state.players
    state.players = {
        nil,
        { id = 2, name = nil, life = nil, tax = nil, poison = nil, cmdrDmg = nil },
        {},
    }
    state.playerCount = 4
    state.selectedPlayer = nil

    -- onDraw must not crash even with corrupted state
    local ok, err = pcall(onDraw)
    assert_true(ok, "onDraw survived corrupted player state: " .. tostring(err))

    -- Restore
    state.players = origPlayers
    for i = 1, 4 do
        state.players[i] = ensurePlayer(state.players[i], i, state.startingLife)
    end
    state.playerCount = 4
    state.selectedPlayer = 1
    onDraw()
end)

-- 3. Nil Safety in onSleepDraw
run_test("test_nil_safety_sleep_draw", function()
    onSleepDraw()

    local origPlayers = state.players
    state.players = { nil, { life = nil, poison = nil, tax = nil }, nil }
    state.playerCount = 3

    local ok, err = pcall(onSleepDraw)
    assert_true(ok, "onSleepDraw survived corrupted state: " .. tostring(err))

    state.players = origPlayers
    for i = 1, 4 do
        state.players[i] = ensurePlayer(state.players[i], i, state.startingLife)
    end
    state.playerCount = 4
end)

-- 4. Modals Drawing Resilience
run_test("test_modals_drawing", function()
    local modals = {"tools", "player_detail", "reset", "player_count"}
    for _, m in ipairs(modals) do
        ui.modal = m
        local ok, err = pcall(onDraw)
        assert_true(ok, "Modal " .. m .. " rendered safely: " .. tostring(err))
    end
    ui.modal = nil
    onDraw()
end)

-- 5. Touch Life Adjustments (Tap ±1 and Hold ±10)
run_test("test_touch_life_adjustments", function()
    onEnter()
    local p1Start = state.players[1].life

    -- 1. Tap left side of P1 card (-1 Life)
    onTouch(50, 150)
    assert_eq(state.players[1].life, p1Start - 1, "P1 life decreased by 1")

    -- 2. Tap right side of P1 card (+1 Life)
    onTouch(350, 150)
    assert_eq(state.players[1].life, p1Start, "P1 life restored by 1")

    -- 3. Press and hold right side (+10 Life)
    input.setMockTouch(true, 350, 150)
    onUpdate(0.1) -- 100ms: not yet 500ms
    assert_eq(state.players[1].life, p1Start, "Life unchanged before 500ms threshold")

    onUpdate(0.45) -- total 550ms: triggers first +10 tick!
    assert_eq(state.players[1].life, p1Start + 10, "Life increased by 10 after 500ms hold")

    onUpdate(0.5) -- total 1050ms: not yet 1550ms (second tick)
    assert_eq(state.players[1].life, p1Start + 10, "Life unchanged between ticks")

    onUpdate(0.6) -- total 1650ms: triggers second +10 tick!
    assert_eq(state.players[1].life, p1Start + 20, "Life increased by another 10 after 1s repeat")

    -- Release touch: tap should be suppressed
    input.setMockTouch(false)
    onUpdate(0.05)
    onTouch(350, 150) -- simulate SDL/hardware tap event fired on release
    assert_eq(state.players[1].life, p1Start + 20, "Tap suppressed after hold tick")

    -- 4. Press and hold left side (-10 Life)
    input.setMockTouch(true, 50, 150)
    onUpdate(0.55) -- 550ms: triggers -10 tick
    assert_eq(state.players[1].life, p1Start + 10, "Life decreased by 10 on hold")
    input.setMockTouch(false)
    onUpdate(0.05)
    onTouch(50, 150)
    assert_eq(state.players[1].life, p1Start + 10, "Tap suppressed after minus hold tick")
end)

-- 6. Touch Tools & Dice Rolling
run_test("test_tools_and_dice", function()
    -- Tap [Tools] button (top right: x=750, y=20)
    onTouch(750, 20)
    assert_eq(ui.modal, "tools", "Tools modal opened")

    -- Tap Roll D20 button in modal (x=150, y=140)
    onTouch(150, 140)
    assert_true(ui.diceResult ~= nil, "Dice result generated")
    assert_true(ui.diceResult.type == "D20", "D20 roll type")
    assert_true(ui.diceResult.val >= 1 and ui.diceResult.val <= 20, "D20 result between 1 and 20")

    -- Tap Roll D6 button (x=300, y=140)
    onTouch(300, 140)
    assert_true(ui.diceResult.type == "D6", "D6 roll type")
    assert_true(ui.diceResult.val >= 1 and ui.diceResult.val <= 6, "D6 result between 1 and 6")

    -- Tap Flip Coin button (x=440, y=140)
    onTouch(440, 140)
    assert_true(ui.diceResult.type == "COIN", "Coin flip type")
    assert_true(ui.diceResult.val == "HEADS" or ui.diceResult.val == "TAILS", "Coin result valid")

    -- Tap Who 1st? button (x=580, y=140)
    onTouch(580, 140)
    assert_true(ui.firstPlayerResult ~= nil, "First player selected")
    assert_true(ui.firstPlayerResult >= 1 and ui.firstPlayerResult <= 4, "First player valid index")

    -- Close modal via onBack
    onBack()
    assert_eq(ui.modal, nil, "Tools modal closed via back")
end)

-- 7. Tokens & Monarch Assignment
run_test("test_monarch_and_tokens", function()
    -- Open tools modal
    onTouch(750, 20)
    -- Switch to Tokens tab (mx=80, tabW=200, tabY=83..113 -> x=350, y=95)
    onTouch(350, 95)
    assert_eq(ui.toolsTab, "tokens", "Switched to Tokens tab")

    -- Set Monarch to P2 (x in [300, 352], y in [129, 161])
    onTouch(320, 140)
    assert_eq(state.monarch, 2, "Monarch set to P2")

    -- Set Day/Night to Night (x in [404, 478], y in [225, 257])
    onTouch(430, 240)
    assert_eq(state.dayNight, "night", "Day/Night set to night")

    onBack()
    assert_eq(ui.modal, nil, "Modal closed")
end)

-- 8. Player Detail & Commander Damage
run_test("test_player_detail_counters", function()
    -- Open P1 detail modal via menu button [···] (x=370, y=50)
    onTouch(370, 50)
    assert_eq(ui.modal, "player_detail", "Player detail opened")
    assert_eq(ui.detailPlayer, 1, "P1 selected for detail")

    local startLife = state.players[1].life

    -- Tap Commander damage + from P2 (opp=2, cw=94, + button is x >= 324)
    onTouch(340, 180)
    assert_eq(state.players[1].cmdrDmg[2], 1, "P1 took 1 commander damage from P2")
    assert_eq(state.players[1].life, startLife - 1, "Life auto-reduced by commander damage")

    -- Tap Poison + (x in [310, 354], y in [123, 155])
    onTouch(330, 135)
    assert_eq(state.players[1].poison, 1, "P1 poison incremented")

    -- Close detail modal
    onBack()
    assert_eq(ui.modal, nil, "Player detail modal closed")
end)

-- 9. Player Count Switching (1, 2, 3, 4 Players)
run_test("test_player_count_switching", function()
    -- Open player count modal (x=50, y=20)
    onTouch(50, 20)
    assert_eq(ui.modal, "player_count", "Player count modal opened")

    -- Tap 2 Players option (x=350, y=225)
    onTouch(350, 225)
    assert_eq(ui.modal, nil, "Modal dismissed on selection")
    assert_eq(state.playerCount, 2, "Player count set to 2")
    onDraw()

    -- Switch back to 4 players (x=350, y=310)
    onTouch(50, 20)
    onTouch(350, 310)
    assert_eq(state.playerCount, 4, "Player count restored to 4")
    onDraw()
end)

-- 10. Hardware Buttons
run_test("test_hardware_buttons", function()
    state.selectedPlayer = 1
    local curLife = state.players[1].life

    -- Button UP (+1)
    onInput(input.BTN_UP, "press")
    assert_eq(state.players[1].life, curLife + 1, "BTN_UP increased life")

    -- Button DOWN (-1)
    onInput(input.BTN_DOWN, "press")
    assert_eq(state.players[1].life, curLife, "BTN_DOWN decreased life")

    -- Button RIGHT (cycle selected player)
    onInput(input.BTN_RIGHT, "press")
    assert_eq(state.selectedPlayer, 2, "BTN_RIGHT selected P2")

    -- Button CONFIRM (toggle detail modal)
    onInput(input.BTN_CONFIRM, "press")
    assert_eq(ui.modal, "player_detail", "BTN_CONFIRM opened detail modal")

    -- Button BACK (dismiss modal)
    local consumed = onBack()
    assert_true(consumed, "onBack consumed modal")
    assert_eq(ui.modal, nil, "Modal dismissed")
end)

-- 11. State Persistence & Corrupt JSON Recovery
run_test("test_persistence_and_recovery", function()
    state.players[1].life = 33
    saveState()
    onEnter()
    assert_eq(state.players[1].life, 33, "State preserved in JSON")

    -- Test corrupt JSON string
    storageFiles["gamestate.json"] = "INVALID JSON {[[["
    local ok, err = pcall(loadState)
    assert_true(ok, "loadState safely handled corrupt JSON: " .. tostring(err))
    assert_true(#state.players == 4, "State recovered to 4 valid players")
    assert_true(state.players[1].life == 40, "Default life restored")

    -- Test JSON where "players" is a number instead of an array (e.g. {"players": 4})
    storageFiles["gamestate.json"] = '{"players": 4, "startingLife": 40}'
    ok, err = pcall(loadState)
    assert_true(ok, "loadState survived numeric players field: " .. tostring(err))
    assert_true(#state.players == 4, "State recovered from numeric players")

    -- Test JSON where "history" is a number instead of an array
    storageFiles["gamestate.json"] = '{"history": 0, "players": [{"life": 40}]}'
    ok, err = pcall(loadState)
    assert_true(ok, "loadState survived numeric history: " .. tostring(err))
    ui.modal = "tools"
    ui.toolsTab = "history"
    ok, err = pcall(onDraw)
    assert_true(ok, "onDraw survived numeric history: " .. tostring(err))
    ui.modal = nil

    -- Test empty file
    storageFiles["gamestate.json"] = ""
    ok, err = pcall(loadState)
    assert_true(ok, "loadState handled empty file")

    -- Test nil file
    storageFiles["gamestate.json"] = nil
    ok, err = pcall(loadState)
    assert_true(ok, "loadState handled nil file")
end)

-- 12. Screen Grid Fuzz Testing (500 random touch coordinates)
run_test("test_grid_fuzzing", function()
    math.randomseed(42)
    for i = 1, 500 do
        local rx = math.random(-50, 850)
        local ry = math.random(-50, 550)
        local ok, err = pcall(onTouch, rx, ry)
        if not ok then
            error("Crash at touch (" .. rx .. ", " .. ry .. "): " .. tostring(err))
        end
    end
    local ok, err = pcall(onDraw)
    assert_true(ok, "onDraw survived after fuzzing")
end)

-- 13. Enlarged Card Menu Button (...) Hitbox Tests
run_test("test_menu_button_hitbox", function()
    local gridModule = require("views.grid")
    local rects = gridModule.getCardRects(800, 480, 4)
    local r1 = rects[1]
    assert_true(r1 ~= nil, "Card 1 rect exists")

    local btnX, btnY, btnW, btnH = gridModule.getMenuButtonBounds(r1)
    assert_true(btnW >= 50, "Visual button width enlarged (>= 50px)")
    assert_true(btnH >= 24, "Visual button height valid")

    -- 1. Center of visual button should be a hit
    assert_true(gridModule.isMenuButtonTouch(btnX + math.floor(btnW / 2), btnY + math.floor(btnH / 2), r1), "Center of button is hit")

    -- 2. Top-right corner of card (above & to the right of visual button) should be a hit
    assert_true(gridModule.isMenuButtonTouch(r1.x + r1.w - 1, r1.y + 1, r1), "Top-right edge of card is hit")

    -- 3. Left margin (just to the left of the button) should be a hit
    assert_true(gridModule.isMenuButtonTouch(btnX - 10, btnY + 10, r1), "Left margin of button is hit")

    -- 4. Lower margin (in header divider / just below button) should be a hit
    assert_true(gridModule.isMenuButtonTouch(btnX + 10, r1.y + 48, r1), "Lower margin below button is hit")

    -- 5. Far below (e.g. at y + 80, in the life + button region) must NOT be a hit
    assert_true(not gridModule.isMenuButtonTouch(btnX + 10, r1.y + 80, r1), "Plus button area is not menu hit")

    -- 6. Left side of card (e.g. player name) must NOT be a hit
    assert_true(not gridModule.isMenuButtonTouch(r1.x + 20, r1.y + 10, r1), "Card left side is not menu hit")

    -- 7. Nil safety
    assert_true(not gridModule.isMenuButtonTouch(100, 100, nil), "Nil rect safely returns false")

    -- 8. Integration: Tapping near top-right corner of card triggers player_detail and preserves life
    ui.modal = nil
    local p1LifeBefore = state.players[1].life
    -- Tap at the very top-right edge of P1 card (r1.x + r1.w - 2, r1.y + 2)
    onTouch(r1.x + r1.w - 2, r1.y + 2)
    assert_eq(ui.modal, "player_detail", "Top-right edge tap opened player detail modal")
    assert_eq(state.players[1].life, p1LifeBefore, "Life unchanged on menu tap")
    onBack()
    assert_eq(ui.modal, nil, "Modal closed")

    -- 9. Integration: getLifeTouchTarget returns nil within menu hitbox (prevents accidental hold ticks)
    assert_true(sc.getLifeTouchTarget(r1.x + r1.w - 2, r1.y + 2) == nil, "getLifeTouchTarget ignores menu hitbox")
    assert_true(sc.getLifeTouchTarget(btnX - 10, btnY + 10) == nil, "getLifeTouchTarget ignores extended left margin")
    assert_true(sc.getLifeTouchTarget(btnX + 10, r1.y + 45) == nil, "getLifeTouchTarget ignores extended lower margin")
end)

-- 14. Modular Managers (modal_manager & hold_handler) Unit Tests
run_test("test_modular_managers", function()
    local mm = require("modal_manager")
    local hh = require("hold_handler")

    -- Modal manager API checks
    assert_true(mm ~= nil, "modal_manager required")
    mm.init(2)
    assert_eq(mm.isOpen(), false, "modal_manager initialized closed")
    assert_eq(mm.getActive(), nil, "modal_manager getActive is nil")
    assert_eq(mm.ui.detailPlayer, 2, "modal_manager default detail player set")

    mm.open("tools")
    assert_eq(mm.isOpen(), true, "modal_manager isOpen true when open")
    assert_eq(mm.getActive(), "tools", "modal_manager active modal is tools")

    mm.close()
    assert_eq(mm.isOpen(), false, "modal_manager close resets open state")
    assert_eq(mm.getActive(), nil, "modal_manager active is nil after close")

    -- Hold handler API checks
    assert_true(hh ~= nil, "hold_handler required")
    hh.reset()
    assert_eq(hh.holdState.active, false, "hold_handler reset active state")
    assert_eq(hh.wasTapSuppressed(), false, "hold_handler wasTapSuppressed false initially")

    hh.holdState.hasTicked = true
    assert_eq(hh.wasTapSuppressed(), true, "hold_handler wasTapSuppressed true after tick")
    assert_eq(hh.wasTapSuppressed(), false, "hold_handler wasTapSuppressed resets after check")
end)

-- ---------------------------------------------------------------------------
-- Summary Output
-- ---------------------------------------------------------------------------
print("\n" .. string.rep("=", 60))
print(string.format("SPELL COUNTER TEST RESULTS: %d Passed, %d Failed (Total: %d)", passCount, failCount, testCount))
print(string.rep("=", 60))

if failCount > 0 then
    os.exit(1)
else
    os.exit(0)
end
