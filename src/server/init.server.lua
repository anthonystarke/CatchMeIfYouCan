--[[
    Server Entry Point
    Catch Me If You Can - Server Bootstrap
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Server] Catch Me If You Can starting...")

-- Get or create Remotes folder
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
end

-- Require services
local Services = script:WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService"))
local RoundService = require(Services:WaitForChild("RoundService"))

-- Initialize services (order matters - DataService first)
DataService:Init()
RoundService:Init()

-- Start services
DataService:Start()
RoundService:Start()

-- Handle player join
local function onPlayerAdded(player)
    print("[Server] Player joined:", player.Name)
end

-- Handle player leave
local function onPlayerRemoving(player)
    print("[Server] Player leaving:", player.Name)
end

-- Connect events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game (for Studio testing)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(function()
        onPlayerAdded(player)
    end)
end

print("[Server] Server ready!")
