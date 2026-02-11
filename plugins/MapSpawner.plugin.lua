--[[
    Map Spawner Plugin
    Spawns the full game world into Workspace for design-mode editing:
    arena (baseplate, walls, obstacles, spawn markers) and lobby platform above.

    Click "Spawn Map" to generate everything. Click "Clear Map" to remove it.
    Supports Ctrl+Z via ChangeHistoryService.

    Structure created:
    playground_panic (Folder)
    ├── Baseplate (Part)
    ├── Boundary_1..4 (Part, semi-transparent walls)
    ├── Obstacle_1..N (Part, colored blocks)
    ├── Spawns (Folder)
    │   ├── RunnerSpawn (Part, green marker)
    │   ├── TaggerSpawn_1..3 (Part, red markers)
    │   └── LobbySpawn_1..5 (Part, blue markers)
    └── Lobby (Folder)
        ├── LobbyFloor (Part)
        └── LobbyWall_1..4 (Part, glass walls)
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

-- Plugin setup
local toolbar = plugin:CreateToolbar("Catch Me If You Can")
local spawnButton = toolbar:CreateButton(
    "Spawn Map",
    "Spawn the full game world (arena + lobby) into Workspace",
    "rbxassetid://6031280882"
)
local clearButton = toolbar:CreateButton(
    "Clear Map",
    "Remove the spawned map from Workspace",
    "rbxassetid://6022668888"
)

-- Constants (mirrors Constants.lua)
local LOBBY_HEIGHT = 100
local LOBBY_SIZE = 30

-- Map definition (mirrors MapService.lua)
local MAP = {
    name = "Playground Panic",
    mapId = "playground_panic",
    size = 120,
    runnerSpawn = Vector3.new(0, 5, 0),
    taggerSpawns = {
        Vector3.new(50, 5, 0),
        Vector3.new(-25, 5, 43),
        Vector3.new(-25, 5, -43),
    },
    lobbySpawns = {
        Vector3.new(-5, LOBBY_HEIGHT + 1, -5),
        Vector3.new(5, LOBBY_HEIGHT + 1, -5),
        Vector3.new(-5, LOBBY_HEIGHT + 1, 5),
        Vector3.new(5, LOBBY_HEIGHT + 1, 5),
        Vector3.new(0, LOBBY_HEIGHT + 1, 0),
    },
    obstacles = {
        { pos = Vector3.new(-20, 3, 0), size = Vector3.new(12, 6, 12), color = Color3.fromRGB(255, 120, 80) },
        { pos = Vector3.new(20, 3, -20), size = Vector3.new(10, 6, 10), color = Color3.fromRGB(80, 200, 120) },
        { pos = Vector3.new(0, 3, 25), size = Vector3.new(14, 6, 8), color = Color3.fromRGB(100, 150, 255) },
        { pos = Vector3.new(-30, 3, 20), size = Vector3.new(8, 6, 8), color = Color3.fromRGB(255, 200, 80) },
        { pos = Vector3.new(30, 3, 15), size = Vector3.new(10, 6, 6), color = Color3.fromRGB(200, 100, 255) },
    },
}

-- Helper: create a labeled spawn marker
local function createSpawnMarker(name, pos, color, labelText, parent)
    local marker = Instance.new("Part")
    marker.Name = name
    marker.Size = Vector3.new(4, 0.3, 4)
    marker.Position = pos
    marker.Anchored = true
    marker.CanCollide = false
    marker.Color = color
    marker.Material = Enum.Material.Neon
    marker.Transparency = 0.3
    marker.Parent = parent

    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.new(0, 120, 0, 30)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.Adornee = marker
    gui.AlwaysOnTop = true
    gui.Parent = marker

    local label = Instance.new("TextLabel")
    label.Text = labelText
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.5
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = gui

    return marker
end

local function spawnMap()
    -- Remove existing map first
    local existing = workspace:FindFirstChild(MAP.mapId)
    if existing then
        existing:Destroy()
    end

    ChangeHistoryService:SetWaypoint("Before Spawn Map")

    local mapFolder = Instance.new("Folder")
    mapFolder.Name = MAP.mapId

    -- === ARENA ===

    -- Baseplate
    local baseplate = Instance.new("Part")
    baseplate.Name = "Baseplate"
    baseplate.Size = Vector3.new(MAP.size, 1, MAP.size)
    baseplate.Position = Vector3.new(0, -0.5, 0)
    baseplate.Anchored = true
    baseplate.Material = Enum.Material.Grass
    baseplate.Color = Color3.fromRGB(80, 160, 80)
    baseplate.Parent = mapFolder

    -- Boundary walls (semi-transparent for design mode visibility)
    local halfSize = MAP.size / 2
    local wallHeight = 20
    local wallThickness = 2

    local walls = {
        { pos = Vector3.new(halfSize + wallThickness / 2, wallHeight / 2, 0), size = Vector3.new(wallThickness, wallHeight, MAP.size) },
        { pos = Vector3.new(-halfSize - wallThickness / 2, wallHeight / 2, 0), size = Vector3.new(wallThickness, wallHeight, MAP.size) },
        { pos = Vector3.new(0, wallHeight / 2, halfSize + wallThickness / 2), size = Vector3.new(MAP.size + wallThickness * 2, wallHeight, wallThickness) },
        { pos = Vector3.new(0, wallHeight / 2, -halfSize - wallThickness / 2), size = Vector3.new(MAP.size + wallThickness * 2, wallHeight, wallThickness) },
    }

    for i, wallData in ipairs(walls) do
        local wall = Instance.new("Part")
        wall.Name = "Boundary_" .. i
        wall.Size = wallData.size
        wall.Position = wallData.pos
        wall.Anchored = true
        wall.Transparency = 0.8
        wall.CanCollide = true
        wall.Color = Color3.fromRGB(200, 200, 200)
        wall.Material = Enum.Material.ForceField
        wall.Parent = mapFolder
    end

    -- Obstacles
    for i, obs in ipairs(MAP.obstacles) do
        local part = Instance.new("Part")
        part.Name = "Obstacle_" .. i
        part.Size = obs.size
        part.Position = obs.pos
        part.Anchored = true
        part.Material = Enum.Material.SmoothPlastic
        part.Color = obs.color
        part.Parent = mapFolder
    end

    -- === SPAWN MARKERS ===

    local spawnsFolder = Instance.new("Folder")
    spawnsFolder.Name = "Spawns"
    spawnsFolder.Parent = mapFolder

    -- Runner spawn (center, green)
    createSpawnMarker("RunnerSpawn", MAP.runnerSpawn, Color3.fromRGB(0, 200, 0), "RUNNER SPAWN", spawnsFolder)

    -- Tagger spawns (circle, red)
    for i, pos in ipairs(MAP.taggerSpawns) do
        createSpawnMarker("TaggerSpawn_" .. i, pos, Color3.fromRGB(200, 0, 0), "TAGGER " .. i, spawnsFolder)
    end

    -- Lobby spawns (blue)
    for i, pos in ipairs(MAP.lobbySpawns) do
        createSpawnMarker("LobbySpawn_" .. i, pos, Color3.fromRGB(80, 120, 255), "LOBBY " .. i, spawnsFolder)
    end

    -- === LOBBY PLATFORM ===

    local lobbyFolder = Instance.new("Folder")
    lobbyFolder.Name = "Lobby"
    lobbyFolder.Parent = mapFolder

    local lobbyY = LOBBY_HEIGHT

    -- Lobby floor
    local lobbyFloor = Instance.new("Part")
    lobbyFloor.Name = "LobbyFloor"
    lobbyFloor.Size = Vector3.new(LOBBY_SIZE, 1, LOBBY_SIZE)
    lobbyFloor.Position = Vector3.new(0, lobbyY - 0.5, 0)
    lobbyFloor.Anchored = true
    lobbyFloor.Material = Enum.Material.SmoothPlastic
    lobbyFloor.Color = Color3.fromRGB(180, 180, 220)
    lobbyFloor.Parent = lobbyFolder

    -- Lobby glass walls
    local lobbyHalf = LOBBY_SIZE / 2
    local lobbyWallHeight = 8
    local lobbyWalls = {
        { pos = Vector3.new(lobbyHalf, lobbyY + lobbyWallHeight / 2, 0), size = Vector3.new(1, lobbyWallHeight, LOBBY_SIZE) },
        { pos = Vector3.new(-lobbyHalf, lobbyY + lobbyWallHeight / 2, 0), size = Vector3.new(1, lobbyWallHeight, LOBBY_SIZE) },
        { pos = Vector3.new(0, lobbyY + lobbyWallHeight / 2, lobbyHalf), size = Vector3.new(LOBBY_SIZE + 2, lobbyWallHeight, 1) },
        { pos = Vector3.new(0, lobbyY + lobbyWallHeight / 2, -lobbyHalf), size = Vector3.new(LOBBY_SIZE + 2, lobbyWallHeight, 1) },
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

    mapFolder.Parent = workspace
    Selection:Set({mapFolder})

    ChangeHistoryService:SetWaypoint("After Spawn Map")
    print("[MapSpawner] Spawned arena + lobby")
end

local function clearMap()
    local existing = workspace:FindFirstChild(MAP.mapId)
    if not existing then
        warn("[MapSpawner] No map found to clear")
        return
    end

    ChangeHistoryService:SetWaypoint("Before Clear Map")
    existing:Destroy()
    ChangeHistoryService:SetWaypoint("After Clear Map")
    print("[MapSpawner] Cleared map")
end

-- Button handlers
spawnButton.Click:Connect(spawnMap)
clearButton.Click:Connect(clearMap)

print("[MapSpawner] Map Spawner plugin loaded!")
