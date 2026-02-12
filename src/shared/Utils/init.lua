--[[
    Utils
    Shared utility functions
]]

-- Try Roblox-style require first, fallback to direct require for tests
local Constants
if script and script.Parent then
    Constants = require(script.Parent:WaitForChild("Config"):WaitForChild("Constants"))
else
    Constants = require("Constants")
end

local Utils = {}

-- Format number with commas (1000 -> 1,000)
function Utils.FormatNumber(number)
    local formatted = tostring(math.floor(number))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- Format time in seconds to readable string
function Utils.FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))

    if seconds < 60 then
        return seconds .. "s"
    elseif seconds < 3600 then
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%dm %ds", mins, secs)
    else
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        return string.format("%dh %dm", hours, mins)
    end
end

-- Clamp value between min and max
function Utils.Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Shuffle array (Fisher-Yates)
function Utils.Shuffle(array)
    local shuffled = {}
    for i, v in ipairs(array) do
        shuffled[i] = v
    end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    return shuffled
end

-- Deep copy table with cycle detection
function Utils.DeepCopy(original, _seen)
    if type(original) ~= "table" then
        return original
    end

    _seen = _seen or {}
    if _seen[original] then
        return _seen[original]
    end

    local copy = {}
    _seen[original] = copy

    for key, value in pairs(original) do
        copy[key] = Utils.DeepCopy(value, _seen)
    end

    return copy
end

-- Find in array
function Utils.Find(array, predicate)
    for i, v in ipairs(array) do
        if predicate(v, i) then
            return v, i
        end
    end
    return nil, nil
end

-- Filter array
function Utils.Filter(array, predicate)
    local result = {}
    for i, v in ipairs(array) do
        if predicate(v, i) then
            table.insert(result, v)
        end
    end
    return result
end

-- Map array
function Utils.Map(array, transform)
    local result = {}
    for i, v in ipairs(array) do
        result[i] = transform(v, i)
    end
    return result
end

-- Find an item in an array where item[key] == value
function Utils.FindByKey(array, key, value)
    for i, item in ipairs(array) do
        if item[key] == value then
            return item, i
        end
    end
    return nil, nil
end

-- Remove and return an item from an array where item[key] == value
-- NOTE: This mutates the original array
function Utils.RemoveByKey(array, key, value)
    for i, item in ipairs(array) do
        if item[key] == value then
            table.remove(array, i)
            return item, true
        end
    end
    return nil, false
end

-- Check if an array contains an item where item[key] == value
function Utils.Contains(array, key, value)
    for _, item in ipairs(array) do
        if item[key] == value then
            return true
        end
    end
    return false
end

-- Check if array is empty
function Utils.IsEmpty(array)
    return #array == 0
end

-- Count items (optionally matching predicate)
function Utils.Count(array, predicate)
    if not predicate then
        return #array
    end
    local count = 0
    for _, v in ipairs(array) do
        if predicate(v) then
            count = count + 1
        end
    end
    return count
end

-- Check if any item matches predicate
function Utils.Some(array, predicate)
    for _, v in ipairs(array) do
        if predicate(v) then
            return true
        end
    end
    return false
end

-- Check if all items match predicate
function Utils.Every(array, predicate)
    for _, v in ipairs(array) do
        if not predicate(v) then
            return false
        end
    end
    return true
end

-- Get unique values (shallow comparison)
function Utils.Unique(array)
    local seen = {}
    local result = {}
    for _, v in ipairs(array) do
        if not seen[v] then
            seen[v] = true
            table.insert(result, v)
        end
    end
    return result
end

-- Split array into two based on predicate
function Utils.Partition(array, predicate)
    local passed = {}
    local failed = {}
    for _, v in ipairs(array) do
        if predicate(v) then
            table.insert(passed, v)
        else
            table.insert(failed, v)
        end
    end
    return passed, failed
end

return Utils
