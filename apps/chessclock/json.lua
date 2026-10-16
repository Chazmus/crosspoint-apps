-- Lightweight JSON encoder and decoder for CrossPoint apps
local json = {}

local function escape_str(s)
    local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
    local out_char = {'\\\\', '\\"', '\\/', '\\b', '\\f', '\\n', '\\r', '\\t'}
    for i, c in ipairs(in_char) do
        s = s:gsub(c, out_char[i])
    end
    return '"' .. s .. '"'
end

local function is_array(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    for i = 1, count do
        if t[i] == nil then return false, 0 end
    end
    return true, count
end

function json.encode(val)
    local t = type(val)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        return escape_str(val)
    elseif t == "table" then
        local isArr, arrCount = is_array(val)
        if isArr then
            local parts = {}
            for i = 1, arrCount do
                parts[i] = json.encode(val[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, escape_str(tostring(k)) .. ":" .. json.encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return "null"
    end
end

local function parse_value(str, i)
    local len = #str
    while i <= len and str:sub(i, i):match("%s") do i = i + 1 end
    if i > len then return nil, i end

    local c = str:sub(i, i)
    if c == '{' then
        local obj = {}
        i = i + 1
        while true do
            while i <= len and str:sub(i, i):match('%s') do i = i + 1 end
            if i > len or str:sub(i, i) == '}' then return obj, i + 1 end
            local key, next_i = parse_value(str, i)
            i = next_i
            while i <= len and str:sub(i, i):match('%s') do i = i + 1 end
            if str:sub(i, i) == ':' then i = i + 1 end
            local val, next_i2 = parse_value(str, i)
            if key ~= nil then obj[key] = val end
            i = next_i2
            while i <= len and str:sub(i, i):match('%s') do i = i + 1 end
            if str:sub(i, i) == ',' then
                i = i + 1
            elseif str:sub(i, i) == '}' then
                return obj, i + 1
            else
                return obj, i
            end
        end
    elseif c == '[' then
        local arr = {}
        i = i + 1
        while true do
            while i <= len and str:sub(i, i):match('%s') do i = i + 1 end
            if i > len or str:sub(i, i) == ']' then return arr, i + 1 end
            local val, next_i = parse_value(str, i)
            table.insert(arr, val)
            i = next_i
            while i <= len and str:sub(i, i):match('%s') do i = i + 1 end
            if str:sub(i, i) == ',' then
                i = i + 1
            elseif str:sub(i, i) == ']' then
                return arr, i + 1
            else
                return arr, i
            end
        end
    elseif c == '"' then
        local j = i + 1
        local res = {}
        while j <= len do
            local ch = str:sub(j, j)
            if ch == '\\' then
                local esc = str:sub(j + 1, j + 1)
                if esc == 'n' then table.insert(res, '\n')
                elseif esc == 'r' then table.insert(res, '\r')
                elseif esc == 't' then table.insert(res, '\t')
                elseif esc == '"' then table.insert(res, '"')
                elseif esc == '\\' then table.insert(res, '\\')
                else table.insert(res, esc) end
                j = j + 2
            elseif ch == '"' then
                return table.concat(res), j + 1
            else
                table.insert(res, ch)
                j = j + 1
            end
        end
        return table.concat(res), len + 1
    elseif c == 't' and str:sub(i, i + 3) == 'true' then
        return true, i + 4
    elseif c == 'f' and str:sub(i, i + 4) == 'false' then
        return false, i + 5
    elseif c == 'n' and str:sub(i, i + 3) == 'null' then
        return nil, i + 4
    else
        local j = i
        while j <= len and str:sub(j, j):match('[-0-9.+eE]') do j = j + 1 end
        local numStr = str:sub(i, j - 1)
        return tonumber(numStr) or numStr, j
    end
end

function json.decode(str)
    if type(str) ~= "string" or str == "" then return nil end
    local ok, val = pcall(function()
        local v, _ = parse_value(str, 1)
        return v
    end)
    if ok then return val else return nil end
end

return json
