-- Test Application for FreeInkUI Phase 1 Components

local state = {
    currentTab = 1,
    counter = 0,
    toggleVal = true,
    showDialog = false,
    themeIdx = 1,
    themes = { "Lyra", "RoundedRaff", "Classic" }
}

function onEnter()
    crosspoint.requestUpdate()
end

function onDraw()
    -- 1. Native Header
    local body = ui.drawHeader({
        title = "UI Kit Showcase",
        subtitle = "Theme: " .. ui.getTheme().name,
        showBack = true,
        showClock = true,
        showBattery = true,
        onBack = function()
            log.info("UI", "Header Back tapped!")
        end
    })

    -- 2. Native Tab Bar
    ui.drawTabBar({
        y = body.y,
        tabs = { "Overview", "Controls", "Theme" },
        selectedIndex = state.currentTab,
        onSelect = function(idx)
            state.currentTab = idx
            crosspoint.requestUpdate()
        end
    })

    local curY = body.y + 44
    local w = gfx.getWidth()

    if state.currentTab == 1 then
        -- Overview tab
        local card = ui.drawCard({
            x = 16,
            y = curY,
            w = w - 32,
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
            label = "Primary Button",
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
        -- Controls tab
        local card = ui.drawCard({
            x = 16,
            y = curY,
            w = w - 32,
            h = 240,
            padding = 16
        })

        gfx.drawText(gfx.FONT_NOTOSANS_14, card.innerX, card.innerY, "Toggle Switch Control", true)
        gfx.drawText(gfx.FONT_NOTOSERIF_12, card.innerX, card.innerY + 28, "Toggle state: " .. (state.toggleVal and "ON" or "OFF"), true)

        ui.drawToggle({
            x = card.innerX + card.innerW - 48,
            y = card.innerY + 10,
            checked = state.toggleVal,
            onToggle = function(newChecked)
                state.toggleVal = (newChecked == 1 or newChecked == true)
                crosspoint.requestUpdate()
            end
        })

        gfx.drawLine(card.innerX, card.innerY + 70, card.innerX + card.innerW, card.innerY + 70, gfx.COLOR_BLACK)

        gfx.drawText(gfx.FONT_NOTOSANS_14, card.innerX, card.innerY + 86, "Badges & Chips", true)
        ui.drawBadge({
            x = card.innerX,
            y = card.innerY + 116,
            text = "FILLED BADGE",
            variant = "filled"
        })

        ui.drawBadge({
            x = card.innerX + 130,
            y = card.innerY + 116,
            text = "OUTLINE BADGE",
            variant = "outlined"
        })

    elseif state.currentTab == 3 then
        -- Theme switcher tab
        local card = ui.drawCard({
            x = 16,
            y = curY,
            w = w - 32,
            h = 280,
            padding = 16
        })

        local theme = ui.getTheme()
        gfx.drawText(gfx.FONT_NOTOSANS_14, card.innerX, card.innerY, "Active Theme: " .. theme.name, true)
        gfx.drawText(gfx.FONT_NOTOSERIF_12, card.innerX, card.innerY + 28, "Corner Radius: " .. tostring(theme.controlRadius) .. "px", true)
        gfx.drawText(gfx.FONT_NOTOSERIF_12, card.innerX, card.innerY + 50, "Header Height: " .. tostring(theme.headerHeight) .. "px", true)

        local btnY = card.innerY + 90
        for i, tName in ipairs(state.themes) do
            local isCurrent = (theme.name == tName)
            ui.drawButton({
                x = card.innerX,
                y = btnY + (i - 1) * 54,
                w = card.innerW,
                h = 44,
                label = (isCurrent and "[x] " or "[ ] ") .. tName .. " Theme",
                variant = isCurrent and "primary" or "secondary",
                onClick = function()
                    ui.setTheme(tName)
                    crosspoint.requestUpdate()
                end
            })
        end
    end

    -- 3. Dialog Modal Overlay (if active)
    if state.showDialog then
        ui.drawDialog({
            title = "Modal Dialog",
            headline = "FreeInkUI OptionDialog",
            message = "This dialog features automatic background dithering and themed buttons.",
            buttons = {
                {
                    label = "Dismiss",
                    variant = "primary",
                    onClick = function()
                        state.showDialog = false
                        crosspoint.requestUpdate()
                    end
                }
            }
        })
    end
end

function onTouch(x, y)
    -- Fall through for any touches outside FreeInkUI components
    log.info("UITEST", "Custom onTouch tap at: " .. tostring(x) .. ", " .. tostring(y))
end
