--[[
    RoundController
    Handles client-side round state, role display, and tag interactions
    Wires phase/role changes to UIController, MovementController, and TagController
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local Controllers = script.Parent
local UIController = require(Controllers:WaitForChild("UIController"))
local MovementController = require(Controllers:WaitForChild("MovementController"))
local TagController = require(Controllers:WaitForChild("TagController"))

local RoundController = {}

-- State
RoundController._currentPhase = Constants.PHASES.LOBBY
RoundController._currentRole = nil
RoundController._roundState = nil
RoundController._chaseHighlight = nil -- Highlight instance on the chased runner
RoundController._chaseTargetId = nil -- UserId of the currently highlighted runner

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
            UIController:SetPhaseText(state.phase)
        end
    end)
end

function RoundController:_onPhaseUpdate(phase)
    self._currentPhase = phase
    print("[RoundController] Phase changed to:", phase)

    UIController:SetPhaseText(phase)

    if phase == Constants.PHASES.LOBBY then
        self._currentRole = nil
        self._roundState = nil
        self:_clearChaseIndicator()
        TagController:StopDetection()
        MovementController:ResetSpeed()
        UIController:HideRoleBanner()
        UIController:HideCountdown()
        UIController:UpdateTimer(0)
    elseif phase == Constants.PHASES.COUNTDOWN then
        TagController:StopDetection()
    elseif phase == Constants.PHASES.PLAYING then
        UIController:HideCountdown()
    elseif phase == Constants.PHASES.RESULTS then
        TagController:StopDetection()
    elseif phase == Constants.PHASES.INTERMISSION then
        UIController:HideCountdown()
    end
end

function RoundController:_onRoundStateUpdate(stateData)
    -- Handle lobby status updates
    if stateData.phase == Constants.PHASES.LOBBY and stateData.lobbyStatus then
        UIController:UpdateLobbyStatus(stateData.lobbyStatus, stateData.playerCount, stateData.targetCount, stateData.timeRemaining)
        return
    end

    -- Handle countdown
    if stateData.phase == Constants.PHASES.COUNTDOWN and stateData.countdown then
        UIController:ShowCountdown(stateData.countdown)
        return
    end

    -- Handle intermission timer
    if stateData.phase == Constants.PHASES.INTERMISSION and stateData.timeRemaining then
        UIController:UpdateIntermissionTimer(stateData.timeRemaining)
        return
    end

    -- Handle role assignment
    if stateData.role then
        self._currentRole = stateData.role
        print("[RoundController] Assigned role:", stateData.role)

        MovementController:ApplyRoleSpeed(stateData.role)
        UIController:ShowRoleBanner(stateData.role)
        UIController:HideCountdown()

        -- Start tag detection if tagger
        if stateData.role == Constants.ROLES.TAGGER then
            TagController:StartDetection(self)
        end
    end

    -- Handle round state updates
    if stateData.roundState then
        self._roundState = stateData.roundState

        -- Update runners remaining count
        local totalRunners = #stateData.roundState.Runners
        local taggedCount = 0
        for _ in pairs(stateData.roundState.TaggedPlayers) do
            taggedCount = taggedCount + 1
        end
        UIController:UpdateRunnersRemaining(totalRunners - taggedCount, totalRunners)

        -- Update chase indicator
        self:_updateChaseIndicator(stateData.roundState)
    end

    -- Handle timer updates
    if stateData.timeRemaining then
        UIController:UpdateTimer(stateData.timeRemaining)
    end

    -- Handle tag events
    if stateData.tagEvent then
        self:_onTagEvent(stateData.tagEvent)
    end

    -- Handle results
    if stateData.phase == Constants.PHASES.RESULTS and stateData.results then
        UIController:ShowResults(stateData.results, stateData.taggerWon)
    end
end

function RoundController:_onTagEvent(tagEvent)
    local localPlayer = Players.LocalPlayer

    if tagEvent.tagged == localPlayer.UserId then
        print("[RoundController] You were tagged!")
        UIController:NotifyTag("You were tagged!")
        MovementController:FreezeControls(Constants.FREEZE_DURATION)
    elseif tagEvent.tagger == localPlayer.UserId then
        print("[RoundController] You tagged someone!")
        UIController:NotifyTag("Tag!")
    end
end

function RoundController:GetCurrentPhase()
    return self._currentPhase
end

function RoundController:GetCurrentRole()
    return self._currentRole
end

function RoundController:GetRoundState()
    return self._roundState
end

-- Chase indicator: show a Highlight on the runner the tagger is chasing
function RoundController:_updateChaseIndicator(roundState)
    local targetId = roundState.ChaseTargetId

    -- Same target as before, nothing to do
    if targetId == self._chaseTargetId then
        return
    end

    -- Clear previous highlight
    self:_clearChaseIndicator()

    if not targetId then
        return
    end

    -- Find the runner's character
    local targetChar = nil
    for _, runner in ipairs(roundState.Runners) do
        if runner.UserId == targetId then
            targetChar = runner.Character
            break
        end
    end

    if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then
        return
    end

    -- Create Highlight on the chased runner
    local highlight = Instance.new("Highlight")
    highlight.Name = "ChaseIndicator"
    highlight.FillColor = GameConfig.RoleColors.Tagger
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = GameConfig.RoleColors.Tagger
    highlight.OutlineTransparency = 0
    highlight.Adornee = targetChar
    highlight.Parent = targetChar

    self._chaseHighlight = highlight
    self._chaseTargetId = targetId
end

function RoundController:_clearChaseIndicator()
    if self._chaseHighlight then
        self._chaseHighlight:Destroy()
        self._chaseHighlight = nil
    end
    self._chaseTargetId = nil
end

return RoundController
