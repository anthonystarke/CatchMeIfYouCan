--[[
    PowerupService
    Manages powerup spawning, pickup, activation, and effects during rounds.
    Server-authoritative: validates all powerup actions before applying.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local Services = script.Parent
local MapService = require(Services:WaitForChild("MapService"))

local Helpers = script.Parent.Parent:WaitForChild("Helpers")
local RemoteHelper = require(Helpers:WaitForChild("RemoteHelper"))

local PowerupService = {}

-- State
PowerupService._roundActive = false
PowerupService._playerPowerups = {} -- [userId] = { type = string, active = bool }
PowerupService._padStates = {} -- [padIndex] = { position = Vector3, powerupType = string?, model = Instance? }
PowerupService._spawnThread = nil
PowerupService._effectTimers = {} -- [userId] = thread (for expiring timed effects)

-- All available powerup types
local POWERUP_TYPES = {
    Constants.POWERUP_TYPES.SPEED_BOOST,
    Constants.POWERUP_TYPES.SHIELD,
    Constants.POWERUP_TYPES.MEGA_JUMP,
    Constants.POWERUP_TYPES.TELEPORT,
}

function PowerupService:Init()
    print("[PowerupService] Initializing...")

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")

    -- Client requests to pick up a powerup
    self._pickupRemote = RemoteHelper:CreateFunction("PickupPowerup", remotes)

    -- Client requests to activate held powerup
    self._activateRemote = RemoteHelper:CreateFunction("ActivatePowerup", remotes)

    -- Server broadcasts powerup state changes to all clients
    self._stateUpdateEvent = RemoteHelper:CreateEvent("PowerupStateUpdate", remotes)
end

function PowerupService:Start()
    print("[PowerupService] Starting...")

    RemoteHelper:BindFunction(self._pickupRemote, function(player, padIndex)
        return self:_handlePickup(player, padIndex)
    end, { rateCategory = "Action" })

    RemoteHelper:BindFunction(self._activateRemote, function(player)
        return self:_handleActivate(player)
    end, { rateCategory = "Action" })
end

-- Called by RoundService when PLAYING phase begins
function PowerupService:OnRoundStart()
    self._roundActive = true
    self._playerPowerups = {}
    self._effectTimers = {}

    -- Initialize pad states from map definition
    local padPositions = MapService:GetPowerupPadPositions()
    self._padStates = {}
    for i, pos in ipairs(padPositions) do
        self._padStates[i] = {
            position = pos,
            powerupType = nil,
            model = nil,
        }
    end

    -- Start spawning powerups
    self._spawnThread = task.spawn(function()
        -- Initial delay before first powerup spawns
        task.wait(Constants.TAGGER_SPAWN_DELAY + 2)
        while self._roundActive do
            self:_spawnPowerup()
            task.wait(Constants.POWERUP_SPAWN_INTERVAL)
        end
    end)
end

-- Called by RoundService when round ends
function PowerupService:OnRoundEnd()
    self._roundActive = false

    -- Cancel spawn thread
    if self._spawnThread then
        task.cancel(self._spawnThread)
        self._spawnThread = nil
    end

    -- Restore player state and cancel all effect timers
    for userId, timer in pairs(self._effectTimers) do
        task.cancel(timer)
        -- Restore any modified stats to defaults
        local player = Players:GetPlayerByUserId(userId)
        if player and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = Constants.DEFAULT_WALK_SPEED
                humanoid.JumpPower = Constants.DEFAULT_JUMP_POWER
            end
        end
    end
    self._effectTimers = {}

    -- Destroy all powerup models on pads
    for _, padState in ipairs(self._padStates) do
        if padState.model then
            padState.model:Destroy()
            padState.model = nil
        end
    end

    -- Clear state
    self._playerPowerups = {}
    self._padStates = {}
end

-- Check if a player has a shield active (called by RoundService._handleTag)
function PowerupService:HasShield(userId)
    local powerup = self._playerPowerups[userId]
    return powerup and powerup.type == Constants.POWERUP_TYPES.SHIELD and powerup.active
end

-- Consume a player's shield (called by RoundService._handleTag)
function PowerupService:ConsumeShield(userId)
    local powerup = self._playerPowerups[userId]
    if not powerup or powerup.type ~= Constants.POWERUP_TYPES.SHIELD then
        return
    end

    self._playerPowerups[userId] = nil
    print("[PowerupService] Shield consumed for", userId)

    -- Notify all clients
    self._stateUpdateEvent:FireAllClients({
        userId = userId,
        powerupType = Constants.POWERUP_TYPES.SHIELD,
        action = "blocked",
    })
end

-- Return pad states so BotService can scan for nearby powerups
function PowerupService:GetPadStates()
    return self._padStates
end

-- Bot picks up and immediately uses a powerup (server-side only, no remotes)
function PowerupService:BotPickupAndUse(bot, padIndex)
    local pickupResult = self:_handlePickup(bot, padIndex)
    if not pickupResult.success then
        return false
    end

    -- Shield is passive (stored until consumed by a tag), skip activation
    local powerup = self._playerPowerups[bot.UserId]
    if powerup and powerup.type ~= Constants.POWERUP_TYPES.SHIELD then
        self:_handleActivate(bot)
    end

    return true
end

-- Clean up powerup state for a disconnected player
function PowerupService:RemovePlayer(userId)
    if self._effectTimers[userId] then
        task.cancel(self._effectTimers[userId])
        self._effectTimers[userId] = nil
    end
    self._playerPowerups[userId] = nil
end

-- Spawn a random powerup on a random empty pad
function PowerupService:_spawnPowerup()
    -- Find empty pads
    local emptyPads = {}
    for i, padState in ipairs(self._padStates) do
        if not padState.powerupType then
            table.insert(emptyPads, i)
        end
    end

    if #emptyPads == 0 then
        return
    end

    local padIndex = emptyPads[math.random(#emptyPads)]
    local powerupType = POWERUP_TYPES[math.random(#POWERUP_TYPES)]
    local padState = self._padStates[padIndex]
    local color = GameConfig.PowerupColors[powerupType] or Color3.fromRGB(255, 255, 255)

    padState.powerupType = powerupType

    -- Create visual powerup model on the pad
    local map = MapService:GetOrCreateMap()
    if map and map.PowerupPadsFolder then
        local padPart = map.PowerupPadsFolder:FindFirstChild("PowerupPad_" .. padIndex)
        if padPart then
            local orb = Instance.new("Part")
            orb.Name = "Powerup_" .. padIndex
            orb.Shape = Enum.PartType.Ball
            orb.Size = Vector3.new(2, 2, 2)
            orb.Position = padState.position + Vector3.new(0, 3, 0)
            orb.Anchored = true
            orb.CanCollide = false
            orb.Material = Enum.Material.Neon
            orb.Color = color
            orb.Parent = map.PowerupPadsFolder

            padState.model = orb

            -- Color the pad to match
            padPart.Color = color
            padPart.Transparency = 0
        end
    end

    -- Notify clients
    self._stateUpdateEvent:FireAllClients({
        action = "spawned",
        padIndex = padIndex,
        powerupType = powerupType,
        position = padState.position,
    })
end

-- Handle client pickup request
function PowerupService:_handlePickup(player, padIndex)
    if not self._roundActive then
        return { success = false, message = "Round not active" }
    end

    -- Validate padIndex
    padIndex = tonumber(padIndex)
    if not padIndex or not self._padStates[padIndex] then
        return { success = false, message = "Invalid pad" }
    end

    local padState = self._padStates[padIndex]
    if not padState.powerupType then
        return { success = false, message = "No powerup on this pad" }
    end

    -- Check if player already has a powerup
    if self._playerPowerups[player.UserId] then
        return { success = false, message = "Already holding a powerup" }
    end

    -- Validate proximity
    if not player.Character then
        return { success = false, message = "No character" }
    end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return { success = false, message = "No character" }
    end
    local distance = (root.Position - padState.position).Magnitude
    if distance > Constants.POWERUP_PICKUP_RANGE * Constants.TAG_RANGE_TOLERANCE then
        return { success = false, message = "Too far away" }
    end

    -- Pick up the powerup
    local powerupType = padState.powerupType
    self._playerPowerups[player.UserId] = {
        type = powerupType,
        active = powerupType == Constants.POWERUP_TYPES.SHIELD, -- Shield is active immediately
    }

    -- Clear the pad
    if padState.model then
        padState.model:Destroy()
        padState.model = nil
    end
    padState.powerupType = nil

    -- Reset pad visual
    local map = MapService:GetOrCreateMap()
    if map and map.PowerupPadsFolder then
        local padPart = map.PowerupPadsFolder:FindFirstChild("PowerupPad_" .. padIndex)
        if padPart then
            padPart.Color = Color3.fromRGB(200, 200, 200)
            padPart.Transparency = 0.3
        end
    end

    print("[PowerupService]", player.Name, "picked up", powerupType)

    -- Notify all clients
    self._stateUpdateEvent:FireAllClients({
        userId = player.UserId,
        powerupType = powerupType,
        action = "acquired",
        padIndex = padIndex,
    })

    return { success = true, message = powerupType }
end

-- Handle client activation request
function PowerupService:_handleActivate(player)
    if not self._roundActive then
        return { success = false, message = "Round not active" }
    end

    local powerup = self._playerPowerups[player.UserId]
    if not powerup then
        return { success = false, message = "No powerup held" }
    end

    -- Shield is passive (active on pickup), no manual activation
    if powerup.type == Constants.POWERUP_TYPES.SHIELD then
        return { success = false, message = "Shield is passive" }
    end

    local powerupType = powerup.type

    -- Apply effect
    if powerupType == Constants.POWERUP_TYPES.SPEED_BOOST then
        self:_applySpeedBoost(player)
    elseif powerupType == Constants.POWERUP_TYPES.MEGA_JUMP then
        self:_applyMegaJump(player)
    elseif powerupType == Constants.POWERUP_TYPES.TELEPORT then
        self:_applyTeleport(player)
    end

    -- Clear the powerup (consumed on activation)
    self._playerPowerups[player.UserId] = nil

    print("[PowerupService]", player.Name, "activated", powerupType)

    -- Notify all clients
    self._stateUpdateEvent:FireAllClients({
        userId = player.UserId,
        powerupType = powerupType,
        action = "activated",
    })

    return { success = true, message = powerupType }
end

function PowerupService:_applySpeedBoost(player)
    if not player.Character then return end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid then return end

    local originalSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = originalSpeed * Constants.POWERUP_SPEED_BOOST_MULT

    -- Expire after duration
    self._effectTimers[player.UserId] = task.delay(Constants.POWERUP_SPEED_BOOST_DURATION, function()
        self._effectTimers[player.UserId] = nil
        if not player.Character then return end
        local h = player.Character:FindFirstChild("Humanoid")
        if h then
            h.WalkSpeed = originalSpeed
        end

        self._stateUpdateEvent:FireAllClients({
            userId = player.UserId,
            powerupType = Constants.POWERUP_TYPES.SPEED_BOOST,
            action = "expired",
        })
    end)
end

function PowerupService:_applyMegaJump(player)
    if not player.Character then return end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid then return end

    humanoid.JumpPower = Constants.DEFAULT_JUMP_POWER * Constants.POWERUP_MEGA_JUMP_MULT

    -- Expire after duration
    self._effectTimers[player.UserId] = task.delay(Constants.POWERUP_MEGA_JUMP_DURATION, function()
        self._effectTimers[player.UserId] = nil
        if not player.Character then return end
        local h = player.Character:FindFirstChild("Humanoid")
        if h then
            h.JumpPower = Constants.DEFAULT_JUMP_POWER
        end

        self._stateUpdateEvent:FireAllClients({
            userId = player.UserId,
            powerupType = Constants.POWERUP_TYPES.MEGA_JUMP,
            action = "expired",
        })
    end)
end

function PowerupService:_applyTeleport(player)
    if not player.Character then return end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Teleport to random position within map bounds (with safety margin)
    local bounds = MapService:GetMapBounds()
    local margin = 10
    local safeBounds = bounds - margin
    local x = math.random(-safeBounds, safeBounds)
    local z = math.random(-safeBounds, safeBounds)

    if not root.Parent then return end
    root.CFrame = CFrame.new(x, 5, z)
end

return PowerupService
