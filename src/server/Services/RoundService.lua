--[[
    RoundService
    Manages game rounds: lobby, countdown, playing, results, intermission
    Supports both real players and bots as participants.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))
local Utils = require(Shared:WaitForChild("Utils"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))
local MapService = require(Services:WaitForChild("MapService"))
local BotService = require(Services:WaitForChild("BotService"))
local PowerupService = require(Services:WaitForChild("PowerupService"))

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

    -- Give BotService a reference to us for bot tagging
    BotService:SetRoundService(self)

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

local function isBot(participant)
    return BotService:IsBot(participant)
end

function RoundService:GetRoundState()
    return {
        phase = self._currentPhase,
        roundState = self:_getClientRoundState(),
        timeRemaining = self._roundTimer,
    }
end

-- Create a client-safe copy of roundState with only the fields clients need.
-- Bot objects contain server-only data (PersonalityStats, AI state, math.huge)
-- that can fail RemoteEvent serialization.
function RoundService:_getClientRoundState()
    if not self._roundState then
        return nil
    end

    local function sanitizeParticipant(p)
        if isBot(p) then
            return { UserId = p.UserId, Name = p.Name, Character = p.Character }
        end
        return p -- Real players serialize fine as-is
    end

    local clientTaggers = {}
    for _, t in ipairs(self._roundState.Taggers) do
        table.insert(clientTaggers, sanitizeParticipant(t))
    end

    local clientRunners = {}
    for _, r in ipairs(self._roundState.Runners) do
        table.insert(clientRunners, sanitizeParticipant(r))
    end

    return {
        Taggers = clientTaggers,
        Runners = clientRunners,
        TaggedPlayers = self._roundState.TaggedPlayers,
        RoundStartTime = self._roundState.RoundStartTime,
        RoundEndTime = self._roundState.RoundEndTime,
        ChaseTargetId = self:_getChaseTargetId(),
    }
end

-- Determine which runner the tagger is actively chasing.
-- Bot taggers: use their committed_target from AI state.
-- Real player taggers: find the nearest untagged runner.
function RoundService:_getChaseTargetId()
    if not self._roundState or self._currentPhase ~= Constants.PHASES.PLAYING then
        return nil
    end

    for _, tagger in ipairs(self._roundState.Taggers) do
        -- Bot tagger: use committed target from AI state
        if isBot(tagger) and tagger.TaggerState and tagger.TaggerState.committed_target then
            local target = tagger.TaggerState.committed_target
            if target.Parent then
                -- Find the runner UserId that owns this HumanoidRootPart
                for _, runner in ipairs(self._roundState.Runners) do
                    if runner.Character and runner.Character:FindFirstChild("HumanoidRootPart") == target then
                        return runner.UserId
                    end
                end
            end
        end

        -- Real player tagger: find nearest untagged runner
        if not isBot(tagger) then
            local taggerChar = tagger.Character
            if taggerChar then
                local taggerRoot = taggerChar:FindFirstChild("HumanoidRootPart")
                if taggerRoot then
                    local nearestId = nil
                    local nearestDist = math.huge
                    for _, runner in ipairs(self._roundState.Runners) do
                        if not self._roundState.TaggedPlayers[runner.UserId] then
                            local runnerChar = runner.Character
                            if runnerChar then
                                local runnerRoot = runnerChar:FindFirstChild("HumanoidRootPart")
                                if runnerRoot then
                                    local dist = (runnerRoot.Position - taggerRoot.Position).Magnitude
                                    if dist < nearestDist then
                                        nearestDist = dist
                                        nearestId = runner.UserId
                                    end
                                end
                            end
                        end
                    end
                    return nearestId
                end
            end
        end
    end

    return nil
end

-- Get all participants (real players + bots)
function RoundService:_getParticipants()
    local participants = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(participants, player)
    end
    for _, bot in ipairs(BotService:GetActiveBots()) do
        table.insert(participants, bot)
    end
    return participants
end

-- Safe FireClient that skips bots
function RoundService:_fireClient(participant, ...)
    if isBot(participant) then
        return
    end
    self._roundStateEvent:FireClient(participant, ...)
end

-- Find a participant (player or bot) by UserId
function RoundService:_findParticipant(userId)
    local player = Players:GetPlayerByUserId(userId)
    if player then
        return player
    end
    for _, bot in ipairs(BotService:GetActiveBots()) do
        if bot.UserId == userId then
            return bot
        end
    end
    return nil
end

-- Remove a disconnected player from round state
function RoundService:RemoveParticipant(player)
    if not self._roundState then
        return
    end

    -- Remove from Taggers
    for i, tagger in ipairs(self._roundState.Taggers) do
        if tagger.UserId == player.UserId then
            table.remove(self._roundState.Taggers, i)
            print("[RoundService] Removed tagger from round:", player.Name)
            break
        end
    end

    -- Remove from Runners and mark as tagged (they're gone)
    for i, runner in ipairs(self._roundState.Runners) do
        if runner.UserId == player.UserId then
            table.remove(self._roundState.Runners, i)
            self._roundState.TaggedPlayers[player.UserId] = true
            print("[RoundService] Removed runner from round:", player.Name)
            break
        end
    end

    -- Clean up per-player state
    self._tagCooldowns[player.UserId] = nil
    self._roundStats[player.UserId] = nil
    PowerupService:RemovePlayer(player.UserId)
end

-- Called by BotService when a bot is close enough to tag
function RoundService:BotTag(taggerBot, targetCharacter)
    if not self._roundState or self._currentPhase ~= Constants.PHASES.PLAYING then
        return
    end

    -- Find the target's UserId from their character
    local targetUserId = nil
    for _, runner in ipairs(self._roundState.Runners) do
        if runner.Character == targetCharacter then
            targetUserId = runner.UserId
            break
        end
    end

    if targetUserId then
        self:_handleTag(taggerBot, targetUserId)
    end
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
        PowerupService:OnRoundEnd()
        self:_processResults()
        BotService:StopAllAI()
        task.wait(Constants.RESULTS_DISPLAY_TIME)

        -- Intermission phase: teleport all players back to lobby
        self:_setPhase(Constants.PHASES.INTERMISSION)
        for _, participant in ipairs(self:_getParticipants()) do
            MapService:TeleportToLobby(participant)
        end
        for i = Constants.INTERMISSION_TIME, 1, -1 do
            self._roundStateEvent:FireAllClients({
                phase = Constants.PHASES.INTERMISSION,
                timeRemaining = i,
            })
            task.wait(1)
        end

        -- Clean up round state
        self._roundState = nil
        self._tagCooldowns = {}
        self._roundStats = {}

        -- Reset all participant speeds
        for _, participant in ipairs(self:_getParticipants()) do
            self:_setWalkSpeed(participant, Constants.DEFAULT_WALK_SPEED)
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
    -- Wait until we have enough total participants (real players + bots)
    while #self:_getParticipants() < Constants.MIN_PLAYERS do
        self._roundStateEvent:FireAllClients({
            phase = Constants.PHASES.LOBBY,
            lobbyStatus = "waiting",
            playerCount = #self:_getParticipants(),
            targetCount = Constants.MIN_PLAYERS,
        })
        task.wait(1)
    end

    -- Wait the lobby time once we have enough
    for i = Constants.LOBBY_WAIT_TIME, 1, -1 do
        self._roundStateEvent:FireAllClients({
            phase = Constants.PHASES.LOBBY,
            lobbyStatus = "starting",
            playerCount = #self:_getParticipants(),
            targetCount = Constants.MIN_PLAYERS,
            timeRemaining = i,
        })
        task.wait(1)
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
    local participants = self:_getParticipants()
    if #participants < Constants.MIN_PLAYERS then
        return
    end

    -- Shuffle and assign roles (prefer real players as tagger for better experience)
    local shuffled = Utils.Shuffle(participants)
    local taggers = {}
    local runners = {}

    for i, participant in ipairs(shuffled) do
        if i <= Constants.TAGGERS_PER_ROUND then
            table.insert(taggers, participant)
        else
            table.insert(runners, participant)
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

    -- Initialize per-participant round stats
    self._roundStats = {}
    for _, participant in ipairs(participants) do
        self._roundStats[participant.UserId] = {
            tagsPerformed = 0,
            survivedSeconds = 0,
        }
    end

    -- Start powerup spawning
    PowerupService:OnRoundStart()

    -- Teleport runners to spawn points
    for _, runner in ipairs(runners) do
        MapService:TeleportPlayerToSpawn(runner, Constants.ROLES.RUNNER)
        self:_setWalkSpeed(runner, Constants.DEFAULT_WALK_SPEED)
    end

    -- Notify real clients of role assignments (bots don't need UI)
    local clientRoundState = self:_getClientRoundState()
    for _, participant in ipairs(taggers) do
        self:_fireClient(participant, {
            phase = Constants.PHASES.PLAYING,
            role = Constants.ROLES.TAGGER,
            roundState = clientRoundState,
        })
    end

    for _, participant in ipairs(runners) do
        self:_fireClient(participant, {
            phase = Constants.PHASES.PLAYING,
            role = Constants.ROLES.RUNNER,
            roundState = clientRoundState,
        })
    end

    -- Start bot AI for runner bots immediately
    for _, runner in ipairs(runners) do
        if isBot(runner) then
            BotService:StartAI(runner, Constants.ROLES.RUNNER, self._roundState)
        end
    end

    -- Tagger gets a head start delay, then teleports and gets speed boost
    task.delay(Constants.TAGGER_SPAWN_DELAY, function()
        for _, tagger in ipairs(taggers) do
            MapService:TeleportPlayerToSpawn(tagger, Constants.ROLES.TAGGER)
            self:_setWalkSpeed(tagger, Constants.DEFAULT_WALK_SPEED + Constants.TAGGER_SPEED_BOOST)

            -- Start bot AI for tagger bots
            if isBot(tagger) then
                BotService:StartAI(tagger, Constants.ROLES.TAGGER, self._roundState)
            end
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

        -- Broadcast timer update to real clients
        self._roundStateEvent:FireAllClients({
            phase = Constants.PHASES.PLAYING,
            timeRemaining = self._roundTimer,
            roundState = self:_getClientRoundState(),
        })

        -- Check if round should end early
        if self:_allRunnersTagged() or self:_allTaggersGone() or #self._roundState.Runners == 0 then
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
    local targetParticipant = self:_findParticipant(targetUserId)
    if not targetParticipant then
        return
    end
    local targetChar = targetParticipant.Character

    if not taggerChar or not targetChar then
        return
    end

    local taggerRoot = taggerChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not taggerRoot or not targetRoot then
        return
    end

    local distance = (taggerRoot.Position - targetRoot.Position).Magnitude
    -- Bots don't need network tolerance, but keep it consistent
    if distance > Constants.TAG_RANGE * Constants.TAG_RANGE_TOLERANCE then
        return
    end

    -- Check if target has a Shield powerup
    if PowerupService:HasShield(targetUserId) then
        PowerupService:ConsumeShield(targetUserId)
        self._tagCooldowns[tagger.UserId] = os.clock()
        return
    end

    -- Perform the tag
    self._roundState.TaggedPlayers[targetUserId] = true
    self._tagCooldowns[tagger.UserId] = now
    print("[RoundService]", tagger.Name, "tagged", targetParticipant.Name)

    -- Update round stats
    if self._roundStats[tagger.UserId] then
        self._roundStats[tagger.UserId].tagsPerformed = self._roundStats[tagger.UserId].tagsPerformed + 1
    end

    -- Freeze the tagged participant
    self:_freezePlayer(targetParticipant)

    -- Stop AI for tagged bot runners
    if isBot(targetParticipant) then
        BotService:StopAI(targetParticipant)
    end

    -- Notify all real clients
    self._roundStateEvent:FireAllClients({
        phase = Constants.PHASES.PLAYING,
        tagEvent = {
            tagger = tagger.UserId,
            tagged = targetUserId,
        },
        roundState = self:_getClientRoundState(),
    })
end

function RoundService:_freezePlayer(participant)
    if not participant.Character then
        return
    end

    local humanoidRootPart = participant.Character:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        humanoidRootPart.Anchored = true
    end

    -- Unfreeze after FREEZE_DURATION and transition to spectator
    -- Minimal rig bots (IsMinimalRig) stay anchored since they use PivotTo movement
    task.delay(Constants.FREEZE_DURATION, function()
        if not participant.Character then
            return
        end
        local isMinimalRigBot = isBot(participant) and participant.IsMinimalRig
        if not isMinimalRigBot then
            local root = participant.Character:FindFirstChild("HumanoidRootPart")
            if root then
                root.Anchored = false
            end
        end

        -- Transition tagged player to spectator role (real players only)
        if not isBot(participant) and self._currentPhase == Constants.PHASES.PLAYING then
            self:_fireClient(participant, {
                phase = Constants.PHASES.PLAYING,
                role = Constants.ROLES.SPECTATOR,
            })
        end
    end)
end

function RoundService:_setWalkSpeed(participant, speed)
    if not participant.Character then
        return
    end

    local humanoid = participant.Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = speed
    end
end

function RoundService:_processResults()
    if not self._roundState then
        return
    end

    local taggersGone = self:_allTaggersGone()
    local taggerWon = self:_allRunnersTagged() and not taggersGone
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

        -- Only update persistent data for real players (not bots)
        if not isBot(tagger) then
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

        -- Only update persistent data for real players (not bots)
        if not isBot(runner) then
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
    end

    -- Broadcast results to all real clients
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

function RoundService:_allTaggersGone()
    if not self._roundState then
        return true
    end

    return #self._roundState.Taggers == 0
end

return RoundService
