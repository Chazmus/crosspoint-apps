-- ============================================================================
-- CrossPoint Chess - Main Application Coordinator
-- Modes: Play vs Computer (Built-in Pure-Lua AI) & Lichess Daily Puzzles
-- ============================================================================

local menuView   = require("views.menu")
local setupView  = require("views.setup")
local gameView   = require("views.game")
local puzzleView = require("views.puzzle")
local sleepView  = require("views.sleep")

-- View Modes
local VIEW_MENU   = 1
local VIEW_SETUP  = 2
local VIEW_GAME   = 3
local VIEW_PUZZLE = 4

local currentView = VIEW_MENU

-- Touch tracking for gesture detection (left-edge swipe)
local touchStartX = -1
local touchStartY = -1

-- Setup screen temporary choices
local setupColor = "w"
local setupDifficulty = 2

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function toggleSleep()
    local current = crosspoint.getSleepApp()
    if current == "chess" then
        crosspoint.clearSleepApp()
    else
        crosspoint.setSleepApp("chess")
    end
    crosspoint.requestUpdate()
end

--------------------------------------------------------------------------------
-- Lifecycle Callbacks
--------------------------------------------------------------------------------
function onEnter()
    gameView.checkSaved()
    puzzleView.loadPuzzle()
    crosspoint.requestUpdate()
end

function onExit()
    gameView.saveState()
end

-- Hardware Back Button and Left-Edge Swipe dispatch
function onBack()
    if currentView == VIEW_GAME or currentView == VIEW_SETUP or currentView == VIEW_PUZZLE then
        gameView.saveState()
        currentView = VIEW_MENU
        gameView.selectedSq = -1
        gameView.legalDests = {}
        puzzleView.selectedSq = -1
        puzzleView.legalDests = {}
        puzzleView.hintSq = -1
        crosspoint.requestUpdate()
        return true  -- Consumed by app: stay in app, return to menu
    end
    -- On Main Menu: return false to allow CrossPoint OS to exit to launcher
    return false
end

function onInput(button, isDown)
    if isDown and button == input.BTN_CONFIRM then
        if currentView == VIEW_PUZZLE then
            puzzleView.reset()
        end
    end
end

function onUpdate(dt)
    if currentView == VIEW_GAME then
        gameView.onUpdate(dt)
    end
end

--------------------------------------------------------------------------------
-- Touch Handling
--------------------------------------------------------------------------------
function onTouchDown(x, y)
    touchStartX = x
    touchStartY = y
end

function onTouchUp(x, y)
    -- Left-edge back swipe gesture detection (drag right from left margin)
    if touchStartX >= 0 and touchStartX <= 60 and (x - touchStartX) >= 60 and math.abs(y - touchStartY) < 120 then
        touchStartX = -1
        touchStartY = -1
        if currentView ~= VIEW_MENU then
            onBack()
            return
        end
    end
    touchStartX = -1
    touchStartY = -1
end

function onTouch(x, y)
    if currentView == VIEW_MENU then
        local action = menuView.onTouch(x, y, gameView.hasSavedGame)
        if action == "resume_game" then
            if gameView.loadSaved() then
                currentView = VIEW_GAME
                crosspoint.requestUpdate()
            end
        elseif action == "new_game" then
            currentView = VIEW_SETUP
            setupColor = "w"
            setupDifficulty = 2
            crosspoint.requestUpdate()
        elseif action == "daily_puzzle" then
            currentView = VIEW_PUZZLE
            crosspoint.requestUpdate()
        elseif action == "toggle_sleep" then
            toggleSleep()
        end
        return
    end

    if currentView == VIEW_SETUP then
        local action = setupView.onTouch(x, y)
        if action == "back" then
            currentView = VIEW_MENU
            crosspoint.requestUpdate()
        elseif action == "color_w" then
            setupColor = "w"
            crosspoint.requestUpdate()
        elseif action == "color_b" then
            setupColor = "b"
            crosspoint.requestUpdate()
        elseif action == "diff_1" then
            setupDifficulty = 1
            crosspoint.requestUpdate()
        elseif action == "diff_2" then
            setupDifficulty = 2
            crosspoint.requestUpdate()
        elseif action == "diff_3" then
            setupDifficulty = 3
            crosspoint.requestUpdate()
        elseif action == "start_game" then
            gameView.startNew(setupColor, setupDifficulty)
            currentView = VIEW_GAME
            crosspoint.requestUpdate()
        end
        return
    end

    if currentView == VIEW_GAME then
        local action = gameView.onTouch(x, y)
        if action == "new_game" then
            currentView = VIEW_SETUP
            crosspoint.requestUpdate()
        elseif action == "menu" then
            onBack()
        end
        return
    end

    if currentView == VIEW_PUZZLE then
        local action = puzzleView.onTouch(x, y)
        if action == "menu" then
            onBack()
        end
        return
    end
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------
function onDraw()
    gfx.clearScreen(1)
    if currentView == VIEW_MENU then
        local isSleep = (crosspoint.getSleepApp() == "chess")
        menuView.draw(gameView.hasSavedGame, puzzleView.rating, puzzleView.themes, isSleep)
    elseif currentView == VIEW_SETUP then
        setupView.draw(setupColor, setupDifficulty)
    elseif currentView == VIEW_GAME then
        gameView.draw()
    elseif currentView == VIEW_PUZZLE then
        puzzleView.draw()
    end
end

function onSleepDraw()
    sleepView.draw(currentView, gameView, puzzleView)
end
