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
        runnerSpawns = {
            Vector3.new(-15, 5, -15),
            Vector3.new(15, 5, -15),
            Vector3.new(-15, 5, 15),
            Vector3.new(15, 5, 15),
            Vector3.new(-20, 5, 0),
            Vector3.new(20, 5, 0),
        },
        taggerSpawn = Vector3.new(0, 5, 0),
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

    for i, pos in ipairs(definition.runnerSpawns) do
        local marker = Instance.new("Part")
        marker.Name = "RunnerSpawn_" .. i
        marker.Size = Vector3.new(1, 1, 1)
        marker.Position = pos
        marker.Anchored = true
        marker.CanCollide = false
        marker.Transparency = 1
        marker.Parent = spawnsFolder
    end

    local taggerMarker = Instance.new("Part")
    taggerMarker.Name = "TaggerSpawn"
    taggerMarker.Size = Vector3.new(1, 1, 1)
    taggerMarker.Position = definition.taggerSpawn
    taggerMarker.Anchored = true
    taggerMarker.CanCollide = false
    taggerMarker.Transparency = 1
    taggerMarker.Parent = spawnsFolder

    return {
        Model = mapFolder,
        Definition = definition,
        SpawnsFolder = spawnsFolder,
    }
end

function MapService:TeleportPlayerToSpawn(player, role)
    if not player or not player.Character then
        return false
    end

    local map = self:GetOrCreateMap()
    if not map then
        return false
    end

    local spawnsFolder = map.SpawnsFolder
    local targetPos = nil

    if role == Constants.ROLES.TAGGER then
        local taggerSpawn = spawnsFolder:FindFirstChild("TaggerSpawn")
        if taggerSpawn then
            targetPos = taggerSpawn.Position + Vector3.new(0, 3, 0)
        end
    else
        -- Pick a random runner spawn
        local runnerSpawns = {}
        for _, child in ipairs(spawnsFolder:GetChildren()) do
            if child.Name:match("^RunnerSpawn_") then
                table.insert(runnerSpawns, child)
            end
        end

        if #runnerSpawns > 0 then
            local randomSpawn = runnerSpawns[math.random(#runnerSpawns)]
            targetPos = randomSpawn.Position + Vector3.new(0, 3, 0)
        end
    end

    if not targetPos then
        return false
    end

    local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        humanoidRootPart.CFrame = CFrame.new(targetPos)
        return true
    end

    return false
end

function MapService:CleanupRound()
    -- For MVP, keep the map and reuse it
end

return MapService
