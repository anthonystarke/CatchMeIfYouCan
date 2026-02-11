--[[
    RoundService
    Manages game rounds: lobby, countdown, playing, results, intermission
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))
local Utils = require(Shared:WaitForChild("Utils"))

local Helpers = script.Parent.Parent:WaitForChild("Helpers")
local RemoteHelper = require(Helpers:WaitForChild("RemoteHelper"))

local RoundService = {}

-- Round state
RoundService._currentPhase = Constants.PHASES.LOBBY
RoundService._roundState = nil
RoundService._roundTimer = 0

function RoundService:Init()
    print("[RoundService] Initializing...")

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")

    -- Phase update event (server -> client)
    self._phaseUpdateEvent = RemoteHelper:CreateEvent("PhaseUpdate", remotes)

    -- Round state update event (server -> client)
    self._roundStateEvent = RemoteHelper:CreateEvent("RoundStateUpdate", remotes)

    -- Tag event (client -> server)
    self._tagEvent = RemoteHelper:CreateEvent("TagPlayer", remotes)

    -- Get round state (client -> server)
    self._getRoundStateRemote = RemoteHelper:CreateFunction("GetRoundState", remotes)
end

function RoundService:Start()
    print("[RoundService] Starting...")

    -- Bind tag event
    RemoteHelper:BindEvent(self._tagEvent, function(player, targetUserId)
        self:_handleTag(player, targetUserId)
    end, { rateCategory = "Action" })

    -- Bind get round state
    RemoteHelper:BindFunction(self._getRoundStateRemote, function(player)
        return self:GetRoundState()
    end, { rateCategory = "Query" })

    -- Start the round loop
    task.spawn(function()
        self:_roundLoop()
    end)
end

function RoundService:GetRoundState()
    return {
        phase = self._currentPhase,
        roundState = self._roundState,
        timeRemaining = self._roundTimer,
    }
end

function RoundService:_roundLoop()
    while true do
        -- Lobby phase: wait for enough players
        self:_setPhase(Constants.PHASES.LOBBY)
        self:_waitForPlayers()

        -- Countdown phase
        self:_setPhase(Constants.PHASES.COUNTDOWN)
        self:_countdown()

        -- Playing phase
        self:_setPhase(Constants.PHASES.PLAYING)
        self:_playRound()

        -- Results phase
        self:_setPhase(Constants.PHASES.RESULTS)
        task.wait(Constants.RESULTS_DISPLAY_TIME)

        -- Intermission phase
        self:_setPhase(Constants.PHASES.INTERMISSION)
        task.wait(Constants.INTERMISSION_TIME)

        -- Clean up round state
        self._roundState = nil
    end
end

function RoundService:_setPhase(phase)
    self._currentPhase = phase
    print("[RoundService] Phase:", phase)
    self._phaseUpdateEvent:FireAllClients(phase)
end

function RoundService:_waitForPlayers()
    while #Players:GetPlayers() < Constants.MIN_PLAYERS do
        task.wait(1)
    end

    -- Wait the lobby time once we have enough players
    local waited = 0
    while waited < Constants.LOBBY_WAIT_TIME do
        task.wait(1)
        waited = waited + 1
    end
end

function RoundService:_countdown()
    for i = Constants.COUNTDOWN_TIME, 1, -1 do
        self._roundTimer = i
        self._roundStateEvent:FireAllClients({
            phase = Constants.PHASES.COUNTDOWN,
            countdown = i,
        })
        task.wait(1)
    end
end

function RoundService:_playRound()
    local players = Players:GetPlayers()
    if #players < Constants.MIN_PLAYERS then
        return
    end

    -- Shuffle and assign roles
    local shuffled = Utils.Shuffle(players)
    local taggers = {}
    local runners = {}

    for i, player in ipairs(shuffled) do
        if i <= Constants.TAGGERS_PER_ROUND then
            table.insert(taggers, player)
        else
            table.insert(runners, player)
        end
    end

    -- Create round state
    self._roundState = {
        Taggers = taggers,
        Runners = runners,
        TaggedPlayers = {},
        RoundStartTime = os.time(),
        RoundEndTime = os.time() + Constants.ROUND_DURATION,
    }

    -- Notify all clients of role assignments
    for _, player in ipairs(taggers) do
        self._roundStateEvent:FireClient(player, {
            phase = Constants.PHASES.PLAYING,
            role = Constants.ROLES.TAGGER,
            roundState = self._roundState,
        })
    end

    for _, player in ipairs(runners) do
        self._roundStateEvent:FireClient(player, {
            phase = Constants.PHASES.PLAYING,
            role = Constants.ROLES.RUNNER,
            roundState = self._roundState,
        })
    end

    -- Run round timer
    local elapsed = 0
    while elapsed < Constants.ROUND_DURATION do
        task.wait(1)
        elapsed = elapsed + 1
        self._roundTimer = Constants.ROUND_DURATION - elapsed

        -- Check if all runners are tagged
        if self:_allRunnersTagged() then
            break
        end
    end
end

function RoundService:_handleTag(tagger, targetUserId)
    if not self._roundState then
        return
    end

    if self._currentPhase ~= Constants.PHASES.PLAYING then
        return
    end

    -- Verify tagger is actually a tagger
    local isTagger = false
    for _, t in ipairs(self._roundState.Taggers) do
        if t.UserId == tagger.UserId then
            isTagger = true
            break
        end
    end

    if not isTagger then
        return
    end

    -- Check if target is a valid runner and not already tagged
    if self._roundState.TaggedPlayers[targetUserId] then
        return
    end

    local isRunner = false
    for _, r in ipairs(self._roundState.Runners) do
        if r.UserId == targetUserId then
            isRunner = true
            break
        end
    end

    if not isRunner then
        return
    end

    -- Perform the tag
    self._roundState.TaggedPlayers[targetUserId] = true
    print("[RoundService]", tagger.Name, "tagged player", targetUserId)

    -- Notify all clients
    self._roundStateEvent:FireAllClients({
        phase = Constants.PHASES.PLAYING,
        tagEvent = {
            tagger = tagger.UserId,
            tagged = targetUserId,
        },
        roundState = self._roundState,
    })
end

function RoundService:_allRunnersTagged()
    if not self._roundState then
        return true
    end

    for _, runner in ipairs(self._roundState.Runners) do
        if not self._roundState.TaggedPlayers[runner.UserId] then
            return false
        end
    end

    return true
end

return RoundService
