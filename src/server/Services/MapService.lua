--[[
    MapService
    Manages game maps: spawn points, terrain, player teleportation
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))

local MapService = {}

-- Cached map instance
MapService._currentMap = nil

-- Map definitions
local MAP_DEFINITIONS = {
    {
        name = "Playground Panic",
        mapId = "playground_panic",
        size = 120,
        runnerSpawn = Vector3.new(0, 5, 0),
        taggerSpawns = {
            Vector3.new(50, 5, 0),      -- 0°
            Vector3.new(-25, 5, 43),     -- 120°
            Vector3.new(-25, 5, -43),    -- 240°
        },
        lobbySpawns = {
            Vector3.new(-5, Constants.LOBBY_HEIGHT + 1, -5),
            Vector3.new(5, Constants.LOBBY_HEIGHT + 1, -5),
            Vector3.new(-5, Constants.LOBBY_HEIGHT + 1, 5),
            Vector3.new(5, Constants.LOBBY_HEIGHT + 1, 5),
            Vector3.new(0, Constants.LOBBY_HEIGHT + 1, 0),
        },
        obstacles = {
            { pos = Vector3.new(-20, 3, 0), size = Vector3.new(12, 6, 12), color = Color3.fromRGB(255, 120, 80) },
            { pos = Vector3.new(20, 3, -20), size = Vector3.new(10, 6, 10), color = Color3.fromRGB(80, 200, 120) },
            { pos = Vector3.new(0, 3, 25), size = Vector3.new(14, 6, 8), color = Color3.fromRGB(100, 150, 255) },
            { pos = Vector3.new(-30, 3, 20), size = Vector3.new(8, 6, 8), color = Color3.fromRGB(255, 200, 80) },
            { pos = Vector3.new(30, 3, 15), size = Vector3.new(10, 6, 6), color = Color3.fromRGB(200, 100, 255) },
        },
    },
}

function MapService:Init()
    print("[MapService] Initializing...")
end

function MapService:Start()
    print("[MapService] Starting...")
    self:_createOrGetMap("playground_panic")
end

function MapService:GetOrCreateMap()
    if self._currentMap then
        return self._currentMap
    end
    return self:_createOrGetMap("playground_panic")
end

function MapService:_createOrGetMap(mapId)
    if self._currentMap then
        return self._currentMap
    end

    local mapDef = nil
    for _, def in ipairs(MAP_DEFINITIONS) do
        if def.mapId == mapId then
            mapDef = def
            break
        end
    end

    if not mapDef then
        warn("[MapService] Unknown map ID:", mapId)
        return nil
    end

    self._currentMap = self:_buildMap(mapDef)
    print("[MapService] Created map:", mapDef.name)
    return self._currentMap
end

function MapService:_buildMap(definition)
    local mapFolder = Instance.new("Folder")
    mapFolder.Name = definition.mapId
    mapFolder.Parent = Workspace

    -- Baseplate
    local baseplate = Instance.new("Part")
    baseplate.Name = "Baseplate"
    baseplate.Size = Vector3.new(definition.size, 1, definition.size)
    baseplate.Position = Vector3.new(0, -0.5, 0)
    baseplate.Anchored = true
    baseplate.Material = Enum.Material.Grass
    baseplate.Color = Color3.fromRGB(80, 160, 80)
    baseplate.Parent = mapFolder

    -- Boundary walls (invisible)
    local halfSize = definition.size / 2
    local wallHeight = 20
    local wallThickness = 2

    local walls = {
        { pos = Vector3.new(halfSize + wallThickness / 2, wallHeight / 2, 0), size = Vector3.new(wallThickness, wallHeight, definition.size) },
        { pos = Vector3.new(-halfSize - wallThickness / 2, wallHeight / 2, 0), size = Vector3.new(wallThickness, wallHeight, definition.size) },
        { pos = Vector3.new(0, wallHeight / 2, halfSize + wallThickness / 2), size = Vector3.new(definition.size + wallThickness * 2, wallHeight, wallThickness) },
        { pos = Vector3.new(0, wallHeight / 2, -halfSize - wallThickness / 2), size = Vector3.new(definition.size + wallThickness * 2, wallHeight, wallThickness) },
    }

    for i, wallData in ipairs(walls) do
        local wall = Instance.new("Part")
        wall.Name = "Boundary_" .. i
        wall.Size = wallData.size
        wall.Position = wallData.pos
        wall.Anchored = true
        wall.Transparency = 1
        wall.CanCollide = true
        wall.Parent = mapFolder
    end

    -- Obstacles
    for i, obs in ipairs(definition.obstacles) do
        local part = Instance.new("Part")
        part.Name = "Obstacle_" .. i
        part.Size = obs.size
        part.Position = obs.pos
        part.Anchored = true
        part.Material = Enum.Material.SmoothPlastic
        part.Color = obs.color
        part.Parent = mapFolder
    end

    -- Spawn markers (invisible)
    local spawnsFolder = Instance.new("Folder")
    spawnsFolder.Name = "Spawns"
    spawnsFolder.Parent = mapFolder

    local runnerMarker = Instance.new("Part")
    runnerMarker.Name = "RunnerSpawn"
    runnerMarker.Size = Vector3.new(1, 1, 1)
    runnerMarker.Position = definition.runnerSpawn
    runnerMarker.Anchored = true
    runnerMarker.CanCollide = false
    runnerMarker.Transparency = 1
    runnerMarker.Parent = spawnsFolder

    for i, pos in ipairs(definition.taggerSpawns) do
        local marker = Instance.new("Part")
        marker.Name = "TaggerSpawn_" .. i
        marker.Size = Vector3.new(1, 1, 1)
        marker.Position = pos
        marker.Anchored = true
        marker.CanCollide = false
        marker.Transparency = 1
        marker.Parent = spawnsFolder
    end

    -- Lobby spawn markers
    for i, pos in ipairs(definition.lobbySpawns) do
        local marker = Instance.new("Part")
        marker.Name = "LobbySpawn_" .. i
        marker.Size = Vector3.new(1, 1, 1)
        marker.Position = pos
        marker.Anchored = true
        marker.CanCollide = false
        marker.Transparency = 1
        marker.Parent = spawnsFolder
    end

    -- Lobby platform (above arena)
    local lobbyFolder = Instance.new("Folder")
    lobbyFolder.Name = "Lobby"
    lobbyFolder.Parent = mapFolder

    local lobbySize = Constants.LOBBY_SIZE
    local lobbyY = Constants.LOBBY_HEIGHT

    -- Lobby floor
    local lobbyFloor = Instance.new("Part")
    lobbyFloor.Name = "LobbyFloor"
    lobbyFloor.Size = Vector3.new(lobbySize, 1, lobbySize)
    lobbyFloor.Position = Vector3.new(0, lobbyY - 0.5, 0)
    lobbyFloor.Anchored = true
    lobbyFloor.Material = Enum.Material.SmoothPlastic
    lobbyFloor.Color = Color3.fromRGB(180, 180, 220)
    lobbyFloor.Parent = lobbyFolder

    -- Lobby walls (prevent falling)
    local lobbyHalf = lobbySize / 2
    local lobbyWallHeight = 8
    local lobbyWalls = {
        { pos = Vector3.new(lobbyHalf, lobbyY + lobbyWallHeight / 2, 0), size = Vector3.new(1, lobbyWallHeight, lobbySize) },
        { pos = Vector3.new(-lobbyHalf, lobbyY + lobbyWallHeight / 2, 0), size = Vector3.new(1, lobbyWallHeight, lobbySize) },
        { pos = Vector3.new(0, lobbyY + lobbyWallHeight / 2, lobbyHalf), size = Vector3.new(lobbySize + 2, lobbyWallHeight, 1) },
        { pos = Vector3.new(0, lobbyY + lobbyWallHeight / 2, -lobbyHalf), size = Vector3.new(lobbySize + 2, lobbyWallHeight, 1) },
    }

    for i, wallData in ipairs(lobbyWalls) do
        local wall = Instance.new("Part")
        wall.Name = "LobbyWall_" .. i
        wall.Size = wallData.size
        wall.Position = wallData.pos
        wall.Anchored = true
        wall.Transparency = 0.5
        wall.CanCollide = true
        wall.Material = Enum.Material.Glass
        wall.Color = Color3.fromRGB(200, 200, 255)
        wall.Parent = lobbyFolder
    end

    -- Lobby ceiling (prevent jumping out)
    local lobbyCeiling = Instance.new("Part")
    lobbyCeiling.Name = "LobbyCeiling"
    lobbyCeiling.Size = Vector3.new(lobbySize + 2, 1, lobbySize + 2)
    lobbyCeiling.Position = Vector3.new(0, lobbyY + lobbyWallHeight + 0.5, 0)
    lobbyCeiling.Anchored = true
    lobbyCeiling.Transparency = 0.5
    lobbyCeiling.CanCollide = true
    lobbyCeiling.Material = Enum.Material.Glass
    lobbyCeiling.Color = Color3.fromRGB(200, 200, 255)
    lobbyCeiling.Parent = lobbyFolder

    return {
        Model = mapFolder,
        Definition = definition,
        SpawnsFolder = spawnsFolder,
    }
end

-- Find spawn markers matching a name pattern
function MapService:_getSpawnsByPattern(pattern)
    local map = self:GetOrCreateMap()
    if not map then
        return {}
    end

    local spawns = {}
    for _, child in ipairs(map.SpawnsFolder:GetChildren()) do
        if child.Name:match(pattern) then
            table.insert(spawns, child)
        end
    end
    return spawns
end

-- Teleport a player to a random spawn from a list, or a single named spawn
function MapService:_teleportToSpawn(player, spawns)
    if not player or not player.Character or #spawns == 0 then
        return false
    end

    local spawn = spawns[math.random(#spawns)]
    local targetPos = spawn.Position + Vector3.new(0, 3, 0)

    local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        humanoidRootPart.CFrame = CFrame.new(targetPos)
        return true
    end

    return false
end

function MapService:TeleportPlayerToSpawn(player, role)
    if role == Constants.ROLES.TAGGER then
        return self:_teleportToSpawn(player, self:_getSpawnsByPattern("^TaggerSpawn_"))
    else
        local runnerSpawn = self:GetOrCreateMap() and self:GetOrCreateMap().SpawnsFolder:FindFirstChild("RunnerSpawn")
        if runnerSpawn then
            return self:_teleportToSpawn(player, { runnerSpawn })
        end
        return false
    end
end

function MapService:TeleportToLobby(player)
    return self:_teleportToSpawn(player, self:_getSpawnsByPattern("^LobbySpawn_"))
end

function MapService:CleanupRound()
    -- For MVP, keep the map and reuse it
end

return MapService
