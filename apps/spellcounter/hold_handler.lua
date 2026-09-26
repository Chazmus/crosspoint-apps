-- ============================================================================
-- Spell Counter - Touch-and-Hold Gesture Handler
-- Coordinates continuous touch holds for rapid life ticking (±10).
-- ============================================================================

local grid = require("views.grid")
local stateEngine = require("state")

local holdHandler = {}

local function safeNum(n, def)
    local v = tonumber(n)
    return (v ~= nil) and v or (def or 0)
end

local function safeInt(n, def)
    local v = tonumber(n)
    return (v ~= nil) and math.floor(v) or (def or 0)
end

local holdState = {
    active = false,
    playerIdx = nil,
    deltaSign = 0,
    duration = 0,
    hasTicked = false,
    nextTickTime = 0,
}

holdHandler.holdState = holdState

function holdHandler.getTarget(x, y, w, h, st, rects, headerH)
    w = safeNum(w, 800)
    h = safeNum(h, 480)
    st = st or stateEngine.state
    local pc = math.max(1, math.min(4, safeInt(st.playerCount, 4)))

    if not rects or not headerH then
        rects, headerH = grid.getCardRects(w, h, pc)
    end

    if y <= headerH then
        return nil
    end

    for i = 1, pc do
        local r = rects[i]
        if r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            -- Top right menu button [···] hitbox
            if grid.isMenuButtonTouch(x, y, r) then
                return nil
            end

            -- Bottom counters strip
            local stripH = 34
            local stripY = r.y + r.h - stripH - 4
            if y >= stripY then
                return nil
            end

            -- Inside life touch area: left half = -1, right half = +1
            local deltaSign = (x < r.x + math.floor(r.w / 2)) and -1 or 1
            return {
                playerIdx = i,
                deltaSign = deltaSign,
                rect = r,
            }
        end
    end
    return nil
end

function holdHandler.onUpdate(dt, st, isModalOpen)
    dt = safeNum(dt, 0.05)
    if isModalOpen then
        if holdState.active then
            holdState.active = false
        end
        return
    end

    if input and input.getTouch then
        local isDown, tx, ty = input.getTouch()
        if isDown then
            local w = (gfx and gfx.getWidth and gfx.getWidth()) or 800
            local h = (gfx and gfx.getHeight and gfx.getHeight()) or 480

            if not holdState.active then
                local target = holdHandler.getTarget(tx, ty, w, h, st)
                if target then
                    holdState.active = true
                    holdState.playerIdx = target.playerIdx
                    holdState.deltaSign = target.deltaSign
                    holdState.duration = 0
                    holdState.hasTicked = false
                    holdState.nextTickTime = 0.5 -- 500ms initial hold threshold
                end
            end

            if holdState.active then
                local target = holdHandler.getTarget(tx, ty, w, h, st)
                if target and target.playerIdx == holdState.playerIdx and target.deltaSign == holdState.deltaSign then
                    holdState.duration = holdState.duration + dt
                    if holdState.duration >= holdState.nextTickTime then
                        holdState.hasTicked = true
                        stateEngine.changeLife(holdState.playerIdx, holdState.deltaSign * 10)
                        holdState.nextTickTime = holdState.duration + 1.0 -- repeat tick once a second (1.0s)
                        if crosspoint and crosspoint.requestUpdate then
                            crosspoint.requestUpdate()
                        end
                    end
                else
                    holdState.active = false
                end
            end
        else
            if holdState.active then
                holdState.active = false
            end
        end
    end
end

function holdHandler.wasTapSuppressed()
    if holdState.hasTicked then
        holdState.hasTicked = false
        return true
    end
    return false
end

function holdHandler.reset()
    holdState.active = false
    holdState.playerIdx = nil
    holdState.deltaSign = 0
    holdState.duration = 0
    holdState.hasTicked = false
    holdState.nextTickTime = 0
end

return holdHandler
