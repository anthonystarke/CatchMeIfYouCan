# Catch Me If You Can - Project Guide

## Overview
A Roblox tag/chase game where players take turns as Taggers and Runners across timed rounds.

## Tech Stack
- **Language**: Luau (Roblox Lua)
- **Build tool**: Rojo 7.7.0-rc.1 (syncs project files to Roblox Studio)
- **Runtime**: Lune 0.8.9 (Lua scripting runtime)
- **Testing**: Busted (Lua test framework) with custom Roblox mocks
- **Data persistence**: DataStore with retry/backoff pattern

## Architecture

### Service/Controller Pattern
Both server Services and client Controllers follow the **Init → Start** lifecycle:
1. `Init()` — Create remotes, set up state, register dependencies
2. `Start()` — Bind event handlers, begin active operation

### Project Structure
```
src/
  server/
    init.server.lua          # Server entry point (bootstraps all services)
    Services/                # Server-side game logic (Init/Start pattern)
      DataService.lua        # Player data persistence
      RoundService.lua       # Round lifecycle management
    Helpers/                 # Server utility modules
      RemoteHelper.lua       # Remote creation and rate-limited binding
      RateLimitHelper.lua    # Per-player rate limiting
      ResponseHelper.lua     # Standardized {success, message} responses
      ServiceHelper.lua      # Common service patterns
      ValidationHelper.lua   # Input validation helpers
  client/
    init.client.lua          # Client entry point (bootstraps all controllers)
    Controllers/             # Client-side UI and interaction logic
      UIController.lua       # Main HUD management
      RoundController.lua    # Client-side round state handling
      SettingsController.lua # Player settings
    Helpers/                 # Client utility modules
  shared/
    Config/                  # Game configuration (Constants, GameConfig)
      Constants.lua          # All magic numbers and enums
      GameConfig.lua         # UI colors, game settings
    Utils/
      init.lua               # Shared utility functions (format, array ops, etc.)
    Types/
      init.lua               # Luau type definitions
    Helpers/
      ObjectFinder.lua       # Workspace object search utility
tests/
  init.lua                   # Test bootstrap (paths + mocks)
  mocks/                     # Roblox API mocks for testing outside Studio
    roblox.lua               # Color3, Vector3, UDim2, Enum, CFrame mocks
    time.lua                 # Deterministic os.time mock
    player.lua               # Player and Players service mock
    remotes.lua              # RemoteEvent/RemoteFunction/Instance mocks
  shared/                    # Shared module tests
```

### Rojo Mapping (default.project.json)
- `ReplicatedStorage/Shared` → `src/shared`
- `ServerScriptService/Server` → `src/server`
- `StarterPlayer/StarterPlayerScripts/Client` → `src/client`

## Key Patterns

### Response Format
All service functions return: `{ success = boolean, message = string? }`
Use `ResponseHelper:Success(data)` and `ResponseHelper:Error(message)`.

### Remote Calls
Use `RemoteHelper` for creating and binding remotes with rate limiting:
```lua
local remote = RemoteHelper:CreateFunction("GetData", remotes)
RemoteHelper:BindFunction(remote, handler, { rateCategory = "Query" })
```

### Data Access
Always go through `DataService:GetData(player)` — never access DataStore directly.

## Commands

### Run tests
```bash
./run_tests.sh              # All tests
./run_tests.sh --verbose    # Verbose output
./run_tests.sh --file tests/shared/Constants_spec.lua  # Single file
```

### Rojo (sync to Studio)
```bash
rojo serve                  # Start sync server
rojo build -o game.rbxl     # Build place file
```

## Game Mechanics
- **Rounds**: Lobby → Countdown → Playing → Results → Intermission → repeat
- **Roles**: Tagger (chases) vs Runner (evades)
- **Scoring**: Points for tags, survival time, and round wins
- **Economy**: Coins and Gems for cosmetic purchases
