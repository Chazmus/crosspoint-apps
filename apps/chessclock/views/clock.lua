-- ============================================================================
-- Chess Clock - Clock Panel View
-- Two half-screen panels facing opposite players: top panel is drawn 180
-- degrees rotated (7-segment digits + 5x7 labels), bottom panel uses native
-- fonts. Tap either panel to switch turns; header holds controls.
-- ============================================================================

local flipgfx = require("flipgfx")

local clock = {}

clock.layout = nil -- populated by computeLayout(w, h)

--- Panel geometry for the current screen. Panels tile the full screen below
--- the header; hit testing and drawing share this single source of truth.
function clock.computeLayout(w, h)
    local headerH = 44
    local panelH = math.floor((h - headerH) / 2)
    local layout = {
        w = w,
        h = h,
        headerH = headerH,
        top = { x = 0, y = headerH, w = w, h = panelH },
        bottom = { x = 0, y = headerH + panelH, w = w, h = h - headerH - panelH },
    }
    clock.layout = layout
    return layout
end

--- Which panel owns a tap. Returns "top" | "bottom" | nil.
function clock.panelAt(x, y, layout)
    if y < layout.headerH then return nil end
    if y < layout.top.y + layout.top.h then return "top" end
    return "bottom"
end

local function panelColors(activeSide, isMine, phase)
    -- Active panel: inverted (solid black card, white digits). Inactive: white.
    local inverted = (phase == "running" and isMine)
        or (phase == "ready")            -- ready: White (bottom by default) highlighted
        or (phase == "flagged" and isMine)
    return inverted, not inverted -- bgBlack, fgBlack
end

local function drawSegmentPanel(rect, timeText, caption, sub, inverted, flipped)
    local bgBlack = inverted
    local fgBlack = not inverted

    if bgBlack then
        gfx.fillRect(rect.x, rect.y, rect.w, rect.h, 0)
    end

    -- Clock digits, centered.
    local digitH = math.floor(rect.h * 0.52)
    local digitW = math.max(18, math.floor(digitH * 0.56))
    local cx = rect.x + math.floor(rect.w / 2)
    local cy = rect.y + math.floor(rect.h * 0.46)
    flipgfx.drawDigits(cx, cy, timeText, digitW, digitH, fgBlack, flipped)

    -- Caption line under the digits (side name / status).
    local capScale = 2
    local capW = flipgfx.glyphTextWidth(caption, capScale)
    if capW > rect.w - 24 then capScale = 1 end
    if flipped then
        local capY = rect.y + rect.h - math.floor(rect.h * 0.10) - 7 * capScale
        flipgfx.drawGlyphTextCentered(cx, capY, caption, capScale, fgBlack, "flip180")
    else
        local capY = rect.y + rect.h - math.floor(rect.h * 0.10) - 7 * capScale
        flipgfx.drawGlyphTextCentered(cx, capY, caption, capScale, fgBlack, "up")
    end

    -- Move count, small, top corner of the panel.
    if sub and sub ~= "" then
        if flipped then
            local w = flipgfx.glyphTextWidth(sub, 1)
            flipgfx.drawGlyphText(rect.x + 10, rect.y + 8, sub, 1, fgBlack, "flip180")
        else
            flipgfx.drawGlyphText(rect.x + 10, rect.y + 8, sub, 1, fgBlack, "up")
        end
    end
end

--- Draw both panels.
-- ctx: { phase, active, flaggedSide, whiteTop, timeText(side), caption(side), sub(side) }
function clock.drawPanels(layout, ctx)
    -- Map sides to panels. Default: White sits nearest the reader (bottom).
    local topSide = ctx.whiteTop and "white" or "black"
    local bottomSide = ctx.whiteTop and "black" or "white"

    for _, panel in ipairs({ "top", "bottom" }) do
        local side = (panel == "top") and topSide or bottomSide
        local flipped = (panel == "top")
        local inverted = (ctx.phase == "running" and ctx.active == side)
            or (ctx.phase == "flagged" and ctx.flaggedSide == side)
            or (ctx.phase == "ready" and side == "white")
        drawSegmentPanel(
            layout[panel],
            ctx.timeText(side),
            ctx.caption(side),
            ctx.sub(side),
            inverted,
            flipped
        )
    end

    -- Divider between panels: thick band reads clearly on reflective E-Ink.
    local divY = layout.top.y + layout.top.h
    gfx.fillRect(0, divY - 2, layout.w, 4, 0)
end

--- Header bar with title + control buttons. Returns button hit boxes.
function clock.drawHeader(layout, ctx)
    local h = layout.headerH
    gfx.fillRect(0, 0, layout.w, h, 0)

    local fontId = gfx.FONT_UI_10
    local lineH = gfx.getLineHeight(fontId)
    local textY = math.floor((h - lineH) / 2) + 1

    -- Left: control label (PAUSE / RESUME / READY / FLAG).
    local leftText = ctx.headerLeft or ""
    gfx.drawText(fontId, 12, textY, leftText, 1)

    -- Center: control name.
    local titleW = gfx.getTextWidth(fontId, ctx.headerTitle or "")
    gfx.drawText(fontId, math.floor((layout.w - titleW) / 2), textY, ctx.headerTitle or "", 1)

    -- Right: two buttons [SWAP] [MENU].
    local btnH = h - 10
    local btnY = 5
    local right = layout.w - 10

    local menuText = "MENU"
    local menuW = gfx.getTextWidth(fontId, menuText) + 16
    right = right - menuW
    gfx.drawRoundedRect(right, btnY, menuW, btnH, 6, 1, 1)
    gfx.drawText(fontId, right + 8, textY, menuText, 1)

    right = right - 8
    local swapText = "SWAP"
    local swapW = gfx.getTextWidth(fontId, swapText) + 16
    right = right - swapW
    gfx.drawRoundedRect(right, btnY, swapW, btnH, 6, 1, 1)
    gfx.drawText(fontId, right + 8, textY, swapText, 1)

    clock.headerButtons = {
        swap = { x = right, y = btnY, w = swapW, h = btnH },
        menu = { x = layout.w - 10 - menuW, y = btnY, w = menuW, h = btnH },
    }
    return clock.headerButtons
end

--- Hit-test header buttons. Returns "swap" | "menu" | nil.
function clock.headerButtonAt(x, y, layout)
    local b = clock.headerButtons
    if not b then return nil end
    if y >= 0 and y < layout.headerH then
        if x >= b.swap.x and x <= b.swap.x + b.swap.w then return "swap" end
        if x >= b.menu.x and x <= b.menu.x + b.menu.w then return "menu" end
    end
    return nil
end

return clock
