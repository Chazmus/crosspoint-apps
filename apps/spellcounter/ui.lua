-- ============================================================================
-- Spell Counter - UI Rendering Toolkit & Primitives
-- Shapes, buttons, segmented large digits, and safe color/font handling.
-- ============================================================================

local ui = {}

ui.C_BLACK = true
ui.C_WHITE = false

local function safeNum(n, def)
    local v = tonumber(n)
    return (v ~= nil) and v or (def or 0)
end

local function safeText(s, def)
    if s == nil then return def or "" end
    return tostring(s)
end

function ui.getFont(name)
    if not gfx then return 1 end
    if name == "ui_10" then return gfx.FONT_UI_10 or 1 end
    if name == "ui_12" then return gfx.FONT_UI_12 or 2 end
    if name == "small" then return gfx.FONT_SMALL or 3 end
    if name == "serif_12" then return gfx.FONT_NOTOSERIF_12 or 7 end
    return gfx.FONT_UI_10 or 1
end

function ui.getTextWidth(font, text)
    if not gfx or not gfx.getTextWidth then
        return #safeText(text, "") * 8
    end
    return gfx.getTextWidth(font, safeText(text, ""))
end

function ui.getLineHeight(font)
    if not gfx or not gfx.getLineHeight then return 16 end
    return gfx.getLineHeight(font)
end

function ui.fillRounded(x, y, w, h, r, isBlack)
    x = safeNum(x, 0)
    y = safeNum(y, 0)
    w = math.max(1, safeNum(w, 1))
    h = math.max(1, safeNum(h, 1))
    r = math.max(0, safeNum(r, 0))
    local col = (isBlack == false or isBlack == 3) and ((gfx and gfx.COLOR_WHITE) or 3) or ((gfx and gfx.COLOR_BLACK) or 0)
    if gfx and gfx.fillRoundedRect then
        gfx.fillRoundedRect(x, y, w, h, r, col)
    end
end

function ui.drawRounded(x, y, w, h, r, lineWidth, isBlack)
    x = safeNum(x, 0)
    y = safeNum(y, 0)
    w = math.max(1, safeNum(w, 1))
    h = math.max(1, safeNum(h, 1))
    r = math.max(0, safeNum(r, 0))
    if type(lineWidth) == "boolean" then
        isBlack = lineWidth
        lineWidth = 1
    end
    lineWidth = math.max(1, safeNum(lineWidth, 1))
    local black = (isBlack ~= false and isBlack ~= 3)
    if gfx and gfx.drawRoundedRect then
        gfx.drawRoundedRect(x, y, w, h, r, lineWidth, black)
    end
end

function ui.drawButton(x, y, w, h, text, font, isBlack, isFilled)
    x = safeNum(x, 0)
    y = safeNum(y, 0)
    w = math.max(1, safeNum(w, 40))
    h = math.max(1, safeNum(h, 20))
    font = font or ui.getFont("ui_10")
    text = safeText(text, "")

    local textBlack = isFilled and (not isBlack) or (isBlack ~= false and isBlack ~= 3)

    if isFilled then
        ui.fillRounded(x, y, w, h, 8, isBlack)
    else
        ui.drawRounded(x, y, w, h, 8, 2, isBlack)
    end

    local tw = ui.getTextWidth(font, text)
    local th = ui.getLineHeight(font)
    if gfx and gfx.drawText then
        gfx.drawText(font, x + math.floor((w - tw) / 2), y + math.floor((h - th) / 2), text, textBlack)
    end
end

-- ---------------------------------------------------------------------------
-- Segmented Large Digits
-- ---------------------------------------------------------------------------
local SEGMENT_PATTERNS = {
    [0] = {"t", "tl", "tr", "bl", "br", "b"},
    [1] = {"tr", "br"},
    [2] = {"t", "tr", "m", "bl", "b"},
    [3] = {"t", "tr", "m", "br", "b"},
    [4] = {"tl", "tr", "m", "br"},
    [5] = {"t", "tl", "m", "br", "b"},
    [6] = {"t", "tl", "m", "bl", "br", "b"},
    [7] = {"t", "tr", "br"},
    [8] = {"t", "tl", "tr", "m", "bl", "br", "b"},
    [9] = {"t", "tl", "tr", "m", "br", "b"},
    ["-"] = {"m"},
}

local function drawSegment(x, y, w, h, s, segKey, isBlack)
    local halfH = math.floor((h - s) / 2)
    local r = 1
    if segKey == "t" then
        ui.fillRounded(x + 1, y, w - 2, s, r, isBlack)
    elseif segKey == "tl" then
        ui.fillRounded(x, y + 1, s, halfH, r, isBlack)
    elseif segKey == "tr" then
        ui.fillRounded(x + w - s, y + 1, s, halfH, r, isBlack)
    elseif segKey == "m" then
        ui.fillRounded(x + 1, y + halfH, w - 2, s, r, isBlack)
    elseif segKey == "bl" then
        ui.fillRounded(x, y + halfH, s, halfH, r, isBlack)
    elseif segKey == "br" then
        ui.fillRounded(x + w - s, y + halfH, s, halfH, r, isBlack)
    elseif segKey == "b" then
        ui.fillRounded(x + 1, y + h - s, w - 2, s, r, isBlack)
    end
end

local function drawSingleDigit(x, y, w, h, s, ch, isBlack)
    x = safeNum(x, 0)
    y = safeNum(y, 0)
    w = safeNum(w, 20)
    h = safeNum(h, 40)
    s = safeNum(s, 6)
    ch = safeText(ch, "0")

    if ch == "1" then
        local barW = s + 1
        local barX = x + math.floor((w - barW) / 2)
        ui.fillRounded(barX, y, barW, h, 2, isBlack)
        ui.fillRounded(barX - s + 1, y + 1, s, s, 1, isBlack)
        return
    end

    if ch == "-" then
        local halfH = math.floor((h - s) / 2)
        ui.fillRounded(x + 2, y + halfH, w - 4, s, 1, isBlack)
        return
    end

    local key = tonumber(ch)
    local pat = key and SEGMENT_PATTERNS[key]
    if pat then
        for _, sk in ipairs(pat) do
            drawSegment(x, y, w, h, s, sk, isBlack)
        end
    end
end

function ui.drawBigNumber(cx, cy, num, digitW, digitH, strokeW, isBlack)
    cx = safeNum(cx, 0)
    cy = safeNum(cy, 0)
    num = safeNum(num, 0)
    digitW = math.max(10, safeNum(digitW, 26))
    digitH = math.max(16, safeNum(digitH, 46))
    strokeW = math.max(2, safeNum(strokeW, 6))

    local numStr = tostring(math.floor(num))
    local spacing = math.floor(digitW * 0.25)
    local totalW = #numStr * digitW + (#numStr - 1) * spacing
    local startX = cx - math.floor(totalW / 2)

    for i = 1, #numStr do
        local ch = numStr:sub(i, i)
        local dx = startX + (i - 1) * (digitW + spacing)
        drawSingleDigit(dx, cy - math.floor(digitH / 2), digitW, digitH, strokeW, ch, isBlack)
    end
end

return ui
