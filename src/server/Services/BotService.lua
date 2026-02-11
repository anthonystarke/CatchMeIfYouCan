--[[
    BotService
    Manages AI bots: spawning, character creation, movement AI, auto-fill logic
    Bots act as participants in rounds alongside real players.
    Uses a Creator Store NPC model with idle/walk/run animations.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))

local BotService = {}

-- State
BotService._bots = {} -- Array of active bot objects
BotService._nextBotId = -1 -- Negative UserId to avoid collision with real players
BotService._aiThreads = {} -- {[botUserId]: thread}
BotService._usedNames = {} -- Track which names are in use
BotService._roundService = nil -- Set during Start

-- Personality list for random assignment
local PERSONALITY_LIST = {
    Constants.BOT_PERSONALITIES.CAUTIOUS,
    Constants.BOT_PERSONALITIES.BOLD,
    Constants.BOT_PERSONALITIES.TRICKY,
}

-- Asset caching
BotService._modelTemplate = nil -- Cached NPC model to clone
BotService._isR15 = false -- Whether the template is R15
BotService._animationIds = { idle = nil, walk = nil, run = nil }
BotService._botAnimTracks = {} -- {[botUserId]: {idle, walk, run, current}}

-- Bot ground height for minimal rig PivotTo movement
local BOT_GROUND_Y = 3

function BotService:Init()
    print("[BotService] Initializing...")
    self:_loadModelTemplate()
    self:_loadAnimations()
end

function BotService:Start()
    print("[BotService] Starting...")

    -- Auto-fill: check player count when players join or leave
    Players.PlayerAdded:Connect(function()
        self:_onPlayerCountChanged()
    end)

    Players.PlayerRemoving:Connect(function()
        -- Delay slightly so the player is actually removed from GetPlayers()
        task.delay(0.1, function()
            self:_onPlayerCountChanged()
        end)
    end)

    -- Initial check
    self:_onPlayerCountChanged()
end

function BotService:SetRoundService(roundService)
    self._roundService = roundService
end

-- Asset Loading

function BotService:_loadModelTemplate()
    local model = ServerStorage:FindFirstChild("Mr Brookhaven")
    if not model then
        warn("[BotService] No 'Mr Brookhaven' found in ServerStorage, will fall back to R6 rig")
        return
    end

    if not model:IsA("Model") then
        warn("[BotService] 'Mr Brookhaven' is not a Model, it's a", model.ClassName)
        return
    end

    self._modelTemplate = model

    -- Detect actual rig type from Humanoid
    local humanoid = model:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        self._isR15 = (humanoid.RigType == Enum.HumanoidRigType.R15)
        print("[BotService] Template rig type:", humanoid.RigType.Name)
    end

    local partCount, motorCount = 0, 0
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then
            partCount = partCount + 1
        elseif desc:IsA("Motor6D") then
            motorCount = motorCount + 1
        end
    end
    print("[BotService] Loaded template - parts:", partCount, "Motor6D joints:", motorCount)
end

function BotService:_loadAnimations()
    local animName = self._isR15 and "R15 Animation" or "R6 Animation"
    local animAsset = ServerStorage:FindFirstChild(animName)

    if animAsset then
        -- Log contents so we can see what's inside
        print("[BotService] Inspecting", animName, "contents:")
        for _, desc in ipairs(animAsset:GetDescendants()) do
            print("  -", desc.Name, "(" .. desc.ClassName .. ")",
                desc:IsA("Animation") and ("AnimationId: " .. desc.AnimationId) or "")
        end

        -- Search all descendants for Animation instances
        for _, desc in ipairs(animAsset:GetDescendants()) do
            if desc:IsA("Animation") then
                local name = desc.Name:lower()
                if name:find("idle") and not self._animationIds.idle then
                    self._animationIds.idle = desc.AnimationId
                elseif name:find("run") and not self._animationIds.run then
                    self._animationIds.run = desc.AnimationId
                elseif name:find("walk") and not self._animationIds.walk then
                    self._animationIds.walk = desc.AnimationId
                end
            end
        end
    else
        warn("[BotService] No '" .. animName .. "' found in ServerStorage, using defaults")
    end

    -- Apply rig-type-aware fallback defaults for any missing animations
    if not self._animationIds.idle then
        self._animationIds.idle = self._isR15 and Constants.BOT_ANIM_IDLE_R15 or Constants.BOT_ANIM_IDLE_R6
    end
    if not self._animationIds.walk then
        self._animationIds.walk = self._isR15 and Constants.BOT_ANIM_WALK_R15 or Constants.BOT_ANIM_WALK_R6
    end
    if not self._animationIds.run then
        self._animationIds.run = self._isR15 and Constants.BOT_ANIM_RUN_R15 or Constants.BOT_ANIM_RUN_R6
    end

    print("[BotService] Animation IDs - idle:", self._animationIds.idle, "walk:", self._animationIds.walk, "run:", self._animationIds.run)
end

-- Auto-fill logic: maintain BOT_FILL_TARGET total participants
function BotService:_onPlayerCountChanged()
    local realPlayerCount = #Players:GetPlayers()
    local currentBotCount = #self._bots
    local totalParticipants = realPlayerCount + currentBotCount
    local target = Constants.BOT_FILL_TARGET

    if totalParticipants < target then
        local botsNeeded = target - totalParticipants
        for _ = 1, botsNeeded do
            self:SpawnBot()
        end
    elseif realPlayerCount >= target and currentBotCount > 0 then
        self:RemoveAllBots()
    elseif totalParticipants > target and currentBotCount > 0 then
        local excess = totalParticipants - target
        local toRemove = math.min(excess, currentBotCount)
        for _ = 1, toRemove do
            self:RemoveBot()
        end
    end
end

function BotService:SpawnBot()
    local botId = self._nextBotId
    self._nextBotId = self._nextBotId - 1

    local botName = self:_pickBotName()

    local character, isMinimalRig = self:_createCharacter(botName)
    if not character then
        warn("[BotService] Failed to create character for", botName)
        return nil
    end

    -- Assign random personality
    local personality = PERSONALITY_LIST[math.random(1, #PERSONALITY_LIST)]
    local personalityStats = Constants.PERSONALITY_STATS[personality]
    if not personalityStats then
        warn("[BotService] No stats for personality", personality, "- defaulting to Tricky")
        personality = Constants.BOT_PERSONALITIES.TRICKY
        personalityStats = Constants.PERSONALITY_STATS[personality]
    end

    local bot = {
        UserId = botId,
        Name = botName,
        Character = character,
        IsBot = true,
        IsMinimalRig = isMinimalRig,
        Personality = personality,
        PersonalityStats = personalityStats,
        -- AI state (initialized fresh each round via StartAI)
        TaggerState = {
            committed_target = nil,
            committed_since = 0,
            reaction_ready_at = 0,
            wander_target = nil,
            wander_started = 0,
        },
        RunnerState = {
            wander_target = nil,
            wander_started = 0,
            reaction_ready_at = 0,
            last_threat = nil,
            last_threat_dist = math.huge,
        },
    }

    table.insert(self._bots, bot)

    -- Set up animations (only for proper rigs, not minimal)
    if not isMinimalRig then
        self:_setupAnimations(bot)
    end

    print("[BotService] Spawned bot:", botName, "(ID:", botId, ") personality:", personality, "minimal:", isMinimalRig)
    return bot
end

function BotService:RemoveBot(specificBot)
    local bot = specificBot
    if not bot and #self._bots > 0 then
        bot = self._bots[#self._bots]
    end

    if not bot then
        return
    end

    self:StopAI(bot)
    self:_cleanupAnimations(bot)

    if bot.Character then
        bot.Character:Destroy()
    end

    for i, b in ipairs(self._bots) do
        if b.UserId == bot.UserId then
            table.remove(self._bots, i)
            break
        end
    end

    self._usedNames[bot.Name] = nil
    print("[BotService] Removed bot:", bot.Name)
end

function BotService:RemoveAllBots()
    while #self._bots > 0 do
        self:RemoveBot()
    end
end

function BotService:GetActiveBots()
    return self._bots
end

function BotService:IsBot(participant)
    return participant.IsBot == true
end

-- Character Creation

function BotService:_createCharacter(name)
    -- Try cloning the loaded NPC model template (proper R15 rig)
    if self._modelTemplate then
        local character = self:_createFromTemplate(name)
        if character then
            return character, false
        end
    end

    -- Fallback: create a proper R6 rig via CreateHumanoidModelFromDescription
    local success, model = pcall(function()
        local description = Instance.new("HumanoidDescription")
        return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
    end)

    if success and model then
        model.Name = name
        model.Parent = Workspace

        local humanoid = model:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = Constants.DEFAULT_WALK_SPEED
            humanoid.DisplayName = name
        end

        print("[BotService] Created R6 fallback rig for", name)
        return model, false
    end

    -- Last resort: minimal anchored rig
    warn("[BotService] All rig creation failed, creating minimal rig for", name)
    local minimal = self:_createMinimalCharacter(name)
    return minimal, true
end

function BotService:_createFromTemplate(name)
    local cloneSuccess, model = pcall(function()
        return self._modelTemplate:Clone()
    end)
    if not cloneSuccess or not model then
        warn("[BotService] Failed to clone template:", model)
        return nil
    end

    model.Name = name

    -- Unanchor all parts so Humanoid:MoveTo() works (Motor6D joints hold them together)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
        end
    end

    local humanoid = model:FindFirstChildWhichIsA("Humanoid")
    if not humanoid then
        humanoid = Instance.new("Humanoid")
        humanoid.Parent = model
    end
    humanoid.WalkSpeed = Constants.DEFAULT_WALK_SPEED
    humanoid.DisplayName = name

    -- Ensure PrimaryPart is set
    if not model.PrimaryPart then
        local rootPart = model:FindFirstChild("HumanoidRootPart")
        if rootPart then
            model.PrimaryPart = rootPart
        else
            warn("[BotService] No HumanoidRootPart found in cloned model!")
        end
    end

    model.Parent = Workspace

    -- Move bot above ground — template position is from ServerStorage and likely underground
    if model.PrimaryPart then
        model:PivotTo(CFrame.new(
            math.random(-20, 20),
            5,
            math.random(-20, 20)
        ))
    end

    print("[BotService] Created character from template for", name)
    return model
end

function BotService:_createMinimalCharacter(name)
    local model = Instance.new("Model")
    model.Name = name

    local rootPart = Instance.new("Part")
    rootPart.Name = "HumanoidRootPart"
    rootPart.Size = Vector3.new(2, 2, 1)
    rootPart.Position = Vector3.new(0, 3, 0)
    rootPart.Anchored = true
    rootPart.CanCollide = true
    rootPart.Transparency = 1
    rootPart.Parent = model

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(2, 2, 2)
    head.Position = Vector3.new(0, 4.5, 0)
    head.Anchored = true
    head.CanCollide = false
    head.Color = Color3.fromRGB(245, 205, 140)
    head.Parent = model

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.Position = Vector3.new(0, 3, 0)
    torso.Anchored = true
    torso.CanCollide = false
    torso.Color = Color3.fromRGB(40, 120, 200)
    torso.Parent = model

    local humanoid = Instance.new("Humanoid")
    humanoid.WalkSpeed = Constants.DEFAULT_WALK_SPEED
    humanoid.DisplayName = name
    humanoid.Parent = model

    local nameLabel = Instance.new("BillboardGui")
    nameLabel.Name = "BotNametag"
    nameLabel.Size = UDim2.new(0, 100, 0, 30)
    nameLabel.StudsOffset = Vector3.new(0, 3, 0)
    nameLabel.Adornee = head
    nameLabel.Parent = head

    local textLabel = Instance.new("TextLabel")
    textLabel.Text = name
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextStrokeTransparency = 0.5
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 14
    textLabel.Parent = nameLabel

    model.PrimaryPart = rootPart
    model.Parent = Workspace

    return model
end

-- Animation Management

function BotService:_setupAnimations(bot)
    local humanoid = bot.Character and bot.Character:FindFirstChildWhichIsA("Humanoid")
    if not humanoid then
        warn("[BotService] No humanoid for animation setup on", bot.Name)
        return
    end

    -- Get or create Animator
    local animator = humanoid:FindFirstChildWhichIsA("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    -- Create and load animation tracks
    local tracks = {}
    local success, err

    local idleAnim = Instance.new("Animation")
    idleAnim.AnimationId = self._animationIds.idle
    success, err = pcall(function()
        tracks.idle = animator:LoadAnimation(idleAnim)
        tracks.idle.Looped = true
        tracks.idle.Priority = Enum.AnimationPriority.Idle
    end)
    if not success then
        warn("[BotService] Failed to load idle animation:", err)
    end

    local walkAnim = Instance.new("Animation")
    walkAnim.AnimationId = self._animationIds.walk
    success, err = pcall(function()
        tracks.walk = animator:LoadAnimation(walkAnim)
        tracks.walk.Looped = true
        tracks.walk.Priority = Enum.AnimationPriority.Movement
    end)
    if not success then
        warn("[BotService] Failed to load walk animation:", err)
    end

    local runAnim = Instance.new("Animation")
    runAnim.AnimationId = self._animationIds.run
    success, err = pcall(function()
        tracks.run = animator:LoadAnimation(runAnim)
        tracks.run.Looped = true
        tracks.run.Priority = Enum.AnimationPriority.Movement
    end)
    if not success then
        warn("[BotService] Failed to load run animation:", err)
    end

    tracks.current = nil
    self._botAnimTracks[bot.UserId] = tracks

    -- No Humanoid.Running listener — animations are driven directly from the AI loop
    -- Start with idle
    self:_playBotAnimation(bot, "idle")
    print("[BotService] Animation setup complete for", bot.Name)
end

function BotService:_playBotAnimation(bot, animName)
    local tracks = self._botAnimTracks[bot.UserId]
    if not tracks then
        return
    end

    -- Skip if already playing this animation
    if tracks.current == animName then
        return
    end

    -- Stop current animation with short fade
    if tracks.current and tracks[tracks.current] then
        tracks[tracks.current]:Stop(0.2)
    end

    -- Play new animation with short fade
    if tracks[animName] then
        tracks[animName]:Play(0.2)
    end
    tracks.current = animName
end

function BotService:_cleanupAnimations(bot)
    local tracks = self._botAnimTracks[bot.UserId]
    if tracks then
        for key, track in pairs(tracks) do
            if key ~= "current" then
                pcall(function() track:Stop() end)
            end
        end
        self._botAnimTracks[bot.UserId] = nil
    end
end

function BotService:_pickBotName()
    for _, name in ipairs(Constants.BOT_NAMES) do
        if not self._usedNames[name] then
            self._usedNames[name] = true
            return name
        end
    end
    local name = "Bot_" .. math.abs(self._nextBotId)
    self._usedNames[name] = true
    return name
end

-- Movement

function BotService:_moveBot(bot, targetPos)
    if bot.IsMinimalRig then
        self:_moveBotPivot(bot, targetPos)
    else
        self:_moveBotHumanoid(bot, targetPos)
    end
end

function BotService:_moveBotHumanoid(bot, targetPos)
    local humanoid = bot.Character and bot.Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:MoveTo(targetPos)
    end
end

function BotService:_moveBotPivot(bot, targetPos)
    if not bot.Character or not bot.Character.PrimaryPart then
        return
    end

    local rootPart = bot.Character.PrimaryPart
    local humanoid = bot.Character:FindFirstChild("Humanoid")
    local speed = humanoid and humanoid.WalkSpeed or Constants.DEFAULT_WALK_SPEED

    local currentPos = rootPart.Position
    local direction = Vector3.new(targetPos.X - currentPos.X, 0, targetPos.Z - currentPos.Z)

    if direction.Magnitude < 0.5 then
        return
    end

    local moveDir = direction.Unit
    local moveDistance = math.min(speed * Constants.BOT_UPDATE_INTERVAL, direction.Magnitude)
    local newPos = Vector3.new(
        currentPos.X + moveDir.X * moveDistance,
        BOT_GROUND_Y,
        currentPos.Z + moveDir.Z * moveDistance
    )

    bot.Character:PivotTo(CFrame.new(newPos, newPos + moveDir))
end

-- Direct movement: move straight toward target position
function BotService:_navigateTo(bot, targetPos)
    self:_moveBot(bot, targetPos)
end

-- AI Control

function BotService:StartAI(bot, role, roundState)
    self:StopAI(bot)

    -- Ensure HumanoidRootPart is unanchored for proper rigs so MoveTo works.
    -- Can be left anchored from a previous round's freeze.
    if not bot.IsMinimalRig then
        local root = bot.Character and bot.Character:FindFirstChild("HumanoidRootPart")
        if root then
            root.Anchored = false
        end
    end

    -- Reset AI state for new round
    bot.TaggerState = {
        committed_target = nil,
        committed_since = 0,
        reaction_ready_at = 0,
        wander_target = nil,
        wander_started = 0,
        last_position = nil,
        stuck_since = 0,
        recovery_attempts = 0,
    }
    bot.RunnerState = {
        wander_target = nil,
        wander_started = 0,
        reaction_ready_at = 0,
        last_threat = nil,
        last_threat_dist = math.huge,
        last_position = nil,
        stuck_since = 0,
        recovery_attempts = 0,
    }

    print("[BotService] Starting AI for", bot.Name, "as", role, "(" .. bot.Personality .. ")")
    self._aiThreads[bot.UserId] = task.spawn(function()
        local success, err = pcall(function()
            if role == Constants.ROLES.TAGGER then
                self:_taggerAI(bot, roundState)
            else
                self:_runnerAI(bot, roundState)
            end
        end)
        if not success then
            warn("[BotService] AI error for", bot.Name, ":", err)
        end
    end)
end

function BotService:StopAI(bot)
    if self._aiThreads[bot.UserId] then
        task.cancel(self._aiThreads[bot.UserId])
        self._aiThreads[bot.UserId] = nil
    end

    self:_playBotAnimation(bot, "idle")
end

function BotService:StopAllAI()
    for botId, thread in pairs(self._aiThreads) do
        task.cancel(thread)
        self._aiThreads[botId] = nil
    end

    for _, bot in ipairs(self._bots) do
        self:_playBotAnimation(bot, "idle")
    end
end

-- Stuck Detection: returns true if bot hasn't moved and performs recovery
function BotService:_checkAndRecoverStuck(bot, state, botRoot)
    if not botRoot or not botRoot.Parent then
        return false
    end

    local now = os.clock()
    local currentPos = botRoot.Position

    if not state.last_position then
        state.last_position = currentPos
        state.stuck_since = now
        state.recovery_attempts = 0
        return false
    end

    local moved = (currentPos - state.last_position).Magnitude
    if moved >= Constants.BOT_STUCK_THRESHOLD then
        -- Bot moved, reset stuck timer and recovery counter
        state.last_position = currentPos
        state.stuck_since = now
        state.recovery_attempts = 0
        return false
    end

    -- Bot hasn't moved enough — check if stuck long enough to recover
    if (now - state.stuck_since) < Constants.BOT_STUCK_CHECK_INTERVAL then
        return false
    end

    -- Stuck! Attempt recovery
    state.recovery_attempts = (state.recovery_attempts or 0) + 1
    warn("[BotService]", bot.Name, "stuck at", currentPos, "- recovery attempt", state.recovery_attempts)

    -- 1. Unanchor root (most common cause for humanoid rigs, safe for all)
    botRoot.Anchored = false

    -- 2. Nudge position to escape physics wedges; escalate after repeated failures
    local nudgeScale = state.recovery_attempts > 3 and 12 or 4
    local jitter = Vector3.new(
        (math.random() - 0.5) * nudgeScale,
        0,
        (math.random() - 0.5) * nudgeScale
    )
    local nudgedPos = currentPos + jitter
    nudgedPos = Vector3.new(
        math.clamp(nudgedPos.X, -Constants.BOT_MAP_BOUNDS, Constants.BOT_MAP_BOUNDS),
        currentPos.Y,
        math.clamp(nudgedPos.Z, -Constants.BOT_MAP_BOUNDS, Constants.BOT_MAP_BOUNDS)
    )

    if bot.IsMinimalRig then
        bot.Character:PivotTo(CFrame.new(nudgedPos))
    else
        botRoot.CFrame = CFrame.new(nudgedPos)
    end

    -- 3. Reset tracking so we give the recovery a chance
    state.last_position = nudgedPos
    state.stuck_since = now
    state.wander_target = nil

    return true
end

function BotService:_taggerAI(bot, roundState)
    local humanoid = bot.Character and bot.Character:FindFirstChild("Humanoid")
    if not humanoid then
        warn("[BotService] No humanoid for tagger", bot.Name)
        return
    end

    local stats = bot.PersonalityStats
    humanoid.WalkSpeed = (Constants.DEFAULT_WALK_SPEED + Constants.TAGGER_SPEED_BOOST) * stats.speed_mult

    while true do
        if not bot.Character or not bot.Character.Parent then
            break
        end

        local botRoot = bot.Character:FindFirstChild("HumanoidRootPart")
        if not botRoot then
            break
        end

        local now = os.clock()
        local state = bot.TaggerState

        -- Stuck detection: recover if bot hasn't moved
        self:_checkAndRecoverStuck(bot, state, botRoot)

        -- Reassess targets on reaction timer
        if now >= state.reaction_ready_at then
            local nearestTarget = nil
            local nearestDist = math.huge

            if roundState and roundState.Runners then
                for _, runner in ipairs(roundState.Runners) do
                    if not roundState.TaggedPlayers[runner.UserId] then
                        local targetChar = runner.Character
                        if targetChar then
                            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                            if targetRoot then
                                local dist = (targetRoot.Position - botRoot.Position).Magnitude
                                if dist < nearestDist then
                                    nearestDist = dist
                                    nearestTarget = targetRoot
                                end
                            end
                        end
                    end
                end
            end

            -- Commit to target: only switch if no current target, current tagged,
            -- or commitment time expired
            local shouldSwitch = not state.committed_target
                or not state.committed_target.Parent
                or (now - state.committed_since) > stats.target_commit_secs

            if nearestTarget and shouldSwitch then
                state.committed_target = nearestTarget
                state.committed_since = now
            elseif not nearestTarget then
                state.committed_target = nil
            end

            state.reaction_ready_at = now + Constants.BOT_REACTION_DELAY_TAGGER * stats.reaction_delay_mult
        end

        -- Act on committed target or wander
        if state.committed_target and state.committed_target.Parent then
            local targetPos = state.committed_target.Position

            -- Personality affects chase precision: faster bots are more direct
            local offsetScale = 4 / math.max(stats.speed_mult, 0.5)
            local offset = Vector3.new(
                (math.random() - 0.5) * offsetScale,
                0,
                (math.random() - 0.5) * offsetScale
            )

            self:_playBotAnimation(bot, "run")
            self:_navigateTo(bot, targetPos + offset)

            -- Tag check
            local dist = (state.committed_target.Position - botRoot.Position).Magnitude
            if dist <= Constants.TAG_RANGE and self._roundService then
                self._roundService:BotTag(bot, state.committed_target.Parent)
            end
        else
            -- Wander with persistence
            self:_playBotAnimation(bot, "walk")

            if not state.wander_target or (now - state.wander_started) > stats.wander_persist_secs then
                state.wander_target = botRoot.Position + Vector3.new(
                    (math.random() - 0.5) * 30,
                    0,
                    (math.random() - 0.5) * 30
                )
                state.wander_target = Vector3.new(
                    math.clamp(state.wander_target.X, -Constants.BOT_MAP_BOUNDS, Constants.BOT_MAP_BOUNDS),
                    state.wander_target.Y,
                    math.clamp(state.wander_target.Z, -Constants.BOT_MAP_BOUNDS, Constants.BOT_MAP_BOUNDS)
                )
                state.wander_started = now
            end

            self:_navigateTo(bot, state.wander_target)
        end

        task.wait(Constants.BOT_UPDATE_INTERVAL)
    end
end

function BotService:_runnerAI(bot, roundState)
    local humanoid = bot.Character and bot.Character:FindFirstChild("Humanoid")
    if not humanoid then
        warn("[BotService] No humanoid for runner", bot.Name)
        return
    end

    local stats = bot.PersonalityStats
    humanoid.WalkSpeed = Constants.DEFAULT_WALK_SPEED * stats.speed_mult

    while true do
        if not bot.Character or not bot.Character.Parent then
            break
        end

        local botRoot = bot.Character:FindFirstChild("HumanoidRootPart")
        if not botRoot then
            break
        end

        -- Tagged: stop moving
        if roundState and roundState.TaggedPlayers[bot.UserId] then
            self:_playBotAnimation(bot, "idle")
            task.wait(Constants.BOT_UPDATE_INTERVAL)
            continue
        end

        local now = os.clock()
        local state = bot.RunnerState

        -- Stuck detection: recover if bot hasn't moved
        self:_checkAndRecoverStuck(bot, state, botRoot)

        -- Threat assessment on reaction timer
        if now >= state.reaction_ready_at then
            local nearestTagger = nil
            local nearestDist = math.huge

            if roundState and roundState.Taggers then
                for _, tagger in ipairs(roundState.Taggers) do
                    local taggerChar = tagger.Character
                    if taggerChar then
                        local taggerRoot = taggerChar:FindFirstChild("HumanoidRootPart")
                        if taggerRoot then
                            local dist = (taggerRoot.Position - botRoot.Position).Magnitude
                            if dist < nearestDist then
                                nearestDist = dist
                                nearestTagger = taggerRoot
                            end
                        end
                    end
                end
            end

            state.last_threat = nearestTagger
            state.last_threat_dist = nearestDist

            state.reaction_ready_at = now + Constants.BOT_REACTION_DELAY_RUNNER * stats.reaction_delay_mult
        end

        -- Personality-adjusted flee distance
        local fleeThreshold = Constants.BOT_FLEE_DISTANCE * stats.flee_distance_mult

        if state.last_threat and state.last_threat.Parent and state.last_threat_dist < fleeThreshold then
            -- Flee: run directly away from tagger
            state.wander_target = nil
            self:_playBotAnimation(bot, "run")

            local fleeDir = (botRoot.Position - state.last_threat.Position)
            fleeDir = Vector3.new(fleeDir.X, 0, fleeDir.Z)
            if fleeDir.Magnitude > 0.1 then
                fleeDir = fleeDir.Unit
            else
                fleeDir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
            end

            local randomOffset = Vector3.new(
                (math.random() - 0.5) * Constants.BOT_RANDOM_OFFSET,
                0,
                (math.random() - 0.5) * Constants.BOT_RANDOM_OFFSET
            )
            local fleeTarget = botRoot.Position + fleeDir * 20 + randomOffset
            fleeTarget = Vector3.new(
                math.clamp(fleeTarget.X, -Constants.BOT_MAP_BOUNDS, Constants.BOT_MAP_BOUNDS),
                fleeTarget.Y,
                math.clamp(fleeTarget.Z, -Constants.BOT_MAP_BOUNDS, Constants.BOT_MAP_BOUNDS)
            )

            self:_navigateTo(bot, fleeTarget)
        else
            -- Wander with persistence
            self:_playBotAnimation(bot, "walk")

            if not state.wander_target or (now - state.wander_started) > stats.wander_persist_secs then
                state.wander_target = botRoot.Position + Vector3.new(
                    (math.random() - 0.5) * 20,
                    0,
                    (math.random() - 0.5) * 20
                )
                state.wander_target = Vector3.new(
                    math.clamp(state.wander_target.X, -Constants.BOT_MAP_BOUNDS, Constants.BOT_MAP_BOUNDS),
                    state.wander_target.Y,
                    math.clamp(state.wander_target.Z, -Constants.BOT_MAP_BOUNDS, Constants.BOT_MAP_BOUNDS)
                )
                state.wander_started = now
            end

            self:_navigateTo(bot, state.wander_target)
        end

        task.wait(Constants.BOT_UPDATE_INTERVAL)
    end
end

return BotService
