--[[
    MovementController
    Manages player movement: speed modifications, double-jump, freeze effects
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))

local MovementController = {}

-- State
MovementController._humanoid = nil
MovementController._humanoidRootPart = nil
MovementController._currentRole = nil
MovementController._isFrozen = false
MovementController._jumpCount = 0
MovementController._canDoubleJump = false
MovementController._stateChangedConnection = nil
MovementController._jumpRequestConnection = nil

function MovementController:Init()
    print("[MovementController] Initializing...")
end

function MovementController:Start()
    print("[MovementController] Starting...")

    local localPlayer = Players.LocalPlayer

    -- Setup for current character
    if localPlayer.Character then
        self:_onCharacterAdded(localPlayer.Character)
    end

    -- Re-setup when character respawns
    localPlayer.CharacterAdded:Connect(function(character)
        self:_onCharacterAdded(character)
    end)
end

function MovementController:_onCharacterAdded(character)
    self._humanoid = character:WaitForChild("Humanoid")
    self._humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    self._jumpCount = 0
    self._canDoubleJump = false
    self._isFrozen = false

    -- Clean up old connections
    if self._stateChangedConnection then
        self._stateChangedConnection:Disconnect()
    end
    if self._jumpRequestConnection then
        self._jumpRequestConnection:Disconnect()
    end

    -- Setup double jump
    self._hasJumped = false
    self._stateChangedConnection = self._humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Landed then
            self._jumpCount = 0
            self._canDoubleJump = false
            self._hasJumped = false
        elseif newState == Enum.HumanoidStateType.Jumping then
            self._hasJumped = true
        elseif newState == Enum.HumanoidStateType.Freefall then
            if self._hasJumped then
                self._canDoubleJump = true
            end
        end
    end)

    self._jumpRequestConnection = UserInputService.JumpRequest:Connect(function()
        if self._isFrozen then
            return
        end
        if self._canDoubleJump and self._jumpCount < 1 then
            self._jumpCount = self._jumpCount + 1
            self._canDoubleJump = false
            self:_performDoubleJump()
        end
    end)

    -- Reapply role speed on respawn
    if self._currentRole then
        self:ApplyRoleSpeed(self._currentRole)
    end
end

function MovementController:_performDoubleJump()
    if not self._humanoid or not self._humanoidRootPart then
        return
    end

    -- Verify character still exists
    if not self._humanoid.Parent or not self._humanoidRootPart.Parent then
        return
    end

    -- Reset vertical velocity then apply upward boost
    local velocity = self._humanoidRootPart.AssemblyLinearVelocity
    self._humanoidRootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)

    -- Apply jump force
    self._humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    self._humanoidRootPart.AssemblyLinearVelocity = self._humanoidRootPart.AssemblyLinearVelocity + Vector3.new(0, 50, 0)
end

function MovementController:ApplyRoleSpeed(role)
    self._currentRole = role

    if not self._humanoid then
        return
    end

    if role == Constants.ROLES.TAGGER then
        self._humanoid.WalkSpeed = Constants.DEFAULT_WALK_SPEED + Constants.TAGGER_SPEED_BOOST
    else
        self._humanoid.WalkSpeed = Constants.DEFAULT_WALK_SPEED
    end
end

function MovementController:FreezeControls(duration)
    if not self._humanoid then
        return
    end

    self._isFrozen = true
    self._humanoid.WalkSpeed = 0
    self._humanoid.JumpPower = 0

    local frozenHumanoid = self._humanoid
    task.delay(duration, function()
        self._isFrozen = false
        -- Check if humanoid still exists (character may have respawned)
        if frozenHumanoid and frozenHumanoid.Parent then
            if self._currentRole then
                self:ApplyRoleSpeed(self._currentRole)
            else
                frozenHumanoid.WalkSpeed = Constants.DEFAULT_WALK_SPEED
            end
            frozenHumanoid.JumpPower = 50
        end
    end)
end

function MovementController:ResetSpeed()
    self._currentRole = nil
    if self._humanoid then
        self._humanoid.WalkSpeed = Constants.DEFAULT_WALK_SPEED
        self._humanoid.JumpPower = 50
    end
end

return MovementController
