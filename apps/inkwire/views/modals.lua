-- Modals and dialog overlays for InkWire (Wi-Fi Sync and Settings)
local ui = require("ui")
local state = require("state")

local modals = {
    btnActionHit = nil,
    btnSecondaryHit = nil
}

local function hitTest(box, x, y)
    return box and x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h
end

function modals.drawSyncModal()
    local title = state.isSyncing and "Updating Edition" or (state.syncSuccess and "Sync Complete" or "Sync Failed")
    local msg = state.syncStatus
    local subtext = state.syncError or (state.isSyncing and "Connecting to Wi-Fi and downloading latest feed..." or "Your offline edition has been saved.")
    local btnLabel = state.isSyncing and "Please wait..." or "Continue"

    modals.btnActionHit = ui.drawModal(title, msg, subtext, btnLabel, 180)
end

function modals.drawSettingsModal()
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    -- Dim the background
    gfx.fillRectDither(0, 0, w, h, gfx.COLOR_DARK_GRAY)

    -- Modal box
    local mw = math.min(430, w - 30)
    local mh = 380
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    gfx.fillRoundedRect(mx, my, mw, mh, 12, gfx.COLOR_WHITE)
    gfx.drawRoundedRect(mx, my, mw, mh, 12, 3, gfx.COLOR_BLACK)

    -- Title
    local title = "InkWire Settings"
    local tw = ui.getTextWidth(gfx.FONT_NOTOSANS_14, title)
    gfx.drawText(gfx.FONT_NOTOSANS_14, mx + math.floor((mw - tw) / 2), my + 20, title, true)
    gfx.drawLine(mx + 20, my + 48, mx + mw - 20, my + 48, gfx.COLOR_BLACK)

    local cy = my + 64
    local contentW = mw - 40
    local contentX = mx + 20

    -- Feed URL Section
    gfx.drawText(gfx.FONT_NOTOSANS_12, contentX, cy, "Feed Endpoint URL:", true)
    cy = cy + 20

    local urlBoxH = 46
    gfx.drawRoundedRect(contentX, cy, contentW, urlBoxH, 6, 1, gfx.COLOR_BLACK)
    local displayUrl = ui.truncateText(gfx.FONT_UI_10, state.config.feedUrl or "(None configured)", contentW - 16)
    gfx.drawText(gfx.FONT_UI_10, contentX + 8, cy + 16, displayUrl, true)
    cy = cy + urlBoxH + 16

    -- Homelab / Cloudflare instructions
    local noteTitle = "How to customise your feed:"
    gfx.drawText(gfx.FONT_NOTOSANS_12, contentX, cy, noteTitle, true)
    cy = cy + 18

    local instructions = "Point your feedUrl to your homelab server or Cloudflare Worker in config.json. InkWire downloads edition.json on demand."
    local instLines = ui.wrapText(gfx.FONT_UI_10, instructions, contentW)
    for _, iline in ipairs(instLines) do
        gfx.drawText(gfx.FONT_UI_10, contentX, cy, iline, true)
        cy = cy + ui.getLineHeight(gfx.FONT_UI_10) + 1
    end
    cy = cy + 14

    -- Reset to Sample Edition Button
    local resetBtnW = contentW
    local resetBtnH = 44
    ui.drawButton(contentX, cy, resetBtnW, resetBtnH, "Reload Sample Edition", false, gfx.FONT_NOTOSANS_12)
    modals.btnSecondaryHit = { x = contentX, y = cy, w = resetBtnW, h = resetBtnH }
    cy = cy + resetBtnH + 16

    -- Close Button
    local closeBtnW = 160
    local closeBtnH = 44
    local closeX = mx + math.floor((mw - closeBtnW) / 2)
    ui.drawButton(closeX, cy, closeBtnW, closeBtnH, "Done", true, gfx.FONT_NOTOSANS_12)
    modals.btnActionHit = { x = closeX, y = cy, w = closeBtnW, h = closeBtnH }
end

function modals.onTouch(x, y)
    if state.currentView == "sync_modal" then
        if not state.isSyncing and hitTest(modals.btnActionHit, x, y) then
            state.currentView = "frontpage"
            if crosspoint then crosspoint.requestUpdate() end
            return true
        end
    elseif state.currentView == "settings_modal" then
        if hitTest(modals.btnSecondaryHit, x, y) then
            -- Reset to sample edition
            if storage then
                storage.remove("edition.json")
            end
            state.loadEdition()
            state.currentView = "frontpage"
            if crosspoint then crosspoint.requestUpdate() end
            return true
        end

        if hitTest(modals.btnActionHit, x, y) then
            state.currentView = "frontpage"
            if crosspoint then crosspoint.requestUpdate() end
            return true
        end
    end
    return false
end

function modals.onInput(btn, action)
    if action ~= "press" then return false end

    if btn == input.BTN_BACK or btn == input.BTN_CONFIRM then
        if not state.isSyncing then
            state.currentView = "frontpage"
            if crosspoint then crosspoint.requestUpdate() end
            return true
        end
    end
    return false
end

return modals
