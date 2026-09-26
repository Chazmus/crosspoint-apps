-- ============================================================================
-- Automated Unit Test Suite for InkWire App
-- Tests JSON parsing, edition loading, section switching, pagination,
-- article reader navigation, text wrapping, QR code binding, and Wi-Fi sync.
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
local qrDrawCalls = {}

local function setupMocks()
    storageFiles = {}
    qrDrawCalls = {}

    -- Pre-load sample edition from disk into mock storage
    local f = io.open("apps/inkwire/sample_edition.json", "r")
    if f then
        storageFiles["sample_edition.json"] = f:read("*a")
        f:close()
    end

    _G.storage = {
        readFile = function(path)
            return storageFiles[path]
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
        end
    }

    _G.gfx = {
        FONT_UI_10 = 1,
        FONT_UI_12 = 2,
        FONT_SMALL = 3,
        FONT_NOTOSANS_12 = 4,
        FONT_NOTOSANS_14 = 5,
        FONT_NOTOSANS_16 = 6,
        FONT_NOTOSERIF_12 = 7,
        FONT_NOTOSERIF_14 = 8,
        COLOR_BLACK = 0,
        COLOR_DARK_GRAY = 1,
        COLOR_LIGHT_GRAY = 2,
        COLOR_WHITE = 3,
        getWidth = function() return 480 end,
        getHeight = function() return 800 end,
        setOrientation = function(o) end,
        clearScreen = function(c) end,
        drawLine = function(x1, y1, x2, y2, c) end,
        drawRect = function(x, y, w, h, c) end,
        fillRect = function(x, y, w, h, c) end,
        fillRectDither = function(x, y, w, h, lvl) end,
        drawRoundedRect = function(x, y, w, h, r, lw, c) end,
        fillRoundedRect = function(x, y, w, h, r, c) end,
        drawText = function(font, x, y, text, c) end,
        drawCenteredText = function(font, y, text, c) end,
        getTextWidth = function(font, text) return #tostring(text or "") * 8 end,
        getLineHeight = function(font) return 18 end,
        drawQrCode = function(x, y, w, h, text)
            table.insert(qrDrawCalls, { x = x, y = y, w = w, h = h, text = text })
        end
    }

    _G.input = {
        BTN_BACK = 0,
        BTN_CONFIRM = 1,
        BTN_LEFT = 2,
        BTN_RIGHT = 3,
        BTN_UP = 4,
        BTN_DOWN = 5,
        BTN_PAGE_BACK = 7,
        BTN_PAGE_FORWARD = 8
    }

    _G.crosspoint = {
        millis = function() return 1000 end,
        requestUpdate = function() end,
        getBattery = function() return { percentage = 92, isCharging = false } end,
        getTime = function() return { year = 2026, month = 9, day = 26, hour = 15, min = 0, sec = 0 } end,
        withWifi = function(cb) cb(true) end,
        httpGet = function(url) return nil end
    }
end

-- Adjust package path for modules
package.path = "apps/inkwire/?.lua;apps/inkwire/?/init.lua;" .. package.path

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

run_test("JSON Encoding & Decoding", function()
    setupMocks()
    local json = require("json")
    local obj = { title = "InkWire Test", count = 42, active = true, items = { "a", "b" } }
    local encoded = json.encode(obj)
    assert_true(encoded ~= nil and #encoded > 0, "json.encode returns valid string")
    local decoded = json.decode(encoded)
    assert_eq(decoded.title, "InkWire Test", "JSON title match")
    assert_eq(decoded.count, 42, "JSON number match")
    assert_eq(decoded.active, true, "JSON boolean match")
    assert_eq(#decoded.items, 2, "JSON array match")
end)

run_test("State Loading Sample Edition", function()
    setupMocks()
    package.loaded["state"] = nil
    local state = require("state")
    local ok = state.loadEdition()
    assert_true(ok, "loadEdition returns true with sample_edition.json")
    assert_true(state.edition ~= nil, "state.edition is populated")
    assert_eq(#state.edition.sections, 4, "4 sections loaded")
    assert_eq(state.edition.sections[1].title, "Tech & AI", "Section 1 title match")
    assert_eq(state.edition.sections[2].title, "Chess", "Section 2 title match")
    assert_eq(state.edition.sections[3].title, "Handhelds", "Section 3 title match")
    assert_eq(state.edition.sections[4].title, "Local & Family", "Section 4 title match")
end)

run_test("Section Filtering & Active Stories", function()
    setupMocks()
    package.loaded["state"] = nil
    local state = require("state")
    state.loadEdition()

    -- Section 0 = All
    state.selectSection(0)
    local allStories = state.getActiveStories()
    assert_eq(#allStories, 12, "All section contains all 12 stories across 4 categories")

    -- Section 1 = Tech & AI (3 stories)
    state.selectSection(1)
    local techStories = state.getActiveStories()
    assert_eq(#techStories, 3, "Tech section contains 3 stories")
    assert_eq(techStories[1].source, "Ars Technica", "First tech story source")

    -- Section 2 = Chess (3 stories)
    state.selectSection(2)
    local chessStories = state.getActiveStories()
    assert_eq(#chessStories, 3, "Chess section contains 3 stories")
    assert_eq(chessStories[1].source, "Chess.com", "First chess story source")
end)

run_test("Pagination Logic", function()
    setupMocks()
    package.loaded["state"] = nil
    local state = require("state")
    state.loadEdition()
    state.selectSection(0) -- 12 stories, 3 items per page -> 4 pages
    assert_eq(state.getTotalPages(), 4, "12 stories at 3 per page = 4 pages")

    state.currentPage = 1
    local p1 = state.getPageStories()
    assert_eq(#p1, 3, "Page 1 has 3 stories")
    assert_eq(p1[1].title, state.edition.sections[1].articles[1].title, "First story on page 1")

    state.currentPage = 4
    local p4 = state.getPageStories()
    assert_eq(#p4, 3, "Page 4 has 3 stories")

    -- Clamping
    state.currentPage = 10
    local clamped = state.getPageStories()
    assert_eq(state.currentPage, 4, "Current page clamped to totalPages")
end)

run_test("Article Reading & Prev/Next Story Navigation", function()
    setupMocks()
    package.loaded["state"] = nil
    local state = require("state")
    state.loadEdition()
    state.selectSection(1) -- Tech & AI (3 stories)

    local stories = state.getActiveStories()
    state.selectArticle(stories[1])
    assert_eq(state.currentView, "article", "currentView is 'article'")
    assert_eq(state.currentArticle.title, stories[1].title, "Selected article 1")

    -- Next article
    state.nextArticle()
    assert_eq(state.currentArticle.title, stories[2].title, "Advanced to article 2")

    state.nextArticle()
    assert_eq(state.currentArticle.title, stories[3].title, "Advanced to article 3")

    -- Clamping at end
    state.nextArticle()
    assert_eq(state.currentArticle.title, stories[3].title, "Clamped at last article")

    -- Prev article
    state.prevArticle()
    assert_eq(state.currentArticle.title, stories[2].title, "Moved back to article 2")
end)

run_test("Back Button Workflow", function()
    setupMocks()
    package.loaded["state"] = nil
    package.loaded["main"] = nil
    local state = require("state")
    require("main")
    onEnter()

    -- 1. In article view -> onBack returns true and switches to frontpage
    state.selectArticle(state.getActiveStories()[1])
    assert_eq(state.currentView, "article", "In article view")
    local handled = onBack()
    assert_true(handled, "onBack consumed back event")
    assert_eq(state.currentView, "frontpage", "Returned to frontpage")

    -- 2. On frontpage in sub-section -> onBack returns to All section (index 0)
    state.selectSection(2)
    assert_eq(state.currentSectionIndex, 2, "In Chess section")
    handled = onBack()
    assert_true(handled, "onBack consumed back event")
    assert_eq(state.currentSectionIndex, 0, "Returned to All section")

    -- 3. On frontpage at All section -> onBack returns false (exit to launcher)
    handled = onBack()
    assert_eq(handled, false, "onBack returns false at root, allowing launcher exit")
end)

run_test("UI Text Wrapping & Truncation", function()
    setupMocks()
    local ui = require("ui")
    local text = "This is a long sentence that should be wrapped across multiple lines on e-ink."
    local lines = ui.wrapText(gfx.FONT_NOTOSANS_12, text, 120)
    assert_true(#lines > 1, "Text wrapped into multiple lines")

    local truncated = ui.truncateText(gfx.FONT_NOTOSANS_12, text, 80)
    assert_true(#truncated < #text, "Text was truncated")
    assert_true(truncated:sub(-3) == "...", "Truncation ends with ellipsis")
end)

run_test("Native QR Code Binding", function()
    setupMocks()
    local qr = require("qr")
    qr.draw(10, 20, 100, 100, "https://example.com/story")
    assert_eq(#qrDrawCalls, 1, "Native gfx.drawQrCode was called")
    assert_eq(qrDrawCalls[1].text, "https://example.com/story", "QR payload matched")
    assert_eq(qrDrawCalls[1].w, 100, "QR width matched")
end)

run_test("Wi-Fi Sync Success Flow", function()
    setupMocks()
    package.loaded["state"] = nil
    local state = require("state")
    state.loadEdition()

    local mockPayload = [[
    {
      "edition": "Updated Edition",
      "syncedAt": "09:00",
      "weather": "Sunny 22°C",
      "sections": [
        {
          "id": "breaking",
          "title": "Breaking News",
          "articles": [
            {
              "title": "Synced Online Article",
              "source": "Live Wire",
              "time": "Just now",
              "bullets": ["Bullet 1", "Bullet 2"],
              "body": "Body content here",
              "url": "https://example.com/breaking"
            }
          ]
        }
      ]
    }
    ]]

    _G.crosspoint.httpGet = function(url)
        return mockPayload
    end

    local syncDone = false
    local syncSuccess = false
    state.syncEdition(function(ok)
        syncDone = true
        syncSuccess = ok
    end)

    assert_true(syncDone, "Sync callback executed")
    assert_true(syncSuccess, "Sync reported success")
    assert_eq(state.edition.edition, "Updated Edition", "Edition was updated")
    assert_eq(state.edition.sections[1].title, "Breaking News", "New section present")
    assert_true(storage.exists("edition.json"), "edition.json persisted to storage")
end)

run_test("Wi-Fi Sync HTTP Failure Flow", function()
    setupMocks()
    package.loaded["state"] = nil
    local state = require("state")
    state.loadEdition()

    _G.crosspoint.httpGet = function(url)
        return nil -- Simulate network failure / 404
    end

    local syncDone = false
    local syncSuccess = true
    state.syncEdition(function(ok)
        syncDone = true
        syncSuccess = ok
    end)

    assert_true(syncDone, "Sync callback executed")
    assert_eq(syncSuccess, false, "Sync reported failure")
    assert_eq(state.syncSuccess, false, "state.syncSuccess is false")
    assert_true(state.syncError ~= nil, "state.syncError is set")
end)

-- ---------------------------------------------------------------------------
-- Report Results
-- ---------------------------------------------------------------------------
print(string.rep("-", 60))
print(string.format("Test Results: %d Passed, %d Failed, %d Total", passCount, failCount, testCount))
print(string.rep("-", 60))

if failCount > 0 then
    os.exit(1)
end
