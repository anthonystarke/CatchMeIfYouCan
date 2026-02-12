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

    -- Find immune player (if any)
    local immunePlayerId = nil
    if self._roundState.immuneUntil then
        for userId, expiry in pairs(self._roundState.immuneUntil) do
            if os.clock() < expiry then
                immunePlayerId = userId
                break
            end
        end
    end

    return {
        Taggers = clientTaggers,
        Runners = clientRunners,
        tagCount = self._roundState.tagCount or 0,
        maxTags = Constants.MAX_TAGS_PER_ROUND,
        immunePlayerId = immunePlayerId,
        RoundStartTime = self._roundState.RoundStartTime,
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
        if isBot(tagger) and tagger._stateMachine and tagger._stateMachine.committed_target then
            local target = tagger._stateMachine.committed_target
            if target.Parent then
                -- Find the runner UserId that owns this HumanoidRootPart
                local runner = Utils.Find(self._roundState.Runners, function(r)
                    return r.Character and r.Character:FindFirstChild("HumanoidRootPart") == target
                end)
                if runner then
                    return runner.UserId
                end
            end
        end

        -- Real player tagger: find nearest runner
        if not isBot(tagger) then
            local taggerChar = tagger.Character
            if taggerChar then
                local taggerRoot = taggerChar:FindFirstChild("HumanoidRootPart")
                if taggerRoot then
                    local nearestId = nil
                    local nearestDist = math.huge
                    for _, runner in ipairs(self._roundState.Runners) do
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
    local _, wasTheTagger = Utils.RemoveByKey(self._roundState.Taggers, "UserId", player.UserId)
    if wasTheTagger then
        print("[RoundService] Removed tagger from round:", player.Name)
    end

    -- Remove from Runners
    local _, wasRunner = Utils.RemoveByKey(self._roundState.Runners, "UserId", player.UserId)
    if wasRunner then
        print("[RoundService] Removed runner from round:", player.Name)
    end

    -- If the tagger disconnected, promote a random runner to tagger
    if wasTheTagger and #self._roundState.Runners > 0 then
        local idx = math.random(#self._roundState.Runners)
        local newTagger = table.remove(self._roundState.Runners, idx)
        table.insert(self._roundState.Taggers, newTagger)
        self:_setWalkSpeed(newTagger, Constants.DEFAULT_WALK_SPEED + Constants.TAGGER_SPEED_BOOST)
        print("[RoundService] Promoted", newTagger.Name, "to tagger (previous tagger disconnected)")

        -- Restart bot AI if needed
        if isBot(newTagger) then
            BotService:SwapRole(newTagger, Constants.ROLES.TAGGER, self._roundState)
        end

        -- Notify clients of the new tagger
        self:_fireClient(newTagger, {
            phase = Constants.PHASES.PLAYING,
            role = Constants.ROLES.TAGGER,
            roundState = self:_getClientRoundState(),
        })

        -- Broadcast updated round state to all
        self._roundStateEvent:FireAllClients({
            phase = Constants.PHASES.PLAYING,
            roundState = self:_getClientRoundState(),
        })
    end

    -- Clean up per-player state
    self._tagCooldowns[player.UserId] = nil
    self._roundStats[player.UserId] = nil
    if self._roundState.immuneUntil then
        self._roundState.immuneUntil[player.UserId] = nil
    end
    PowerupService:RemovePlayer(player.UserId)
end

-- Called by BotService when a bot is close enough to tag
function RoundService:BotTag(taggerBot, targetCharacter)
    if not self._roundState or self._currentPhase ~= Constants.PHASES.PLAYING then
        return
    end

    -- Find the target's UserId from their character
    local targetRunner = Utils.Find(self._roundState.Runners, function(runner)
        return runner.Character == targetCharacter
    end)
    local targetUserId = targetRunner and targetRunner.UserId

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

    -- Shuffle and assign roles: 1 tagger, rest are runners
    local shuffled = Utils.Shuffle(participants)
    local tagger = shuffled[1]
    local runners = {}

    for i = 2, #shuffled do
        table.insert(runners, shuffled[i])
    end

    -- Create round state (hot potato model)
    self._roundState = {
        Taggers = { tagger },
        Runners = runners,
        tagCount = 0,
        immuneUntil = {},
        RoundStartTime = os.time(),
    }

    -- Initialize per-participant round stats
    self._roundStats = {}
    for _, participant in ipairs(participants) do
        self._roundStats[participant.UserId] = {
            tagsPerformed = 0,
            timeAsRunner = 0,
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
    self:_fireClient(tagger, {
        phase = Constants.PHASES.PLAYING,
        role = Constants.ROLES.TAGGER,
        roundState = clientRoundState,
    })

    for _, runner in ipairs(runners) do
        self:_fireClient(runner, {
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
        MapService:TeleportPlayerToSpawn(tagger, Constants.ROLES.TAGGER)
        self:_setWalkSpeed(tagger, Constants.DEFAULT_WALK_SPEED + Constants.TAGGER_SPEED_BOOST)

        -- Start bot AI for tagger bot
        if isBot(tagger) then
            BotService:StartAI(tagger, Constants.ROLES.TAGGER, self._roundState)
        end
    end)

    -- Main loop: runs until max tags reached (no timer)
    local elapsed = 0
    while self._roundState.tagCount < Constants.MAX_TAGS_PER_ROUND do
        task.wait(1)
        elapsed = elapsed + 1

        -- Track runner time for all current runners
        for _, runner in ipairs(self._roundState.Runners) do
            if self._roundStats[runner.UserId] then
                self._roundStats[runner.UserId].timeAsRunner = self._roundStats[runner.UserId].timeAsRunner + 1
            end
        end

        -- Broadcast state update to real clients
        self._roundStateEvent:FireAllClients({
            phase = Constants.PHASES.PLAYING,
            elapsed = elapsed,
            roundState = self:_getClientRoundState(),
        })

        -- Check if round should end early
        if self:_maxTagsReached() or self:_allTaggersGone() or #self._roundState.Runners == 0 then
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
    if not Utils.Contains(self._roundState.Taggers, "UserId", tagger.UserId) then
        return
    end

    -- Check tag cooldown
    local now = os.clock()
    if self._tagCooldowns[tagger.UserId] and (now - self._tagCooldowns[tagger.UserId]) < Constants.TAG_COOLDOWN then
        return
    end

    -- Check immunity (new tagger can't tag for TAG_SWAP_IMMUNITY seconds)
    if self._roundState.immuneUntil[tagger.UserId] and now < self._roundState.immuneUntil[tagger.UserId] then
        return
    end

    -- Check if target is a valid runner
    if not Utils.Contains(self._roundState.Runners, "UserId", targetUserId) then
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
    if distance > Constants.TAG_RANGE * Constants.TAG_RANGE_TOLERANCE then
        return
    end

    -- Check if target has a Shield powerup
    if PowerupService:HasShield(targetUserId) then
        PowerupService:ConsumeShield(targetUserId)
        self._tagCooldowns[tagger.UserId] = os.clock()
        return
    end

    -- Role swap: old tagger becomes runner, tagged runner becomes tagger
    self._tagCooldowns[tagger.UserId] = now
    print("[RoundService]", tagger.Name, "tagged", targetParticipant.Name, "- roles swapped!")

    -- Update round stats
    if self._roundStats[tagger.UserId] then
        self._roundStats[tagger.UserId].tagsPerformed = self._roundStats[tagger.UserId].tagsPerformed + 1
    end

    -- Increment tag count
    self._roundState.tagCount = self._roundState.tagCount + 1

    -- Move old tagger from Taggers → Runners
    Utils.RemoveByKey(self._roundState.Taggers, "UserId", tagger.UserId)
    table.insert(self._roundState.Runners, tagger)
    self:_setWalkSpeed(tagger, Constants.DEFAULT_WALK_SPEED)

    -- Move tagged runner from Runners → Taggers
    Utils.RemoveByKey(self._roundState.Runners, "UserId", targetUserId)
    table.insert(self._roundState.Taggers, targetParticipant)
    self:_setWalkSpeed(targetParticipant, Constants.DEFAULT_WALK_SPEED + Constants.TAGGER_SPEED_BOOST)

    -- Set immunity for new tagger
    self._roundState.immuneUntil[targetParticipant.UserId] = now + Constants.TAG_SWAP_IMMUNITY

    -- Handle bot role swaps
    if isBot(tagger) then
        BotService:SwapRole(tagger, Constants.ROLES.RUNNER, self._roundState)
    end
    if isBot(targetParticipant) then
        BotService:SwapRole(targetParticipant, Constants.ROLES.TAGGER, self._roundState)
    end

    -- Build client state once (avoids 3 redundant rebuilds)
    local clientRoundState = self:_getClientRoundState()

    -- Fire individual role assignments to affected real players
    self:_fireClient(tagger, {
        phase = Constants.PHASES.PLAYING,
        role = Constants.ROLES.RUNNER,
        roundState = clientRoundState,
    })
    self:_fireClient(targetParticipant, {
        phase = Constants.PHASES.PLAYING,
        role = Constants.ROLES.TAGGER,
        roundState = clientRoundState,
    })

    -- Broadcast tag event to ALL clients
    self._roundStateEvent:FireAllClients({
        phase = Constants.PHASES.PLAYING,
        tagEvent = {
            tagger = tagger.UserId,
            tagged = targetUserId,
        },
        roundState = clientRoundState,
    })
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

    local scores = {}
    local bestPoints = -1
    local winnerId = nil

    -- Score all participants (everyone played both roles during the round)
    local allParticipants = {}
    for _, t in ipairs(self._roundState.Taggers) do
        table.insert(allParticipants, t)
    end
    for _, r in ipairs(self._roundState.Runners) do
        table.insert(allParticipants, r)
    end

    for _, participant in ipairs(allParticipants) do
        local stats = self._roundStats[participant.UserId]
        local tagsCount = stats and stats.tagsPerformed or 0
        local runnerTime = stats and stats.timeAsRunner or 0
        local points = (runnerTime * Constants.POINTS_PER_SECOND_ALIVE) + (tagsCount * Constants.POINTS_PER_TAG)
        local coins = (tagsCount * Constants.COINS_PER_TAG) + Constants.COINS_PER_ROUND

        if points > bestPoints then
            bestPoints = points
            winnerId = participant.UserId
        end

        scores[participant.UserId] = {
            tags = tagsCount,
            timeAsRunner = runnerTime,
            points = points,
            coins = coins,
            won = false, -- Set below for winner
        }

        -- Only update persistent data for real players (not bots)
        if not isBot(participant) then
            local data = DataService:GetData(participant)
            if data then
                data.Stats.RoundsPlayed = data.Stats.RoundsPlayed + 1
                data.Stats.TotalTags = data.Stats.TotalTags + tagsCount
                data.Stats.TotalPoints = data.Stats.TotalPoints + points
                DataService:AddCoins(participant, coins)
            end
        end
    end

    -- Mark the winner
    if winnerId and scores[winnerId] then
        scores[winnerId].won = true
        scores[winnerId].coins = scores[winnerId].coins + Constants.COINS_PER_WIN
        -- Award bonus coins to winner
        local winner = self:_findParticipant(winnerId)
        if winner and not isBot(winner) then
            DataService:AddCoins(winner, Constants.COINS_PER_WIN)
        end
    end

    -- Broadcast results to all real clients
    self._roundStateEvent:FireAllClients({
        phase = Constants.PHASES.RESULTS,
        results = scores,
    })

    print("[RoundService] Round complete! Tags:", self._roundState.tagCount, "Winner:", winnerId or "none")
end

function RoundService:_maxTagsReached()
    if not self._roundState then
        return true
    end

    return self._roundState.tagCount >= Constants.MAX_TAGS_PER_ROUND
end

function RoundService:_allTaggersGone()
    if not self._roundState then
        return true
    end

    return #self._roundState.Taggers == 0
end

return RoundService
