-- ============================================================================
-- Spell Counter - Game State & Mutation Engine
-- Manages players, life totals, counters, history, and persistence.
-- ============================================================================

local json = require("json")

local state = {
    playerCount = 4,
    startingLife = 40,
    players = {},
    monarch = nil,
    initiative = nil,
    dayNight = "none",
    selectedPlayer = 1,
    history = {},
}

local PRESET_NAMES = {
    {"P1", "Mono White", "Aggro", "Commander 1"},
    {"P2", "Mono Blue",  "Control", "Commander 2"},
    {"P3", "Mono Black", "Midrange", "Commander 3"},
    {"P4", "Mono Red",   "Combo", "Commander 4"},
}

local function safeNum(n, def)
    local v = tonumber(n)
    return (v ~= nil) and v or (def or 0)
end

local function safeInt(n, def)
    local v = tonumber(n)
    return (v ~= nil) and math.floor(v) or (def or 0)
end

local function safeText(s, def)
    if s == nil then return def or "" end
    return tostring(s)
end

local function ensurePlayer(p, idx, defaultLife)
    idx = math.max(1, math.min(4, safeInt(idx, 1)))
    defaultLife = safeNum(defaultLife, state.startingLife or 40)
    if type(p) ~= "table" then p = {} end

    p.id = safeInt(p.id, idx)
    p.nameIdx = safeInt(p.nameIdx, 1)
    if not p.name or p.name == "" then
        local presets = PRESET_NAMES[idx] or {"P" .. idx}
        p.name = presets[p.nameIdx] or ("P" .. idx)
    end
    p.name = safeText(p.name, "P" .. idx)

    p.life = safeNum(p.life, defaultLife)
    p.delta = safeNum(p.delta, 0)
    p.deltaTimer = safeNum(p.deltaTimer, 0)
    p.poison = math.max(0, safeNum(p.poison, 0))
    p.tax = math.max(0, safeNum(p.tax, 0))
    p.energy = math.max(0, safeNum(p.energy, 0))
    p.experience = math.max(0, safeNum(p.experience, 0))
    p.storm = math.max(0, safeNum(p.storm, 0))
    p.inverted = (p.inverted == true)

    if type(p.cmdrDmg) ~= "table" then
        p.cmdrDmg = {0, 0, 0, 0}
    else
        for opp = 1, 4 do
            p.cmdrDmg[opp] = math.max(0, safeNum(p.cmdrDmg[opp], 0))
        end
    end

    return p
end

local function createPlayer(idx, startLife)
    return ensurePlayer({}, idx, startLife)
end

local function addHistory(msg)
    if type(state.history) ~= "table" then state.history = {} end
    table.insert(state.history, 1, safeText(msg, ""))
    if #state.history > 30 then
        table.remove(state.history)
    end
end

local function initNewGame(startLife, count)
    state.startingLife = safeNum(startLife, 40)
    state.playerCount = math.max(1, math.min(4, safeInt(count, 4)))
    state.players = {}
    for i = 1, 4 do
        table.insert(state.players, createPlayer(i, state.startingLife))
    end
    state.monarch = nil
    state.initiative = nil
    state.dayNight = "none"
    state.selectedPlayer = 1
    state.history = {}

    local msg = "Game reset: " .. state.playerCount .. " players @ " .. state.startingLife .. " life"
    addHistory(msg)
    if log and log.info then
        log.info("STATE", msg)
    end
end

local function saveState()
    if not storage or not storage.writeFile then return end

    local data = {
        playerCount = math.max(1, math.min(4, safeInt(state.playerCount, 4))),
        startingLife = safeNum(state.startingLife, 40),
        monarch = state.monarch,
        initiative = state.initiative,
        dayNight = safeText(state.dayNight, "none"),
        selectedPlayer = math.max(1, math.min(4, safeInt(state.selectedPlayer, 1))),
        history = state.history or {},
        players = {},
    }

    for i = 1, 4 do
        local p = ensurePlayer(state.players[i], i, state.startingLife)
        table.insert(data.players, {
            id = p.id,
            name = p.name,
            nameIdx = p.nameIdx,
            life = p.life,
            poison = p.poison,
            tax = p.tax,
            energy = p.energy,
            experience = p.experience,
            storm = p.storm,
            inverted = p.inverted,
            cmdrDmg = p.cmdrDmg,
        })
    end

    local encoded = json.encode(data)
    storage.writeFile("gamestate.json", encoded)
    if crosspoint and crosspoint.requestUpdate then
        crosspoint.requestUpdate()
    end
end

local function loadState()
    if not storage or not storage.readFile then
        initNewGame(40, 4)
        return
    end

    local content = storage.readFile("gamestate.json")
    if not content or content == "" then
        initNewGame(40, 4)
        return
    end

    local ok, data = pcall(function() return json.decode(content) end)
    if not ok or not data or type(data) ~= "table" or type(data.players) ~= "table" or #data.players == 0 then
        if log and log.warn then log.warn("STATE", "Corrupt gamestate.json, initializing fresh game") end
        initNewGame(40, 4)
        return
    end

    state.startingLife = safeNum(data.startingLife, 40)
    state.playerCount = math.max(1, math.min(4, safeInt(data.playerCount, 4)))
    state.monarch = data.monarch and safeInt(data.monarch, 1) or nil
    state.initiative = data.initiative and safeInt(data.initiative, 1) or nil
    state.dayNight = safeText(data.dayNight, "none")
    state.selectedPlayer = math.max(1, math.min(state.playerCount, safeInt(data.selectedPlayer, 1)))
    state.history = (type(data.history) == "table") and data.history or {}

    state.players = {}
    for i = 1, 4 do
        local sp = data.players[i]
        local p = createPlayer(i, state.startingLife)
        if type(sp) == "table" then
            p.name = safeText(sp.name, p.name)
            p.nameIdx = safeInt(sp.nameIdx, p.nameIdx)
            p.life = safeNum(sp.life, state.startingLife)
            p.poison = math.max(0, safeNum(sp.poison, 0))
            p.tax = math.max(0, safeNum(sp.tax, 0))
            p.energy = math.max(0, safeNum(sp.energy, 0))
            p.experience = math.max(0, safeNum(sp.experience, 0))
            p.storm = math.max(0, safeNum(sp.storm, 0))
            p.inverted = (sp.inverted == true)
            if type(sp.cmdrDmg) == "table" then
                p.cmdrDmg = {
                    math.max(0, safeNum(sp.cmdrDmg[1], 0)),
                    math.max(0, safeNum(sp.cmdrDmg[2], 0)),
                    math.max(0, safeNum(sp.cmdrDmg[3], 0)),
                    math.max(0, safeNum(sp.cmdrDmg[4], 0)),
                }
            end
        end
        table.insert(state.players, p)
    end

    if log and log.info then
        log.info("STATE", "Game state loaded successfully (" .. state.playerCount .. " players)")
    end
end

local function changeLife(playerIdx, amount)
    playerIdx = math.max(1, math.min(4, safeInt(playerIdx, 1)))
    amount = safeNum(amount, 0)
    local p = ensurePlayer(state.players[playerIdx], playerIdx, state.startingLife)
    state.players[playerIdx] = p

    p.life = safeNum(p.life, state.startingLife) + amount
    p.delta = safeNum(p.delta, 0) + amount

    local now = (crosspoint and crosspoint.millis and crosspoint.millis()) or 0
    p.deltaTimer = now + 2500

    local sign = (amount >= 0) and "+" or ""
    addHistory(p.name .. " " .. sign .. amount .. " life (" .. p.life .. ")")
    if log and log.info then
        log.info("STATE", p.name .. " life " .. sign .. amount .. " -> " .. p.life)
    end
    saveState()
end

local function changePoison(playerIdx, amount)
    playerIdx = math.max(1, math.min(4, safeInt(playerIdx, 1)))
    amount = safeNum(amount, 0)
    local p = ensurePlayer(state.players[playerIdx], playerIdx, state.startingLife)
    state.players[playerIdx] = p

    p.poison = math.max(0, safeNum(p.poison, 0) + amount)
    addHistory(p.name .. " poison: " .. p.poison)
    if log and log.info then
        log.info("STATE", p.name .. " poison -> " .. p.poison)
    end
    saveState()
end

local function changeCmdrDamage(playerIdx, oppIdx, amount, linkToLife)
    playerIdx = math.max(1, math.min(4, safeInt(playerIdx, 1)))
    oppIdx = math.max(1, math.min(4, safeInt(oppIdx, 1)))
    amount = safeNum(amount, 0)
    local p = ensurePlayer(state.players[playerIdx], playerIdx, state.startingLife)
    state.players[playerIdx] = p

    local oldDmg = safeNum(p.cmdrDmg[oppIdx], 0)
    local newDmg = math.max(0, oldDmg + amount)
    local diff = newDmg - oldDmg
    p.cmdrDmg[oppIdx] = newDmg

    if linkToLife and diff ~= 0 then
        p.life = safeNum(p.life, state.startingLife) - diff
        p.delta = safeNum(p.delta, 0) - diff
        local now = (crosspoint and crosspoint.millis and crosspoint.millis()) or 0
        p.deltaTimer = now + 2500
    end

    local oppP = state.players[oppIdx]
    local oppName = (oppP and oppP.name) or ("P" .. oppIdx)
    addHistory(p.name .. " took " .. diff .. " Cmdr Dmg from " .. oppName .. " (" .. newDmg .. ")")
    if log and log.info then
        log.info("STATE", p.name .. " took " .. diff .. " Cmdr Dmg from " .. oppName .. " (Total: " .. newDmg .. ")")
    end
    saveState()
end

local function isPlayerLethal(p)
    if not p then return false, nil end
    local life = safeNum(p.life, 40)
    local poison = safeNum(p.poison, 0)
    if life <= 0 then return true, "DEAD (0 LIFE)" end
    if poison >= 10 then return true, "POISONED (10)" end
    for oppIdx = 1, 4 do
        local dmg = safeNum(p.cmdrDmg and p.cmdrDmg[oppIdx], 0)
        if dmg >= 21 then
            return true, "CMDR LETHAL (21)"
        end
    end
    return false, nil
end

local function cyclePlayerName(playerIdx)
    playerIdx = math.max(1, math.min(4, safeInt(playerIdx, 1)))
    local p = ensurePlayer(state.players[playerIdx], playerIdx, state.startingLife)
    local presets = PRESET_NAMES[playerIdx] or {"P" .. playerIdx}
    p.nameIdx = (safeInt(p.nameIdx, 1) % #presets) + 1
    p.name = presets[p.nameIdx] or ("P" .. playerIdx)
    addHistory("Renamed P" .. playerIdx .. " to " .. p.name)
    saveState()
end

local function clearExpiredDeltas(nowMs)
    local dirty = false
    local pc = math.max(1, math.min(4, safeInt(state.playerCount, 4)))
    for i = 1, pc do
        local p = state.players[i]
        if p and safeNum(p.delta, 0) ~= 0 and nowMs >= safeNum(p.deltaTimer, 0) then
            p.delta = 0
            dirty = true
        end
    end
    return dirty
end

return {
    state = state,
    PRESET_NAMES = PRESET_NAMES,
    ensurePlayer = ensurePlayer,
    createPlayer = createPlayer,
    initNewGame = initNewGame,
    saveState = saveState,
    loadState = loadState,
    changeLife = changeLife,
    changePoison = changePoison,
    changeCmdrDamage = changeCmdrDamage,
    isPlayerLethal = isPlayerLethal,
    cyclePlayerName = cyclePlayerName,
    addHistory = addHistory,
    clearExpiredDeltas = clearExpiredDeltas,
}
