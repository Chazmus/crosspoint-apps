-- UI rendering utilities and chessboard graphics for CrossPoint Chess
local pieces = require("pieces")

local ui = {}

function ui.drawButton(x, y, w, h, label, isFilled)
    local lh = gfx.getLineHeight(gfx.FONT_SMALL)
    local lw = gfx.getTextWidth(gfx.FONT_SMALL, label)
    local lx = x + math.floor((w - lw) / 2)
    local ly = y + math.floor((h - lh) / 2)

    if isFilled then
        gfx.fillRoundedRect(x, y, w, h, 6, gfx.COLOR_BLACK)
        gfx.drawText(gfx.FONT_SMALL, lx, ly, label, false)
    else
        gfx.drawRoundedRect(x, y, w, h, 6, 2, true)
        gfx.drawText(gfx.FONT_SMALL, lx, ly, label, true)
    end
end

function ui.truncateText(font, text, maxW)
    if gfx.getTextWidth(font, text) <= maxW then return text end
    local str = text
    while #str > 3 and gfx.getTextWidth(font, str .. "...") > maxW do
        str = str:sub(1, -2)
    end
    return str .. "..."
end

function ui.screenToSquare(x, y, boardX, boardY, boardSize, flipped)
    if x < boardX or x >= boardX + boardSize or y < boardY or y >= boardY + boardSize then
        return -1
    end
    local sqSize = boardSize / 8
    local dispFile = math.floor((x - boardX) / sqSize)
    local dispRank = math.floor((y - boardY) / sqSize)
    local file = flipped and (7 - dispFile) or dispFile
    local rank = flipped and dispRank or (7 - dispRank)
    return rank * 8 + file
end

function ui.drawBoard(boardTable, boardX, boardY, boardSize, flipped, selSq, hintSquare, legalDests)
    local sqSize = boardSize / 8
    local pieceOffset = math.floor((sqSize - 40) / 2)

    -- Outer border
    gfx.drawRect(boardX - 2, boardY - 2, boardSize + 4, boardSize + 4, 2, true)

    for rank = 0, 7 do
        for file = 0, 7 do
            local dispFile = flipped and (7 - file) or file
            local dispRank = flipped and rank or (7 - rank)
            local sqX = boardX + dispFile * sqSize
            local sqY = boardY + dispRank * sqSize
            local sq = rank * 8 + file

            local isDark = ((file + rank) % 2 == 0)
            if isDark then
                gfx.fillRectDither(sqX, sqY, sqSize, sqSize, gfx.COLOR_LIGHT_GRAY)
            else
                gfx.fillRect(sqX, sqY, sqSize, sqSize, false)
            end

            -- Selection highlight
            if sq == selSq then
                gfx.drawRect(sqX + 1, sqY + 1, sqSize - 2, sqSize - 2, 4, true)
            end

            -- Hint highlight
            if sq == hintSquare then
                gfx.drawRect(sqX + 2, sqY + 2, sqSize - 4, sqSize - 4, 3, true)
            end

            -- Draw piece sprite
            local p = boardTable[sq]
            if p and p ~= "." and pieces[p] then
                gfx.drawSprite(sqX + pieceOffset, sqY + pieceOffset, 40, 40, pieces[p].ink, pieces[p].mask)
            end

            -- Legal move target indicator
            if legalDests and legalDests[sq] then
                if p == "." then
                    -- Quiet move: small dot in center
                    gfx.fillRoundedRect(sqX + 21, sqY + 21, 8, 8, 3, true)
                else
                    -- Capture move: corner-rounded capture ring
                    gfx.drawRoundedRect(sqX + 2, sqY + 2, sqSize - 4, sqSize - 4, 6, 3, true)
                end
            end
        end
    end

    -- Rank labels (1..8)
    for r = 0, 7 do
        local dispRank = flipped and r or (7 - r)
        local lbl = tostring(r + 1)
        local ly = boardY + dispRank * sqSize + math.floor((sqSize - gfx.getLineHeight(gfx.FONT_SMALL)) / 2)
        gfx.drawText(gfx.FONT_SMALL, boardX - 16, ly, lbl, true)
    end

    -- File labels (a..h)
    for f = 0, 7 do
        local dispFile = flipped and (7 - f) or f
        local lbl = string.char(97 + f)
        local lw = gfx.getTextWidth(gfx.FONT_SMALL, lbl)
        local lx = boardX + dispFile * sqSize + math.floor((sqSize - lw) / 2)
        gfx.drawText(gfx.FONT_SMALL, lx, boardY + boardSize + 4, lbl, true)
    end
end

return ui
