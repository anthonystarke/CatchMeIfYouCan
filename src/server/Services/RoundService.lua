--[[
    RoundService
    Manages game rounds: lobby, countdown, playing, results, intermission
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))
local Utils = require(Shared:WaitForChild("Utils"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))
local MapService = require(Services:WaitForChild("MapService"))

local Helpers = script.Parent.Parent:WaitForChild("Helpers")
local RemoteHelper = require(Helpers:WaitForChild("RemoteHelper"))

local RoundService = {}

-- Round state
RoundService._currentPhase = Constants.PHASES.LOBBY
RoundService._roundState = nil
RoundService._roundTimer = 0
RoundService._tagCooldowns = {}
RoundService._roundStats = {}

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
        self:_processResults()
        task.wait(Constants.RESULTS_DISPLAY_TIME)

        -- Intermission phase
        self:_setPhase(Constants.PHASES.INTERMISSION)
        task.wait(Constants.INTERMISSION_TIME)

        -- Clean up round state
        self._roundState = nil
        self._tagCooldowns = {}
        self._roundStats = {}

        -- Reset player speeds
        for _, player in ipairs(Players:GetPlayers()) do
            self:_setWalkSpeed(player, Constants.DEFAULT_WALK_SPEED)
        end

        MapService:CleanupRound()
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

    -- Initialize per-player round stats
    self._roundStats = {}
    for _, player in ipairs(players) do
        self._roundStats[player.UserId] = {
            tagsPerformed = 0,
            survivedSeconds = 0,
        }
    end

    -- Teleport runners to spawn points
    for _, runner in ipairs(runners) do
        MapService:TeleportPlayerToSpawn(runner, Constants.ROLES.RUNNER)
        self:_setWalkSpeed(runner, Constants.DEFAULT_WALK_SPEED)
    end

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

    -- Tagger gets a 3-second head start delay, then teleports and gets speed boost
    task.delay(3, function()
        for _, tagger in ipairs(taggers) do
            MapService:TeleportPlayerToSpawn(tagger, Constants.ROLES.TAGGER)
            self:_setWalkSpeed(tagger, Constants.DEFAULT_WALK_SPEED + Constants.TAGGER_SPEED_BOOST)
        end
    end)

    -- Run round timer
    local elapsed = 0
    while elapsed < Constants.ROUND_DURATION do
        task.wait(1)
        elapsed = elapsed + 1
        self._roundTimer = Constants.ROUND_DURATION - elapsed

        -- Track survival time for untagged runners
        for _, runner in ipairs(runners) do
            if not self._roundState.TaggedPlayers[runner.UserId] and self._roundStats[runner.UserId] then
                self._roundStats[runner.UserId].survivedSeconds = elapsed
            end
        end

        -- Broadcast timer update
        self._roundStateEvent:FireAllClients({
            phase = Constants.PHASES.PLAYING,
            timeRemaining = self._roundTimer,
            roundState = self._roundState,
        })

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

    -- Check tag cooldown
    local now = os.clock()
    if self._tagCooldowns[tagger.UserId] and (now - self._tagCooldowns[tagger.UserId]) < Constants.TAG_COOLDOWN then
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

    -- Server-side distance validation
    local taggerChar = tagger.Character
    local targetPlayer = Players:GetPlayerByUserId(targetUserId)
    if not targetPlayer then
        return
    end
    local targetChar = targetPlayer.Character

    if not taggerChar or not targetChar then
        return
    end

    local taggerRoot = taggerChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not taggerRoot or not targetRoot then
        return
    end

    local distance = (taggerRoot.Position - targetRoot.Position).Magnitude
    if distance > Constants.TAG_RANGE * Constants.TAG_RANGE_TOLERANCE then
        return
    end

    -- Perform the tag
    self._roundState.TaggedPlayers[targetUserId] = true
    self._tagCooldowns[tagger.UserId] = now
    print("[RoundService]", tagger.Name, "tagged", targetPlayer.Name)

    -- Update round stats
    if self._roundStats[tagger.UserId] then
        self._roundStats[tagger.UserId].tagsPerformed = self._roundStats[tagger.UserId].tagsPerformed + 1
    end

    -- Freeze the tagged player
    self:_freezePlayer(targetPlayer)

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

function RoundService:_freezePlayer(player)
    if not player.Character then
        return
    end

    local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        humanoidRootPart.Anchored = true
    end

    -- Unfreeze after FREEZE_DURATION (player becomes spectator but stays frozen visually)
    task.delay(Constants.FREEZE_DURATION, function()
        if player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                root.Anchored = false
            end
        end
    end)
end

function RoundService:_setWalkSpeed(player, speed)
    if not player.Character then
        return
    end

    local humanoid = player.Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = speed
    end
end

function RoundService:_processResults()
    if not self._roundState then
        return
    end

    local taggerWon = self:_allRunnersTagged()
    local scores = {}

    -- Calculate tagger scores
    for _, tagger in ipairs(self._roundState.Taggers) do
        local stats = self._roundStats[tagger.UserId]
        local tagsCount = stats and stats.tagsPerformed or 0
        local points = tagsCount * Constants.POINTS_PER_TAG
        local coins = tagsCount * Constants.COINS_PER_TAG + Constants.COINS_PER_ROUND

        if taggerWon then
            coins = coins + Constants.COINS_PER_WIN
        end

        scores[tagger.UserId] = {
            role = Constants.ROLES.TAGGER,
            tags = tagsCount,
            points = points,
            coins = coins,
            won = taggerWon,
        }

        -- Update persistent data
        local data = DataService:GetData(tagger)
        if data then
            data.Stats.RoundsPlayed = data.Stats.RoundsPlayed + 1
            data.Stats.TotalTags = data.Stats.TotalTags + tagsCount
            data.Stats.TotalPoints = data.Stats.TotalPoints + points
            if taggerWon then
                data.Stats.RoundsWonAsTagger = data.Stats.RoundsWonAsTagger + 1
            end
            DataService:AddCoins(tagger, coins)
        end
    end

    -- Calculate runner scores
    for _, runner in ipairs(self._roundState.Runners) do
        local stats = self._roundStats[runner.UserId]
        local survived = stats and stats.survivedSeconds or 0
        local escaped = not self._roundState.TaggedPlayers[runner.UserId]
        local points = survived * Constants.POINTS_PER_SECOND_ALIVE
        local coins = Constants.COINS_PER_ROUND

        if escaped then
            points = points + Constants.BONUS_LAST_RUNNER
            coins = coins + Constants.COINS_PER_WIN
        end

        scores[runner.UserId] = {
            role = Constants.ROLES.RUNNER,
            survived = survived,
            escaped = escaped,
            points = points,
            coins = coins,
            won = escaped,
        }

        -- Update persistent data
        local data = DataService:GetData(runner)
        if data then
            data.Stats.RoundsPlayed = data.Stats.RoundsPlayed + 1
            data.Stats.TotalPoints = data.Stats.TotalPoints + points
            data.Stats.LongestSurvival = math.max(data.Stats.LongestSurvival, survived)
            if escaped then
                data.Stats.TotalEscapes = data.Stats.TotalEscapes + 1
                data.Stats.RoundsWonAsRunner = data.Stats.RoundsWonAsRunner + 1
            end
            DataService:AddCoins(runner, coins)
        end
    end

    -- Broadcast results to all clients
    self._roundStateEvent:FireAllClients({
        phase = Constants.PHASES.RESULTS,
        results = scores,
        taggerWon = taggerWon,
    })

    print("[RoundService] Round results:", taggerWon and "Tagger wins!" or "Runners survive!")
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
