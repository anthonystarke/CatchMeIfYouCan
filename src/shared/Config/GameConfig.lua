--[[
    GameConfig
    Global game settings and constants

    Note: Default player values are in Constants.lua (used by DataService)
]]

local GameConfig = {}

-- Standard UI dimensions for menu backdrops
GameConfig.UI = {
    BackdropSize = UDim2.new(0.65, 0, 0.85, 0),
    BackdropPosition = UDim2.new(0.175, 0, 0.075, 0),
}

-- Menu UI colors
GameConfig.MenuColors = {
    Backdrop = Color3.fromRGB(25, 25, 35),
    BackdropBorder = Color3.fromRGB(60, 60, 80),
    CloseButton = Color3.fromRGB(60, 60, 80),
    CardBackground = Color3.fromRGB(40, 40, 50),
    CardHover = Color3.fromRGB(55, 55, 70),
    HeaderBackground = Color3.fromRGB(40, 40, 50),
    AccentLine = Color3.fromRGB(100, 150, 200),
    RewardCoins = Color3.fromRGB(255, 215, 0),
}

-- Role colors (for UI and nametags)
GameConfig.RoleColors = {
    Tagger = Color3.fromRGB(255, 80, 80),
    Runner = Color3.fromRGB(80, 200, 255),
    Spectator = Color3.fromRGB(150, 150, 150),
}

-- Powerup types and their colors
GameConfig.PowerupColors = {
    SpeedBoost = Color3.fromRGB(255, 255, 100),
    Invisibility = Color3.fromRGB(200, 200, 255),
    Shield = Color3.fromRGB(100, 255, 100),
    Freeze = Color3.fromRGB(100, 200, 255),
}

-- Semantic state backgrounds
GameConfig.StateBackgrounds = {
    Success = Color3.fromRGB(30, 50, 30),
    Warning = Color3.fromRGB(40, 35, 30),
    Danger = Color3.fromRGB(50, 30, 30),
    Dark = Color3.fromRGB(25, 30, 35),
    DarkElevated = Color3.fromRGB(35, 40, 45),
}

return GameConfig
