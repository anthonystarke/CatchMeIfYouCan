--[[
    PowerupController
    Handles client-side powerup UI, pickup detection, and E-key activation
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local Controllers = script.Parent
local UIController = require(Controllers:WaitForChild("UIController"))
local MovementController = require(Controllers:WaitForChild("MovementController"))

local PowerupController = {}

-- State
PowerupController._heldPowerup = nil -- string: powerup type, or nil
PowerupController._pickupRemote = nil
PowerupController._activateRemote = nil
PowerupController._stateUpdateEvent = nil
PowerupController._pickupThread = nil
PowerupController._detectingPickups = false
PowerupController._inputConnection = nil

function PowerupController:Init()
    print("[PowerupController] Initializing...")
end

function PowerupController:Start()
    print("[PowerupController] Starting...")

    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    self._pickupRemote = Remotes:WaitForChild("PickupPowerup")
    self._activateRemote = Remotes:WaitForChild("ActivatePowerup")
    self._stateUpdateEvent = Remotes:WaitForChild("PowerupStateUpdate")

    -- Listen for server powerup state updates
    self._stateUpdateEvent.OnClientEvent:Connect(function(data)
        self:_onPowerupStateUpdate(data)
    end)

    -- Listen for E key to activate powerup
    self._inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.E then
            self:_onActivatePressed()
        end
    end)
end

-- Start proximity detection for powerup pickups (called when PLAYING phase starts)
function PowerupController:StartPickupDetection()
    if self._pickupThread then return end

    self._detectingPickups = true
    self._pickupThread = task.spawn(function()
        self:_pickupDetectionLoop()
    end)
end

-- Stop pickup detection (called on phase change)
function PowerupController:StopPickupDetection()
    self._detectingPickups = false
    if self._pickupThread then
        task.cancel(self._pickupThread)
        self._pickupThread = nil
    end
end

-- Clear held powerup, reset effects, and hide HUD
function PowerupController:ClearPowerup()
    self._heldPowerup = nil
    self:StopPickupDetection()
    MovementController:ResetJumpMultiplier()
    UIController:HidePowerupPrompt()
end

function PowerupController:_pickupDetectionLoop()
    local localPlayer = Players.LocalPlayer

    while self._detectingPickups do
        if self._heldPowerup then
            -- Already holding a powerup, skip detection
            task.wait(0.2)
            continue
        end

        local localChar = localPlayer.Character
        if localChar and localChar:FindFirstChild("HumanoidRootPart") then
            local localPos = localChar.HumanoidRootPart.Position

            -- Find powerup pads folder in the map
            local mapFolder = self:_findMapFolder()
            if mapFolder then
                local padsFolder = mapFolder:FindFirstChild("PowerupPads")
                if padsFolder then
                    for _, pad in ipairs(padsFolder:GetChildren()) do
                        -- Check if pad has a powerup orb as a sibling
                        local padIndex = pad.Name:match("PowerupPad_(%d+)")
                        if padIndex then
                            local orb = padsFolder:FindFirstChild("Powerup_" .. padIndex)
                            if orb then
                                local dist = (pad.Position - localPos).Magnitude
                                if dist <= Constants.POWERUP_PICKUP_RANGE then
                                    self:_tryPickup(tonumber(padIndex))
                                end
                            end
                        end
                    end
                end
            end
        end

        task.wait(0.2)
    end
end

function PowerupController:_findMapFolder()
    -- Find the first folder in Workspace that looks like a map
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Folder") and child:FindFirstChild("PowerupPads") then
            return child
        end
    end
    return nil
end

function PowerupController:_tryPickup(padIndex)
    local result = self._pickupRemote:InvokeServer(padIndex)
    if result and result.success then
        -- Server confirmed pickup, state update will come via event
        print("[PowerupController] Picked up powerup:", result.message)
    end
end

function PowerupController:_onActivatePressed()
    if not self._heldPowerup then return end

    -- Shield is passive, can't manually activate
    if self._heldPowerup == Constants.POWERUP_TYPES.SHIELD then
        return
    end

    local result = self._activateRemote:InvokeServer()
    if result and result.success then
        print("[PowerupController] Activated powerup:", result.message)
    end
end

function PowerupController:_onPowerupStateUpdate(data)
    local localPlayer = Players.LocalPlayer

    if data.action == "acquired" and data.userId == localPlayer.UserId then
        self._heldPowerup = data.powerupType
        local displayName = GameConfig.PowerupNames[data.powerupType] or data.powerupType
        if data.powerupType == Constants.POWERUP_TYPES.SHIELD then
            UIController:ShowPowerupPrompt(data.powerupType, displayName .. " (Active)")
        else
            UIController:ShowPowerupPrompt(data.powerupType, "Press E: " .. displayName)
        end
    elseif data.action == "activated" and data.userId == localPlayer.UserId then
        self._heldPowerup = nil
        UIController:HidePowerupPrompt()

        -- Apply client-side effects for mega jump
        if data.powerupType == Constants.POWERUP_TYPES.MEGA_JUMP then
            MovementController:ApplyJumpMultiplier(Constants.POWERUP_MEGA_JUMP_MULT)
        end
    elseif data.action == "expired" and data.userId == localPlayer.UserId then
        self._heldPowerup = nil
        UIController:HidePowerupPrompt()

        if data.powerupType == Constants.POWERUP_TYPES.MEGA_JUMP then
            MovementController:ResetJumpMultiplier()
        end
    elseif data.action == "blocked" and data.userId == localPlayer.UserId then
        self._heldPowerup = nil
        UIController:HidePowerupPrompt()
        UIController:NotifyTag("Shield blocked!")
    end
end

return PowerupController
