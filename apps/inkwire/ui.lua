-- High-contrast UI toolkit and typography for InkWire
local ui = {}

-- Safe text width and line height helpers
function ui.getTextWidth(font, text)
    if not gfx or not gfx.getTextWidth then return #text * 8 end
    return gfx.getTextWidth(font, tostring(text or ""))
end

function ui.getLineHeight(font)
    if not gfx or not gfx.getLineHeight then return 16 end
    return gfx.getLineHeight(font)
end

function ui.truncateText(font, text, maxW)
    text = tostring(text or "")
    if ui.getTextWidth(font, text) <= maxW then return text end
    local str = text
    while #str > 3 and ui.getTextWidth(font, str .. "...") > maxW do
        str = str:sub(1, -2)
    end
    return str .. "..."
end

function ui.wrapText(font, text, maxW)
    if not text or text == "" then return {} end
    local lines = {}
    -- Split by explicit line breaks first
    for para in string.gmatch(text .. "\n", "([^\n]*)\n") do
        if para == "" then
            table.insert(lines, "")
        else
            local currentLine = ""
            for word in string.gmatch(para, "%S+") do
                local testLine = (currentLine == "") and word or (currentLine .. " " .. word)
                if ui.getTextWidth(font, testLine) <= maxW then
                    currentLine = testLine
                else
                    if currentLine ~= "" then
                        table.insert(lines, currentLine)
                        currentLine = word
                    else
                        table.insert(lines, ui.truncateText(font, word, maxW))
                        currentLine = ""
                    end
                end
            end
            if currentLine ~= "" then
                table.insert(lines, currentLine)
            end
        end
    end
    return lines
end

function ui.drawButton(x, y, w, h, label, isFilled, fontId, onClick)
    if _G.ui and _G.ui.drawButton then
        return _G.ui.drawButton({
            x = x, y = y, w = w, h = h,
            label = label,
            variant = isFilled and "primary" or "secondary",
            onClick = onClick
        })
    end
    fontId = fontId or gfx.FONT_NOTOSANS_12
    local lh = ui.getLineHeight(fontId)
    local lw = ui.getTextWidth(fontId, label)
    local lx = x + math.floor((w - lw) / 2)
    local ly = y + math.floor((h - lh) / 2)

    if isFilled then
        gfx.fillRoundedRect(x, y, w, h, 6, gfx.COLOR_BLACK)
        gfx.drawText(fontId, lx, ly, label, false)
    else
        gfx.drawRoundedRect(x, y, w, h, 6, 1, gfx.COLOR_BLACK)
        gfx.drawText(fontId, lx, ly, label, true)
    end
end

function ui.drawMasthead(editionTitle, weather, batteryPct)
    if _G.ui and _G.ui.drawHeader then
        local sub = editionTitle or "DAILY BRIEFING"
        return _G.ui.drawHeader({
            title = "THE INKWIRE CHRONICLE",
            subtitle = sub,
            rightLabel = weather or "",
            showBattery = true,
            showClock = true
        })
    end
    local w = gfx.getWidth()
    -- Top hairline rule
    gfx.drawLine(16, 8, w - 16, 8, gfx.COLOR_BLACK)
    
    -- Main newspaper title
    local title = "THE INKWIRE CHRONICLE"
    local fontTitle = gfx.FONT_NOTOSERIF_14
    local tw = ui.getTextWidth(fontTitle, title)
    gfx.drawText(fontTitle, math.floor((w - tw) / 2), 14, title, true)

    -- Sub-masthead line (Date • Weather • Battery)
    local subline = editionTitle or "DAILY BRIEFING"
    if weather and weather ~= "" then
        subline = subline .. "  •  " .. weather
    end
    if batteryPct then
        subline = subline .. "  •  " .. tostring(batteryPct) .. "%"
    end

    local fontSub = gfx.FONT_UI_10
    local sw = ui.getTextWidth(fontSub, subline)
    if sw > w - 32 then
        subline = ui.truncateText(fontSub, subline, w - 32)
        sw = ui.getTextWidth(fontSub, subline)
    end
    -- Positioned with clean clearance above the bottom rule
    gfx.drawText(fontSub, math.floor((w - sw) / 2), 42, subline, true)

    -- Single clean bottom hairline rule with comfortable breathing room
    gfx.drawLine(16, 68, w - 16, 68, gfx.COLOR_BLACK)
    return { x = 0, y = 70, w = w, h = gfx.getHeight() - 70 }
end

function ui.drawStoryCard(x, y, w, h, article, isHero, onClick)
    if _G.ui and _G.ui.drawCard and _G.ui.drawBadge then
        local card = _G.ui.drawCard({
            x = x, y = y, w = w, h = h,
            variant = "outlined",
            padding = 12,
            onClick = onClick
        })

        -- Source badge / Beat tag
        local badgeText = (article.sectionTitle and (article.sectionTitle:upper() .. "  ") or "") ..
                          (article.source or "Unknown Source")
        if article.time and article.time ~= "" then
            badgeText = badgeText .. " • " .. article.time
        end
        local badge = _G.ui.drawBadge({
            x = card.innerX,
            y = card.innerY,
            text = badgeText,
            variant = isHero and "filled" or "outlined",
            font = gfx.FONT_UI_10
        })

        -- Headline
        local headlineFont = isHero and gfx.FONT_NOTOSANS_14 or gfx.FONT_NOTOSANS_12
        local headLines = ui.wrapText(headlineFont, article.title or "Untitled", card.innerW)
        local maxHeadLines = 2
        local curY = card.innerY + badge.h + 6
        for i = 1, math.min(#headLines, maxHeadLines) do
            local lineText = headLines[i]
            if i == maxHeadLines and #headLines > maxHeadLines then
                lineText = ui.truncateText(headlineFont, lineText, card.innerW)
            end
            gfx.drawText(headlineFont, card.innerX, curY, lineText, true)
            curY = curY + ui.getLineHeight(headlineFont) + 2
        end
        curY = curY + 2

        -- Teaser: Render takeaways / summary lines
        local teaserFont = gfx.FONT_NOTOSERIF_12
        local remainingH = (y + h) - curY - 22
        local maxTeaserLines = math.max(1, math.floor(remainingH / (ui.getLineHeight(teaserFont) + 2)))
        local linesRendered = 0

        if article.bullets and #article.bullets > 0 then
            for _, b in ipairs(article.bullets) do
                if linesRendered >= maxTeaserLines then break end
                local bLines = ui.wrapText(teaserFont, "• " .. b, card.innerW)
                for _, bline in ipairs(bLines) do
                    if linesRendered >= maxTeaserLines then break end
                    gfx.drawText(teaserFont, card.innerX, curY, bline, true)
                    curY = curY + ui.getLineHeight(teaserFont) + 2
                    linesRendered = linesRendered + 1
                end
            end
        elseif article.body and article.body ~= "" then
            local bodyLines = ui.wrapText(teaserFont, article.body, card.innerW)
            for _, bline in ipairs(bodyLines) do
                if linesRendered >= maxTeaserLines then break end
                gfx.drawText(teaserFont, card.innerX, curY, bline, true)
                curY = curY + ui.getLineHeight(teaserFont) + 2
                linesRendered = linesRendered + 1
            end
        end

        -- Bottom action teaser tag
        local readTag = "Read Brief >"
        local rw = ui.getTextWidth(gfx.FONT_UI_10, readTag)
        gfx.drawText(gfx.FONT_UI_10, x + w - rw - 14, y + h - 18, readTag, true)
        return card
    end

    -- Card background and clean 1px border
    gfx.drawRoundedRect(x, y, w, h, 6, 1, gfx.COLOR_BLACK)
    
    local padX = 14
    local innerW = w - padX * 2
    local curY = y + 10

    -- Source badge / Beat tag
    local badge = (article.sectionTitle and ("[" .. article.sectionTitle:upper() .. "] ") or "") ..
                  (article.source or "Unknown Source")
    if article.time and article.time ~= "" then
        badge = badge .. " • " .. article.time
    end
    gfx.drawText(gfx.FONT_UI_10, x + padX, curY, ui.truncateText(gfx.FONT_UI_10, badge, innerW), true)
    curY = curY + 16

    -- Headline
    local headlineFont = isHero and gfx.FONT_NOTOSANS_14 or gfx.FONT_NOTOSANS_12
    local headLines = ui.wrapText(headlineFont, article.title or "Untitled", innerW)
    local maxHeadLines = isHero and 2 or 2
    for i = 1, math.min(#headLines, maxHeadLines) do
        local lineText = headLines[i]
        if i == maxHeadLines and #headLines > maxHeadLines then
            lineText = ui.truncateText(headlineFont, lineText, innerW)
        end
        gfx.drawText(headlineFont, x + padX, curY, lineText, true)
        curY = curY + ui.getLineHeight(headlineFont) + 2
    end
    curY = curY + 2

    -- Teaser: Render takeaways / summary lines
    local teaserFont = gfx.FONT_NOTOSERIF_12
    local remainingH = (y + h) - curY - 26
    local maxTeaserLines = math.max(1, math.floor(remainingH / (ui.getLineHeight(teaserFont) + 2)))
    local linesRendered = 0

    if article.bullets and #article.bullets > 0 then
        for _, b in ipairs(article.bullets) do
            if linesRendered >= maxTeaserLines then break end
            local bLines = ui.wrapText(teaserFont, "• " .. b, innerW)
            for _, bline in ipairs(bLines) do
                if linesRendered >= maxTeaserLines then break end
                gfx.drawText(teaserFont, x + padX, curY, bline, true)
                curY = curY + ui.getLineHeight(teaserFont) + 2
                linesRendered = linesRendered + 1
            end
        end
    elseif article.body and article.body ~= "" then
        local bodyLines = ui.wrapText(teaserFont, article.body, innerW)
        for _, bline in ipairs(bodyLines) do
            if linesRendered >= maxTeaserLines then break end
            gfx.drawText(teaserFont, x + padX, curY, bline, true)
            curY = curY + ui.getLineHeight(teaserFont) + 2
            linesRendered = linesRendered + 1
        end
    end

    -- Bottom action teaser tag
    local readTag = "Read Brief >"
    local rw = ui.getTextWidth(gfx.FONT_UI_10, readTag)
    gfx.drawText(gfx.FONT_UI_10, x + w - rw - padX, y + h - 18, readTag, true)
end

function ui.drawModal(title, msg, subtext, buttonText, buttonW, onAction)
    if _G.ui and _G.ui.drawDialog then
        return _G.ui.drawDialog({
            title = title,
            headline = msg,
            message = subtext,
            buttons = {
                {
                    label = buttonText or "OK",
                    onClick = onAction or function() end
                }
            }
        })
    end

    local w = gfx.getWidth()
    local h = gfx.getHeight()

    -- Dim the background with Bayer dither
    gfx.fillRectDither(0, 0, w, h, gfx.COLOR_DARK_GRAY)

    -- Modal box dimensions
    local mw = math.min(420, w - 40)
    local mh = 240
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    -- Modal background
    gfx.fillRoundedRect(mx, my, mw, mh, 12, gfx.COLOR_WHITE)
    gfx.drawRoundedRect(mx, my, mw, mh, 12, 3, gfx.COLOR_BLACK)

    -- Title
    local tw = ui.getTextWidth(gfx.FONT_NOTOSANS_14, title)
    gfx.drawText(gfx.FONT_NOTOSANS_14, mx + math.floor((mw - tw) / 2), my + 24, title, true)
    gfx.drawLine(mx + 20, my + 52, mx + mw - 20, my + 52, gfx.COLOR_BLACK)

    -- Message
    local mwMax = mw - 40
    local msgLines = ui.wrapText(gfx.FONT_NOTOSERIF_12, msg, mwMax)
    local cy = my + 68
    for _, line in ipairs(msgLines) do
        local lw = ui.getTextWidth(gfx.FONT_NOTOSERIF_12, line)
        gfx.drawText(gfx.FONT_NOTOSERIF_12, mx + math.floor((mw - lw) / 2), cy, line, true)
        cy = cy + ui.getLineHeight(gfx.FONT_NOTOSERIF_12) + 2
    end

    -- Subtext (if any)
    if subtext and subtext ~= "" then
        cy = cy + 6
        local subLines = ui.wrapText(gfx.FONT_UI_10, subtext, mwMax)
        for _, sline in ipairs(subLines) do
            local slw = ui.getTextWidth(gfx.FONT_UI_10, sline)
            gfx.drawText(gfx.FONT_UI_10, mx + math.floor((mw - slw) / 2), cy, sline, true)
            cy = cy + ui.getLineHeight(gfx.FONT_UI_10) + 2
        end
    end

    -- Close / Action Button
    local bw = buttonW or 160
    local bh = 46
    local bx = mx + math.floor((mw - bw) / 2)
    local by = my + mh - bh - 16
    ui.drawButton(bx, by, bw, bh, buttonText or "OK", true, gfx.FONT_NOTOSANS_12)

    return { x = bx, y = by, w = bw, h = bh }
end

return ui
