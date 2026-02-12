--[[
    Server Entry Point
    Catch Me If You Can - Server Bootstrap
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))

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
local MapService = require(Services:WaitForChild("MapService"))
local BotService = require(Services:WaitForChild("BotService"))
local PowerupService = require(Services:WaitForChild("PowerupService"))
local RoundService = require(Services:WaitForChild("RoundService"))

-- Initialize services (order matters)
DataService:Init()
MapService:Init()
BotService:Init()
PowerupService:Init()
RoundService:Init()

-- Start services
DataService:Start()
MapService:Start()
BotService:Start()
PowerupService:Start()
RoundService:Start()

-- Handle player join
local function onPlayerAdded(player)
    print("[Server] Player joined:", player.Name)

    local function onCharacterAdded(character)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.WalkSpeed = Constants.DEFAULT_WALK_SPEED

        -- Teleport to lobby on spawn/respawn
        task.defer(function()
            MapService:TeleportToLobby(player)
        end)
    end

    if player.Character then
        onCharacterAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharacterAdded)
end

-- Handle player leave
local function onPlayerRemoving(player)
    print("[Server] Player leaving:", player.Name)
    RoundService:RemoveParticipant(player)
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
