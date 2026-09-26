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

function ui.drawButton(x, y, w, h, label, isFilled, fontId)
    fontId = fontId or gfx.FONT_NOTOSANS_12
    local lh = ui.getLineHeight(fontId)
    local lw = ui.getTextWidth(fontId, label)
    local lx = x + math.floor((w - lw) / 2)
    local ly = y + math.floor((h - lh) / 2)

    if isFilled then
        gfx.fillRoundedRect(x, y, w, h, 6, gfx.COLOR_BLACK)
        gfx.drawText(fontId, lx, ly, label, false)
    else
        gfx.drawRoundedRect(x, y, w, h, 6, 2, gfx.COLOR_BLACK)
        gfx.drawText(fontId, lx, ly, label, true)
    end
end

function ui.drawMasthead(editionTitle, weather, batteryPct)
    local w = gfx.getWidth()
    -- Top rule
    gfx.drawLine(16, 10, w - 16, 10, gfx.COLOR_BLACK)
    
    -- Main newspaper title
    local title = "THE INKWIRE CHRONICLE"
    local fontTitle = gfx.FONT_NOTOSERIF_14
    local tw = ui.getTextWidth(fontTitle, title)
    gfx.drawText(fontTitle, math.floor((w - tw) / 2), 16, title, true)

    -- Sub-masthead line
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
    gfx.drawText(fontSub, math.floor((w - sw) / 2), 40, subline, true)

    -- Double bottom rule
    gfx.drawLine(16, 56, w - 16, 56, gfx.COLOR_BLACK)
    gfx.drawLine(16, 59, w - 16, 59, gfx.COLOR_BLACK)
end

function ui.drawStoryCard(x, y, w, h, article, isHero)
    -- Card background and border
    gfx.drawRoundedRect(x, y, w, h, 8, isHero and 3 or 2, gfx.COLOR_BLACK)
    
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

    -- Teaser / First Bullet
    local teaserText = nil
    if article.bullets and #article.bullets > 0 then
        teaserText = "• " .. article.bullets[1]
    elseif article.body and article.body ~= "" then
        teaserText = article.body
    end

    if teaserText then
        local teaserFont = gfx.FONT_NOTOSERIF_12
        local remainingH = (y + h) - curY - 24
        local maxTeaserLines = math.max(1, math.floor(remainingH / ui.getLineHeight(teaserFont)))
        local teaserLines = ui.wrapText(teaserFont, teaserText, innerW)
        for i = 1, math.min(#teaserLines, maxTeaserLines) do
            local lineText = teaserLines[i]
            if i == maxTeaserLines and #teaserLines > maxTeaserLines then
                lineText = ui.truncateText(teaserFont, lineText, innerW)
            end
            gfx.drawText(teaserFont, x + padX, curY, lineText, true)
            curY = curY + ui.getLineHeight(teaserFont)
        end
    end

    -- Bottom action teaser tag
    local readTag = "Read Brief >"
    local rw = ui.getTextWidth(gfx.FONT_UI_10, readTag)
    gfx.drawText(gfx.FONT_UI_10, x + w - rw - padX, y + h - 18, readTag, true)
end

function ui.drawModal(title, msg, subtext, buttonText, buttonW)
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
