--[[
    Test Bootstrap
    Sets up paths and installs mocks for testing outside Roblox Studio
]]

local TestBootstrap = {}

-- Get the project root by finding the tests directory
local function getProjectRoot()
    local handle = io.popen("pwd")
    if handle then
        local cwd = handle:read("*a"):gsub("%s+$", "")
        handle:close()
        return cwd
    end
    return "."
end

-- Setup package paths
function TestBootstrap.setupPaths()
    local projectRoot = getProjectRoot()

    package.path = table.concat({
        -- Test paths (prioritize these)
        projectRoot .. "/tests/?.lua",
        projectRoot .. "/tests/?/init.lua",
        projectRoot .. "/tests/mocks/?.lua",
        projectRoot .. "/tests/helpers/?.lua",
        -- Project source paths
        projectRoot .. "/src/shared/?.lua",
        projectRoot .. "/src/shared/?/init.lua",
        projectRoot .. "/src/shared/Config/?.lua",
        projectRoot .. "/src/shared/Utils/?.lua",
        projectRoot .. "/src/shared/Helpers/?.lua",
        projectRoot .. "/src/shared/Types/?.lua",
        -- Server helper paths (for testing server helpers)
        projectRoot .. "/src/server/Helpers/?.lua",
        -- Keep existing paths
        package.path,
    }, ";")
end

-- Install all mocks
function TestBootstrap.installMocks()
    local RobloxMocks = require("roblox")
    RobloxMocks.install()
    TestBootstrap.RobloxMocks = RobloxMocks
end

-- Install time mock
function TestBootstrap.installTimeMock()
    local TimeMock = require("time")
    TimeMock.install()
    TestBootstrap.TimeMock = TimeMock
    return TimeMock
end

-- Install player mock
function TestBootstrap.installPlayerMock()
    local PlayerMock = require("player")
    local playersService = PlayerMock.install()
    TestBootstrap.PlayerMock = PlayerMock
    TestBootstrap.PlayersService = playersService
    return PlayerMock
end

-- Install remotes mock
function TestBootstrap.installRemotesMock()
    local RemotesMock = require("remotes")
    RemotesMock.install()
    TestBootstrap.RemotesMock = RemotesMock
    return RemotesMock
end

-- Helper to create a mock player
function TestBootstrap.createPlayer(userId, name)
    local PlayerMock = TestBootstrap.PlayerMock or require("player")
    return PlayerMock.createPlayer(userId, name)
end

-- Full initialization
function TestBootstrap.init()
    TestBootstrap.setupPaths()
    TestBootstrap.installMocks()
    return TestBootstrap
end

-- Cleanup
function TestBootstrap.cleanup()
    if TestBootstrap.RobloxMocks then
        TestBootstrap.RobloxMocks.uninstall()
    end
    if TestBootstrap.TimeMock then
        TestBootstrap.TimeMock.uninstall()
    end
    if TestBootstrap.PlayerMock then
        TestBootstrap.PlayerMock.uninstall()
    end
    if TestBootstrap.RemotesMock then
        TestBootstrap.RemotesMock.uninstall()
    end
end

-- Helper to require shared modules
function TestBootstrap.requireShared(moduleName)
    return require(moduleName)
end

-- Helper to require config modules
function TestBootstrap.requireConfig(configName)
    return require(configName)
end

-- Auto-setup paths when this module is loaded (for helper mode)
TestBootstrap.setupPaths()
TestBootstrap.installMocks()

return TestBootstrap
