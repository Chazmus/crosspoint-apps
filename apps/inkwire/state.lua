-- State management for InkWire
local json = require("json")

local state = {
    edition = nil,
    config = {
        feedUrl = "https://raw.githubusercontent.com/chazmus/crosspoint-apps/main/apps/inkwire/sample_edition.json"
    },
    currentSectionIndex = 0, -- 0 = "All", 1..N = specific section
    currentPage = 1,
    itemsPerPage = 3,
    currentArticle = nil,
    currentView = "frontpage", -- "frontpage", "article", "sync_modal", "settings_modal"
    
    -- Sync state
    isSyncing = false,
    syncStatus = "Idle",
    syncSuccess = false,
    syncError = nil,
    syncStartTime = 0
}

function state.loadConfig()
    if not storage then return end
    local data = storage.readFile("config.json")
    if data then
        local cfg = json.decode(data)
        if cfg and type(cfg) == "table" then
            if cfg.feedUrl and cfg.feedUrl ~= "" then
                state.config.feedUrl = cfg.feedUrl
            end
        end
    end
end

function state.saveConfig()
    if not storage then return end
    local str = json.encode(state.config)
    if str then
        storage.writeFile("config.json", str)
    end
end

function state.loadEdition()
    local data = nil
    if storage then
        data = storage.readFile("edition.json")
        if not data then
            data = storage.readFile("sample_edition.json")
        end
    end

    if data then
        local parsed = json.decode(data)
        if parsed and parsed.sections and #parsed.sections > 0 then
            state.edition = parsed
            return true
        end
    end

    -- Fallback empty edition structure
    state.edition = {
        edition = "InkWire Edition",
        syncedAt = "--:--",
        weather = "No weather data",
        sections = {}
    }
    return false
end

function state.saveEdition(rawJson)
    if not rawJson or rawJson == "" then return false end
    local parsed = json.decode(rawJson)
    if not parsed or not parsed.sections or #parsed.sections == 0 then
        return false
    end
    state.edition = parsed
    if storage then
        storage.writeFile("edition.json", rawJson)
    end
    return true
end

function state.getActiveStories()
    if not state.edition or not state.edition.sections then return {} end
    
    if state.currentSectionIndex == 0 then
        -- "All" tab: Aggregate the top stories across all sections
        local allStories = {}
        for _, sec in ipairs(state.edition.sections) do
            if sec.articles then
                for _, art in ipairs(sec.articles) do
                    -- Attach section title for context in "All" view
                    art.sectionTitle = sec.title
                    table.insert(allStories, art)
                end
            end
        end
        return allStories
    else
        local sec = state.edition.sections[state.currentSectionIndex]
        if sec and sec.articles then
            for _, art in ipairs(sec.articles) do
                art.sectionTitle = sec.title
            end
            return sec.articles
        end
    end
    return {}
end

function state.getTotalPages()
    local stories = state.getActiveStories()
    if #stories == 0 then return 1 end
    return math.ceil(#stories / state.itemsPerPage)
end

function state.getPageStories()
    local stories = state.getActiveStories()
    local totalPages = state.getTotalPages()
    if state.currentPage > totalPages then state.currentPage = totalPages end
    if state.currentPage < 1 then state.currentPage = 1 end

    local pageStories = {}
    local startIdx = (state.currentPage - 1) * state.itemsPerPage + 1
    local endIdx = math.min(startIdx + state.itemsPerPage - 1, #stories)
    for i = startIdx, endIdx do
        table.insert(pageStories, stories[i])
    end
    return pageStories
end

function state.selectSection(idx)
    state.currentSectionIndex = idx
    state.currentPage = 1
    state.currentView = "frontpage"
    state.currentArticle = nil
    if crosspoint then crosspoint.requestUpdate() end
end

function state.selectArticle(article)
    state.currentArticle = article
    state.currentView = "article"
    if crosspoint then crosspoint.requestUpdate() end
end

function state.findArticleIndex(article)
    local stories = state.getActiveStories()
    for i, a in ipairs(stories) do
        if a == article or (a.title == article.title and a.source == article.source) then
            return i
        end
    end
    return 1
end

function state.prevArticle()
    if not state.currentArticle then return end
    local stories = state.getActiveStories()
    local idx = state.findArticleIndex(state.currentArticle)
    if idx > 1 then
        state.selectArticle(stories[idx - 1])
    end
end

function state.nextArticle()
    if not state.currentArticle then return end
    local stories = state.getActiveStories()
    local idx = state.findArticleIndex(state.currentArticle)
    if idx < #stories then
        state.selectArticle(stories[idx + 1])
    end
end

function state.syncEdition(onComplete)
    state.isSyncing = true
    state.syncStatus = "Connecting to Wi-Fi..."
    state.syncSuccess = false
    state.syncError = nil
    state.currentView = "sync_modal"
    if crosspoint then crosspoint.requestUpdate() end

    if not crosspoint or not crosspoint.withWifi then
        state.isSyncing = false
        state.syncStatus = "Wi-Fi API not available"
        state.syncError = "No networking support in this environment"
        if onComplete then onComplete(false) end
        if crosspoint then crosspoint.requestUpdate() end
        return
    end

    crosspoint.withWifi(function(connected)
        if not connected then
            state.isSyncing = false
            state.syncStatus = "Wi-Fi Connection Failed"
            state.syncError = "Could not connect to configured Wi-Fi network"
            if onComplete then onComplete(false) end
            crosspoint.requestUpdate()
            return
        end

        state.syncStatus = "Downloading edition..."
        crosspoint.requestUpdate()

        local url = state.config.feedUrl
        local rawData = crosspoint.httpGet(url)
        if not rawData or rawData == "" then
            state.isSyncing = false
            state.syncStatus = "Download Failed"
            state.syncError = "Server returned empty response or HTTP error"
            if onComplete then onComplete(false) end
            crosspoint.requestUpdate()
            return
        end

        local ok = state.saveEdition(rawData)
        state.isSyncing = false
        if ok then
            state.syncSuccess = true
            state.syncStatus = "Edition Updated Successfully!"
            state.syncError = nil
            state.currentPage = 1
        else
            state.syncSuccess = false
            state.syncStatus = "Invalid Edition Data"
            state.syncError = "Could not parse JSON payload from feed server"
        end

        if onComplete then onComplete(ok) end
        crosspoint.requestUpdate()
    end)
end

return state
