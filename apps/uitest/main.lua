-- Test Application for FreeInkUI Phase 1 & 2 Components

local state = {
    currentTab = 1,
    counter = 0,
    toggleVal = true,
    checkboxVal = true,
    sliderVal = 42,
    capsuleVal = 65,
    stepperVal = 14,
    radioVal = 1,
    showDialog = false,
    showContextMenu = false,
    themes = { "Lyra", "RoundedRaff", "Classic" }
}

function onEnter()
    crosspoint.requestUpdate()
end

function onDraw()
    -- 1. Native Header
    local body = ui.drawHeader({
        title = "FreeInkUI Showcase",
        subtitle = "Theme: " .. ui.getTheme().name,
        showBack = true,
        showClock = true,
        showBattery = true,
        onBack = function()
            log.info("UI", "Header Back tapped!")
        end
    })

    -- 2. Native Segmented Tab Bar
    ui.drawTabBar({
        y = body.y,
        tabs = { "Basic", "Sliders", "Settings", "Data" },
        selectedIndex = state.currentTab,
        onSelect = function(idx)
            state.currentTab = idx
            crosspoint.requestUpdate()
        end
    })

    local curY = body.y + 44
    local w = gfx.getWidth()
    local contentW = w - 32

    if state.currentTab == 1 then
        -- Tab 1: Basic Cards & Buttons
        local card = ui.drawCard({
            x = 16,
            y = curY,
            w = contentW,
            h = 160,
            variant = "outlined",
            padding = 14,
            onClick = function()
                state.counter = state.counter + 1
                crosspoint.requestUpdate()
            end
        })

        ui.drawBadge({
            x = card.innerX,
            y = card.innerY,
            text = "FREEINKUI NATIVE",
            variant = "filled"
        })

        gfx.drawText(gfx.FONT_NOTOSANS_14, card.innerX, card.innerY + 28, "Interactive Card", true)
        gfx.drawText(gfx.FONT_NOTOSERIF_12, card.innerX, card.innerY + 54, "Tap card to increment counter:", true)
        gfx.drawText(gfx.FONT_NOTOSANS_16, card.innerX, card.innerY + 80, "Count: " .. tostring(state.counter), true)

        -- Action Buttons
        curY = curY + 180
        ui.drawButton({
            x = 16,
            y = curY,
            w = 140,
            h = 44,
            label = "+10",
            variant = "primary",
            onClick = function()
                state.counter = state.counter + 10
                crosspoint.requestUpdate()
            end
        })

        ui.drawButton({
            x = 170,
            y = curY,
            w = 140,
            h = 44,
            label = "Reset",
            variant = "secondary",
            onClick = function()
                state.counter = 0
                crosspoint.requestUpdate()
            end
        })

        ui.drawButton({
            x = 324,
            y = curY,
            w = 140,
            h = 44,
            label = "Dialog...",
            variant = "secondary",
            onClick = function()
                state.showDialog = true
                crosspoint.requestUpdate()
            end
        })

    elseif state.currentTab == 2 then
        -- Tab 2: Sliders, Progress & Checkbox
        gfx.drawText(gfx.FONT_NOTOSANS_14, 16, curY, "Standard Slider: " .. tostring(state.sliderVal) .. "%", true)
        curY = curY + 24
        ui.drawSlider({
            x = 16,
            y = curY,
            w = contentW,
            h = 32,
            value = state.sliderVal,
            min = 0,
            max = 100,
            onChange = function(newVal)
                state.sliderVal = newVal
                crosspoint.requestUpdate()
            end
        })

        curY = curY + 48
        gfx.drawText(gfx.FONT_NOTOSANS_14, 16, curY, "Capsule Slider: " .. tostring(state.capsuleVal) .. "%", true)
        curY = curY + 24
        ui.drawCapsuleSlider({
            x = 16,
            y = curY,
            w = contentW,
            h = 36,
            value = state.capsuleVal,
            min = 0,
            max = 100,
            onChange = function(newVal)
                state.capsuleVal = newVal
                crosspoint.requestUpdate()
            end
        })

        curY = curY + 54
        gfx.drawText(gfx.FONT_NOTOSANS_14, 16, curY, "Progress Bar (" .. tostring(state.sliderVal) .. "%)", true)
        curY = curY + 22
        ui.drawProgressBar({
            x = 16,
            y = curY,
            w = contentW,
            h = 14,
            value = state.sliderVal,
            max = 100
        })

        curY = curY + 40
        ui.drawCheckbox({
            x = 16,
            y = curY,
            w = contentW,
            h = 36,
            label = "Enable High Contrast Dithering",
            checked = state.checkboxVal,
            onToggle = function(newChecked)
                state.checkboxVal = newChecked
                crosspoint.requestUpdate()
            end
        })

    elseif state.currentTab == 3 then
        -- Tab 3: Setting Rows & Steppers
        ui.drawSettingRow({
            x = 16,
            y = curY,
            w = contentW,
            h = 50,
            label = "Screen Refresh Mode",
            subtitle = "Automatic e-ink waveform selection",
            value = "Fast",
            drawChevron = true,
            onClick = function()
                ui.drawToast({ message = "Tapped Refresh Mode", anchor = "bottom" })
                crosspoint.requestUpdate()
            end
        })

        curY = curY + 56
        ui.drawToggleRow({
            x = 16,
            y = curY,
            w = contentW,
            h = 50,
            label = "Wi-Fi Standby Sleep",
            subtitle = "Power down ESP32-S3 radio during sleep",
            checked = state.toggleVal,
            onToggle = function(newVal)
                state.toggleVal = newVal
                crosspoint.requestUpdate()
            end
        })

        curY = curY + 56
        ui.drawStepperRow({
            x = 16,
            y = curY,
            w = contentW,
            h = 50,
            label = "Default Font Size",
            subtitle = "Base reader typography scaling",
            value = tostring(state.stepperVal) .. " pt",
            onDecrement = function()
                if state.stepperVal > 8 then
                    state.stepperVal = state.stepperVal - 1
                    crosspoint.requestUpdate()
                end
            end,
            onIncrement = function()
                if state.stepperVal < 36 then
                    state.stepperVal = state.stepperVal + 1
                    crosspoint.requestUpdate()
                end
            end
        })

        curY = curY + 68
        ui.drawButton({
            x = 16,
            y = curY,
            w = contentW,
            h = 44,
            label = "Open Context Menu...",
            variant = "secondary",
            onClick = function()
                state.showContextMenu = true
                crosspoint.requestUpdate()
            end
        })

    elseif state.currentTab == 4 then
        -- Tab 4: Metric Cards, Radio Groups & Tables
        local cardW = math.floor((contentW - 12) / 2)
        ui.drawMetricCard({
            x = 16,
            y = curY,
            w = cardW,
            h = 96,
            label = "TEMPERATURE",
            value = "21°",
            unit = "C",
            caption = "London • Sunny",
            onClick = function()
                ui.drawToast({ message = "Refreshed weather" })
            end
        })

        ui.drawMetricCard({
            x = 16 + cardW + 12,
            y = curY,
            w = cardW,
            h = 96,
            label = "BATTERY",
            value = "87%",
            caption = "Charging • 4.12V",
            onClick = function()
                ui.drawToast({ message = "Battery healthy" })
            end
        })

        curY = curY + 112
        gfx.drawText(gfx.FONT_NOTOSANS_14, 16, curY, "Theme Selector (Radio Group)", true)
        curY = curY + 22
        ui.drawRadioGroup({
            x = 16,
            y = curY,
            w = contentW,
            h = 38,
            options = { "Lyra", "RoundedRaff", "Classic" },
            selectedIndex = state.radioVal,
            onSelect = function(idx)
                state.radioVal = idx
                if state.themes[idx] then
                    ui.setTheme(state.themes[idx])
                end
                crosspoint.requestUpdate()
            end
        })

        curY = curY + 54
        gfx.drawText(gfx.FONT_NOTOSANS_14, 16, curY, "Tabular Data Grid", true)
        curY = curY + 22
        ui.drawTable({
            x = 16,
            y = curY,
            w = contentW,
            h = 120,
            rows = 4,
            cols = 3,
            rowHeight = 28,
            headerRow = true,
            cells = {
                "Rank", "Player", "Elo",
                "1", "Carlsen", "2882",
                "2", "Nakamura", "2802",
                "3", "Caruana", "2805"
            }
        })
    end

    -- 3. Dialog Modal Overlay (if active)
    if state.showDialog then
        ui.drawDialog({
            title = "Modal Dialog",
            headline = "FreeInkUI OptionDialog",
            message = "This dialog features background dithering and themed buttons.",
            buttons = {
                {
                    label = "Dismiss",
                    onClick = function()
                        state.showDialog = false
                        crosspoint.requestUpdate()
                    end
                }
            }
        })
    end

    -- 4. Context Menu Overlay (if active)
    if state.showContextMenu then
        ui.drawContextMenu({
            x = 40,
            y = 220,
            w = w - 80,
            title = "Actions",
            items = {
                {
                    label = "Send via Tailscale",
                    onClick = function()
                        state.showContextMenu = false
                        ui.drawToast({ message = "Handoff initiated" })
                        crosspoint.requestUpdate()
                    end
                },
                {
                    label = "Bookmark Story",
                    onClick = function()
                        state.showContextMenu = false
                        ui.drawToast({ message = "Bookmarked!" })
                        crosspoint.requestUpdate()
                    end
                },
                {
                    label = "Cancel",
                    onClick = function()
                        state.showContextMenu = false
                        crosspoint.requestUpdate()
                    end
                }
            }
        })
    end
end

function onTouch(x, y)
    log.info("UITEST", "Touch tap at: " .. tostring(x) .. ", " .. tostring(y))
end
