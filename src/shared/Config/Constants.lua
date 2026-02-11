--[[
    Constants
    Centralized game constants and magic numbers
]]

local Constants = {}

-- Round roles
Constants.ROLES = {
    TAGGER = "Tagger",
    RUNNER = "Runner",
    SPECTATOR = "Spectator",
}

-- Round phases
Constants.PHASES = {
    LOBBY = "Lobby",
    COUNTDOWN = "Countdown",
    PLAYING = "Playing",
    RESULTS = "Results",
    INTERMISSION = "Intermission",
}

-- Default player values
Constants.DEFAULT_COINS = 100
Constants.DEFAULT_GEMS = 10

-- Round timing (seconds)
Constants.LOBBY_WAIT_TIME = 5
Constants.COUNTDOWN_TIME = 5
Constants.ROUND_DURATION = 120
Constants.RESULTS_DISPLAY_TIME = 8
Constants.INTERMISSION_TIME = 10

-- Player counts
Constants.MIN_PLAYERS = 2
Constants.MAX_PLAYERS = 12
Constants.TAGGERS_PER_ROUND = 3

-- Movement
Constants.DEFAULT_WALK_SPEED = 16
Constants.TAGGER_SPEED_BOOST = 4
Constants.RUNNER_SPEED_BOOST = 0

-- Tag mechanics
Constants.TAG_COOLDOWN = 1.5
Constants.TAG_RANGE = 6
Constants.TAG_RANGE_TOLERANCE = 1.5 -- Server-side multiplier for network latency
Constants.FREEZE_DURATION = 3

-- Scoring
Constants.POINTS_PER_TAG = 10
Constants.POINTS_PER_SURVIVAL = 5
Constants.POINTS_PER_SECOND_ALIVE = 1
Constants.BONUS_LAST_RUNNER = 50
Constants.COINS_PER_TAG = 5
Constants.COINS_PER_WIN = 25
Constants.COINS_PER_ROUND = 10

-- Lobby
Constants.LOBBY_HEIGHT = 100 -- Y position of lobby platform above arena
Constants.LOBBY_SIZE = 30 -- Size of the lobby platform (studs)

-- Bots
Constants.BOT_FILL_TARGET = 4 -- Auto-fill games to this many total participants
Constants.BOT_UPDATE_INTERVAL = 0.3 -- AI decision frequency (seconds)
Constants.BOT_FLEE_DISTANCE = 60 -- How far runner bots flee from tagger
Constants.BOT_RANDOM_OFFSET = 15 -- Random movement variation for organic feel
Constants.BOT_MAP_BOUNDS = 35 -- Effective play area for bot AI (±studs from center)
Constants.BOT_STUCK_CHECK_INTERVAL = 2 -- Seconds before declaring a bot stuck
Constants.BOT_STUCK_THRESHOLD = 1 -- Minimum studs of movement to not be "stuck"
Constants.BOT_JUMP_COOLDOWN = 0.8 -- Base seconds between jumps (modified by personality)
Constants.BOT_JUMP_PROXIMITY_THRESHOLD = 15 -- Distance (studs) to trigger proximity jump
Constants.BOT_JUMP_RAYCAST_DISTANCE = 8 -- How far ahead to raycast for obstacles (studs)
Constants.BOT_NAMES = { "Bolt", "Dash", "Flash", "Blitz", "Zippy", "Turbo", "Rocket", "Swift", "Storm", "Spark" }

-- Bot reaction delays (seconds before acting on new information)
Constants.BOT_REACTION_DELAY_TAGGER = 0.15
Constants.BOT_REACTION_DELAY_RUNNER = 0.25

-- Bot personalities
Constants.BOT_PERSONALITIES = {
    CAUTIOUS = "Cautious",
    BOLD = "Bold",
    TRICKY = "Tricky",
}

-- Personality stat modifiers
-- reaction_delay_mult: applied to base reaction delay (>1 = slower to react)
-- wander_persist_secs: how long to commit to a wander target (seconds)
-- target_commit_secs: how long tagger commits to chasing one target (seconds)
-- speed_mult: multiplier for humanoid.WalkSpeed
-- flee_distance_mult: multiplier for BOT_FLEE_DISTANCE threshold
Constants.PERSONALITY_STATS = {
    Cautious = {
        reaction_delay_mult = 1.3,
        wander_persist_secs = 2.5,
        target_commit_secs = 0.9,
        speed_mult = 0.85,
        flee_distance_mult = 1.4,
        jump_cooldown_mult = 1.5,
    },
    Bold = {
        reaction_delay_mult = 0.7,
        wander_persist_secs = 1.0,
        target_commit_secs = 2.0,
        speed_mult = 1.15,
        flee_distance_mult = 0.7,
        jump_cooldown_mult = 0.6,
    },
    Tricky = {
        reaction_delay_mult = 0.9,
        wander_persist_secs = 1.8,
        target_commit_secs = 1.2,
        speed_mult = 1.0,
        flee_distance_mult = 1.0,
        jump_cooldown_mult = 1.0,
    },
}

-- Bot animation fallback IDs (used when ServerStorage animations can't be loaded)
-- R15 defaults
Constants.BOT_ANIM_IDLE_R15 = "rbxassetid://507766666"
Constants.BOT_ANIM_WALK_R15 = "rbxassetid://507777826"
Constants.BOT_ANIM_RUN_R15 = "rbxassetid://507767714"
-- R6 defaults
Constants.BOT_ANIM_IDLE_R6 = "rbxassetid://180435571"
Constants.BOT_ANIM_WALK_R6 = "rbxassetid://180426354"
Constants.BOT_ANIM_RUN_R6 = "rbxassetid://180426354"

-- Powerups
Constants.POWERUP_SPAWN_INTERVAL = 15
Constants.POWERUP_DURATION = 8

-- Data store version
Constants.DATA_STORE_KEY = "PlayerData_v1"

-- Time constants
Constants.SECONDS_PER_MINUTE = 60
Constants.SECONDS_PER_HOUR = 3600
Constants.SECONDS_PER_DAY = 86400

return Constants
