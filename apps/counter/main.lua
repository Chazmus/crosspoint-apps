-- Tally Counter Lua Application for CrossPoint Reader

local count = 0
local dataFile = "count.txt"

function onEnter()
    local saved = storage.readFile(dataFile)
    if saved and saved ~= "" then
        count = tonumber(saved) or 0
    end
end

local function saveCount()
    storage.writeFile(dataFile, tostring(count))
    crosspoint.requestUpdate()
end

function onTouch(x, y)
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    -- Check sleep toggle button (bottom right)
    local sleepBtnX = w - 180
    local sleepBtnY = h - 60
    if x >= sleepBtnX and x <= sleepBtnX + 160 and y >= sleepBtnY and y <= sleepBtnY + 45 then
        local currentSleep = crosspoint.getSleepApp()
        if currentSleep == "counter" then
            crosspoint.clearSleepApp()
        else
            crosspoint.setSleepApp("counter")
        end
        crosspoint.requestUpdate()
        return
    end

    -- Check reset button (bottom left)
    local resetBtnX = 20
    local resetBtnY = h - 60
    if x >= resetBtnX and x <= resetBtnX + 120 and y >= resetBtnY and y <= resetBtnY + 45 then
        count = 0
        saveCount()
        return
    end

    -- Tap left side of screen for -1
    if x < w / 3 then
        count = count - 1
        saveCount()
    -- Tap right side or center for +1
    else
        count = count + 1
        saveCount()
    end
end

function onInput(button, isDown)
    if button == input.BTN_UP or button == input.BTN_CONFIRM or button == input.BTN_PAGE_FORWARD then
        count = count + 1
        saveCount()
    elseif button == input.BTN_DOWN or button == input.BTN_PAGE_BACK then
        count = count - 1
        saveCount()
    end
end

function onDraw()
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    gfx.clearScreen(1)

    -- Header
    gfx.fillRect(0, 0, w, 40, true)
    gfx.drawCenteredText(gfx.FONT_UI_10, 24, "Tally Counter", false)

    -- Subtitle
    gfx.drawCenteredText(gfx.FONT_SMALL, 70, "Tap right for +1, left for -1, or use side buttons", true)

    -- Big number box in center
    local boxW = 320
    local boxH = 160
    local boxX = (w - boxW) / 2
    local boxY = (h - boxH) / 2 - 20

    gfx.drawRoundedRect(boxX, boxY, boxW, boxH, 16, 3, true)
    gfx.drawCenteredText(gfx.FONT_UI_12, boxY + boxH / 2 + 10, tostring(count), true)

    -- Reset button
    local resetBtnX = 20
    local resetBtnY = h - 60
    gfx.drawRoundedRect(resetBtnX, resetBtnY, 120, 45, 8, 2, true)
    gfx.drawText(gfx.FONT_SMALL, resetBtnX + 35, resetBtnY + 28, "Reset", true)

    -- Sleep Screen Toggle button
    local sleepBtnX = w - 180
    local sleepBtnY = h - 60
    local isSleepActive = (crosspoint.getSleepApp() == "counter")

    if isSleepActive then
        gfx.fillRoundedRect(sleepBtnX, sleepBtnY, 160, 45, 8, gfx.COLOR_BLACK)
        gfx.drawText(gfx.FONT_SMALL, sleepBtnX + 28, sleepBtnY + 28, "Sleep: ON", false)
    else
        gfx.drawRoundedRect(sleepBtnX, sleepBtnY, 160, 45, 8, 2, true)
        gfx.drawText(gfx.FONT_SMALL, sleepBtnX + 24, sleepBtnY + 28, "Set Sleep", true)
    end
end

function onSleepDraw()
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    gfx.clearScreen(1)
    gfx.fillRect(0, 0, w, 50, true)
    gfx.drawCenteredText(gfx.FONT_UI_12, 32, "CROSSPOINT TALLY", false)

    local boxW = 340
    local boxH = 180
    local boxX = (w - boxW) / 2
    local boxY = (h - boxH) / 2 - 10

    gfx.drawRoundedRect(boxX, boxY, boxW, boxH, 16, 4, true)
    gfx.drawCenteredText(gfx.FONT_SMALL, boxY + 35, "CURRENT COUNT", true)
    gfx.drawCenteredText(gfx.FONT_UI_12, boxY + 115, tostring(count), true)

    gfx.drawCenteredText(gfx.FONT_SMALL, h - 35, "Press Power to Wake", true)
end
