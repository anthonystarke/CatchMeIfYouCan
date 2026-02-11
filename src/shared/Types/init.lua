--[[
    Types
    Centralized type definitions for Catch Me If You Can

    Usage:
    local Types = require(path.to.Types)

    function doSomething(player: Types.PlayerData): Types.ServiceResponse
        ...
    end
]]

local Types = {}

--[=[
    @type Role "Tagger" | "Runner" | "Spectator"
    Player's role in the current round
]=]
export type Role = "Tagger" | "Runner" | "Spectator"

--[=[
    @type Phase "Lobby" | "Countdown" | "Playing" | "Results" | "Intermission"
    Current round phase
]=]
export type Phase = "Lobby" | "Countdown" | "Playing" | "Results" | "Intermission"

--[=[
    @type PowerupType "SpeedBoost" | "Invisibility" | "Shield" | "Freeze"
    Available powerup types
]=]
export type PowerupType = "SpeedBoost" | "Invisibility" | "Shield" | "Freeze"

--[=[
    @type PlayerStats
    Tracked statistics for a player
]=]
export type PlayerStats = {
    TotalTags: number,
    TotalEscapes: number,
    RoundsPlayed: number,
    RoundsWonAsTagger: number,
    RoundsWonAsRunner: number,
    TotalPoints: number,
    PowerupsCollected: number,
    LongestSurvival: number,
}

--[=[
    @type PlayerSettings
    Player preference settings
]=]
export type PlayerSettings = {
    MusicEnabled: boolean,
    SFXEnabled: boolean,
}

--[=[
    @type PlayerData
    Complete player data structure
]=]
export type PlayerData = {
    Coins: number,
    Gems: number,
    Stats: PlayerStats,
    Settings: PlayerSettings,
    OwnedSkins: {[string]: boolean},
    EquippedSkin: string?,
    OwnedTrails: {[string]: boolean},
    EquippedTrail: string?,
    OwnedEmotes: {[string]: boolean},
    FirstJoin: number,
    LastJoin: number,
}

--[=[
    @type RoundState
    Current state of an active round
]=]
export type RoundState = {
    Phase: Phase,
    Taggers: {Player},
    Runners: {Player},
    TaggedPlayers: {[number]: boolean},
    RoundStartTime: number,
    RoundEndTime: number,
    MapId: string?,
}

--[=[
    @type ServiceResponse
    Standardized response from service functions
]=]
export type ServiceResponse<T> = {
    success: boolean,
    message: string?,
} & T

return Types
