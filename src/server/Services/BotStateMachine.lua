--[[
    BotStateMachine
    State machine engine for bot AI behavior.

    States per role:
        Tagger:  IDLE → WANDER ↔ CHASE
        Runner:  IDLE → WANDER ↔ FLEE

    Cross-cutting actions (handled outside state machine):
        Jump, Powerup Pickup, Stuck Recovery
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))

local BotStateMachine = {}

-- Valid state transitions per role
local TRANSITIONS = {
    Tagger = {
        IDLE   = { "WANDER", "CHASE" },
        WANDER = { "CHASE", "IDLE" },
        CHASE  = { "WANDER", "IDLE" },
    },
    Runner = {
        IDLE   = { "WANDER", "FLEE" },
        WANDER = { "FLEE", "IDLE" },
        FLEE   = { "WANDER", "IDLE" },
    },
}

-- Check if a transition is valid
function BotStateMachine.canTransition(role, from, to)
    local roleTransitions = TRANSITIONS[role]
    if not roleTransitions or not roleTransitions[from] then
        return false
    end
    for _, valid in ipairs(roleTransitions[from]) do
        if valid == to then
            return true
        end
    end
    return false
end

-- Transition the state machine to a new state (validates first)
function BotStateMachine.transition(sm, role, newState)
    if not BotStateMachine.canTransition(role, sm.current, newState) then
        warn("[BotStateMachine] Invalid transition:", role, sm.current, "→", newState)
        return false
    end
    sm.current = newState
    sm.entered_at = os.clock()
    return true
end

-- Create a new state machine instance
function BotStateMachine.create()
    return {
        current = "IDLE",
        entered_at = os.clock(),
        -- Shared fields (used by cross-state actions)
        last_position = nil,
        stuck_since = 0,
        recovery_attempts = 0,
        jump_ready_at = 0,
        -- Tagger-specific
        committed_target = nil,
        committed_since = 0,
        reaction_ready_at = 0,
        -- Runner-specific
        last_threat = nil,
        last_threat_dist = math.huge,
        -- Shared movement
        wander_target = nil,
        wander_started = 0,
    }
end

------------------------------------------------------------------------
-- State handlers
-- Each receives (sm, ctx) where ctx contains:
--   bot, botRoot, humanoid, stats, roundState,
--   moveBot(targetPos), playAnim(animName), tryJump(moveTarget, nearDist),
--   clampBounds(pos), generateWander(currentPos, range), roundService
------------------------------------------------------------------------

-- Tagger States --

local function _taggerIdle(sm, ctx)
    ctx.playAnim("idle")
    -- Immediately transition to WANDER on first tick
    BotStateMachine.transition(sm, "Tagger", "WANDER")
end

local function _taggerWander(sm, ctx)
    local now = os.clock()
    local stats = ctx.stats

    -- Check for chase targets on reaction timer
    if now >= sm.reaction_ready_at then
        local nearestTarget, nearestDist = ctx.findNearestRunner()

        if nearestTarget then
            sm.committed_target = nearestTarget
            sm.committed_since = now
            sm.reaction_ready_at = now + Constants.BOT_REACTION_DELAY_TAGGER * stats.reaction_delay_mult
            BotStateMachine.transition(sm, "Tagger", "CHASE")
            return
        end

        sm.reaction_ready_at = now + Constants.BOT_REACTION_DELAY_TAGGER * stats.reaction_delay_mult
    end

    -- Wander with persistence
    ctx.playAnim("walk")

    if not sm.wander_target or (now - sm.wander_started) > stats.wander_persist_secs then
        sm.wander_target = ctx.generateWander(ctx.botRoot.Position, 30)
        sm.wander_started = now
    end

    ctx.moveBot(sm.wander_target)
end

local function _taggerChase(sm, ctx)
    local now = os.clock()
    local stats = ctx.stats

    -- Reassess targets on reaction timer
    if now >= sm.reaction_ready_at then
        local nearestTarget = ctx.findNearestRunner()

        -- Decide whether to switch targets
        local shouldSwitch = not sm.committed_target
            or not sm.committed_target.Parent
            or (now - sm.committed_since) > stats.target_commit_secs

        if nearestTarget and shouldSwitch then
            sm.committed_target = nearestTarget
            sm.committed_since = now
        elseif not nearestTarget then
            sm.committed_target = nil
        end

        sm.reaction_ready_at = now + Constants.BOT_REACTION_DELAY_TAGGER * stats.reaction_delay_mult
    end

    -- Lost target → back to wander
    if not sm.committed_target or not sm.committed_target.Parent then
        sm.committed_target = nil
        BotStateMachine.transition(sm, "Tagger", "WANDER")
        return
    end

    -- Chase committed target
    local targetPos = sm.committed_target.Position

    -- Personality affects chase precision
    local offsetScale = 4 / math.max(stats.speed_mult, 0.5)
    local offset = Vector3.new(
        (math.random() - 0.5) * offsetScale,
        0,
        (math.random() - 0.5) * offsetScale
    )

    ctx.playAnim("run")
    ctx.moveBot(targetPos + offset)

    -- Jump when close to target or obstacle ahead
    local dist = (sm.committed_target.Position - ctx.botRoot.Position).Magnitude
    ctx.tryJump(targetPos, dist)

    -- Tag check
    if dist <= Constants.TAG_RANGE and ctx.roundService then
        ctx.roundService:BotTag(ctx.bot, sm.committed_target.Parent)
    end
end

-- Runner States --

local function _runnerIdle(sm, ctx)
    ctx.playAnim("idle")
    -- Immediately transition to WANDER on first tick
    BotStateMachine.transition(sm, "Runner", "WANDER")
end

local function _runnerWander(sm, ctx)
    local now = os.clock()
    local stats = ctx.stats

    -- Threat assessment on reaction timer
    if now >= sm.reaction_ready_at then
        local nearestTagger, nearestDist = ctx.findNearestTagger()
        sm.last_threat = nearestTagger
        sm.last_threat_dist = nearestDist
        sm.reaction_ready_at = now + Constants.BOT_REACTION_DELAY_RUNNER * stats.reaction_delay_mult
    end

    -- Check if we need to flee
    local fleeThreshold = Constants.BOT_FLEE_DISTANCE * stats.flee_distance_mult
    if sm.last_threat and sm.last_threat.Parent and sm.last_threat_dist < fleeThreshold then
        sm.wander_target = nil
        BotStateMachine.transition(sm, "Runner", "FLEE")
        return
    end

    -- Wander with persistence
    ctx.playAnim("walk")

    if not sm.wander_target or (now - sm.wander_started) > stats.wander_persist_secs then
        sm.wander_target = ctx.generateWander(ctx.botRoot.Position, 20)
        sm.wander_started = now
    end

    ctx.moveBot(sm.wander_target)
end

local function _runnerFlee(sm, ctx)
    local now = os.clock()
    local stats = ctx.stats

    -- Update threat assessment on reaction timer
    if now >= sm.reaction_ready_at then
        local nearestTagger, nearestDist = ctx.findNearestTagger()
        sm.last_threat = nearestTagger
        sm.last_threat_dist = nearestDist
        sm.reaction_ready_at = now + Constants.BOT_REACTION_DELAY_RUNNER * stats.reaction_delay_mult
    end

    -- Threat gone → back to wander
    local fleeThreshold = Constants.BOT_FLEE_DISTANCE * stats.flee_distance_mult
    if not sm.last_threat or not sm.last_threat.Parent or sm.last_threat_dist >= fleeThreshold then
        sm.last_threat = nil
        sm.last_threat_dist = math.huge
        BotStateMachine.transition(sm, "Runner", "WANDER")
        return
    end

    -- Flee: run directly away from tagger
    ctx.playAnim("run")

    local fleeDir = (ctx.botRoot.Position - sm.last_threat.Position)
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
    local fleeTarget = ctx.clampBounds(ctx.botRoot.Position + fleeDir * 20 + randomOffset)

    ctx.moveBot(fleeTarget)

    -- Jump when threat is close or obstacle ahead while fleeing
    ctx.tryJump(fleeTarget, sm.last_threat_dist)
end

-- Handler dispatch tables
local HANDLERS = {
    Tagger = {
        IDLE   = _taggerIdle,
        WANDER = _taggerWander,
        CHASE  = _taggerChase,
    },
    Runner = {
        IDLE   = _runnerIdle,
        WANDER = _runnerWander,
        FLEE   = _runnerFlee,
    },
}

-- Tick the state machine: dispatches to the current state's handler
function BotStateMachine.update(sm, role, ctx)
    local roleHandlers = HANDLERS[role]
    if not roleHandlers then
        warn("[BotStateMachine] Unknown role:", role)
        return
    end

    local handler = roleHandlers[sm.current]
    if not handler then
        warn("[BotStateMachine] No handler for", role, sm.current)
        return
    end

    handler(sm, ctx)
end

return BotStateMachine
