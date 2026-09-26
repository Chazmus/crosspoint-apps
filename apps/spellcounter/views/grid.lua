-- ============================================================================
-- Spell Counter - Grid & Card Layout Manager
-- Dynamic card partitioning for 1 to 4 players in landscape & portrait.
-- ============================================================================

local ui = require("ui")
local stateEngine = require("state")

local grid = {}

local function safeNum(n, def)
    local v = tonumber(n)
    return (v ~= nil) and v or (def or 0)
end

local function safeInt(n, def)
    local v = tonumber(n)
    return (v ~= nil) and math.floor(v) or (def or 0)
end

function grid.getCardRects(w, h, count)
    w = safeNum(w, 800)
    h = safeNum(h, 480)
    count = math.max(1, math.min(4, safeInt(count, 4)))
    local headerH = 38
    local availH = h - headerH
    local rects = {}

    if count == 1 then
        rects[1] = {x = 10, y = headerH + 6, w = w - 20, h = availH - 14}
    elseif count == 2 then
        if w >= h then
            local halfW = math.floor((w - 20) / 2)
            rects[1] = {x = 8, y = headerH + 6, w = halfW - 4, h = availH - 14}
            rects[2] = {x = 12 + halfW, y = headerH + 6, w = halfW - 4, h = availH - 14}
        else
            local halfH = math.floor((availH - 20) / 2)
            rects[1] = {x = 8, y = headerH + 6, w = w - 16, h = halfH - 4}
            rects[2] = {x = 8, y = headerH + 12 + halfH, w = w - 16, h = halfH - 4}
        end
    elseif count == 3 then
        if w >= h then
            local col1W = math.floor((w - 24) * 0.48)
            local col2W = w - 24 - col1W
            local rowH = math.floor((availH - 18) / 2)
            rects[1] = {x = 8, y = headerH + 6, w = col1W, h = availH - 14}
            rects[2] = {x = 16 + col1W, y = headerH + 6, w = col2W, h = rowH}
            rects[3] = {x = 16 + col1W, y = headerH + 12 + rowH, w = col2W, h = rowH}
        else
            local rowH = math.floor((availH - 24) / 3)
            for i = 1, 3 do
                rects[i] = {x = 8, y = headerH + 6 + (i - 1) * (rowH + 6), w = w - 16, h = rowH}
            end
        end
    else
        local colW = math.floor((w - 20) / 2)
        local rowH = math.floor((availH - 18) / 2)
        rects[1] = {x = 8, y = headerH + 6, w = colW, h = rowH}
        rects[2] = {x = 12 + colW, y = headerH + 6, w = colW, h = rowH}
        rects[3] = {x = 8, y = headerH + 12 + rowH, w = colW, h = rowH}
        rects[4] = {x = 12 + colW, y = headerH + 12 + rowH, w = colW, h = rowH}
    end

    return rects, headerH
end

function grid.drawTopBar(w, headerH, state)
    w = safeNum(w, 800)
    headerH = safeNum(headerH, 38)
    if gfx and gfx.fillRect then
        gfx.fillRect(0, 0, w, headerH, ui.C_BLACK)
    end

    -- Left: Player Count button
    local pc = math.max(1, math.min(4, safeInt(state.playerCount, 4)))
    local pcText = pc .. " Player" .. (pc > 1 and "s" or "")
    local pcW = ui.getTextWidth(ui.getFont("ui_10"), pcText) + 16
    ui.drawRounded(10, 5, pcW, headerH - 10, 6, 1, ui.C_WHITE)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_10"), 18, 9, pcText, ui.C_WHITE)
    end

    -- Center: App Title & Day/Night badge
    local title = "SPELL COUNTER"
    if state.dayNight == "day" then
        title = "SPELL COUNTER [DAY]"
    elseif state.dayNight == "night" then
        title = "SPELL COUNTER [NIGHT]"
    end
    local tw = ui.getTextWidth(ui.getFont("ui_10"), title)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_10"), math.floor((w - tw) / 2), 9, title, ui.C_WHITE)
    end

    -- Right Buttons: [Reset] & [Tools]
    local rightX = w - 10

    -- [Tools]
    local toolsText = "Tools"
    local toolsW = ui.getTextWidth(ui.getFont("ui_10"), toolsText) + 16
    rightX = rightX - toolsW
    ui.drawRounded(rightX, 5, toolsW, headerH - 10, 6, 1, ui.C_WHITE)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_10"), rightX + 8, 9, toolsText, ui.C_WHITE)
    end

    -- [Reset]
    rightX = rightX - 8
    local resetText = "Reset"
    local resetW = ui.getTextWidth(ui.getFont("ui_10"), resetText) + 16
    rightX = rightX - resetW
    ui.drawRounded(rightX, 5, resetW, headerH - 10, 6, 1, ui.C_WHITE)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_10"), rightX + 8, 9, resetText, ui.C_WHITE)
    end
end

function grid.getMenuButtonBounds(rect)
    if not rect then return 0, 0, 0, 0 end
    local x = safeNum(rect.x, 0)
    local y = safeNum(rect.y, 0)
    local w = safeNum(rect.w, 100)
    local btnW = 54
    local btnH = 26
    local btnX = x + w - btnW - 8
    local btnY = y + 4
    return btnX, btnY, btnW, btnH
end

function grid.isMenuButtonTouch(x, y, rect)
    if not rect then return false end
    local rx = safeNum(rect.x, 0)
    local ry = safeNum(rect.y, 0)
    local rw = safeNum(rect.w, 100)
    local rh = safeNum(rect.h, 100)

    -- Generous touch target (hitbox) covering the top-right menu region:
    -- - Extends to the top (ry) and right (rx + rw) edges of the card
    -- - Width: at least 78px (or 45% of card width, capped at 78px)
    -- - Height: 54px (well above the + button which starts at ry + 76 or lower)
    local hitW = math.min(math.floor(rw * 0.45), 78)
    local hitH = math.min(math.floor(rh * 0.28), 54)
    local hitX = rx + rw - hitW
    local hitY = ry

    return x >= hitX and x <= rx + rw and y >= hitY and y <= ry + hitH
end

function grid.drawPlayerCard(p, rect, isSelected, state)
    if not rect or type(rect) ~= "table" then return end
    p = stateEngine.ensurePlayer(p, 1, state.startingLife or 40)

    local x, y, w, h = safeNum(rect.x, 0), safeNum(rect.y, 0), safeNum(rect.w, 100), safeNum(rect.h, 100)
    local bgCol = p.inverted and ui.C_BLACK or ui.C_WHITE
    local fgCol = p.inverted and ui.C_WHITE or ui.C_BLACK

    -- Card Background
    if p.inverted then
        ui.fillRounded(x, y, w, h, 12, ui.C_BLACK)
        ui.drawRounded(x, y, w, h, 12, 2, ui.C_WHITE)
    else
        ui.fillRounded(x, y, w, h, 12, ui.C_WHITE)
        ui.drawRounded(x, y, w, h, 12, isSelected and 3 or 2, ui.C_BLACK)
    end

    -- Focus halo
    if isSelected and not p.inverted then
        ui.drawRounded(x - 2, y - 2, w + 4, h + 4, 14, 1, ui.C_BLACK)
    end

    -- Card Header Bar
    local cardHeaderH = 34
    local pName = p.name or ("P" .. p.id)
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_10"), x + 12, y + 7, pName, fgCol)
    end

    -- Card Menu / Counter detail icon [···] top right
    local menuBtnX, menuBtnY, menuBtnW, menuBtnH = grid.getMenuButtonBounds(rect)

    -- Status Badges (Monarch / Initiative)
    local badgeX = x + ui.getTextWidth(ui.getFont("ui_10"), pName) + 18
    if state.monarch == p.id then
        local mw = ui.getTextWidth(ui.getFont("small"), "CROWN") + 12
        if badgeX + mw < menuBtnX - 4 then
            ui.fillRounded(badgeX, y + 6, mw, 20, 4, fgCol)
            if gfx and gfx.drawText then
                gfx.drawText(ui.getFont("small"), badgeX + 6, y + 8, "CROWN", bgCol)
            end
            badgeX = badgeX + mw + 6
        end
    end
    if state.initiative == p.id then
        local iw = ui.getTextWidth(ui.getFont("small"), "INIT") + 12
        if badgeX + iw < menuBtnX - 4 then
            ui.fillRounded(badgeX, y + 6, iw, 20, 4, fgCol)
            if gfx and gfx.drawText then
                gfx.drawText(ui.getFont("small"), badgeX + 6, y + 8, "INIT", bgCol)
            end
            badgeX = badgeX + iw + 6
        end
    end

    ui.drawRounded(menuBtnX, menuBtnY, menuBtnW, menuBtnH, 6, 1, fgCol)
    if gfx and gfx.drawText then
        local font = ui.getFont("ui_10")
        local tw = ui.getTextWidth(font, "...")
        local th = ui.getLineHeight(font)
        gfx.drawText(font, menuBtnX + math.floor((menuBtnW - tw) / 2), menuBtnY + math.floor((menuBtnH - th) / 2) - 1, "...", fgCol)
    end

    -- Header divider
    if gfx and gfx.drawLine then
        gfx.drawLine(x + 8, y + cardHeaderH, x + w - 8, y + cardHeaderH, 1, fgCol)
    end

    -- Life Digits
    local lifeCenterY = y + cardHeaderH + math.floor((h - cardHeaderH - 42) / 2)
    local lifeCenterX = x + math.floor(w / 2)
    local digitH = (h >= 240) and 58 or 46
    local digitW = math.floor(digitH * 0.55)
    local strokeW = (h >= 240) and 7 or 6
    ui.drawBigNumber(lifeCenterX, lifeCenterY, p.life, digitW, digitH, strokeW, fgCol)

    -- Floating Delta (+1, -5)
    local now = (crosspoint and crosspoint.millis and crosspoint.millis()) or 0
    if safeNum(p.delta, 0) ~= 0 and now < safeNum(p.deltaTimer, 0) then
        local deltaStr = (p.delta > 0 and "+" or "") .. p.delta
        local deltaW = ui.getTextWidth(ui.getFont("ui_10"), deltaStr)
        local deltaY = lifeCenterY - math.floor(digitH / 2) - 16
        if deltaY > y + cardHeaderH + 2 then
            ui.fillRounded(lifeCenterX - math.floor(deltaW / 2) - 6, deltaY, deltaW + 12, 18, 4, fgCol)
            if gfx and gfx.drawText then
                gfx.drawText(ui.getFont("ui_10"), lifeCenterX - math.floor(deltaW / 2), deltaY + 1, deltaStr, bgCol)
            end
        end
    end

    -- Large Touch Target Indicators (- on left, + on right)
    local btnSize = math.min(52, math.floor(h * 0.32))
    local minusX = x + 16
    local plusX = x + w - btnSize - 16
    local btnY = lifeCenterY - math.floor(btnSize / 2)

    ui.drawRounded(minusX, btnY, btnSize, btnSize, 10, 2, fgCol)
    if gfx and gfx.drawLine then
        gfx.drawLine(minusX + 12, lifeCenterY, minusX + btnSize - 12, lifeCenterY, 3, fgCol)
    end

    ui.drawRounded(plusX, btnY, btnSize, btnSize, 10, 2, fgCol)
    if gfx and gfx.drawLine then
        gfx.drawLine(plusX + 12, lifeCenterY, plusX + btnSize - 12, lifeCenterY, 3, fgCol)
        gfx.drawLine(plusX + math.floor(btnSize / 2), btnY + 12, plusX + math.floor(btnSize / 2), btnY + btnSize - 12, 3, fgCol)
    end

    -- Bottom Counters Strip (Poison, Commander, Tax, Energy)
    local stripH = 34
    local stripY = y + h - stripH - 4
    if gfx and gfx.drawLine then
        gfx.drawLine(x + 8, stripY, x + w - 8, stripY, 1, fgCol)
    end

    local cx = x + 12

    -- Poison Chip
    local pStr = "P: " .. safeNum(p.poison, 0)
    local pw = ui.getTextWidth(ui.getFont("small"), pStr) + 16
    if safeNum(p.poison, 0) > 0 then
        ui.fillRounded(cx, stripY + 5, pw, 22, 6, fgCol)
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("small"), cx + 8, stripY + 9, pStr, bgCol)
        end
    else
        ui.drawRounded(cx, stripY + 5, pw, 22, 6, 1, fgCol)
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("small"), cx + 8, stripY + 9, pStr, fgCol)
        end
    end
    cx = cx + pw + 8

    -- Commander Damage Chip
    local maxCmdr = 0
    for _, d in ipairs(p.cmdrDmg or {}) do
        local val = safeNum(d, 0)
        if val > maxCmdr then maxCmdr = val end
    end
    local cStr = "Cmdr: " .. maxCmdr
    local cw = ui.getTextWidth(ui.getFont("small"), cStr) + 16
    if maxCmdr >= 15 then
        ui.fillRounded(cx, stripY + 5, cw, 22, 6, fgCol)
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("small"), cx + 8, stripY + 9, cStr, bgCol)
        end
    else
        ui.drawRounded(cx, stripY + 5, cw, 22, 6, 1, fgCol)
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("small"), cx + 8, stripY + 9, cStr, fgCol)
        end
    end
    cx = cx + cw + 8

    -- Commander Tax Chip
    local taxVal = safeNum(p.tax, 0)
    if cx + 64 <= x + w - 40 then
        local tStr = "Tax: +" .. (taxVal * 2)
        local tw = ui.getTextWidth(ui.getFont("small"), tStr) + 14
        ui.drawRounded(cx, stripY + 5, tw, 22, 6, 1, fgCol)
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("small"), cx + 7, stripY + 9, tStr, fgCol)
        end
        cx = cx + tw + 8
    end

    -- Energy {E} Chip
    local energyVal = safeNum(p.energy, 0)
    if energyVal > 0 and cx + 44 <= x + w - 10 then
        local eStr = "E: " .. energyVal
        local ew = ui.getTextWidth(ui.getFont("small"), eStr) + 12
        ui.drawRounded(cx, stripY + 5, ew, 22, 6, 1, fgCol)
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("small"), cx + 6, stripY + 9, eStr, fgCol)
        end
    end

    -- Lethal / Defeated Banner
    local isDead, reason = stateEngine.isPlayerLethal(p)
    if isDead then
        local bannerH = 34
        local bannerY = y + math.floor((h - bannerH) / 2)
        if gfx and gfx.fillRect then
            gfx.fillRect(x + 4, bannerY, w - 8, bannerH, ui.C_BLACK)
        end
        if gfx and gfx.drawRect then
            gfx.drawRect(x + 4, bannerY, w - 8, bannerH, 2, ui.C_WHITE)
        end
        local deathText = "DEFEATED - " .. (reason or "LETHAL")
        local dw = ui.getTextWidth(ui.getFont("ui_10"), deathText)
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("ui_10"), x + math.floor((w - dw) / 2), bannerY + 7, deathText, ui.C_WHITE)
        end
    end
end

return grid
