--[[
    RoundService Tests
    Tests for round lifecycle, tag handling, and participant management
]]

-- Save original require before any patching
local _originalRequire = require

local TestBootstrap = _originalRequire("init")
local RemotesMock = _originalRequire("remotes")
local PlayerMock = _originalRequire("player")
local TimeMock = _originalRequire("time")

-- Helper: create a mock instance with WaitForChild/FindFirstChild
local function mockInstance(name, children)
    local inst = {
        Name = name,
        _children = children or {},
    }
    function inst:WaitForChild(childName)
        return self._children[childName]
    end
    function inst:FindFirstChild(childName)
        return self._children[childName]
    end
    return inst
end

-- Helper: create a mock character at a position
local function createCharacter(x, y, z)
    local root = { Position = Vector3.new(x or 0, y or 0, z or 0), Anchored = false }
    local humanoid = { WalkSpeed = 16 }
    local character = {
        _children = { HumanoidRootPart = root, Humanoid = humanoid },
    }
    function character:FindFirstChild(name)
        return self._children[name]
    end
    return character
end

-- Helper: create a test player with a character
local function createTestPlayer(userId, name, x, y, z)
    local player = {
        UserId = userId,
        Name = name or ("Player" .. userId),
        Character = createCharacter(x, y, z),
    }
    return player
end

-- Module registry for intercepting require(tableInstance) calls
local moduleMap = {}

-- Stub services
local DataServiceStub = {
    Init = function() end,
    Start = function() end,
    GetData = function() return nil end,
    AddCoins = function() end,
}

local MapServiceStub = {
    Init = function() end,
    Start = function() end,
    TeleportPlayerToSpawn = function() end,
    TeleportToLobby = function() end,
    CleanupRound = function() end,
}

local BotServiceStub = {
    Init = function() end,
    Start = function() end,
    IsBot = function(_, p) return p._isBot == true end,
    GetActiveBots = function() return {} end,
    SetRoundService = function() end,
    StartAI = function() end,
    StopAI = function() end,
    StopAllAI = function() end,
}

local PowerupServiceStub = {
    Init = function() end,
    Start = function() end,
    OnRoundStart = function() end,
    OnRoundEnd = function() end,
    HasShield = function() return false end,
    ConsumeShield = function() end,
    RemovePlayer = function() end,
}

local RemoteHelperStub = {
    CreateEvent = function(_, name)
        return RemotesMock.RemoteEvent.new(name)
    end,
    CreateFunction = function(_, name)
        return RemotesMock.RemoteFunction.new(name)
    end,
    BindEvent = function() end,
    BindFunction = function() end,
}

-- Load real shared modules
local Constants = _originalRequire("Constants")
local Utils = _originalRequire("Utils")

-- Create mock module instances and register in moduleMap
local constantsModule = mockInstance("Constants")
local utilsModule = mockInstance("Utils")
local dataServiceModule = mockInstance("DataService")
local mapServiceModule = mockInstance("MapService")
local botServiceModule = mockInstance("BotService")
local powerupServiceModule = mockInstance("PowerupService")
local remoteHelperModule = mockInstance("RemoteHelper")

moduleMap[constantsModule] = Constants
moduleMap[utilsModule] = Utils
moduleMap[dataServiceModule] = DataServiceStub
moduleMap[mapServiceModule] = MapServiceStub
moduleMap[botServiceModule] = BotServiceStub
moduleMap[powerupServiceModule] = PowerupServiceStub
moduleMap[remoteHelperModule] = RemoteHelperStub

-- Build the WaitForChild tree that RoundService expects
local configFolder = mockInstance("Config", { Constants = constantsModule })
local sharedFolder = mockInstance("Shared", { Config = configFolder, Utils = utilsModule })
local remotesFolder = mockInstance("Remotes")

local servicesFolder = mockInstance("Services", {
    DataService = dataServiceModule,
    MapService = mapServiceModule,
    BotService = botServiceModule,
    PowerupService = powerupServiceModule,
})

local helpersFolder = mockInstance("Helpers", {
    RemoteHelper = remoteHelperModule,
})

local serverFolder = mockInstance("Server", {
    Services = servicesFolder,
    Helpers = helpersFolder,
})

servicesFolder.Parent = serverFolder

local replicatedStorage = mockInstance("ReplicatedStorage", {
    Shared = sharedFolder,
    Remotes = remotesFolder,
})

-- Set up globals needed by RoundService at module load time
local playersService = PlayerMock.createPlayersService()

_G.game = {
    GetService = function(_, name)
        if name == "Players" then return playersService end
        if name == "ReplicatedStorage" then return replicatedStorage end
        return {}
    end,
}

_G.script = mockInstance("RoundService")
_G.script.Parent = servicesFolder

_G.task = {
    spawn = function(fn) end, -- Don't auto-start round loop in tests
    delay = function(_, _) end,
    wait = function() end,
    defer = function(fn) fn() end,
}

-- Patch require globally to intercept mock module instances
rawset(_G, "require", function(target)
    if type(target) == "table" and moduleMap[target] then
        return moduleMap[target]
    end
    return _originalRequire(target)
end)

-- Load the real RoundService module
package.loaded["RoundService"] = nil
local RoundService = _originalRequire("RoundService")

-- Restore require
rawset(_G, "require", _originalRequire)

-- Initialize remotes (creates _roundStateEvent, _phaseUpdateEvent, etc.)
RoundService:Init()

-- Install time mock for os.clock in _handleTag
TimeMock.install()
TimeMock.setClock(0)

----------------------------------------------------------------------
-- Tests
----------------------------------------------------------------------

describe("RoundService", function()
    before_each(function()
        -- Reset RoundService state before each test
        RoundService._currentPhase = Constants.PHASES.LOBBY
        RoundService._roundState = nil
        RoundService._roundTimer = 0
        RoundService._tagCooldowns = {}
        RoundService._roundStats = {}

        -- Reset time mock
        TimeMock.setClock(100)

        -- Clear any fired remote events
        if RoundService._roundStateEvent and RoundService._roundStateEvent.ClearFires then
            RoundService._roundStateEvent:ClearFires()
        end

        -- Clear players service
        for _, p in ipairs(playersService:GetPlayers()) do
            playersService._players[p.UserId] = nil
        end
    end)

    -- Helper: set up a standard round with 1 tagger and 2 runners
    local function setupRound(tagger, runners)
        RoundService._currentPhase = Constants.PHASES.PLAYING
        RoundService._roundState = {
            Taggers = { tagger },
            Runners = runners,
            TaggedPlayers = {},
            RoundStartTime = os.time(),
            RoundEndTime = os.time() + Constants.ROUND_DURATION,
        }
        RoundService._roundStats = {}
        RoundService._tagCooldowns = {}
        for _, p in ipairs({ tagger }) do
            RoundService._roundStats[p.UserId] = { tagsPerformed = 0, survivedSeconds = 0 }
        end
        for _, r in ipairs(runners) do
            RoundService._roundStats[r.UserId] = { tagsPerformed = 0, survivedSeconds = 0 }
        end
    end

    describe("_allRunnersTagged", function()
        it("returns false with untagged runners", function()
            local tagger = createTestPlayer(1, "Tagger")
            local runner1 = createTestPlayer(2, "Runner1")
            local runner2 = createTestPlayer(3, "Runner2")
            setupRound(tagger, { runner1, runner2 })

            assert.is_false(RoundService:_allRunnersTagged())
        end)

        it("returns false with some runners tagged", function()
            local tagger = createTestPlayer(1, "Tagger")
            local runner1 = createTestPlayer(2, "Runner1")
            local runner2 = createTestPlayer(3, "Runner2")
            setupRound(tagger, { runner1, runner2 })

            RoundService._roundState.TaggedPlayers[2] = true

            assert.is_false(RoundService:_allRunnersTagged())
        end)

        it("returns true when all runners are tagged", function()
            local tagger = createTestPlayer(1, "Tagger")
            local runner1 = createTestPlayer(2, "Runner1")
            local runner2 = createTestPlayer(3, "Runner2")
            setupRound(tagger, { runner1, runner2 })

            RoundService._roundState.TaggedPlayers[2] = true
            RoundService._roundState.TaggedPlayers[3] = true

            assert.is_true(RoundService:_allRunnersTagged())
        end)

        it("returns true when no round state", function()
            assert.is_true(RoundService:_allRunnersTagged())
        end)
    end)

    describe("_allTaggersGone", function()
        it("returns false with taggers present", function()
            local tagger = createTestPlayer(1, "Tagger")
            local runner = createTestPlayer(2, "Runner")
            setupRound(tagger, { runner })

            assert.is_false(RoundService:_allTaggersGone())
        end)

        it("returns true when taggers array is empty", function()
            local tagger = createTestPlayer(1, "Tagger")
            local runner = createTestPlayer(2, "Runner")
            setupRound(tagger, { runner })

            -- Remove the tagger
            RoundService._roundState.Taggers = {}

            assert.is_true(RoundService:_allTaggersGone())
        end)

        it("returns true when no round state", function()
            assert.is_true(RoundService:_allTaggersGone())
        end)
    end)

    describe("RemoveParticipant", function()
        it("removes player from Taggers list", function()
            local tagger = createTestPlayer(1, "Tagger")
            local runner = createTestPlayer(2, "Runner")
            setupRound(tagger, { runner })

            RoundService:RemoveParticipant(tagger)

            assert.equal(0, #RoundService._roundState.Taggers)
        end)

        it("removes player from Runners list and marks as tagged", function()
            local tagger = createTestPlayer(1, "Tagger")
            local runner1 = createTestPlayer(2, "Runner1")
            local runner2 = createTestPlayer(3, "Runner2")
            setupRound(tagger, { runner1, runner2 })

            RoundService:RemoveParticipant(runner1)

            assert.equal(1, #RoundService._roundState.Runners)
            assert.equal(3, RoundService._roundState.Runners[1].UserId)
            assert.is_true(RoundService._roundState.TaggedPlayers[2])
        end)

        it("cleans up roundStats and tagCooldowns", function()
            local tagger = createTestPlayer(1, "Tagger")
            local runner = createTestPlayer(2, "Runner")
            setupRound(tagger, { runner })

            RoundService._tagCooldowns[2] = 50
            assert.is_not_nil(RoundService._roundStats[2])

            RoundService:RemoveParticipant(runner)

            assert.is_nil(RoundService._roundStats[2])
            assert.is_nil(RoundService._tagCooldowns[2])
        end)

        it("does nothing when no round state exists", function()
            local player = createTestPlayer(1, "Player")

            -- Should not error
            RoundService:RemoveParticipant(player)

            assert.is_nil(RoundService._roundState)
        end)

        it("causes _allTaggersGone to return true when last tagger removed", function()
            local tagger = createTestPlayer(1, "Tagger")
            local runner = createTestPlayer(2, "Runner")
            setupRound(tagger, { runner })

            assert.is_false(RoundService:_allTaggersGone())

            RoundService:RemoveParticipant(tagger)

            assert.is_true(RoundService:_allTaggersGone())
        end)
    end)

    describe("_handleTag", function()
        it("rejects tag when not in PLAYING phase", function()
            local tagger = createTestPlayer(1, "Tagger", 0, 0, 0)
            local runner = createTestPlayer(2, "Runner", 1, 0, 0)
            setupRound(tagger, { runner })

            -- Set phase to LOBBY instead of PLAYING
            RoundService._currentPhase = Constants.PHASES.LOBBY
            playersService._players[2] = runner

            RoundService:_handleTag(tagger, 2)

            assert.is_nil(RoundService._roundState.TaggedPlayers[2])
        end)

        it("rejects tag from non-tagger", function()
            local tagger = createTestPlayer(1, "Tagger", 0, 0, 0)
            local runner1 = createTestPlayer(2, "Runner1", 1, 0, 0)
            local runner2 = createTestPlayer(3, "Runner2", 2, 0, 0)
            setupRound(tagger, { runner1, runner2 })
            playersService._players[3] = runner2

            -- Runner1 tries to tag Runner2 (should fail, not a tagger)
            RoundService:_handleTag(runner1, 3)

            assert.is_nil(RoundService._roundState.TaggedPlayers[3])
        end)

        it("rejects tag on already-tagged runner", function()
            local tagger = createTestPlayer(1, "Tagger", 0, 0, 0)
            local runner = createTestPlayer(2, "Runner", 1, 0, 0)
            setupRound(tagger, { runner })
            playersService._players[2] = runner

            -- Pre-tag the runner
            RoundService._roundState.TaggedPlayers[2] = true

            RoundService:_handleTag(tagger, 2)

            -- Stats should not have changed (no new tag performed)
            assert.equal(0, RoundService._roundStats[1].tagsPerformed)
        end)

        it("rejects tag when target is out of range", function()
            -- Place tagger and runner far apart (beyond TAG_RANGE * TAG_RANGE_TOLERANCE = 9)
            local tagger = createTestPlayer(1, "Tagger", 0, 0, 0)
            local runner = createTestPlayer(2, "Runner", 100, 0, 0)
            setupRound(tagger, { runner })
            playersService._players[2] = runner

            RoundService:_handleTag(tagger, 2)

            assert.is_nil(RoundService._roundState.TaggedPlayers[2])
        end)

        it("succeeds for valid tag within range", function()
            -- Place tagger and runner close together (within TAG_RANGE * TAG_RANGE_TOLERANCE)
            local tagger = createTestPlayer(1, "Tagger", 0, 0, 0)
            local runner = createTestPlayer(2, "Runner", 3, 0, 0)
            setupRound(tagger, { runner })
            playersService._players[2] = runner

            RoundService:_handleTag(tagger, 2)

            assert.is_true(RoundService._roundState.TaggedPlayers[2])
            assert.equal(1, RoundService._roundStats[1].tagsPerformed)
        end)

        it("respects tag cooldown", function()
            local tagger = createTestPlayer(1, "Tagger", 0, 0, 0)
            local runner1 = createTestPlayer(2, "Runner1", 3, 0, 0)
            local runner2 = createTestPlayer(3, "Runner2", 3, 0, 0)
            setupRound(tagger, { runner1, runner2 })
            playersService._players[2] = runner1
            playersService._players[3] = runner2

            -- Tag first runner
            TimeMock.setClock(100)
            RoundService:_handleTag(tagger, 2)
            assert.is_true(RoundService._roundState.TaggedPlayers[2])

            -- Try to tag second runner immediately (within cooldown)
            TimeMock.setClock(100.5)
            RoundService:_handleTag(tagger, 3)
            assert.is_nil(RoundService._roundState.TaggedPlayers[3])

            -- Tag second runner after cooldown expires
            TimeMock.setClock(102)
            RoundService:_handleTag(tagger, 3)
            assert.is_true(RoundService._roundState.TaggedPlayers[3])
        end)
    end)
end)
