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
    ui.drawMasthead(state.edition and state.edition.edition, state.edition and state.edition.weather, batteryPct)

    -- 2. Section Navigation Tabs
    frontpage.tabHits = {}
    local tabY = 70
    local tabH = 34
    local curX = 16

    -- Build list of tab labels: 0="All", then section titles
    local tabs = { { idx = 0, label = "All" } }
    if state.edition and state.edition.sections then
        for i, sec in ipairs(state.edition.sections) do
            table.insert(tabs, { idx = i, label = sec.title })
        end
    end

    local tabFont = gfx.FONT_NOTOSANS_12
    for _, tab in ipairs(tabs) do
        local tw = ui.getTextWidth(tabFont, tab.label)
        local btnW = math.max(54, tw + 18)
        
        -- Check if tab fits on screen width, if not wrap to next row if needed or clip
        if curX + btnW > w - 50 then
            -- Fallback compact sizing if many sections
            btnW = tw + 12
        end

        local isSelected = (state.currentSectionIndex == tab.idx)
        if isSelected then
            gfx.fillRoundedRect(curX, tabY, btnW, tabH, 6, gfx.COLOR_BLACK)
            local lw = ui.getTextWidth(tabFont, tab.label)
            local lh = ui.getLineHeight(tabFont)
            gfx.drawText(tabFont, curX + math.floor((btnW - lw) / 2), tabY + math.floor((tabH - lh) / 2), tab.label, false)
        else
            gfx.drawRoundedRect(curX, tabY, btnW, tabH, 6, 1, gfx.COLOR_BLACK)
            local lw = ui.getTextWidth(tabFont, tab.label)
            local lh = ui.getLineHeight(tabFont)
            gfx.drawText(tabFont, curX + math.floor((btnW - lw) / 2), tabY + math.floor((tabH - lh) / 2), tab.label, true)
        end

        table.insert(frontpage.tabHits, {
            x = curX, y = tabY, w = btnW, h = tabH, idx = tab.idx
        })
        curX = curX + btnW + 6
    end

    -- Settings gear tab at far right
    local gearW = 42
    local gearX = w - 16 - gearW
    gfx.drawRoundedRect(gearX, tabY, gearW, tabH, 6, 1, gfx.COLOR_BLACK)
    local gearLabel = "Cfg"
    local gw = ui.getTextWidth(tabFont, gearLabel)
    local gh = ui.getLineHeight(tabFont)
    gfx.drawText(tabFont, gearX + math.floor((gearW - gw) / 2), tabY + math.floor((tabH - gh) / 2), gearLabel, true)
    frontpage.btnSettingsHit = { x = gearX, y = tabY, w = gearW, h = tabH }

    -- 3. Story Cards List
    frontpage.cardHits = {}
    local stories = state.getPageStories()
    local cardStartY = 114
    local cardH = 192
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
            ui.drawStoryCard(cardX, cy, cardW, cardH, story, isHero)
            table.insert(frontpage.cardHits, {
                x = cardX, y = cy, w = cardW, h = cardH, story = story
            })
        end
    end

    -- 4. Bottom Action Bar (Y: 730 to 790)
    local bottomY = h - 62
    local btnH = 48
    frontpage.btnPrevHit = nil
    frontpage.btnNextHit = nil
    frontpage.btnSyncHit = nil

    local totalPages = state.getTotalPages()

    -- Pagination controls (Left side)
    if totalPages > 1 then
        local pBtnW = 68
        if state.currentPage > 1 then
            ui.drawButton(16, bottomY, pBtnW, btnH, "< Prev", false, gfx.FONT_NOTOSANS_12)
            frontpage.btnPrevHit = { x = 16, y = bottomY, w = pBtnW, h = btnH }
        end

        local pageStr = string.format("%d / %d", state.currentPage, totalPages)
        local pw = ui.getTextWidth(gfx.FONT_NOTOSANS_12, pageStr)
        local pageStrX = 16 + pBtnW + 8
        gfx.drawText(gfx.FONT_NOTOSANS_12, pageStrX, bottomY + 16, pageStr, true)

        if state.currentPage < totalPages then
            local nextX = pageStrX + pw + 8
            ui.drawButton(nextX, bottomY, pBtnW, btnH, "Next >", false, gfx.FONT_NOTOSANS_12)
            frontpage.btnNextHit = { x = nextX, y = bottomY, w = pBtnW, h = btnH }
        end
    else
        -- Single page count
        local storyCountStr = string.format("%d stories", #state.getActiveStories())
        gfx.drawText(gfx.FONT_UI_10, 20, bottomY + 18, storyCountStr, true)
    end

    -- Sync Button (Right side, high contrast filled button)
    local syncW = 150
    local syncX = w - 16 - syncW
    ui.drawButton(syncX, bottomY, syncW, btnH, "Sync Feed", true, gfx.FONT_NOTOSANS_12)
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
