-- ============================================================================
-- Chess Clock - FlipGfx: Upside-Down Rendering for the Far Player's Panel
-- The Lua API exposes no rotated text (firmware has drawTextRotated90CW but
-- does not bind it; the simulator does not either), so the far side is drawn
-- with self-rendered glyphs that flip at blit time:
--   * 7-segment digits: each active segment's rectangle is rotated 180
--     degrees about the digit cell center (exact integer remap), and the
--     character sequence is reversed so "4:59" reads correctly inverted.
--   * 5x7 bitmap font: rows and columns of each glyph are reversed, and the
--     character order is reversed, giving a true 180-degree rotation.
-- Both primitives avoid gfx.drawSprite's row-packed string format: a Lua-side
-- fillRect loop keeps the code readable and is fast enough for a clock panel
-- (a few hundred rects per frame, drawn on demand only).
-- ============================================================================

local flipgfx = {}

flipgfx.C_BLACK = 0
flipgfx.C_WHITE = 1

-- Segment layout per digit, keys: t top, tl top-left, tr top-right,
-- m middle, bl bottom-left, br bottom-right, b bottom.
local SEG_PATTERNS = {
    ["0"] = { t = 1, tl = 1, tr = 1, bl = 1, br = 1, b = 1 },
    ["1"] = { tr = 1, br = 1 },
    ["2"] = { t = 1, tr = 1, m = 1, bl = 1, b = 1 },
    ["3"] = { t = 1, tr = 1, m = 1, br = 1, b = 1 },
    ["4"] = { tl = 1, tr = 1, m = 1, br = 1 },
    ["5"] = { t = 1, tl = 1, m = 1, br = 1, b = 1 },
    ["6"] = { t = 1, tl = 1, m = 1, bl = 1, br = 1, b = 1 },
    ["7"] = { t = 1, tr = 1, br = 1 },
    ["8"] = { t = 1, tl = 1, tr = 1, m = 1, bl = 1, br = 1, b = 1 },
    ["9"] = { t = 1, tl = 1, tr = 1, m = 1, br = 1, b = 1 },
    ["-"] = { m = 1 },
}

--- Draw one 7-segment digit. When `flipped`, every active segment rectangle
--- is rotated 180 degrees about the digit cell center, so the digit reads
--- correctly for the player sitting opposite.
function flipgfx.drawDigit(x, y, w, h, ch, black, flipped)
    local pat = SEG_PATTERNS[ch]
    if not pat then return end
    local s = math.max(2, math.floor(w * 0.22)) -- segment thickness
    local halfH = math.floor((h - s) / 2)

    -- Upright segment rectangles (relative to the cell origin).
    local segs = {
        t  = { x + s, y,               w - 2 * s, s },
        b  = { x + s, y + h - s,       w - 2 * s, s },
        m  = { x + s, y + halfH,       w - 2 * s, s },
        tl = { x,     y + s,           s, halfH - s },
        tr = { x + w - s, y + s,       s, halfH - s },
        bl = { x,     y + halfH + s,   s, h - halfH - 2 * s },
        br = { x + w - s, y + halfH + s, s, h - halfH - 2 * s },
    }

    for key, active in pairs(pat) do
        if active then
            local r = segs[key]
            if flipped then
                -- Exact 180-degree rotation about the cell center.
                gfx.fillRect(2 * x + w - r[1] - r[3], 2 * y + h - r[2] - r[4], r[3], r[4], black)
            else
                gfx.fillRect(r[1], r[2], r[3], r[4], black)
            end
        end
    end
end

--- Draw a digit string centered on (cx, cy). When `flipped`, the character
--- sequence is reversed and each glyph is individually rotated, so the whole
--- string is a true 180-degree rotation ("4:59" renders readable inverted).
function flipgfx.drawDigits(cx, cy, text, digitW, digitH, black, flipped)
    if not text or text == "" then return end
    local n = #text
    local spacing = math.max(2, math.floor(digitW * 0.28))
    local colonW = math.max(2, math.floor(digitW * 0.22))
    local dotW = math.max(2, math.floor(digitW * 0.22)) -- "." slot width
    local dotH = math.max(2, math.floor(digitH * 0.09))
    local dotTop = math.floor(digitH * 0.25)

    local chars, widths, totalW = {}, {}, 0
    for i = 1, n do
        local ch = text:sub(i, i)
        chars[i] = ch
        if ch == ":" then
            widths[i] = colonW
        elseif ch == "." then
            widths[i] = dotW
        else
            widths[i] = digitW
        end
        totalW = totalW + widths[i]
        if i < n then totalW = totalW + spacing end
    end

    local y = cy - math.floor(digitH / 2)
    local x = cx - math.floor(totalW / 2)

    local function drawSlot(i, sx)
        local ch = chars[i]
        if ch == ":" then
            -- Square dots, vertically placed so the pair is 180-symmetric.
            local cxr = sx + math.floor((colonW - dotH) / 2)
            gfx.fillRect(cxr, y + dotTop, dotH, dotH, black)
            gfx.fillRect(cxr, y + digitH - dotTop - dotH, dotH, dotH, black)
        elseif ch == "." then
            -- Baseline dot at the slot's right edge (left edge when flipped).
            if flipped then
                gfx.fillRect(sx, y, dotH, dotH, black)
            else
                gfx.fillRect(sx + dotW - dotH, y + digitH - dotH, dotH, dotH, black)
            end
        else
            flipgfx.drawDigit(sx, y, widths[i], digitH, ch, black, flipped)
        end
    end

    if flipped then
        for i = n, 1, -1 do
            drawSlot(i, x)
            x = x + widths[i] + spacing
        end
    else
        for i = 1, n do
            drawSlot(i, x)
            x = x + widths[i] + spacing
        end
    end
end

-- ---------------------------------------------------------------------------
-- 5x7 bitmap font (columns MSB-first per row, 1 = ink). Covers the label
-- glyphs the far panel needs.
-- ---------------------------------------------------------------------------
local FONT_5X7 = {
    ["0"] = { 0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E },
    ["1"] = { 0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E },
    ["2"] = { 0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F },
    ["3"] = { 0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E },
    ["4"] = { 0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02 },
    ["5"] = { 0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E },
    ["6"] = { 0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E },
    ["7"] = { 0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08 },
    ["8"] = { 0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E },
    ["9"] = { 0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C },
    ["A"] = { 0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11 },
    ["B"] = { 0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E },
    ["C"] = { 0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E },
    ["D"] = { 0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E },
    ["E"] = { 0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F },
    ["F"] = { 0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10 },
    ["G"] = { 0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0F },
    ["H"] = { 0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11 },
    ["I"] = { 0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E },
    ["J"] = { 0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C },
    ["K"] = { 0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11 },
    ["L"] = { 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F },
    ["M"] = { 0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11 },
    ["N"] = { 0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11 },
    ["O"] = { 0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E },
    ["P"] = { 0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10 },
    ["Q"] = { 0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D },
    ["R"] = { 0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11 },
    ["S"] = { 0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E },
    ["T"] = { 0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04 },
    ["U"] = { 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E },
    ["V"] = { 0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04 },
    ["W"] = { 0x11, 0x11, 0x11, 0x15, 0x15, 0x1B, 0x11 },
    ["X"] = { 0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11 },
    ["Y"] = { 0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04 },
    ["Z"] = { 0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F },
    ["+"] = { 0x00, 0x04, 0x04, 0x1F, 0x04, 0x04, 0x00 },
    ["-"] = { 0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00 },
    [":"] = { 0x00, 0x04, 0x00, 0x00, 0x04, 0x00, 0x00 },
    ["."] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x0C, 0x0C },
    [" "] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
}

local GLYPH_W = 5
local GLYPH_H = 7

--- Draw a string with the 5x7 font. mode "flip180" renders a true 180-degree
--- rotation: each glyph's rows and columns are reversed AND the character
--- order is reversed, so "BLACK" reads correctly for the opposite player.
function flipgfx.drawGlyphText(x, y, text, scale, black, mode)
    scale = math.max(1, math.floor(scale or 1))
    local flipped = (mode == "flip180")
    local advance = (GLYPH_W + 1) * scale
    local first, last, step = 1, #text, 1
    if flipped then
        first, last, step = #text, 1, -1
    end
    local cursor = x
    for i = first, last, step do
        local glyph = FONT_5X7[text:sub(i, i)]
        if glyph then
            for row = 1, GLYPH_H do
                local srcRow = flipped and (GLYPH_H + 1 - row) or row
                local bits = glyph[srcRow]
                for col = 1, GLYPH_W do
                    local srcCol = flipped and (GLYPH_W + 1 - col) or col
                    -- bits: bit 4 = leftmost column
                    local bitIdx = GLYPH_W - srcCol -- 0 for leftmost
                    if (bits >> bitIdx) & 1 == 1 then
                        local px = cursor + (col - 1) * scale
                        local py = y + (row - 1) * scale
                        if scale == 1 then
                            gfx.drawPixel(px, py, black)
                        else
                            gfx.fillRect(px, py, scale, scale, black)
                        end
                    end
                end
            end
        end
        cursor = cursor + advance
    end
end

--- Pixel width a string will occupy when drawn by drawGlyphText.
function flipgfx.glyphTextWidth(text, scale)
    scale = math.max(1, math.floor(scale or 1))
    if not text or text == "" then return 0 end
    return #text * (GLYPH_W + 1) * scale - scale
end

--- Draw glyph text centered on (cx, y).
function flipgfx.drawGlyphTextCentered(cx, y, text, scale, black, mode)
    local w = flipgfx.glyphTextWidth(text, scale)
    flipgfx.drawGlyphText(cx - math.floor(w / 2), y, text, scale, black, mode)
end

return flipgfx
