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
Constants.LOBBY_WAIT_TIME = 15
Constants.COUNTDOWN_TIME = 5
Constants.ROUND_DURATION = 120
Constants.RESULTS_DISPLAY_TIME = 8
Constants.INTERMISSION_TIME = 10

-- Player counts
Constants.MIN_PLAYERS = 2
Constants.MAX_PLAYERS = 12
Constants.TAGGERS_PER_ROUND = 1

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

-- Bots
Constants.BOT_FILL_TARGET = 4 -- Auto-fill games to this many total participants
Constants.BOT_UPDATE_INTERVAL = 0.3 -- AI decision frequency (seconds)
Constants.BOT_FLEE_DISTANCE = 40 -- How far runner bots flee from tagger
Constants.BOT_RANDOM_OFFSET = 15 -- Random movement variation for organic feel
Constants.BOT_NAMES = { "Bolt", "Dash", "Flash", "Blitz", "Zippy", "Turbo", "Rocket", "Swift", "Storm", "Spark" }

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
