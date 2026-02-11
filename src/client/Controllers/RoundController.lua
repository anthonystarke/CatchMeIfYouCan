--[[
    RoundController
    Handles client-side round state, role display, and tag interactions
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local RoundController = {}

-- State
RoundController._currentPhase = Constants.PHASES.LOBBY
RoundController._currentRole = nil
RoundController._roundState = nil

function RoundController:Init()
    print("[RoundController] Initializing...")
end

function RoundController:Start()
    print("[RoundController] Starting...")

    local Remotes = ReplicatedStorage:WaitForChild("Remotes")

    -- Listen for phase updates
    local phaseUpdateEvent = Remotes:WaitForChild("PhaseUpdate")
    phaseUpdateEvent.OnClientEvent:Connect(function(phase)
        self:_onPhaseUpdate(phase)
    end)

    -- Listen for round state updates
    local roundStateEvent = Remotes:WaitForChild("RoundStateUpdate")
    roundStateEvent.OnClientEvent:Connect(function(stateData)
        self:_onRoundStateUpdate(stateData)
    end)

    -- Get initial round state
    task.defer(function()
        local getRoundState = Remotes:WaitForChild("GetRoundState")
        local state = getRoundState:InvokeServer()
        if state then
            self._currentPhase = state.phase
        end
    end)
end

function RoundController:_onPhaseUpdate(phase)
    self._currentPhase = phase
    print("[RoundController] Phase changed to:", phase)

    if phase == Constants.PHASES.LOBBY then
        self._currentRole = nil
        self._roundState = nil
    end
end

function RoundController:_onRoundStateUpdate(stateData)
    if stateData.role then
        self._currentRole = stateData.role
        print("[RoundController] Assigned role:", stateData.role)
    end

    if stateData.roundState then
        self._roundState = stateData.roundState
    end

    if stateData.tagEvent then
        self:_onTagEvent(stateData.tagEvent)
    end
end

function RoundController:_onTagEvent(tagEvent)
    local localPlayer = Players.LocalPlayer

    if tagEvent.tagged == localPlayer.UserId then
        print("[RoundController] You were tagged!")
    elseif tagEvent.tagger == localPlayer.UserId then
        print("[RoundController] You tagged someone!")
    end
end

function RoundController:GetCurrentPhase()
    return self._currentPhase
end

function RoundController:GetCurrentRole()
    return self._currentRole
end

return RoundController
