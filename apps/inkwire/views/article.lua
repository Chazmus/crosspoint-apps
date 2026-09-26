-- Article Detail Reading View for InkWire (Bullets, Body, QR Code Mobile Handoff, Navigation)
local ui = require("ui")
local state = require("state")
local qr = require("qr")

local articleView = {
    btnBackHit = nil,
    btnPrevHit = nil,
    btnNextHit = nil
}

function articleView.draw()
    local w = gfx.getWidth()
    local h = gfx.getHeight()
    local art = state.currentArticle
    if not art then
        state.currentView = "frontpage"
        return
    end

    -- 1. Top Header Bar
    local headY = 12
    local headH = 40
    ui.drawButton(16, headY, 84, headH, "< Back", false, gfx.FONT_NOTOSANS_12)
    articleView.btnBackHit = { x = 16, y = headY, w = 84, h = headH }

    -- Section & Source info right-aligned
    local sourceInfo = (art.sectionTitle and (art.sectionTitle:upper() .. " • ") or "") ..
                       (art.source or "Source") ..
                       (art.time and (" • " .. art.time) or "")
    local infoFont = gfx.FONT_UI_10
    local iw = ui.getTextWidth(infoFont, sourceInfo)
    local maxInfoW = w - 16 - 110
    if iw > maxInfoW then
        sourceInfo = ui.truncateText(infoFont, sourceInfo, maxInfoW)
        iw = ui.getTextWidth(infoFont, sourceInfo)
    end
    gfx.drawText(infoFont, w - 16 - iw, headY + 12, sourceInfo, true)

    -- Separator line
    gfx.drawLine(16, headY + headH + 8, w - 16, headY + headH + 8, gfx.COLOR_BLACK)

    local curY = headY + headH + 16
    local contentW = w - 32
    local contentX = 16

    -- 2. Article Title (Bold, wrapped)
    local titleFont = gfx.FONT_NOTOSANS_14
    local titleLines = ui.wrapText(titleFont, art.title or "Untitled", contentW)
    for _, line in ipairs(titleLines) do
        gfx.drawText(titleFont, contentX, curY, line, true)
        curY = curY + ui.getLineHeight(titleFont) + 2
    end
    curY = curY + 6

    -- 3. Key Takeaways Box (if bullets exist)
    if art.bullets and #art.bullets > 0 then
        local boxPad = 12
        local innerBoxW = contentW - boxPad * 2
        local bulletFont = gfx.FONT_NOTOSERIF_12

        -- Pre-calculate box height
        local boxH = 26 -- Header space
        local wrappedBullets = {}
        for _, b in ipairs(art.bullets) do
            local lines = ui.wrapText(bulletFont, "• " .. b, innerBoxW)
            table.insert(wrappedBullets, lines)
            boxH = boxH + (#lines * (ui.getLineHeight(bulletFont) + 2)) + 4
        end

        -- Draw container
        gfx.drawRoundedRect(contentX, curY, contentW, boxH, 8, 2, gfx.COLOR_BLACK)
        gfx.drawText(gfx.FONT_UI_10, contentX + boxPad, curY + 8, "KEY TAKEAWAYS", true)
        gfx.drawLine(contentX + boxPad, curY + 22, contentX + contentW - boxPad, curY + 22, gfx.COLOR_BLACK)

        local bY = curY + 28
        for _, lines in ipairs(wrappedBullets) do
            for _, bline in ipairs(lines) do
                gfx.drawText(bulletFont, contentX + boxPad, bY, bline, true)
                bY = bY + ui.getLineHeight(bulletFont) + 2
            end
            bY = bY + 4
        end

        curY = curY + boxH + 12
    end

    -- 4. Article Summary / Body
    if art.body and art.body ~= "" then
        local bodyFont = gfx.FONT_NOTOSERIF_12
        local bodyLines = ui.wrapText(bodyFont, art.body, contentW)
        
        -- Measure how many lines fit before reaching the QR code section
        local maxBodyY = (art.url and art.url ~= "") and (h - 180) or (h - 80)
        for _, bline in ipairs(bodyLines) do
            if curY + ui.getLineHeight(bodyFont) > maxBodyY then
                gfx.drawText(bodyFont, contentX, curY, "[Continued in original source...]", true)
                curY = curY + ui.getLineHeight(bodyFont)
                break
            end
            if bline == "" then
                curY = curY + 6
            else
                gfx.drawText(bodyFont, contentX, curY, bline, true)
                curY = curY + ui.getLineHeight(bodyFont) + 2
            end
        end
        curY = curY + 10
    end

    -- 5. QR Code "Mobile Handoff" Section
    if art.url and art.url ~= "" then
        local qrSize = 92
        local qrBoxY = h - 64 - qrSize - 12
        local qrX = contentX + 6
        
        -- QR container outline
        gfx.drawRoundedRect(contentX, qrBoxY, contentW, qrSize + 8, 8, 1, gfx.COLOR_BLACK)
        
        -- Draw 1-bit QR Code
        qr.draw(qrX, qrBoxY + 4, qrSize, qrSize, art.url)

        -- Companion Text
        local textX = qrX + qrSize + 14
        local textW = contentW - qrSize - 26
        local qrTitle = "Read Full Story On Phone"
        gfx.drawText(gfx.FONT_NOTOSANS_12, textX, qrBoxY + 12, qrTitle, true)
        
        local qrDesc = "Scan code with camera to open original source in your browser."
        local descLines = ui.wrapText(gfx.FONT_UI_10, qrDesc, textW)
        local dY = qrBoxY + 34
        for _, dl in ipairs(descLines) do
            gfx.drawText(gfx.FONT_UI_10, textX, dY, dl, true)
            dY = dY + ui.getLineHeight(gfx.FONT_UI_10) + 1
        end

        local hostStr = art.url:match("^https?://([^/]+)") or art.url
        gfx.drawText(gfx.FONT_UI_10, textX, qrBoxY + qrSize - 12, "Source: " .. hostStr, true)
    end

    -- 6. Bottom Navigation Bar (Prev Story / Next Story)
    local bottomY = h - 62
    local btnH = 48
    local btnW = 130
    local stories = state.getActiveStories()
    local idx = state.findArticleIndex(art)

    articleView.btnPrevHit = nil
    articleView.btnNextHit = nil

    if idx > 1 then
        ui.drawButton(16, bottomY, btnW, btnH, "< Prev Story", false, gfx.FONT_NOTOSANS_12)
        articleView.btnPrevHit = { x = 16, y = bottomY, w = btnW, h = btnH }
    end

    local storyIndicator = string.format("%d of %d", idx, #stories)
    local sw = ui.getTextWidth(gfx.FONT_NOTOSANS_12, storyIndicator)
    gfx.drawText(gfx.FONT_NOTOSANS_12, math.floor((w - sw) / 2), bottomY + 16, storyIndicator, true)

    if idx < #stories then
        local nextX = w - 16 - btnW
        ui.drawButton(nextX, bottomY, btnW, btnH, "Next Story >", false, gfx.FONT_NOTOSANS_12)
        articleView.btnNextHit = { x = nextX, y = bottomY, w = btnW, h = btnH }
    end
end

local function hitTest(box, x, y)
    return box and x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h
end

function articleView.onTouch(x, y)
    if hitTest(articleView.btnBackHit, x, y) then
        state.currentView = "frontpage"
        state.currentArticle = nil
        if crosspoint then crosspoint.requestUpdate() end
        return true
    end

    if hitTest(articleView.btnPrevHit, x, y) then
        state.prevArticle()
        return true
    end

    if hitTest(articleView.btnNextHit, x, y) then
        state.nextArticle()
        return true
    end

    return false
end

function articleView.onInput(btn, action)
    if action ~= "press" then return false end

    if btn == input.BTN_BACK then
        state.currentView = "frontpage"
        state.currentArticle = nil
        if crosspoint then crosspoint.requestUpdate() end
        return true
    elseif btn == input.BTN_PAGE_BACK or btn == input.BTN_LEFT then
        state.prevArticle()
        return true
    elseif btn == input.BTN_PAGE_FORWARD or btn == input.BTN_RIGHT then
        state.nextArticle()
        return true
    end

    return false
end

return articleView
