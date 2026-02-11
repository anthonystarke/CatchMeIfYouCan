--[[
    DataService
    Handles player data persistence using ProfileService pattern
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))
local Utils = require(Shared:WaitForChild("Utils"))

local Helpers = script.Parent.Parent:WaitForChild("Helpers")
local RemoteHelper = require(Helpers:WaitForChild("RemoteHelper"))

local DataService = {}
DataService._profiles = {}

-- Default player data template
local DEFAULT_DATA = {
    -- Currency
    Coins = Constants.DEFAULT_COINS,
    Gems = Constants.DEFAULT_GEMS,

    -- Cosmetics
    OwnedSkins = {},
    EquippedSkin = nil,
    OwnedTrails = {},
    EquippedTrail = nil,
    OwnedEmotes = {},

    -- Player stats
    Stats = {
        TotalTags = 0,
        TotalEscapes = 0,
        RoundsPlayed = 0,
        RoundsWonAsTagger = 0,
        RoundsWonAsRunner = 0,
        TotalPoints = 0,
        PowerupsCollected = 0,
        LongestSurvival = 0,
    },

    -- Settings
    Settings = {
        MusicEnabled = true,
        SFXEnabled = true,
    },

    -- Timestamps
    FirstJoin = 0,
    LastJoin = 0,
}

-- Reconcile data with template (add missing fields)
local function reconcileData(data, template)
    for key, value in pairs(template) do
        if data[key] == nil then
            if type(value) == "table" then
                data[key] = Utils.DeepCopy(value)
            else
                data[key] = value
            end
        elseif type(value) == "table" and type(data[key]) == "table" then
            reconcileData(data[key], value)
        end
    end
end

function DataService:Init()
    print("[DataService] Initializing...")

    -- Create DataStore
    local success, dataStore = pcall(function()
        return DataStoreService:GetDataStore(Constants.DATA_STORE_KEY)
    end)

    if success then
        self._dataStore = dataStore
    else
        warn("[DataService] Failed to get DataStore:", dataStore)
    end

    -- Create currency update event (Remotes folder created by init.server.lua)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")

    self._currencyUpdateEvent = Instance.new("RemoteEvent")
    self._currencyUpdateEvent.Name = "CurrencyUpdate"
    self._currencyUpdateEvent.Parent = remotes
end

function DataService:Start()
    print("[DataService] Starting...")

    -- Initialize RemoteHelper (initializes rate limiting)
    RemoteHelper:Init()

    -- Create and bind remotes with rate limiting
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")

    -- GetCurrency remote
    self._getCurrencyRemote = RemoteHelper:CreateFunction("GetCurrency", remotes)
    RemoteHelper:BindFunction(self._getCurrencyRemote, function(player)
        return self:GetCurrency(player)
    end, { rateCategory = "Query" })

    -- GetSettings remote
    self._getSettingsRemote = RemoteHelper:CreateFunction("GetSettings", remotes)
    RemoteHelper:BindFunction(self._getSettingsRemote, function(player)
        return self:GetSettings(player)
    end, { rateCategory = "Query" })

    -- UpdateSetting remote
    self._updateSettingRemote = RemoteHelper:CreateFunction("UpdateSetting", remotes)
    RemoteHelper:BindFunction(self._updateSettingRemote, function(player, settingKey, settingValue)
        return self:UpdateSetting(player, settingKey, settingValue)
    end, { rateCategory = "DataMutation" })

    -- Handle player join
    Players.PlayerAdded:Connect(function(player)
        self:_loadPlayerData(player)
    end)

    -- Handle player leave
    Players.PlayerRemoving:Connect(function(player)
        self:_savePlayerData(player)
    end)

    -- Handle server shutdown
    game:BindToClose(function()
        for _, player in ipairs(Players:GetPlayers()) do
            self:_savePlayerData(player)
        end
    end)

    -- Load data for players already in game
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            self:_loadPlayerData(player)
        end)
    end
end

-- Retry configuration for DataStore operations
local RETRY_CONFIG = {
    MaxAttempts = 3,
    BaseDelay = 1,
    MaxDelay = 5,
}

-- Helper to retry DataStore operations with exponential backoff
local function retryWithBackoff(operation, operationName)
    local attempts = 0
    local lastError = nil

    while attempts < RETRY_CONFIG.MaxAttempts do
        attempts = attempts + 1
        local success, result = pcall(operation)

        if success then
            return true, result
        end

        lastError = result
        warn("[DataService]", operationName, "attempt", attempts, "failed:", result)

        if attempts < RETRY_CONFIG.MaxAttempts then
            local delay = math.min(RETRY_CONFIG.BaseDelay * (2 ^ (attempts - 1)), RETRY_CONFIG.MaxDelay)
            delay = delay * (0.5 + math.random() * 0.5)
            task.wait(delay)
        end
    end

    return false, lastError
end

function DataService:_loadPlayerData(player)
    local userId = player.UserId
    local key = "Player_" .. userId

    local data = nil
    local success, result = retryWithBackoff(function()
        return self._dataStore:GetAsync(key)
    end, "GetAsync for " .. player.Name)

    if success then
        if result then
            data = result
            reconcileData(data, DEFAULT_DATA)
        else
            -- New player
            data = Utils.DeepCopy(DEFAULT_DATA)
            data.FirstJoin = os.time()
        end
        data.LastJoin = os.time()
    else
        warn("[DataService] All retry attempts failed to load data for", player.Name, ":", result)
        data = Utils.DeepCopy(DEFAULT_DATA)
        data.FirstJoin = os.time()
        data.LastJoin = os.time()
        data._loadFailed = true
    end

    self._profiles[userId] = {
        Data = data,
        UserId = userId,
        Player = player,
    }

    print("[DataService] Loaded data for", player.Name, success and "" or "(FAILED - using defaults)")
end

-- Recursively sanitize data table for DataStore compatibility
function DataService:_sanitizeForDataStore(tbl, path)
    path = path or "Data"
    for key, value in pairs(tbl) do
        if type(value) == "number" then
            if value ~= value or value == math.huge or value == -math.huge then
                warn("[DataService] Sanitized non-finite value at " .. path .. "." .. tostring(key) .. " (" .. tostring(value) .. " -> 0)")
                tbl[key] = 0
            end
        elseif type(value) == "table" then
            self:_sanitizeForDataStore(value, path .. "." .. tostring(key))
        elseif type(value) ~= "string" and type(value) ~= "boolean" then
            warn("[DataService] Removed non-serializable " .. type(value) .. " at " .. path .. "." .. tostring(key))
            tbl[key] = nil
        end
    end
end

function DataService:_savePlayerData(player)
    local userId = player.UserId
    local profile = self._profiles[userId]

    if not profile then
        return
    end

    -- Don't save if load failed
    if profile.Data._loadFailed then
        warn("[DataService] Skipping save for", player.Name, "- load had failed, avoiding data loss")
        self._profiles[userId] = nil
        return
    end

    local key = "Player_" .. userId

    local dataToSave = profile.Data
    dataToSave._loadFailed = nil

    self:_sanitizeForDataStore(dataToSave)

    local success, result = retryWithBackoff(function()
        self._dataStore:SetAsync(key, dataToSave)
    end, "SetAsync for " .. player.Name)

    if success then
        print("[DataService] Saved data for", player.Name)
    else
        warn("[DataService] All retry attempts failed to save data for", player.Name, ":", result)
    end

    self._profiles[userId] = nil
end

function DataService:GetProfile(player)
    return self._profiles[player.UserId]
end

function DataService:GetData(player)
    local profile = self:GetProfile(player)
    return profile and profile.Data
end

-- Currency helpers
function DataService:AddCoins(player, amount)
    local data = self:GetData(player)
    if data then
        data.Coins = data.Coins + amount
        self:_notifyCurrencyChange(player, data)
        return true
    end
    return false
end

function DataService:_tryDeduct(player, field, amount)
    local data = self:GetData(player)
    if not data then
        return false, "Data not loaded"
    end
    if data[field] < amount then
        return false, "Not enough " .. field:lower()
    end
    data[field] = data[field] - amount
    self:_notifyCurrencyChange(player, data)
    return true, nil
end

function DataService:TryDeductCoins(player, amount)
    return self:_tryDeduct(player, "Coins", amount)
end

function DataService:AddGems(player, amount)
    local data = self:GetData(player)
    if data then
        data.Gems = data.Gems + amount
        self:_notifyCurrencyChange(player, data)
        return true
    end
    return false
end

function DataService:TryDeductGems(player, amount)
    return self:_tryDeduct(player, "Gems", amount)
end

function DataService:_notifyCurrencyChange(player, data)
    if self._currencyUpdateEvent then
        self._currencyUpdateEvent:FireClient(player, data.Coins, data.Gems)
    end
end

function DataService:GetCurrency(player)
    local data = self:GetData(player)
    if data then
        return data.Coins, data.Gems
    end
    return 0, 0
end

-- Settings helpers
function DataService:GetSettings(player)
    local maxWait = 5
    local waited = 0
    while not self:GetData(player) and waited < maxWait do
        task.wait(0.1)
        waited = waited + 0.1
    end

    local data = self:GetData(player)
    if data and data.Settings then
        return data.Settings
    end
    return { MusicEnabled = true, SFXEnabled = true }
end

function DataService:UpdateSetting(player, settingKey, settingValue)
    local data = self:GetData(player)
    if not data then
        return false, "Data not loaded"
    end

    if not data.Settings then
        data.Settings = {}
    end

    if settingKey == "MusicEnabled" or settingKey == "SFXEnabled" then
        if type(settingValue) ~= "boolean" then
            return false, "Invalid boolean value"
        end
    else
        return false, "Unknown setting key"
    end

    data.Settings[settingKey] = settingValue
    return true, nil
end

return DataService
