-- ============================================================================
-- Chess Clock - Setup View (Time Control Picker)
-- Vertical list of presets, a custom stepper row, seat orientation toggle,
-- and a start button. Also reachable mid-game via MENU -> NEW GAME.
-- ============================================================================

local state = require("state")

local setup = {}

local SCROLL_STEP = 1

function setup.init()
    setup.selected = 1
    -- Match current selection to the active control if known.
    for i, p in ipairs(state.PRESETS) do
        if p.mins == state.control.mins and p.inc == state.control.inc then
            setup.selected = i
            break
        end
    end
    setup.scroll = math.max(1, setup.selected - 3)
end

local function rowsVisible(h)
    return math.max(3, math.floor((h - 120) / 34))
end

local function drawList(w, h)
    local vis = rowsVisible(h)
    local listX, listY = 12, 64
    local rowH = 34
    local rowW = w - 24

    -- Keep selection visible.
    if setup.selected < setup.scroll then setup.scroll = setup.selected end
    if setup.selected >= setup.scroll + vis then setup.scroll = setup.selected - vis + 1 end

    for row = 0, vis - 1 do
        local idx = setup.scroll + row
        local preset = state.PRESETS[idx]
        if not preset then break end
        local y = listY + row * rowH

        local isSelected = (idx == setup.selected)
        if isSelected then
            gfx.fillRoundedRect(listX, y, rowW, rowH - 4, 8, 0)
            gfx.drawRoundedRect(listX, y, rowW, rowH - 4, 8, 2, 1)
            gfx.drawText(gfx.FONT_UI_12, listX + 12, y + 8, preset.label, 1)
        else
            gfx.drawRoundedRect(listX, y, rowW, rowH - 4, 8, 1, 0)
            gfx.drawText(gfx.FONT_UI_12, listX + 12, y + 8, preset.label, 0)
        end

        -- Time summary on the right edge of the row.
        local sum = preset.mins .. " min"
        if preset.inc > 0 then sum = sum .. " +" .. preset.inc .. "s" end
        local sw = gfx.getTextWidth(gfx.FONT_UI_10, sum)
        gfx.drawText(gfx.FONT_UI_10, listX + rowW - sw - 12, y + 10, sum, isSelected and 1 or 0)
    end

    -- Scroll indicator.
    local total = #state.PRESETS
    if total > vis then
        local barX = w - 6
        local barH = math.floor(vis * rowH * (vis / total))
        barH = math.max(12, barH)
        local barY = listY + math.floor((setup.scroll - 1) * (vis * rowH - barH) / (total - vis))
        gfx.fillRect(barX, listY, 3, vis * rowH, 2)
        gfx.fillRect(barX, barY, 3, barH, 0)
    end
end

local function drawCustomRow(w, h)
    local y = h - 96
    gfx.drawLine(12, y - 8, w - 12, y - 8, 1, 0)
    gfx.drawText(gfx.FONT_UI_10, 12, y - 2, "CUSTOM", 0)

    -- [-] m:ss [+]   [-] +inc [+] steppers
    local bx = 90
    local btnSize = 34
    local by = y + 2

    -- Minutes stepper
    gfx.drawRoundedRect(bx, by, btnSize, btnSize, 8, 2, 0)
    gfx.drawText(gfx.FONT_UI_12, bx + 11, by + 8, "-", 0)
    local minsText = tostring(state.custom.mins)
    local mw = gfx.getTextWidth(gfx.FONT_UI_12, minsText)
    gfx.drawText(gfx.FONT_UI_12, bx + btnSize + 16 - math.floor(mw / 2), by + 8, minsText, 0)
    gfx.drawText(gfx.FONT_UI_10, bx + btnSize + 34, by + 11, "min", 0)
    gfx.drawRoundedRect(bx + btnSize + 72, by, btnSize, btnSize, 8, 2, 0)
    gfx.drawText(gfx.FONT_UI_12, bx + btnSize + 83, by + 8, "+", 0)

    -- Increment stepper
    local ix = bx + btnSize + 130
    gfx.drawRoundedRect(ix, by, btnSize, btnSize, 8, 2, 0)
    gfx.drawText(gfx.FONT_UI_12, ix + 11, by + 8, "-", 0)
    local incText = tostring(state.custom.inc)
    local iw = gfx.getTextWidth(gfx.FONT_UI_12, incText)
    gfx.drawText(gfx.FONT_UI_12, ix + btnSize + 24 - math.floor(iw / 2), by + 8, incText, 0)
    gfx.drawText(gfx.FONT_UI_10, ix + btnSize + 40, by + 11, "inc s", 0)
    gfx.drawRoundedRect(ix + btnSize + 96, by, btnSize, 34, 8, 2, 0)
    gfx.drawText(gfx.FONT_UI_12, ix + btnSize + 107, by + 8, "+", 0)

    setup.customButtons = {
        minsMinus = { x = bx, y = by, w = btnSize, h = btnSize },
        minsPlus = { x = bx + btnSize + 72, y = by, w = btnSize, h = btnSize },
        incMinus = { x = ix, y = by, w = btnSize, h = btnSize },
        incPlus = { x = ix + btnSize + 96, y = by, w = btnSize, h = btnSize },
    }
end

local function drawFooter(w, h)
    -- Left: seat orientation toggle. Right: START button.
    local footY = h - 54
    local btnH = 44

    local seatText = "WHITE NEAR"
    if state.whiteTop then seatText = "WHITE FAR" end
    local seatW = gfx.getTextWidth(gfx.FONT_UI_10, seatText) + 20
    gfx.drawRoundedRect(12, footY, seatW, btnH, 8, 2, 0)
    local stw = gfx.getTextWidth(gfx.FONT_UI_10, seatText)
    gfx.drawText(gfx.FONT_UI_10, 12 + math.floor((seatW - stw) / 2), footY + 15, seatText, 0)

    local startW = math.max(140, w - seatW - 56)
    local startX = w - startW - 12
    gfx.fillRoundedRect(startX, footY, startW, btnH, 8, 0)
    gfx.drawRoundedRect(startX, footY, startW, btnH, 8, 2, 0)
    gfx.drawText(gfx.FONT_UI_12, startX + math.floor((startW - gfx.getTextWidth(gfx.FONT_UI_12, "START")) / 2),
        footY + 13, "START", 1)

    setup.footerButtons = {
        seat = { x = 12, y = footY, w = seatW, h = btnH },
        start = { x = startX, y = footY, w = startW, h = btnH },
    }
end

function setup.draw(w, h)
    gfx.clearScreen(1)

    gfx.fillRect(0, 0, w, 44, 0)
    local titleW = gfx.getTextWidth(gfx.FONT_UI_12, "TIME CONTROL")
    gfx.drawText(gfx.FONT_UI_12, math.floor((w - titleW) / 2), 14, "TIME CONTROL", 1)
    local backW = gfx.getTextWidth(gfx.FONT_UI_10, "BACK") + 16
    gfx.drawRoundedRect(10, 7, backW, 30, 6, 1, 1)
    gfx.drawText(gfx.FONT_UI_10, 18, 17, "BACK", 1)
    setup.backButton = { x = 10, y = 7, w = backW, h = 30 }

    drawList(w, h)
    drawCustomRow(w, h)
    drawFooter(w, h)
end

--- Returns "back" | "start" | "seat" | "custom" | "select" | nil.
--- (custom/select only when something was actually hit/changed).
function setup.onTouch(x, y, w, h)
    -- Header back
    local b = setup.backButton
    if b and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
        return "back"
    end

    -- Footer buttons
    local f = setup.footerButtons
    if f then
        if x >= f.seat.x and x <= f.seat.x + f.seat.w and y >= f.seat.y and y <= f.seat.y + f.seat.h then
            return "seat"
        end
        if x >= f.start.x and x <= f.start.x + f.start.w and y >= f.start.y and y <= f.start.y + f.start.h then
            return "start"
        end
    end

    -- Custom steppers
    local c = setup.customButtons
    if c and y >= c.minsMinus.y - 6 and y <= c.minsMinus.y + 46 then
        if x >= c.minsMinus.x and x <= c.minsMinus.x + c.minsMinus.w then return "custom_mins_minus" end
        if x >= c.minsPlus.x and x <= c.minsPlus.x + c.minsPlus.w then return "custom_mins_plus" end
        if x >= c.incMinus.x and x <= c.incMinus.x + c.incMinus.w then return "custom_inc_minus" end
        if x >= c.incPlus.x and x <= c.incPlus.x + c.incPlus.w then return "custom_inc_plus" end
    end

    -- Preset rows
    local listX, listY = 12, 64
    local rowH = 34
    if x >= listX and x <= w - 24 and y >= listY then
        local row = math.floor((y - listY) / rowH)
        local idx = setup.scroll + row
        local preset = state.PRESETS[idx]
        if preset then
            if setup.selected == idx then
                return "start" -- tap selected row again to start
            end
            setup.selected = idx
            return "select"
        end
    end

    return nil
end

--- Arrow-key support in setup.
function setup.moveSelection(delta)
    setup.selected = math.max(1, math.min(#state.PRESETS, setup.selected + SCROLL_STEP * 0 + (delta or 0)))
end

function setup.changeSelection(delta)
    setup.selected = math.max(1, math.min(#state.PRESETS, setup.selected + delta))
end

--- Apply the chosen control and start a fresh game.
function setup.applyAndStart(whiteTop)
    local preset = state.PRESETS[setup.selected]
    if preset then
        state.newGame(preset.mins, preset.inc, preset.label, whiteTop)
    else
        state.newGame(state.custom.mins, state.custom.inc,
            state.custom.mins .. "+" .. state.custom.inc .. " CUSTOM", whiteTop)
    end
end

return setup
