--[[
    Client Entry Point
    Catch Me If You Can - Client Bootstrap
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

print("[Client] Catch Me If You Can loading...")
print("[Client] Welcome, " .. LocalPlayer.Name .. "!")

-- Wait for remotes to be ready
ReplicatedStorage:WaitForChild("Remotes")

-- Require controllers
local Controllers = script:WaitForChild("Controllers")
local SettingsController = require(Controllers:WaitForChild("SettingsController"))
local UIController = require(Controllers:WaitForChild("UIController"))
local MovementController = require(Controllers:WaitForChild("MovementController"))
local TagController = require(Controllers:WaitForChild("TagController"))
local RoundController = require(Controllers:WaitForChild("RoundController"))

-- Initialize controllers (order matters)
SettingsController:Init()
UIController:Init()
MovementController:Init()
TagController:Init()
RoundController:Init()

-- Start controllers
SettingsController:Start()
UIController:Start()
MovementController:Start()
TagController:Start()
RoundController:Start()

-- Currency update handling
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Listen for currency updates
local currencyUpdateEvent = Remotes:WaitForChild("CurrencyUpdate")
currencyUpdateEvent.OnClientEvent:Connect(function(coins, gems)
    UIController:UpdateCoins(coins)
    UIController:UpdateGems(gems)
end)

-- Get initial currency
task.defer(function()
    local getCurrencyRemote = Remotes:WaitForChild("GetCurrency")
    local coins, gems = getCurrencyRemote:InvokeServer()
    UIController:UpdateCoins(coins)
    UIController:UpdateGems(gems)
end)

print("[Client] Client ready!")
