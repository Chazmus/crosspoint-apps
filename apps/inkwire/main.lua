-- Main application coordinator for InkWire
-- CrossPoint E-Ink Personal Feed & Curated Daily Briefing

local state = require("state")
local frontpage = require("views.frontpage")
local articleView = require("views.article")
local modals = require("views.modals")

function onEnter()
    if gfx and gfx.setOrientation then
        gfx.setOrientation("portrait")
    end

    state.loadConfig()
    state.loadEdition()
    state.currentView = "frontpage"
    state.currentPage = 1
    state.currentSectionIndex = 0

    if crosspoint then
        crosspoint.requestUpdate()
    end
end

function onTouch(x, y)
    if state.currentView == "sync_modal" or state.currentView == "settings_modal" then
        return modals.onTouch(x, y)
    elseif state.currentView == "article" then
        return articleView.onTouch(x, y)
    else
        return frontpage.onTouch(x, y)
    end
end

function onTouchDown(x, y)
    -- Reserved for gesture / drag tracking if needed
end

function onTouchUp(x, y)
    -- Reserved for touch release tracking
end

function onInput(buttonId, action)
    if state.currentView == "sync_modal" or state.currentView == "settings_modal" then
        return modals.onInput(buttonId, action)
    elseif state.currentView == "article" then
        return articleView.onInput(buttonId, action)
    else
        return frontpage.onInput(buttonId, action)
    end
end

function onBack()
    if state.currentView == "sync_modal" or state.currentView == "settings_modal" then
        state.currentView = "frontpage"
        if crosspoint then crosspoint.requestUpdate() end
        return true
    elseif state.currentView == "article" then
        state.currentView = "frontpage"
        state.currentArticle = nil
        if crosspoint then crosspoint.requestUpdate() end
        return true
    elseif state.currentView == "frontpage" then
        if state.currentSectionIndex ~= 0 then
            state.selectSection(0)
            return true
        end
        -- Exit to CrossPoint launcher
        return false
    end
    return false
end

function onUpdate(dt)
    -- Periodic non-drawing updates
end

function onDraw()
    gfx.clearScreen(gfx.COLOR_WHITE)

    if state.currentView == "article" then
        articleView.draw()
    else
        frontpage.draw()
    end

    -- Draw modals on top if active
    if state.currentView == "sync_modal" then
        modals.drawSyncModal()
    elseif state.currentView == "settings_modal" then
        modals.drawSettingsModal()
    end
end

function onExit()
    state.saveConfig()
end
