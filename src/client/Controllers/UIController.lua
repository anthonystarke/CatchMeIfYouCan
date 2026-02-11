--[[
    UIController
    Manages the main HUD and UI elements
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local UIController = {}

-- State
UIController._coins = 0
UIController._gems = 0
UIController._screenGui = nil

function UIController:Init()
    print("[UIController] Initializing...")
end

function UIController:Start()
    print("[UIController] Starting...")
    self:_createHUD()
end

function UIController:_createHUD()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- Create main ScreenGui
    self._screenGui = Instance.new("ScreenGui")
    self._screenGui.Name = "MainHUD"
    self._screenGui.ResetOnSpawn = false
    self._screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self._screenGui.Parent = playerGui
end

function UIController:UpdateCoins(coins)
    self._coins = coins
end

function UIController:UpdateGems(gems)
    self._gems = gems
end

function UIController:GetScreenGui()
    return self._screenGui
end

return UIController
