-- Front Page View for InkWire (Masthead, Section Tabs, Story Cards, Pagination)
local ui = require("ui")
local state = require("state")

local frontpage = {
    tabHits = {},
    cardHits = {},
    btnPrevHit = nil,
    btnNextHit = nil,
    btnSyncHit = nil,
    btnSettingsHit = nil
}

function frontpage.draw()
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    -- 1. Masthead
    local batteryPct = nil
    if crosspoint and crosspoint.getBattery then
        local b = crosspoint.getBattery()
        if b and b.percentage then batteryPct = b.percentage end
    end
    local headerArea = ui.drawMasthead(state.edition and state.edition.edition, state.edition and state.edition.weather, batteryPct)

    -- 2. Section Navigation Tabs
    frontpage.tabHits = {}
    local tabY = (headerArea and headerArea.y or 44) + 6
    local tabH = 34
    local totalW = w - 32
    
    local function formatTabLabel(title)
        if not title or title == "All" then return "All" end
        if title == "Tech & AI" or title == "Technology & AI" then return "Tech" end
        if title == "Handheld Gaming & Emulation" or title == "Handhelds" then return "Gaming" end
        if title == "Family & Community" or title == "Local & Family" then return "Local" end
        return title
    end

    local tabLabels = { "All" }
    local tabIndices = { 0 }
    if state.edition and state.edition.sections then
        for i, sec in ipairs(state.edition.sections) do
            table.insert(tabLabels, formatTabLabel(sec.title))
            table.insert(tabIndices, i)
        end
    end

    local selectedTabSlot = 1
    for slot, sIdx in ipairs(tabIndices) do
        if state.currentSectionIndex == sIdx then
            selectedTabSlot = slot
            break
        end
    end

    if _G.ui and _G.ui.drawTabBar then
        _G.ui.drawTabBar({
            x = 16,
            y = tabY,
            w = totalW,
            h = tabH,
            selectedIndex = selectedTabSlot,
            tabs = tabLabels,
            onSelect = function(slot)
                if tabIndices[slot] ~= nil then
                    state.selectSection(tabIndices[slot])
                end
            end
        })
    end

    local numTabs = #tabLabels
    local tabGap = 6
    local tabW = math.floor((totalW - (numTabs - 1) * tabGap) / numTabs)

    for slot, label in ipairs(tabLabels) do
        local tx = 16 + (slot - 1) * (tabW + tabGap)
        local isSelected = (selectedTabSlot == slot)
        if not (_G.ui and _G.ui.drawTabBar) then
            local tabFont = gfx.FONT_NOTOSANS_12
            if isSelected then
                gfx.fillRoundedRect(tx, tabY, tabW, tabH, 5, gfx.COLOR_BLACK)
                local lw = ui.getTextWidth(tabFont, label)
                local lh = ui.getLineHeight(tabFont)
                gfx.drawText(tabFont, tx + math.floor((tabW - lw) / 2), tabY + math.floor((tabH - lh) / 2), label, false)
            else
                gfx.drawRoundedRect(tx, tabY, tabW, tabH, 5, 1, gfx.COLOR_BLACK)
                local lw = ui.getTextWidth(tabFont, label)
                local lh = ui.getLineHeight(tabFont)
                gfx.drawText(tabFont, tx + math.floor((tabW - lw) / 2), tabY + math.floor((tabH - lh) / 2), label, true)
            end
        end

        table.insert(frontpage.tabHits, {
            x = tx, y = tabY, w = tabW, h = tabH, idx = tabIndices[slot]
        })
    end

    -- 3. Story Cards List
    frontpage.cardHits = {}
    local stories = state.getPageStories()
    local cardStartY = tabY + tabH + 8
    local cardH = 186
    local cardGap = 10
    local cardW = w - 32
    local cardX = 16

    if #stories == 0 then
        -- Empty state
        local emptyMsg = "No articles available in this section."
        local ew = ui.getTextWidth(gfx.FONT_NOTOSERIF_12, emptyMsg)
        gfx.drawText(gfx.FONT_NOTOSERIF_12, math.floor((w - ew) / 2), 300, emptyMsg, true)
    else
        for i, story in ipairs(stories) do
            local cy = cardStartY + (i - 1) * (cardH + cardGap)
            local isHero = (state.currentSectionIndex == 0 and state.currentPage == 1 and i == 1)
            ui.drawStoryCard(cardX, cy, cardW, cardH, story, isHero, function()
                state.selectArticle(story)
            end)
            table.insert(frontpage.cardHits, {
                x = cardX, y = cy, w = cardW, h = cardH, story = story
            })
        end
    end

    -- 4. Bottom Action Bar (Y: 732 to 776)
    local bottomY = 732
    local btnH = 44
    frontpage.btnPrevHit = nil
    frontpage.btnNextHit = nil
    frontpage.btnSyncHit = nil
    frontpage.btnSettingsHit = nil

    local totalPages = state.getTotalPages()

    -- Pagination controls (Left side)
    if totalPages > 1 then
        local pBtnW = 72
        if state.currentPage > 1 then
            ui.drawButton(16, bottomY, pBtnW, btnH, "< Prev", false, gfx.FONT_NOTOSANS_12, function()
                state.currentPage = state.currentPage - 1
                crosspoint.requestUpdate()
            end)
            frontpage.btnPrevHit = { x = 16, y = bottomY, w = pBtnW, h = btnH }
        end

        local pageStr = string.format("%d / %d", state.currentPage, totalPages)
        local pw = ui.getTextWidth(gfx.FONT_NOTOSANS_12, pageStr)
        local pageStrX = 16 + pBtnW + 8
        gfx.drawText(gfx.FONT_NOTOSANS_12, pageStrX, bottomY + 13, pageStr, true)

        if state.currentPage < totalPages then
            local nextX = pageStrX + pw + 8
            ui.drawButton(nextX, bottomY, pBtnW, btnH, "Next >", false, gfx.FONT_NOTOSANS_12, function()
                state.currentPage = state.currentPage + 1
                crosspoint.requestUpdate()
            end)
            frontpage.btnNextHit = { x = nextX, y = bottomY, w = pBtnW, h = btnH }
        end
    else
        -- Single page count
        local storyCountStr = string.format("%d stories", #state.getActiveStories())
        gfx.drawText(gfx.FONT_UI_10, 20, bottomY + 15, storyCountStr, true)
    end

    -- Right Action Buttons: [Sync] and [Settings]
    local cfgW = 84
    local cfgX = w - 16 - cfgW
    ui.drawButton(cfgX, bottomY, cfgW, btnH, "Settings", false, gfx.FONT_NOTOSANS_12, function()
        state.currentView = "settings_modal"
        crosspoint.requestUpdate()
    end)
    frontpage.btnSettingsHit = { x = cfgX, y = bottomY, w = cfgW, h = btnH }

    local syncW = 84
    local syncX = cfgX - 8 - syncW
    ui.drawButton(syncX, bottomY, syncW, btnH, "Sync", false, gfx.FONT_NOTOSANS_12, function()
        state.syncEdition()
    end)
    frontpage.btnSyncHit = { x = syncX, y = bottomY, w = syncW, h = btnH }
end

local function hitTest(box, x, y)
    return box and x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h
end

function frontpage.onTouch(x, y)
    -- 1. Check Section Tabs
    for _, tab in ipairs(frontpage.tabHits) do
        if hitTest(tab, x, y) then
            state.selectSection(tab.idx)
            return true
        end
    end

    -- 2. Check Settings Gear Button
    if hitTest(frontpage.btnSettingsHit, x, y) then
        state.currentView = "settings_modal"
        if crosspoint then crosspoint.requestUpdate() end
        return true
    end

    -- 3. Check Story Cards
    for _, card in ipairs(frontpage.cardHits) do
        if hitTest(card, x, y) then
            state.selectArticle(card.story)
            return true
        end
    end

    -- 4. Check Pagination Prev / Next
    if hitTest(frontpage.btnPrevHit, x, y) then
        if state.currentPage > 1 then
            state.currentPage = state.currentPage - 1
            if crosspoint then crosspoint.requestUpdate() end
        end
        return true
    end

    if hitTest(frontpage.btnNextHit, x, y) then
        if state.currentPage < state.getTotalPages() then
            state.currentPage = state.currentPage + 1
            if crosspoint then crosspoint.requestUpdate() end
        end
        return true
    end

    -- 5. Check Sync Button
    if hitTest(frontpage.btnSyncHit, x, y) then
        state.syncEdition()
        return true
    end

    return false
end

function frontpage.onInput(btn, action)
    if action ~= "press" then return false end

    if btn == input.BTN_PAGE_BACK or btn == input.BTN_LEFT then
        if state.currentPage > 1 then
            state.currentPage = state.currentPage - 1
            if crosspoint then crosspoint.requestUpdate() end
            return true
        end
    elseif btn == input.BTN_PAGE_FORWARD or btn == input.BTN_RIGHT then
        if state.currentPage < state.getTotalPages() then
            state.currentPage = state.currentPage + 1
            if crosspoint then crosspoint.requestUpdate() end
            return true
        end
    elseif btn == input.BTN_CONFIRM then
        -- Open first article on current page
        local stories = state.getPageStories()
        if stories and #stories > 0 then
            state.selectArticle(stories[1])
            return true
        end
    end

    return false
end

return frontpage
