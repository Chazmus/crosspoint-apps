-- ============================================================================
-- Spell Counter - MTG Life & Game Companion for CrossPoint Reader
-- Supports 1 to 4 players, Commander damage, Poison, Energy, Experience, Tax,
-- Storm, Dice rolling (D20, D6, Coin), Monarch / Initiative, Sleep screen,
-- and persistent game state.
-- ============================================================================

local json = nil

-- ---------------------------------------------------------------------------
-- Color constants & drawing wrappers
-- ---------------------------------------------------------------------------
local C_BLACK = true
local C_WHITE = false

local function fillRounded(x, y, w, h, r, isBlack)
    local col = (isBlack == false or isBlack == 3) and (gfx.COLOR_WHITE or 3) or (gfx.COLOR_BLACK or 0)
    gfx.fillRoundedRect(x, y, w, h, r, col)
end

local function drawRounded(x, y, w, h, r, lineWidth, isBlack)
    if type(lineWidth) == "boolean" then
        isBlack = lineWidth
        lineWidth = 1
    end
    local black = (isBlack ~= false and isBlack ~= 3)
    gfx.drawRoundedRect(x, y, w, h, r, lineWidth or 1, black)
end

local function drawButton(x, y, w, h, text, font, isBlack, isFilled)
    font = font or gfx.FONT_UI_10
    local textBlack
    if isFilled then
        textBlack = not isBlack
    else
        textBlack = isBlack
    end
    if isFilled then
        fillRounded(x, y, w, h, 8, isBlack)
    else
        drawRounded(x, y, w, h, 8, 2, isBlack)
    end
    local tw = gfx.getTextWidth(font, text)
    local th = gfx.getLineHeight(font)
    gfx.drawText(font, x + math.floor((w - tw) / 2), y + math.floor((h - th) / 2), text, textBlack)
end

-- ---------------------------------------------------------------------------
-- Game State
-- ---------------------------------------------------------------------------
local state = {
    playerCount = 2,         -- 1, 2, 3, or 4
    startingLife = 40,       -- 40 (Commander), 20 (Constructed), 30 (Brawl)
    players = {},
    monarch = nil,           -- Player index who has Monarch or nil
    initiative = nil,        -- Player index who has Initiative or nil
    dayNight = "none",       -- "none", "day", "night"
    history = {},            -- Recent event strings
    selectedPlayer = 1,      -- Currently selected player for hardware button focus
}

-- UI Navigation State
local ui = {
    modal = nil,             -- nil, "tools", "player_detail", "reset", "player_count"
    detailPlayer = 1,        -- Player index opened in detail modal
    toolsTab = "dice",       -- "dice", "tokens", "history"
    diceResult = nil,        -- { type = "D20", val = 20 }
    firstPlayerResult = nil, -- index
    linkCmdrDamage = true,   -- Auto-subtract life when taking commander damage
}

-- Preset player names
local PRESET_NAMES = {
    {"P1", "Mono White", "Aggro", "Commander 1"},
    {"P2", "Mono Blue",  "Control", "Commander 2"},
    {"P3", "Mono Black", "Midrange", "Commander 3"},
    {"P4", "Mono Red",   "Combo", "Commander 4"},
}

-- ---------------------------------------------------------------------------
-- Module Loading & Persistence
-- ---------------------------------------------------------------------------
local function initJson()
    if not json then
        local src = storage.readFile("json.lua")
        if src then
            local chunk = load(src)
            if chunk then json = chunk() end
        end
    end
end

local function addHistory(msg)
    table.insert(state.history, 1, msg)
    if #state.history > 30 then
        table.remove(state.history)
    end
end

local function createPlayer(idx, startLife)
    local presets = PRESET_NAMES[idx] or {"P" .. idx}
    return {
        id = idx,
        name = presets[1],
        nameIdx = 1,
        life = startLife or 40,
        delta = 0,
        deltaTimer = 0,
        poison = 0,
        energy = 0,
        experience = 0,
        tax = 0,             -- Commander tax casts
        storm = 0,
        cmdrDmg = {0, 0, 0, 0}, -- Damage taken from player 1..4 commanders
        inverted = false,    -- Dark card theme toggle
    }
end

local function initNewGame(startLife, count)
    state.playerCount = count or state.playerCount or 4
    state.startingLife = startLife or state.startingLife or 40
    state.players = {}
    for i = 1, 4 do
        table.insert(state.players, createPlayer(i, state.startingLife))
    end
    state.monarch = nil
    state.initiative = nil
    state.dayNight = "none"
    state.history = {}
    state.selectedPlayer = 1
    addHistory("Game started: " .. state.playerCount .. "P at " .. state.startingLife .. " life")
end

local function saveState()
    initJson()
    if not json then return end

    local data = {
        playerCount = state.playerCount,
        startingLife = state.startingLife,
        monarch = state.monarch,
        initiative = state.initiative,
        dayNight = state.dayNight,
        selectedPlayer = state.selectedPlayer,
        history = state.history,
        players = {},
    }
    for i = 1, 4 do
        local p = state.players[i]
        if p then
            table.insert(data.players, {
                id = p.id,
                name = p.name,
                nameIdx = p.nameIdx or 1,
                life = p.life,
                poison = p.poison,
                energy = p.energy,
                experience = p.experience,
                tax = p.tax,
                storm = p.storm,
                cmdrDmg = p.cmdrDmg,
                inverted = p.inverted,
            })
        end
    end

    local encoded = json.encode(data)
    storage.writeFile("gamestate.json", encoded)
    crosspoint.requestUpdate()
end

local function loadState()
    initJson()
    if not json then
        initNewGame(40, 4)
        return
    end

    local content = storage.readFile("gamestate.json")
    if not content or content == "" then
        initNewGame(40, 4)
        return
    end

    local data = json.decode(content)
    if not data or not data.players or #data.players == 0 then
        initNewGame(40, 4)
        return
    end

    state.playerCount = data.playerCount or 4
    state.startingLife = data.startingLife or 40
    state.monarch = data.monarch
    state.initiative = data.initiative
    state.dayNight = data.dayNight or "none"
    state.selectedPlayer = data.selectedPlayer or 1
    state.history = data.history or {}

    state.players = {}
    for i = 1, 4 do
        local sp = data.players[i]
        if sp then
            local p = createPlayer(i, state.startingLife)
            p.name = sp.name or ("P" .. i)
            p.nameIdx = sp.nameIdx or 1
            p.life = tonumber(sp.life) or state.startingLife
            p.poison = tonumber(sp.poison) or 0
            p.energy = tonumber(sp.energy) or 0
            p.experience = tonumber(sp.experience) or 0
            p.tax = tonumber(sp.tax) or 0
            p.storm = tonumber(sp.storm) or 0
            p.inverted = sp.inverted or false
            if type(sp.cmdrDmg) == "table" then
                p.cmdrDmg = {
                    tonumber(sp.cmdrDmg[1]) or 0,
                    tonumber(sp.cmdrDmg[2]) or 0,
                    tonumber(sp.cmdrDmg[3]) or 0,
                    tonumber(sp.cmdrDmg[4]) or 0,
                }
            end
            table.insert(state.players, p)
        else
            table.insert(state.players, createPlayer(i, state.startingLife))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Crisp Digit Rendering (Continuous bold strokes)
-- ---------------------------------------------------------------------------
local function drawSegment(x, y, w, h, s, segKey, isBlack)
    local halfH = math.floor((h - s) / 2)
    local r = 1
    if segKey == "t" then
        fillRounded(x + 1, y, w - 2, s, r, isBlack)
    elseif segKey == "tl" then
        fillRounded(x, y + 1, s, halfH, r, isBlack)
    elseif segKey == "tr" then
        fillRounded(x + w - s, y + 1, s, halfH, r, isBlack)
    elseif segKey == "m" then
        fillRounded(x + 1, y + halfH, w - 2, s, r, isBlack)
    elseif segKey == "bl" then
        fillRounded(x, y + halfH, s, halfH, r, isBlack)
    elseif segKey == "br" then
        fillRounded(x + w - s, y + halfH, s, halfH, r, isBlack)
    elseif segKey == "b" then
        fillRounded(x + 1, y + h - s, w - 2, s, r, isBlack)
    end
end

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

local function drawSingleDigit(x, y, w, h, s, ch, isBlack)
    if ch == "1" then
        local barW = s + 1
        local barX = x + math.floor((w - barW) / 2)
        fillRounded(barX, y, barW, h, 2, isBlack)
        fillRounded(barX - s + 1, y + 1, s, s, 1, isBlack)
        return
    end

    if ch == "-" then
        local halfH = math.floor((h - s) / 2)
        fillRounded(x + 2, y + halfH, w - 4, s, 1, isBlack)
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

local function drawBigNumber(cx, cy, num, digitW, digitH, strokeW, isBlack)
    local str = tostring(num)
    local spacing = math.max(4, math.floor(digitW * 0.22))
    local totalW = #str * digitW + (#str - 1) * spacing
    local startX = cx - math.floor(totalW / 2)
    local startY = cy - math.floor(digitH / 2)

    for i = 1, #str do
        local ch = str:sub(i, i)
        local curX = startX + (i - 1) * (digitW + spacing)
        drawSingleDigit(curX, startY, digitW, digitH, strokeW, ch, isBlack)
    end
end

-- ---------------------------------------------------------------------------
-- Life & Counter Mutation Helpers
-- ---------------------------------------------------------------------------
local function changeLife(playerIdx, amount)
    local p = state.players[playerIdx]
    if not p then return end
    p.life = p.life + amount
    p.delta = p.delta + amount
    p.deltaTimer = crosspoint.millis() + 2500
    local sign = amount >= 0 and "+" or ""
    addHistory(p.name .. " " .. sign .. amount .. " life (" .. p.life .. ")")
    saveState()
end

local function changePoison(playerIdx, amount)
    local p = state.players[playerIdx]
    if not p then return end
    p.poison = math.max(0, p.poison + amount)
    addHistory(p.name .. " poison: " .. p.poison)
    saveState()
end

local function changeCmdrDamage(playerIdx, opponentIdx, amount)
    local p = state.players[playerIdx]
    if not p then return end
    local oldDmg = p.cmdrDmg[opponentIdx] or 0
    local newDmg = math.max(0, oldDmg + amount)
    local diff = newDmg - oldDmg
    p.cmdrDmg[opponentIdx] = newDmg

    if ui.linkCmdrDamage and diff ~= 0 then
        p.life = p.life - diff
        p.delta = p.delta - diff
        p.deltaTimer = crosspoint.millis() + 2500
    end

    local oppName = (state.players[opponentIdx] and state.players[opponentIdx].name) or ("P" .. opponentIdx)
    addHistory(p.name .. " took " .. diff .. " Cmdr Dmg from " .. oppName .. " (Total: " .. newDmg .. ")")
    saveState()
end

local function isPlayerLethal(p)
    if p.life <= 0 then return true, "DEAD (0 LIFE)" end
    if p.poison >= 10 then return true, "POISONED (10)" end
    for oppIdx, dmg in ipairs(p.cmdrDmg or {}) do
        if dmg >= 21 then
            return true, "CMDR LETHAL (21)"
        end
    end
    return false, nil
end

-- ---------------------------------------------------------------------------
-- Layout Computation (Dynamic orientation & player count)
-- ---------------------------------------------------------------------------
local function getCardRects(w, h, count)
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

-- ---------------------------------------------------------------------------
-- UI Drawing: Player Card
-- ---------------------------------------------------------------------------
local function drawPlayerCard(p, rect, isSelected)
    local x, y, w, h = rect.x, rect.y, rect.w, rect.h
    local bgCol = p.inverted and C_BLACK or C_WHITE
    local fgCol = p.inverted and C_WHITE or C_BLACK

    -- Background
    if p.inverted then
        fillRounded(x, y, w, h, 12, C_BLACK)
        drawRounded(x, y, w, h, 12, 2, C_WHITE)
    else
        fillRounded(x, y, w, h, 12, C_WHITE)
        drawRounded(x, y, w, h, 12, isSelected and 3 or 2, C_BLACK)
    end

    -- Selection halo if active
    if isSelected and not p.inverted then
        drawRounded(x - 2, y - 2, w + 4, h + 4, 14, 1, C_BLACK)
    end

    -- Card Header Bar
    local cardHeaderH = 30
    local pName = p.name or ("P" .. p.id)
    gfx.drawText(gfx.FONT_UI_10, x + 12, y + 6, pName, fgCol)

    -- Status Badges (Monarch / Initiative)
    local badgeX = x + gfx.getTextWidth(gfx.FONT_UI_10, pName) + 20
    if state.monarch == p.id then
        local mw = gfx.getTextWidth(gfx.FONT_SMALL, "CROWN") + 12
        fillRounded(badgeX, y + 5, mw, 18, 4, fgCol)
        gfx.drawText(gfx.FONT_SMALL, badgeX + 6, y + 7, "CROWN", bgCol)
        badgeX = badgeX + mw + 6
    end
    if state.initiative == p.id then
        local iw = gfx.getTextWidth(gfx.FONT_SMALL, "INIT") + 12
        fillRounded(badgeX, y + 5, iw, 18, 4, fgCol)
        gfx.drawText(gfx.FONT_SMALL, badgeX + 6, y + 7, "INIT", bgCol)
        badgeX = badgeX + iw + 6
    end

    -- Card Menu / Counter detail icon [···] top right
    local menuBtnW = 44
    local menuBtnH = 24
    local menuBtnX = x + w - menuBtnW - 8
    local menuBtnY = y + 4
    drawRounded(menuBtnX, menuBtnY, menuBtnW, menuBtnH, 6, 1, fgCol)
    gfx.drawText(gfx.FONT_SMALL, menuBtnX + 11, menuBtnY + 4, "...", fgCol)

    -- Divider line under card header
    gfx.drawLine(x + 8, y + cardHeaderH, x + w - 8, y + cardHeaderH, 1, fgCol)

    -- Main Life Number & Touch Areas
    local lifeCenterY = y + cardHeaderH + math.floor((h - cardHeaderH - 42) / 2)
    local lifeCenterX = x + math.floor(w / 2)

    -- Giant Life Digits
    local digitH = (h >= 240) and 58 or 46
    local digitW = math.floor(digitH * 0.55)
    local strokeW = (h >= 240) and 7 or 6
    drawBigNumber(lifeCenterX, lifeCenterY, p.life, digitW, digitH, strokeW, fgCol)

    -- Floating Delta (e.g. -3 or +5)
    if p.delta ~= 0 and crosspoint.millis() < p.deltaTimer then
        local deltaStr = (p.delta > 0 and "+" or "") .. p.delta
        local deltaW = gfx.getTextWidth(gfx.FONT_UI_10, deltaStr)
        local deltaY = lifeCenterY - math.floor(digitH / 2) - 16
        if deltaY > y + cardHeaderH + 2 then
            fillRounded(lifeCenterX - math.floor(deltaW / 2) - 6, deltaY, deltaW + 12, 18, 4, fgCol)
            gfx.drawText(gfx.FONT_UI_10, lifeCenterX - math.floor(deltaW / 2), deltaY + 1, deltaStr, bgCol)
        end
    end

    -- Large Touch Target Indicators (- on left, + on right)
    local btnSize = math.min(46, math.floor(h * 0.28))
    local minusX = x + 14
    local plusX = x + w - btnSize - 14
    local btnY = lifeCenterY - math.floor(btnSize / 2)

    -- Minus button box
    drawRounded(minusX, btnY, btnSize, btnSize, 8, 2, fgCol)
    gfx.drawLine(minusX + 10, lifeCenterY, minusX + btnSize - 10, lifeCenterY, 3, fgCol)

    -- Plus button box
    drawRounded(plusX, btnY, btnSize, btnSize, 8, 2, fgCol)
    gfx.drawLine(plusX + 10, lifeCenterY, plusX + btnSize - 10, lifeCenterY, 3, fgCol)
    gfx.drawLine(plusX + math.floor(btnSize / 2), btnY + 10, plusX + math.floor(btnSize / 2), btnY + btnSize - 10, 3, fgCol)

    -- Quick +/- 5 pills
    if h >= 180 then
        local pillW = 38
        local pillH = 22
        local pillY = btnY + btnSize + 6
        if pillY + pillH <= y + h - 40 then
            -- -5 pill
            drawRounded(minusX + math.floor((btnSize - pillW) / 2), pillY, pillW, pillH, 6, 1, fgCol)
            gfx.drawText(gfx.FONT_SMALL, minusX + math.floor((btnSize - pillW) / 2) + 7, pillY + 4, "-5", fgCol)
            -- +5 pill
            drawRounded(plusX + math.floor((btnSize - pillW) / 2), pillY, pillW, pillH, 6, 1, fgCol)
            gfx.drawText(gfx.FONT_SMALL, plusX + math.floor((btnSize - pillW) / 2) + 5, pillY + 4, "+5", fgCol)
        end
    end

    -- Bottom Counters Strip (Poison, Commander Dmg, Tax)
    local stripH = 34
    local stripY = y + h - stripH - 4
    gfx.drawLine(x + 8, stripY, x + w - 8, stripY, 1, fgCol)

    local cx = x + 12
    -- Poison chip: P: <count>
    local pStr = "P: " .. p.poison
    local pw = gfx.getTextWidth(gfx.FONT_SMALL, pStr) + 16
    if p.poison > 0 then
        fillRounded(cx, stripY + 5, pw, 22, 6, fgCol)
        gfx.drawText(gfx.FONT_SMALL, cx + 8, stripY + 9, pStr, bgCol)
    else
        drawRounded(cx, stripY + 5, pw, 22, 6, 1, fgCol)
        gfx.drawText(gfx.FONT_SMALL, cx + 8, stripY + 9, pStr, fgCol)
    end
    cx = cx + pw + 8

    -- Commander Damage Chip
    local maxCmdr = 0
    for _, d in ipairs(p.cmdrDmg or {}) do
        if d > maxCmdr then maxCmdr = d end
    end
    local cStr = "Cmdr: " .. maxCmdr
    local cw = gfx.getTextWidth(gfx.FONT_SMALL, cStr) + 16
    if maxCmdr >= 15 then
        fillRounded(cx, stripY + 5, cw, 22, 6, fgCol)
        gfx.drawText(gfx.FONT_SMALL, cx + 8, stripY + 9, cStr, bgCol)
    else
        drawRounded(cx, stripY + 5, cw, 22, 6, 1, fgCol)
        gfx.drawText(gfx.FONT_SMALL, cx + 8, stripY + 9, cStr, fgCol)
    end
    cx = cx + cw + 8

    -- Commander Tax Chip
    if cx + 64 <= x + w - 40 then
        local tStr = "Tax: +" .. (p.tax * 2)
        local tw = gfx.getTextWidth(gfx.FONT_SMALL, tStr) + 14
        drawRounded(cx, stripY + 5, tw, 22, 6, 1, fgCol)
        gfx.drawText(gfx.FONT_SMALL, cx + 7, stripY + 9, tStr, fgCol)
        cx = cx + tw + 8
    end

    -- Energy {E} Chip if > 0
    if p.energy > 0 and cx + 44 <= x + w - 10 then
        local eStr = "E: " .. p.energy
        local ew = gfx.getTextWidth(gfx.FONT_SMALL, eStr) + 12
        drawRounded(cx, stripY + 5, ew, 22, 6, 1, fgCol)
        gfx.drawText(gfx.FONT_SMALL, cx + 6, stripY + 9, eStr, fgCol)
    end

    -- Lethal / Defeated Banner
    local isDead, reason = isPlayerLethal(p)
    if isDead then
        local bannerH = 34
        local bannerY = y + math.floor((h - bannerH) / 2)
        gfx.fillRect(x + 4, bannerY, w - 8, bannerH, C_BLACK)
        gfx.drawRect(x + 4, bannerY, w - 8, bannerH, 2, C_WHITE)
        local deathText = "DEFEATED - " .. reason
        local dw = gfx.getTextWidth(gfx.FONT_UI_10, deathText)
        gfx.drawText(gfx.FONT_UI_10, x + math.floor((w - dw) / 2), bannerY + 7, deathText, C_WHITE)
    end
end

-- ---------------------------------------------------------------------------
-- UI Drawing: Top Navigation Bar
-- ---------------------------------------------------------------------------
local function drawTopBar(w, headerH)
    gfx.fillRect(0, 0, w, headerH, C_BLACK)

    -- Left: Player Count selector button [4 Players]
    local pcText = state.playerCount .. " Player" .. (state.playerCount > 1 and "s" or "")
    local pcW = gfx.getTextWidth(gfx.FONT_UI_10, pcText) + 16
    drawRounded(10, 5, pcW, headerH - 10, 6, 1, C_WHITE)
    gfx.drawText(gfx.FONT_UI_10, 18, 9, pcText, C_WHITE)

    -- Center: App Title / Token Summary
    local title = "SPELL COUNTER"
    if state.dayNight == "day" then
        title = "SPELL COUNTER [DAY]"
    elseif state.dayNight == "night" then
        title = "SPELL COUNTER [NIGHT]"
    end
    local tw = gfx.getTextWidth(gfx.FONT_UI_10, title)
    gfx.drawText(gfx.FONT_UI_10, math.floor((w - tw) / 2), 9, title, C_WHITE)

    -- Right Buttons: [Reset] & [Tools]
    local rightX = w - 10

    -- [Tools] button
    local toolsText = "Tools"
    local toolsW = gfx.getTextWidth(gfx.FONT_UI_10, toolsText) + 16
    rightX = rightX - toolsW
    drawRounded(rightX, 5, toolsW, headerH - 10, 6, 1, C_WHITE)
    gfx.drawText(gfx.FONT_UI_10, rightX + 8, 9, toolsText, C_WHITE)

    -- [Reset] button
    rightX = rightX - 8
    local resetText = "Reset"
    local resetW = gfx.getTextWidth(gfx.FONT_UI_10, resetText) + 16
    rightX = rightX - resetW
    drawRounded(rightX, 5, resetW, headerH - 10, 6, 1, C_WHITE)
    gfx.drawText(gfx.FONT_UI_10, rightX + 8, 9, resetText, C_WHITE)
end

-- ---------------------------------------------------------------------------
-- UI Drawing: Modals
-- ---------------------------------------------------------------------------

-- 1. Tools Modal (Dice, Tokens, History)
local function drawToolsModal(w, h)
    local mw = math.min(640, w - 40)
    local mh = math.min(410, h - 30)
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    fillRounded(mx, my, mw, mh, 16, C_WHITE)
    drawRounded(mx, my, mw, mh, 16, 3, C_BLACK)

    -- Header
    gfx.fillRect(mx + 3, my + 3, mw - 6, 38, C_BLACK)
    gfx.drawText(gfx.FONT_UI_10, mx + 16, my + 11, "GAME TOOLS & UTILITIES", C_WHITE)

    -- Close [X] button
    local closeX = mx + mw - 46
    drawRounded(closeX, my + 7, 36, 28, 6, 1, C_WHITE)
    gfx.drawText(gfx.FONT_UI_10, closeX + 12, my + 11, "X", C_WHITE)

    -- Tabs: [Dice & Coin] | [Tokens & Status] | [Game Log]
    local tabY = my + 48
    local tabW = math.floor((mw - 40) / 3)

    -- Tab 1: Dice
    drawButton(mx + 16, tabY, tabW, 30, "Dice & Coin", gfx.FONT_SMALL, C_BLACK, ui.toolsTab == "dice")

    -- Tab 2: Tokens
    local t2X = mx + 20 + tabW
    drawButton(t2X, tabY, tabW, 30, "Tokens & Status", gfx.FONT_SMALL, C_BLACK, ui.toolsTab == "tokens")

    -- Tab 3: History Log
    local t3X = mx + 24 + tabW * 2
    drawButton(t3X, tabY, tabW, 30, "Game Log", gfx.FONT_SMALL, C_BLACK, ui.toolsTab == "history")

    local contentY = tabY + 42

    -- Tab Content 1: Dice & Coin
    if ui.toolsTab == "dice" then
        local btnW = 126
        local btnH = 38
        local bx = mx + 24

        drawButton(bx, contentY, btnW, btnH, "Roll D20", gfx.FONT_UI_10, C_BLACK, false)
        bx = bx + btnW + 16
        drawButton(bx, contentY, btnW, btnH, "Roll D6", gfx.FONT_UI_10, C_BLACK, false)
        bx = bx + btnW + 16
        drawButton(bx, contentY, btnW, btnH, "Flip Coin", gfx.FONT_UI_10, C_BLACK, false)
        bx = bx + btnW + 16
        if bx + btnW <= mx + mw - 16 then
            drawButton(bx, contentY, btnW, btnH, "Who 1st?", gfx.FONT_UI_10, C_BLACK, false)
        end

        -- Big Dice Result Display Box
        local resBoxY = contentY + btnH + 18
        local resBoxW = mw - 48
        local resBoxH = mh - (resBoxY - my) - 18
        drawRounded(mx + 24, resBoxY, resBoxW, resBoxH, 12, 2, C_BLACK)

        if ui.diceResult then
            local header = ui.diceResult.type .. " RESULT:"
            local hw = gfx.getTextWidth(gfx.FONT_SMALL, header)
            gfx.drawText(gfx.FONT_SMALL, mx + 24 + math.floor((resBoxW - hw) / 2), resBoxY + 16, header, C_BLACK)

            local resStr = tostring(ui.diceResult.val)
            local rw = gfx.getTextWidth(gfx.FONT_UI_12, resStr)
            gfx.drawText(gfx.FONT_UI_12, mx + 24 + math.floor((resBoxW - rw) / 2), resBoxY + 48, resStr, C_BLACK)
        elseif ui.firstPlayerResult then
            local fpName = state.players[ui.firstPlayerResult] and state.players[ui.firstPlayerResult].name or ("Player " .. ui.firstPlayerResult)
            local header = "RANDOM STARTING PLAYER:"
            local hw = gfx.getTextWidth(gfx.FONT_UI_10, header)
            gfx.drawText(gfx.FONT_UI_10, mx + 24 + math.floor((resBoxW - hw) / 2), resBoxY + 24, header, C_BLACK)

            local resText = "-> " .. fpName .. " GOES FIRST! <-"
            local rw = gfx.getTextWidth(gfx.FONT_UI_12, resText)
            gfx.drawText(gfx.FONT_UI_12, mx + 24 + math.floor((resBoxW - rw) / 2), resBoxY + 54, resText, C_BLACK)
        else
            local hint = "Tap a button above to roll dice or pick first player"
            local hw = gfx.getTextWidth(gfx.FONT_SMALL, hint)
            gfx.drawText(gfx.FONT_SMALL, mx + 24 + math.floor((resBoxW - hw) / 2), resBoxY + math.floor(resBoxH / 2) - 8, hint, C_BLACK)
        end

    -- Tab Content 2: Tokens & Status (Monarch, Initiative, Day/Night)
    elseif ui.toolsTab == "tokens" then
        local rowY = contentY + 4

        -- 1. Monarch Row
        gfx.drawText(gfx.FONT_UI_10, mx + 24, rowY + 6, "The Monarch:", C_BLACK)
        local btnX = mx + 160
        for i = 1, state.playerCount do
            local pName = "P" .. i
            drawButton(btnX, rowY, 52, 32, pName, gfx.FONT_SMALL, C_BLACK, state.monarch == i)
            btnX = btnX + 60
        end
        drawButton(btnX, rowY, 68, 32, "Clear", gfx.FONT_SMALL, C_BLACK, false)

        -- 2. Initiative Row
        rowY = rowY + 48
        gfx.drawText(gfx.FONT_UI_10, mx + 24, rowY + 6, "Initiative:", C_BLACK)
        btnX = mx + 160
        for i = 1, state.playerCount do
            local pName = "P" .. i
            drawButton(btnX, rowY, 52, 32, pName, gfx.FONT_SMALL, C_BLACK, state.initiative == i)
            btnX = btnX + 60
        end
        drawButton(btnX, rowY, 68, 32, "Clear", gfx.FONT_SMALL, C_BLACK, false)

        -- 3. Day / Night Tracker
        rowY = rowY + 48
        gfx.drawText(gfx.FONT_UI_10, mx + 24, rowY + 6, "Day / Night:", C_BLACK)
        btnX = mx + 160
        local modes = {{"none", "Off"}, {"day", "Day"}, {"night", "Night"}}
        for _, m in ipairs(modes) do
            drawButton(btnX, rowY, 74, 32, m[2], gfx.FONT_SMALL, C_BLACK, state.dayNight == m[1])
            btnX = btnX + 82
        end

    -- Tab Content 3: Game History Log
    elseif ui.toolsTab == "history" then
        local logBoxY = contentY
        local logBoxH = mh - (logBoxY - my) - 20
        drawRounded(mx + 20, logBoxY, mw - 40, logBoxH, 10, 1, C_BLACK)

        local lineY = logBoxY + 8
        local maxLines = math.floor((logBoxH - 16) / 20)
        for i = 1, math.min(#state.history, maxLines) do
            local item = state.history[i]
            gfx.drawText(gfx.FONT_SMALL, mx + 32, lineY, item, C_BLACK)
            lineY = lineY + 20
        end
        if #state.history == 0 then
            local emptyMsg = "No events recorded yet."
            local ew = gfx.getTextWidth(gfx.FONT_SMALL, emptyMsg)
            gfx.drawText(gfx.FONT_SMALL, mx + 20 + math.floor((mw - 40 - ew) / 2), logBoxY + 30, emptyMsg, C_BLACK)
        end
    end
end

-- 2. Player Detail / Counters Drawer Modal
local function drawPlayerDetailModal(w, h)
    local p = state.players[ui.detailPlayer]
    if not p then return end

    local mw = math.min(680, w - 30)
    local mh = math.min(430, h - 20)
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    fillRounded(mx, my, mw, mh, 16, C_WHITE)
    drawRounded(mx, my, mw, mh, 16, 3, C_BLACK)

    -- Header with Player Name & Close
    gfx.fillRect(mx + 3, my + 3, mw - 6, 42, C_BLACK)
    gfx.drawText(gfx.FONT_UI_12, mx + 16, my + 10, (p.name or ("Player " .. p.id)) .. " - COUNTERS & DETAILS", C_WHITE)

    -- Name Cycle button [Cycle Name]
    local nameBtnW = 110
    local nameBtnX = mx + mw - nameBtnW - 56
    drawButton(nameBtnX, my + 7, nameBtnW, 28, "Cycle Name", gfx.FONT_SMALL, C_WHITE, false)

    -- Close [X] button
    local closeX = mx + mw - 46
    drawButton(closeX, my + 7, 36, 28, "X", gfx.FONT_UI_10, C_WHITE, false)

    local rowY = my + 54

    -- Row 1: Life Controls
    gfx.drawText(gfx.FONT_UI_10, mx + 20, rowY + 6, "Life Total: " .. p.life, C_BLACK)
    local btnX = mx + 200
    local lifeDeltas = {-10, -5, -1, 1, 5, 10}
    for _, delta in ipairs(lifeDeltas) do
        local dStr = (delta > 0 and "+" or "") .. delta
        drawButton(btnX, rowY, 44, 32, dStr, gfx.FONT_SMALL, C_BLACK, false)
        btnX = btnX + 50
    end

    -- Row 2: Poison Counters
    rowY = rowY + 44
    local poisStr = "Poison Counters: " .. p.poison .. (p.poison >= 10 and " [LETHAL!]" or "")
    gfx.drawText(gfx.FONT_UI_10, mx + 20, rowY + 6, poisStr, C_BLACK)
    btnX = mx + 200
    drawButton(btnX, rowY, 44, 32, "-", gfx.FONT_UI_10, C_BLACK, false)
    drawButton(btnX + 50, rowY, 44, 32, "+", gfx.FONT_UI_10, C_BLACK, false)

    -- Row 3: Commander Damage Received
    rowY = rowY + 44
    gfx.drawText(gfx.FONT_UI_10, mx + 20, rowY + 6, "Commander Damage:", C_BLACK)
    btnX = mx + 200
    for opp = 1, state.playerCount do
        if opp ~= p.id then
            local dmg = p.cmdrDmg[opp] or 0
            local oppName = "P" .. opp
            local cw = 94
            local isLethal = (dmg >= 21)
            if isLethal then
                fillRounded(btnX, rowY - 2, cw, 34, 6, C_BLACK)
                local valText = oppName .. ":" .. dmg
                local vw = gfx.getTextWidth(gfx.FONT_SMALL, valText)
                gfx.drawText(gfx.FONT_SMALL, btnX + math.floor((cw - vw) / 2), rowY + 6, valText, C_WHITE)
                drawButton(btnX + 3, rowY + 2, 24, 26, "-", gfx.FONT_SMALL, C_WHITE, false)
                drawButton(btnX + cw - 27, rowY + 2, 24, 26, "+", gfx.FONT_SMALL, C_WHITE, false)
            else
                drawRounded(btnX, rowY - 2, cw, 34, 6, 1, C_BLACK)
                local valText = oppName .. ":" .. dmg
                local vw = gfx.getTextWidth(gfx.FONT_SMALL, valText)
                gfx.drawText(gfx.FONT_SMALL, btnX + math.floor((cw - vw) / 2), rowY + 6, valText, C_BLACK)
                drawButton(btnX + 3, rowY + 2, 24, 26, "-", gfx.FONT_SMALL, C_BLACK, false)
                drawButton(btnX + cw - 27, rowY + 2, 24, 26, "+", gfx.FONT_SMALL, C_BLACK, false)
            end
            btnX = btnX + cw + 10
        end
    end

    -- Row 4: Commander Tax, Energy, Experience
    rowY = rowY + 44
    -- Tax
    local taxLabel = "Tax: " .. p.tax .. " (+" .. (p.tax * 2) .. ")"
    gfx.drawText(gfx.FONT_SMALL, mx + 20, rowY + 6, taxLabel, C_BLACK)
    drawButton(mx + 130, rowY, 32, 28, "-", gfx.FONT_SMALL, C_BLACK, false)
    drawButton(mx + 168, rowY, 32, 28, "+", gfx.FONT_SMALL, C_BLACK, false)

    -- Energy
    local energyLabel = "Energy: " .. p.energy
    gfx.drawText(gfx.FONT_SMALL, mx + 224, rowY + 6, energyLabel, C_BLACK)
    drawButton(mx + 314, rowY, 32, 28, "-", gfx.FONT_SMALL, C_BLACK, false)
    drawButton(mx + 352, rowY, 32, 28, "+", gfx.FONT_SMALL, C_BLACK, false)

    -- Experience
    local xpLabel = "XP: " .. p.experience
    gfx.drawText(gfx.FONT_SMALL, mx + 408, rowY + 6, xpLabel, C_BLACK)
    drawButton(mx + 478, rowY, 32, 28, "-", gfx.FONT_SMALL, C_BLACK, false)
    drawButton(mx + 516, rowY, 32, 28, "+", gfx.FONT_SMALL, C_BLACK, false)

    -- Row 5: Storm count, Invert Theme, Link Checkbox
    rowY = rowY + 42
    local stormLabel = "Storm Count: " .. p.storm
    gfx.drawText(gfx.FONT_SMALL, mx + 20, rowY + 6, stormLabel, C_BLACK)
    drawButton(mx + 130, rowY, 32, 28, "-", gfx.FONT_SMALL, C_BLACK, false)
    drawButton(mx + 168, rowY, 32, 28, "+", gfx.FONT_SMALL, C_BLACK, false)

    -- Reset Storm
    drawButton(mx + 206, rowY, 84, 28, "Reset Storm", gfx.FONT_SMALL, C_BLACK, false)

    -- Invert Card Color Toggle
    local invText = p.inverted and "Card: Dark (Invert)" or "Card: Light (Normal)"
    drawButton(mx + 304, rowY, 160, 28, invText, gfx.FONT_SMALL, C_BLACK, false)

    -- Auto-link Cmdr Damage to Life Checkbox
    local linkText = ui.linkCmdrDamage and "[X] Cmdr Dmg reduces life" or "[ ] Cmdr Dmg reduces life"
    gfx.drawText(gfx.FONT_SMALL, mx + 476, rowY + 6, linkText, C_BLACK)
end

-- 3. Reset Game Confirmation Modal
local function drawResetModal(w, h)
    local mw = 440
    local mh = 280
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    fillRounded(mx, my, mw, mh, 16, C_WHITE)
    drawRounded(mx, my, mw, mh, 16, 3, C_BLACK)

    -- Title
    gfx.fillRect(mx + 3, my + 3, mw - 6, 38, C_BLACK)
    local title = "RESET GAME"
    local tw = gfx.getTextWidth(gfx.FONT_UI_10, title)
    gfx.drawText(gfx.FONT_UI_10, mx + math.floor((mw - tw) / 2), my + 11, title, C_WHITE)

    local cy = my + 54
    local subtitle = "Select starting life total for all players:"
    local sw = gfx.getTextWidth(gfx.FONT_SMALL, subtitle)
    gfx.drawText(gfx.FONT_SMALL, mx + math.floor((mw - sw) / 2), cy, subtitle, C_BLACK)

    -- Reset Options
    cy = cy + 28
    local btnW = 340
    local btnH = 40
    local bx = mx + math.floor((mw - btnW) / 2)

    drawButton(bx, cy, btnW, btnH, "40 Life - Commander / EDH", gfx.FONT_UI_10, C_BLACK, false)
    cy = cy + 48
    drawButton(bx, cy, btnW, btnH, "20 Life - Standard / Modern", gfx.FONT_UI_10, C_BLACK, false)
    cy = cy + 48
    drawButton(bx, cy, btnW, btnH, "30 Life - Brawl / 2HG", gfx.FONT_UI_10, C_BLACK, false)
    cy = cy + 48
    drawButton(bx, cy, btnW, 34, "Cancel", gfx.FONT_SMALL, C_BLACK, false)
end

-- 4. Player Count Selector Modal
local function drawPlayerCountModal(w, h)
    local mw = 360
    local mh = 260
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    fillRounded(mx, my, mw, mh, 16, C_WHITE)
    drawRounded(mx, my, mw, mh, 16, 3, C_BLACK)

    gfx.fillRect(mx + 3, my + 3, mw - 6, 38, C_BLACK)
    local title = "SELECT PLAYERS"
    local tw = gfx.getTextWidth(gfx.FONT_UI_10, title)
    gfx.drawText(gfx.FONT_UI_10, mx + math.floor((mw - tw) / 2), my + 11, title, C_WHITE)

    local cy = my + 54
    local btnW = 280
    local btnH = 38
    local bx = mx + math.floor((mw - btnW) / 2)

    for c = 1, 4 do
        local label = c .. " Player" .. (c > 1 and "s" or "")
        if state.playerCount == c then
            drawButton(bx, cy, btnW, btnH, label .. " (Active)", gfx.FONT_UI_10, C_BLACK, true)
        else
            drawButton(bx, cy, btnW, btnH, label, gfx.FONT_UI_10, C_BLACK, false)
        end
        cy = cy + 44
    end

    drawButton(bx, cy, btnW, 30, "Close", gfx.FONT_SMALL, C_BLACK, false)
end

-- ---------------------------------------------------------------------------
-- Lifecycle Callback: onDraw()
-- ---------------------------------------------------------------------------
function onDraw()
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    -- Clear screen (1 = White)
    gfx.clearScreen(1)

    -- Calculate layouts
    local rects, headerH = getCardRects(w, h, state.playerCount)

    -- Draw player cards
    for i = 1, state.playerCount do
        local isSel = (state.selectedPlayer == i)
        drawPlayerCard(state.players[i], rects[i], isSel)
    end

    -- Top Navigation Bar
    drawTopBar(w, headerH)

    -- Active Modals
    if ui.modal == "tools" then
        drawToolsModal(w, h)
    elseif ui.modal == "player_detail" then
        drawPlayerDetailModal(w, h)
    elseif ui.modal == "reset" then
        drawResetModal(w, h)
    elseif ui.modal == "player_count" then
        drawPlayerCountModal(w, h)
    end
end

-- ---------------------------------------------------------------------------
-- Lifecycle Callback: onSleepDraw() - E-Ink Persistent Lockscreen
-- ---------------------------------------------------------------------------
function onSleepDraw()
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    gfx.clearScreen(1)

    -- Header Banner
    gfx.fillRect(0, 0, w, 44, C_BLACK)
    local headerText = "SPELL COUNTER - GAME PAUSED"
    local hw = gfx.getTextWidth(gfx.FONT_UI_12, headerText)
    gfx.drawText(gfx.FONT_UI_12, math.floor((w - hw) / 2), 8, headerText, C_WHITE)

    -- Subtitle
    local subText = "Match state preserved on E-Ink display | Press power button to resume"
    local sw = gfx.getTextWidth(gfx.FONT_SMALL, subText)
    gfx.drawText(gfx.FONT_SMALL, math.floor((w - sw) / 2), 50, subText, C_BLACK)

    -- Player cards summary in 2x2 or grid
    local count = state.playerCount
    local availY = 74
    local availH = h - availY - 30

    local colW = math.floor((w - 24) / (count >= 2 and 2 or 1))
    local rowH = math.floor((availH - 16) / (count >= 3 and 2 or 1))

    for i = 1, count do
        local p = state.players[i]
        local cCol = ((i - 1) % 2)
        local cRow = math.floor((i - 1) / 2)
        local px = 8 + cCol * (colW + 8)
        local py = availY + cRow * (rowH + 8)

        drawRounded(px, py, colW, rowH, 12, 2, C_BLACK)

        -- Header
        local pName = (p and p.name) or ("Player " .. i)
        if state.monarch == i then pName = pName .. " [CROWN]" end
        if state.initiative == i then pName = pName .. " [INIT]" end
        gfx.drawText(gfx.FONT_UI_10, px + 12, py + 8, pName, C_BLACK)

        -- Big Life Number
        local lifeY = py + math.floor(rowH / 2)
        local lifeX = px + math.floor(colW / 2)
        local digitH = math.min(52, rowH - 46)
        local digitW = math.floor(digitH * 0.55)
        local strokeW = 6
        drawBigNumber(lifeX, lifeY, p.life, digitW, digitH, strokeW, C_BLACK)

        -- Bottom stats
        local statStr = "Poison: " .. p.poison
        local maxCmdr = 0
        for _, d in ipairs(p.cmdrDmg or {}) do
            if d > maxCmdr then maxCmdr = d end
        end
        if maxCmdr > 0 then statStr = statStr .. "  |  Cmdr: " .. maxCmdr end
        if p.tax > 0 then statStr = statStr .. "  |  Tax: +" .. (p.tax * 2) end
        gfx.drawText(gfx.FONT_SMALL, px + 12, py + rowH - 22, statStr, C_BLACK)
    end

    -- Bottom footer
    local footText = "CrossPoint Reader Ecosystem"
    local fw = gfx.getTextWidth(gfx.FONT_SMALL, footText)
    gfx.drawText(gfx.FONT_SMALL, math.floor((w - fw) / 2), h - 22, footText, C_BLACK)
end

-- ---------------------------------------------------------------------------
-- Lifecycle Callback: onTouch(x, y)
-- ---------------------------------------------------------------------------
function onTouch(x, y)
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    -- -----------------------------------------------------------------------
    -- 1. Handle Active Modals
    -- -----------------------------------------------------------------------
    if ui.modal == "tools" then
        local mw = math.min(640, w - 40)
        local mh = math.min(410, h - 30)
        local mx = math.floor((w - mw) / 2)
        local my = math.floor((h - mh) / 2)

        -- Close button [X]
        local closeX = mx + mw - 46
        if x >= closeX and x <= closeX + 36 and y >= my + 7 and y <= my + 35 then
            ui.modal = nil
            crosspoint.requestUpdate()
            return
        end

        -- Tab switches
        local tabY = my + 48
        local tabW = math.floor((mw - 40) / 3)
        if y >= tabY and y <= tabY + 30 then
            if x >= mx + 16 and x <= mx + 16 + tabW then
                ui.toolsTab = "dice"
            elseif x >= mx + 20 + tabW and x <= mx + 20 + tabW * 2 then
                ui.toolsTab = "tokens"
            elseif x >= mx + 24 + tabW * 2 and x <= mx + 24 + tabW * 3 then
                ui.toolsTab = "history"
            end
            crosspoint.requestUpdate()
            return
        end

        -- Tab 1 Action clicks: Dice
        local contentY = tabY + 42
        if ui.toolsTab == "dice" and y >= contentY and y <= contentY + 38 then
            local btnW = 126
            local bx = mx + 24
            -- Roll D20
            if x >= bx and x <= bx + btnW then
                math.randomseed(crosspoint.millis())
                local roll = math.random(1, 20)
                ui.diceResult = {type = "D20", val = roll}
                ui.firstPlayerResult = nil
                addHistory("D20 roll: " .. roll)
                saveState()
                return
            end
            -- Roll D6
            bx = bx + btnW + 16
            if x >= bx and x <= bx + btnW then
                math.randomseed(crosspoint.millis())
                local roll = math.random(1, 6)
                ui.diceResult = {type = "D6", val = roll}
                ui.firstPlayerResult = nil
                addHistory("D6 roll: " .. roll)
                saveState()
                return
            end
            -- Flip Coin
            bx = bx + btnW + 16
            if x >= bx and x <= bx + btnW then
                math.randomseed(crosspoint.millis())
                local flip = math.random(1, 2) == 1 and "HEADS" or "TAILS"
                ui.diceResult = {type = "COIN", val = flip}
                ui.firstPlayerResult = nil
                addHistory("Coin flip: " .. flip)
                saveState()
                return
            end
            -- Who Goes First?
            bx = bx + btnW + 16
            if x >= bx and x <= bx + btnW then
                math.randomseed(crosspoint.millis())
                local fp = math.random(1, state.playerCount)
                ui.firstPlayerResult = fp
                ui.diceResult = nil
                local pName = state.players[fp] and state.players[fp].name or ("P" .. fp)
                addHistory("First player: " .. pName)
                saveState()
                return
            end
        end

        -- Tab 2 Action clicks: Tokens (Monarch, Initiative, Day/Night)
        if ui.toolsTab == "tokens" then
            local rowY = contentY + 4
            -- Monarch row
            if y >= rowY and y <= rowY + 32 then
                local btnX = mx + 160
                for i = 1, state.playerCount do
                    if x >= btnX and x <= btnX + 52 then
                        state.monarch = (state.monarch == i) and nil or i
                        local pName = state.players[i] and state.players[i].name or ("P" .. i)
                        addHistory("Monarch: " .. (state.monarch and pName or "None"))
                        saveState()
                        return
                    end
                    btnX = btnX + 60
                end
                -- Clear Monarch
                if x >= btnX and x <= btnX + 68 then
                    state.monarch = nil
                    addHistory("Monarch cleared")
                    saveState()
                    return
                end
            end

            -- Initiative row
            rowY = rowY + 48
            if y >= rowY and y <= rowY + 32 then
                local btnX = mx + 160
                for i = 1, state.playerCount do
                    if x >= btnX and x <= btnX + 52 then
                        state.initiative = (state.initiative == i) and nil or i
                        local pName = state.players[i] and state.players[i].name or ("P" .. i)
                        addHistory("Initiative: " .. (state.initiative and pName or "None"))
                        saveState()
                        return
                    end
                    btnX = btnX + 60
                end
                -- Clear Initiative
                if x >= btnX and x <= btnX + 68 then
                    state.initiative = nil
                    addHistory("Initiative cleared")
                    saveState()
                    return
                end
            end

            -- Day / Night row
            rowY = rowY + 48
            if y >= rowY and y <= rowY + 32 then
                local btnX = mx + 160
                local modes = {"none", "day", "night"}
                for _, m in ipairs(modes) do
                    if x >= btnX and x <= btnX + 74 then
                        state.dayNight = m
                        addHistory("Day/Night set to: " .. m)
                        saveState()
                        return
                    end
                    btnX = btnX + 82
                end
            end
        end

        -- Tap outside modal to dismiss
        if x < mx or x > mx + mw or y < my or y > my + mh then
            ui.modal = nil
            crosspoint.requestUpdate()
            return
        end
        return
    end

    if ui.modal == "player_detail" then
        local p = state.players[ui.detailPlayer]
        if not p then ui.modal = nil return end

        local mw = math.min(680, w - 30)
        local mh = math.min(430, h - 20)
        local mx = math.floor((w - mw) / 2)
        local my = math.floor((h - mh) / 2)

        -- Close [X]
        local closeX = mx + mw - 46
        if x >= closeX and x <= closeX + 36 and y >= my + 7 and y <= my + 35 then
            ui.modal = nil
            crosspoint.requestUpdate()
            return
        end

        -- Cycle Name button
        local nameBtnW = 110
        local nameBtnX = mx + mw - nameBtnW - 56
        if x >= nameBtnX and x <= nameBtnX + nameBtnW and y >= my + 7 and y <= my + 35 then
            local list = PRESET_NAMES[p.id] or {"Player " .. p.id}
            p.nameIdx = ((p.nameIdx or 1) % #list) + 1
            p.name = list[p.nameIdx]
            saveState()
            return
        end

        local rowY = my + 54

        -- Row 1: Life +/- buttons
        if y >= rowY and y <= rowY + 32 then
            local btnX = mx + 200
            local lifeDeltas = {-10, -5, -1, 1, 5, 10}
            for _, delta in ipairs(lifeDeltas) do
                if x >= btnX and x <= btnX + 44 then
                    changeLife(p.id, delta)
                    return
                end
                btnX = btnX + 50
            end
        end

        -- Row 2: Poison +/-
        rowY = rowY + 44
        if y >= rowY and y <= rowY + 32 then
            local btnX = mx + 200
            if x >= btnX and x <= btnX + 44 then
                changePoison(p.id, -1)
                return
            elseif x >= btnX + 50 and x <= btnX + 94 then
                changePoison(p.id, 1)
                return
            end
        end

        -- Row 3: Commander Damage from each opponent
        rowY = rowY + 44
        if y >= rowY - 2 and y <= rowY + 32 then
            local btnX = mx + 200
            for opp = 1, state.playerCount do
                if opp ~= p.id then
                    local cw = 94
                    if x >= btnX and x <= btnX + cw then
                        if x <= btnX + 30 then
                            changeCmdrDamage(p.id, opp, -1)
                        elseif x >= btnX + cw - 30 then
                            changeCmdrDamage(p.id, opp, 1)
                        end
                        return
                    end
                    btnX = btnX + cw + 10
                end
            end
        end

        -- Row 4: Commander Tax, Energy, Experience
        rowY = rowY + 44
        if y >= rowY and y <= rowY + 28 then
            -- Tax -
            if x >= mx + 130 and x <= mx + 162 then
                p.tax = math.max(0, p.tax - 1)
                saveState()
                return
            -- Tax +
            elseif x >= mx + 168 and x <= mx + 200 then
                p.tax = p.tax + 1
                saveState()
                return
            -- Energy -
            elseif x >= mx + 314 and x <= mx + 346 then
                p.energy = math.max(0, p.energy - 1)
                saveState()
                return
            -- Energy +
            elseif x >= mx + 352 and x <= mx + 384 then
                p.energy = p.energy + 1
                saveState()
                return
            -- XP -
            elseif x >= mx + 478 and x <= mx + 510 then
                p.experience = math.max(0, p.experience - 1)
                saveState()
                return
            -- XP +
            elseif x >= mx + 516 and x <= mx + 548 then
                p.experience = p.experience + 1
                saveState()
                return
            end
        end

        -- Row 5: Storm count, Invert Theme, Link Checkbox
        rowY = rowY + 42
        if y >= rowY and y <= rowY + 28 then
            -- Storm -
            if x >= mx + 130 and x <= mx + 162 then
                p.storm = math.max(0, p.storm - 1)
                saveState()
                return
            -- Storm +
            elseif x >= mx + 168 and x <= mx + 200 then
                p.storm = p.storm + 1
                saveState()
                return
            -- Reset Storm
            elseif x >= mx + 206 and x <= mx + 290 then
                p.storm = 0
                saveState()
                return
            -- Invert theme
            elseif x >= mx + 304 and x <= mx + 464 then
                p.inverted = not p.inverted
                saveState()
                return
            -- Link Cmdr Dmg checkbox
            elseif x >= mx + 476 and x <= mx + mw - 10 then
                ui.linkCmdrDamage = not ui.linkCmdrDamage
                saveState()
                return
            end
        end

        -- Tap outside
        if x < mx or x > mx + mw or y < my or y > my + mh then
            ui.modal = nil
            crosspoint.requestUpdate()
            return
        end
        return
    end

    if ui.modal == "reset" then
        local mw = 440
        local mh = 280
        local mx = math.floor((w - mw) / 2)
        local my = math.floor((h - mh) / 2)
        local btnW = 340
        local bx = mx + math.floor((mw - btnW) / 2)
        local cy = my + 82

        -- 40 Life (Commander)
        if x >= bx and x <= bx + btnW and y >= cy and y <= cy + 40 then
            initNewGame(40, state.playerCount)
            ui.modal = nil
            saveState()
            return
        end
        -- 20 Life (Standard)
        cy = cy + 48
        if x >= bx and x <= bx + btnW and y >= cy and y <= cy + 40 then
            initNewGame(20, state.playerCount)
            ui.modal = nil
            saveState()
            return
        end
        -- 30 Life (Brawl)
        cy = cy + 48
        if x >= bx and x <= bx + btnW and y >= cy and y <= cy + 40 then
            initNewGame(30, state.playerCount)
            ui.modal = nil
            saveState()
            return
        end
        -- Cancel
        cy = cy + 48
        if x >= bx and x <= bx + btnW and y >= cy and y <= cy + 34 then
            ui.modal = nil
            crosspoint.requestUpdate()
            return
        end
        -- Tap outside
        if x < mx or x > mx + mw or y < my or y > my + mh then
            ui.modal = nil
            crosspoint.requestUpdate()
            return
        end
        return
    end

    if ui.modal == "player_count" then
        local mw = 360
        local mh = 260
        local mx = math.floor((w - mw) / 2)
        local my = math.floor((h - mh) / 2)
        local btnW = 280
        local bx = mx + math.floor((mw - btnW) / 2)
        local cy = my + 54

        for c = 1, 4 do
            if x >= bx and x <= bx + btnW and y >= cy and y <= cy + 38 then
                state.playerCount = c
                ui.modal = nil
                saveState()
                return
            end
            cy = cy + 44
        end
        -- Close button
        if x >= bx and x <= bx + btnW and y >= cy and y <= cy + 30 then
            ui.modal = nil
            crosspoint.requestUpdate()
            return
        end
        -- Tap outside
        if x < mx or x > mx + mw or y < my or y > my + mh then
            ui.modal = nil
            crosspoint.requestUpdate()
            return
        end
        return
    end

    -- -----------------------------------------------------------------------
    -- 2. Handle Top Bar Buttons
    -- -----------------------------------------------------------------------
    local rects, headerH = getCardRects(w, h, state.playerCount)
    if y <= headerH then
        -- Left: Player Count selector button
        local pcText = state.playerCount .. " Player" .. (state.playerCount > 1 and "s" or "")
        local pcW = gfx.getTextWidth(gfx.FONT_UI_10, pcText) + 16
        if x >= 10 and x <= 10 + pcW then
            ui.modal = "player_count"
            crosspoint.requestUpdate()
            return
        end

        -- Right Buttons: [Reset] & [Tools]
        local rightX = w - 10
        local toolsText = "Tools"
        local toolsW = gfx.getTextWidth(gfx.FONT_UI_10, toolsText) + 16
        rightX = rightX - toolsW
        if x >= rightX and x <= rightX + toolsW then
            ui.modal = "tools"
            crosspoint.requestUpdate()
            return
        end

        rightX = rightX - 8
        local resetText = "Reset"
        local resetW = gfx.getTextWidth(gfx.FONT_UI_10, resetText) + 16
        rightX = rightX - resetW
        if x >= rightX and x <= rightX + resetW then
            ui.modal = "reset"
            crosspoint.requestUpdate()
            return
        end
        return
    end

    -- -----------------------------------------------------------------------
    -- 3. Handle Player Card Interactions
    -- -----------------------------------------------------------------------
    for i = 1, state.playerCount do
        local r = rects[i]
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            state.selectedPlayer = i

            -- Card Menu / Counter detail icon [···] top right
            local menuBtnW = 44
            local menuBtnH = 24
            local menuBtnX = r.x + r.w - menuBtnW - 8
            local menuBtnY = r.y + 4
            if x >= menuBtnX and x <= menuBtnX + menuBtnW and y >= menuBtnY and y <= menuBtnY + menuBtnH then
                ui.detailPlayer = i
                ui.modal = "player_detail"
                crosspoint.requestUpdate()
                return
            end

            -- Bottom Counters Strip (Poison, Commander, Tax)
            local stripH = 34
            local stripY = r.y + r.h - stripH - 4
            if y >= stripY then
                local cx = r.x + 12
                -- Poison chip tap (+1 poison)
                local pStr = "P: " .. state.players[i].poison
                local pw = gfx.getTextWidth(gfx.FONT_SMALL, pStr) + 16
                if x >= cx and x <= cx + pw then
                    changePoison(i, 1)
                    return
                end
                cx = cx + pw + 8

                -- Cmdr dmg chip tap (opens detail)
                local cw = 70
                if x >= cx and x <= cx + cw then
                    ui.detailPlayer = i
                    ui.modal = "player_detail"
                    crosspoint.requestUpdate()
                    return
                end

                -- Otherwise open player details
                ui.detailPlayer = i
                ui.modal = "player_detail"
                crosspoint.requestUpdate()
                return
            end

            -- Quick +/- 5 buttons if present
            local cardHeaderH = 30
            local lifeCenterY = r.y + cardHeaderH + math.floor((r.h - cardHeaderH - 42) / 2)
            local btnSize = math.min(46, math.floor(r.h * 0.28))
            local minusX = r.x + 14
            local plusX = r.x + r.w - btnSize - 14
            local btnY = lifeCenterY - math.floor(btnSize / 2)
            local pillW = 38
            local pillH = 22
            local pillY = btnY + btnSize + 6

            if r.h >= 180 and y >= pillY and y <= pillY + pillH then
                -- -5 pill
                if x >= minusX and x <= minusX + btnSize then
                    changeLife(i, -5)
                    return
                -- +5 pill
                elseif x >= plusX and x <= plusX + btnSize then
                    changeLife(i, 5)
                    return
                end
            end

            -- Main Life +/- Buttons / Half-card tap
            -- Left side: -1 Life
            if x < r.x + math.floor(r.w / 2) then
                changeLife(i, -1)
            -- Right side: +1 Life
            else
                changeLife(i, 1)
            end
            return
        end
    end
end

-- ---------------------------------------------------------------------------
-- Lifecycle Callback: onInput(button, isDown)
-- ---------------------------------------------------------------------------
function onInput(button, isDown)
    if not isDown and isDown ~= nil and isDown ~= "press" then
        return
    end

    local sel = state.selectedPlayer or 1

    if button == input.BTN_CONFIRM then
        if ui.modal == nil then
            ui.detailPlayer = sel
            ui.modal = "player_detail"
            crosspoint.requestUpdate()
        else
            ui.modal = nil
            crosspoint.requestUpdate()
        end
    elseif button == input.BTN_UP or button == input.BTN_PAGE_BACK then
        if ui.modal == nil then
            changeLife(sel, 1)
        end
    elseif button == input.BTN_DOWN or button == input.BTN_PAGE_FORWARD then
        if ui.modal == nil then
            changeLife(sel, -1)
        end
    elseif button == input.BTN_RIGHT then
        state.selectedPlayer = (sel % state.playerCount) + 1
        saveState()
    elseif button == input.BTN_LEFT then
        state.selectedPlayer = ((sel - 2 + state.playerCount) % state.playerCount) + 1
        saveState()
    end
end

-- ---------------------------------------------------------------------------
-- Lifecycle Callback: onBack()
-- ---------------------------------------------------------------------------
function onBack()
    if ui.modal ~= nil then
        ui.modal = nil
        crosspoint.requestUpdate()
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Lifecycle Callback: onUpdate(dt)
-- ---------------------------------------------------------------------------
function onUpdate(dt)
    local now = crosspoint.millis()
    local dirty = false
    for i = 1, state.playerCount do
        local p = state.players[i]
        if p and p.delta ~= 0 and now >= p.deltaTimer then
            p.delta = 0
            dirty = true
        end
    end
    if dirty then
        crosspoint.requestUpdate()
    end
end

-- ---------------------------------------------------------------------------
-- Lifecycle Callback: onEnter() & onExit()
-- ---------------------------------------------------------------------------
function onEnter()
    loadState()
    local curSleep = crosspoint.getSleepApp()
    if curSleep == "" or curSleep == nil then
        crosspoint.setSleepApp("spellcounter")
    end
end

function onExit()
    saveState()
end
