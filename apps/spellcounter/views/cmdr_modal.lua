-- ============================================================================
-- Spell Counter - Dedicated Commander Damage View
-- Generous touch targets for tracking 21 lethal commander combat damage.
-- ============================================================================

local ui = require("ui")
local stateEngine = require("state")

local cmdrModal = {}

local function safeNum(n, def)
    local v = tonumber(n)
    return (v ~= nil) and v or (def or 0)
end

local function safeInt(n, def)
    local v = tonumber(n)
    return (v ~= nil) and math.floor(v) or (def or 0)
end

-- Layout helper: calculates geometry for opponent cards
function cmdrModal.getOpponentCardRects(mx, my, mw, mh, pc, detailPlayer)
    local opponents = {}
    for opp = 1, pc do
        if opp ~= detailPlayer then
            table.insert(opponents, opp)
        end
    end

    local cardY = my + 64
    local cardH = 296
    local totalW = mw - 32
    local gap = 14
    local numOpp = #opponents
    local rects = {}

    if numOpp == 0 then
        return rects, opponents
    end

    local cardW = math.floor((totalW - (numOpp - 1) * gap) / numOpp)
    if numOpp == 1 then
        cardW = math.min(380, cardW)
        local startX = mx + math.floor((mw - cardW) / 2)
        rects[1] = {x = startX, y = cardY, w = cardW, h = cardH, opp = opponents[1]}
    else
        local startX = mx + 16
        for i, opp in ipairs(opponents) do
            local cx = startX + (i - 1) * (cardW + gap)
            rects[i] = {x = cx, y = cardY, w = cardW, h = cardH, opp = opp}
        end
    end

    return rects, opponents
end

function cmdrModal.draw(w, h, state, detailPlayer, linkCmdrDamage)
    w = safeNum(w, 800)
    h = safeNum(h, 480)
    local pc = math.max(1, math.min(4, safeInt(state.playerCount, 4)))
    local dIdx = math.max(1, math.min(pc, safeInt(detailPlayer, 1)))
    local p = stateEngine.ensurePlayer(state.players[dIdx], dIdx, state.startingLife or 40)
    state.players[dIdx] = p

    local mw = math.min(760, w - 24)
    local mh = math.min(440, h - 20)
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    -- Modal Background
    ui.fillRounded(mx, my, mw, mh, 16, ui.C_WHITE)
    ui.drawRounded(mx, my, mw, mh, 16, 3, ui.C_BLACK)

    -- Header Bar
    if gfx and gfx.fillRect then
        gfx.fillRect(mx + 3, my + 3, mw - 6, 42, ui.C_BLACK)
    end

    -- Title
    local titleText = "COMMANDER DAMAGE -> " .. (p.name or ("Player " .. dIdx))
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_12"), mx + 16, my + 10, titleText, ui.C_WHITE)
    end

    -- Deduct from Life Checkbox / Button
    local linkText = linkCmdrDamage and "[X] Deduct Life" or "[ ] Deduct Life"
    local linkW = 148
    local linkX = mx + mw - linkW - 54
    ui.drawButton(linkX, my + 7, linkW, 28, linkText, ui.getFont("small"), ui.C_WHITE, false)

    -- Close [X] Button
    local closeX = mx + mw - 44
    ui.drawButton(closeX, my + 7, 36, 28, "X", ui.getFont("ui_10"), ui.C_WHITE, false)

    -- Sub-header info
    local subText = "21 lethal combat damage from a single commander defeats player."
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("small"), mx + 18, my + 48, subText, ui.C_BLACK)
    end

    -- Opponent Cards
    local cardRects, opponents = cmdrModal.getOpponentCardRects(mx, my, mw, mh, pc, dIdx)

    if #opponents == 0 then
        -- 1 Player mode placeholder
        local msg = "Solo game: No opponents available for commander damage."
        local mwText = ui.getTextWidth(ui.getFont("ui_10"), msg)
        if gfx and gfx.drawText then
            gfx.drawText(ui.getFont("ui_10"), mx + math.floor((mw - mwText) / 2), my + 180, msg, ui.C_BLACK)
        end
    else
        for _, cr in ipairs(cardRects) do
            local opp = cr.opp
            local oppP = stateEngine.ensurePlayer(state.players[opp], opp, state.startingLife or 40)
            local dmg = safeNum(p.cmdrDmg and p.cmdrDmg[opp], 0)
            local isLethal = (dmg >= 21)

            local cx, cy, cw, ch = cr.x, cr.y, cr.w, cr.h
            local bgIsBlack = isLethal
            local fgCol = isLethal and ui.C_WHITE or ui.C_BLACK
            local bgCol = isLethal and ui.C_BLACK or ui.C_WHITE

            -- Card Box
            ui.fillRounded(cx, cy, cw, ch, 14, bgIsBlack)
            ui.drawRounded(cx, cy, cw, ch, 14, isLethal and 3 or 2, isLethal and ui.C_WHITE or ui.C_BLACK)

            -- Card Header: Opponent Name & Badges
            local oppName = oppP.name or ("Player " .. opp)
            if state.monarch == opp then oppName = oppName .. " [CROWN]" end
            if state.initiative == opp then oppName = oppName .. " [INIT]" end

            if gfx and gfx.drawText then
                gfx.drawText(ui.getFont("ui_10"), cx + 12, cy + 8, oppName, fgCol)
            end

            -- Lethal Badge
            if isLethal then
                local lText = "LETHAL (21+)"
                local lw = ui.getTextWidth(ui.getFont("small"), lText) + 12
                ui.fillRounded(cx + cw - lw - 10, cy + 6, lw, 22, 4, ui.C_WHITE)
                if gfx and gfx.drawText then
                    gfx.drawText(ui.getFont("small"), cx + cw - lw - 4, cy + 8, lText, ui.C_BLACK)
                end
            end

            -- Header separator
            if gfx and gfx.drawLine then
                gfx.drawLine(cx + 8, cy + 34, cx + cw - 8, cy + 34, 1, fgCol)
            end

            -- Big Damage Number
            local numX = cx + math.floor(cw / 2)
            local numY = cy + 84
            ui.drawBigNumber(numX, numY, dmg, 24, 46, 6, fgCol)

            -- Damage Gauge / Progress Bar
            local progW = cw - 28
            local progX = cx + 14
            local progY = cy + 124
            local progH = 8
            ui.drawRounded(progX, progY, progW, progH, 3, 1, fgCol)
            local fillW = math.floor(progW * math.min(1.0, dmg / 21))
            if fillW > 0 then
                ui.fillRounded(progX + 1, progY + 1, fillW, progH - 2, 2, fgCol)
            end

            local ratioText = dmg .. " / 21 Lethal"
            local rw = ui.getTextWidth(ui.getFont("small"), ratioText)
            if gfx and gfx.drawText then
                gfx.drawText(ui.getFont("small"), cx + math.floor((cw - rw) / 2), cy + 138, ratioText, fgCol)
            end

            -- Large Primary [-] and [+] Buttons
            local btnY = cy + 162
            local btnH = 68
            local btnW = math.floor((cw - 28) / 2)
            local leftBtnX = cx + 10
            local rightBtnX = cx + cw - 10 - btnW

            -- Minus Button (Left)
            ui.drawRounded(leftBtnX, btnY, btnW, btnH, 10, 2, fgCol)
            if gfx and gfx.drawLine then
                local midY = btnY + math.floor(btnH / 2)
                gfx.drawLine(leftBtnX + 18, midY, leftBtnX + btnW - 18, midY, 4, fgCol)
            end

            -- Plus Button (Right)
            ui.drawRounded(rightBtnX, btnY, btnW, btnH, 10, 2, fgCol)
            if gfx and gfx.drawLine then
                local midY = btnY + math.floor(btnH / 2)
                local midX = rightBtnX + math.floor(btnW / 2)
                gfx.drawLine(rightBtnX + 18, midY, rightBtnX + btnW - 18, midY, 4, fgCol)
                gfx.drawLine(midX, btnY + 18, midX, btnY + btnH - 18, 4, fgCol)
            end

            -- Quick Adjustment Buttons: [-5], [+5], [Clear]
            local qY = cy + 242
            local qH = 40
            local qW = math.floor((cw - 32) / 3)
            ui.drawButton(cx + 10, qY, qW, qH, "-5", ui.getFont("small"), fgCol, false)
            ui.drawButton(cx + 10 + qW + 6, qY, qW, qH, "+5", ui.getFont("small"), fgCol, false)
            ui.drawButton(cx + cw - 10 - qW, qY, qW, qH, "Clear", ui.getFont("small"), fgCol, false)
        end
    end

    -- Bottom Bar: Target Player Switcher & Details Link
    local bottomY = my + mh - 50
    if gfx and gfx.drawText then
        gfx.drawText(ui.getFont("ui_10"), mx + 18, bottomY + 7, "Switch Target:", ui.C_BLACK)
    end

    local tabX = mx + 130
    for i = 1, pc do
        local pI = stateEngine.ensurePlayer(state.players[i], i, state.startingLife or 40)
        local isSel = (i == dIdx)
        local tabText = pI.name or ("P" .. i)
        local tabW = math.max(68, ui.getTextWidth(ui.getFont("small"), tabText) + 16)
        ui.drawButton(tabX, bottomY, tabW, 34, tabText, ui.getFont("small"), isSel and ui.C_BLACK or ui.C_BLACK, isSel)
        tabX = tabX + tabW + 8
    end

    -- [Counters & Details] Link
    local detailBtnW = 150
    local detailBtnX = mx + mw - detailBtnW - 16
    ui.drawButton(detailBtnX, bottomY, detailBtnW, 34, "Counters & Details...", ui.getFont("small"), ui.C_BLACK, false)
end

function cmdrModal.handleTouch(x, y, w, h, state, detailPlayer, linkCmdrDamage, callbacks)
    w = safeNum(w, 800)
    h = safeNum(h, 480)
    local pc = math.max(1, math.min(4, safeInt(state.playerCount, 4)))
    local dIdx = math.max(1, math.min(pc, safeInt(detailPlayer, 1)))

    local mw = math.min(760, w - 24)
    local mh = math.min(440, h - 20)
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    callbacks = callbacks or {}

    -- 1. Header Bar: Close [X]
    local closeX = mx + mw - 44
    if x >= closeX and x <= closeX + 36 and y >= my + 7 and y <= my + 35 then
        if callbacks.onClose then callbacks.onClose() end
        return true
    end

    -- 2. Header Bar: Toggle Deduct Life
    local linkW = 148
    local linkX = mx + mw - linkW - 54
    if x >= linkX and x <= linkX + linkW and y >= my + 7 and y <= my + 35 then
        if callbacks.onToggleLink then callbacks.onToggleLink() end
        return true
    end

    -- 3. Bottom Bar: Player Switcher Tabs & Details Button
    local bottomY = my + mh - 50
    if y >= bottomY and y <= bottomY + 36 then
        local tabX = mx + 130
        for i = 1, pc do
            local pI = stateEngine.ensurePlayer(state.players[i], i, state.startingLife or 40)
            local tabText = pI.name or ("P" .. i)
            local tabW = math.max(68, ui.getTextWidth(ui.getFont("small"), tabText) + 16)
            if x >= tabX and x <= tabX + tabW then
                if callbacks.onSelectPlayer then callbacks.onSelectPlayer(i) end
                return true
            end
            tabX = tabX + tabW + 8
        end

        local detailBtnW = 150
        local detailBtnX = mx + mw - detailBtnW - 16
        if x >= detailBtnX and x <= detailBtnX + detailBtnW then
            if callbacks.onOpenDetails then callbacks.onOpenDetails() end
            return true
        end
    end

    -- 4. Opponent Cards Touch Handling
    local cardRects, opponents = cmdrModal.getOpponentCardRects(mx, my, mw, mh, pc, dIdx)
    for _, cr in ipairs(cardRects) do
        local cx, cy, cw, ch = cr.x, cr.y, cr.w, cr.h
        if x >= cx and x <= cx + cw and y >= cy and y <= cy + ch then
            local opp = cr.opp
            local qY = cy + 242
            local qH = 40
            local qW = math.floor((cw - 32) / 3)

            -- Quick Buttons row ([-5], [+5], [Clear])
            if y >= qY and y <= qY + qH then
                if x >= cx + 10 and x <= cx + 10 + qW then
                    if callbacks.onChangeDamage then callbacks.onChangeDamage(opp, -5) end
                    return true
                elseif x >= cx + 10 + qW + 6 and x <= cx + 10 + 2 * qW + 6 then
                    if callbacks.onChangeDamage then callbacks.onChangeDamage(opp, 5) end
                    return true
                elseif x >= cx + cw - 10 - qW and x <= cx + cw - 10 then
                    if callbacks.onClearDamage then callbacks.onClearDamage(opp) end
                    return true
                end
            end

            -- Upper & Middle Card Body: Generous Left (-1) / Right (+1) split
            if y >= cy + 36 and y < qY then
                local midX = cx + math.floor(cw / 2)
                if x < midX then
                    if callbacks.onChangeDamage then callbacks.onChangeDamage(opp, -1) end
                else
                    if callbacks.onChangeDamage then callbacks.onChangeDamage(opp, 1) end
                end
                return true
            end

            return true
        end
    end

    -- Eat any touch inside the modal window boundary to prevent pass-through
    if x >= mx and x <= mx + mw and y >= my and y <= my + mh then
        return true
    end

    return false
end

return cmdrModal
