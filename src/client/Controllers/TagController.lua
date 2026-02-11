--[[
    TagController
    Handles proximity-based tag detection and firing TagPlayer remote
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))

local TagController = {}

-- State
TagController._tagPlayerRemote = nil
TagController._tagCooldownUntil = 0
TagController._detectionThread = nil

function TagController:Init()
    print("[TagController] Initializing...")
end

function TagController:Start()
    print("[TagController] Starting...")

    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    self._tagPlayerRemote = Remotes:WaitForChild("TagPlayer")
end

function TagController:StartDetection(roundController)
    if self._detectionThread then
        return
    end

    self._roundController = roundController
    print("[TagController] Starting proximity detection")
    self._detectionThread = task.spawn(function()
        self:_detectionLoop()
    end)
end

function TagController:StopDetection()
    if self._detectionThread then
        task.cancel(self._detectionThread)
        self._detectionThread = nil
    end
end

function TagController:_detectionLoop()
    local localPlayer = Players.LocalPlayer

    while true do
        -- Stop if no longer playing as tagger
        if not self._roundController
            or self._roundController:GetCurrentPhase() ~= Constants.PHASES.PLAYING
            or self._roundController:GetCurrentRole() ~= Constants.ROLES.TAGGER then
            break
        end

        local localChar = localPlayer.Character
        if localChar and localChar:FindFirstChild("HumanoidRootPart") then
            local localPos = localChar.HumanoidRootPart.Position
            local roundState = self._roundController:GetRoundState()

            if roundState and roundState.Runners then
                for _, runner in ipairs(roundState.Runners) do
                    -- Skip already tagged runners
                    if not roundState.TaggedPlayers[runner.UserId] then
                        local runnerChar = runner.Character
                        if runnerChar and runnerChar:FindFirstChild("HumanoidRootPart") then
                            local dist = (runnerChar.HumanoidRootPart.Position - localPos).Magnitude
                            if dist <= Constants.TAG_RANGE then
                                self:_tryTag(runner.UserId)
                            end
                        end
                    end
                end
            end
        end

        task.wait(0.1)
    end

    self._detectionThread = nil
end

function TagController:_tryTag(targetUserId)
    -- Client-side cooldown check
    if os.clock() < self._tagCooldownUntil then
        return
    end

    self._tagPlayerRemote:FireServer(targetUserId)
    self._tagCooldownUntil = os.clock() + Constants.TAG_COOLDOWN
end

return TagController
