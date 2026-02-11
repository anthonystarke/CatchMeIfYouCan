--[[
    Player Mock
    Provides mock implementations of Roblox Player for testing server services
]]

local PlayerMock = {}

-- Player class mock
local Player = {}
Player.__index = Player

function Player.new(userId, name)
    local self = setmetatable({}, Player)
    self.UserId = userId or math.random(100000, 999999)
    self.Name = name or "TestPlayer" .. self.UserId
    self.Parent = {}
    self._className = "Player"
    return self
end

function Player:IsA(className)
    return className == "Player"
end

function Player:GetAttribute(name)
    return self._attributes and self._attributes[name]
end

function Player:SetAttribute(name, value)
    self._attributes = self._attributes or {}
    self._attributes[name] = value
end

function Player:Disconnect()
    self.Parent = nil
end

function Player:__tostring()
    return "Player: " .. self.Name
end

PlayerMock.Player = Player

-- Players service mock
local PlayersService = {}
PlayersService.__index = PlayersService

function PlayersService.new()
    local self = setmetatable({}, PlayersService)
    self._players = {}
    self._playerAddedCallbacks = {}
    self._playerRemovingCallbacks = {}
    return self
end

function PlayersService:GetPlayers()
    local list = {}
    for _, player in pairs(self._players) do
        table.insert(list, player)
    end
    return list
end

function PlayersService:AddPlayer(player)
    self._players[player.UserId] = player
    for _, callback in ipairs(self._playerAddedCallbacks) do
        callback(player)
    end
    return player
end

function PlayersService:RemovePlayer(player)
    if self._players[player.UserId] then
        for _, callback in ipairs(self._playerRemovingCallbacks) do
            callback(player)
        end
        self._players[player.UserId] = nil
        player.Parent = nil
    end
end

function PlayersService:GetPlayerByUserId(userId)
    return self._players[userId]
end

PlayersService.PlayerAdded = {
    Connect = function(self, callback)
        table.insert(PlayersService._playerAddedCallbacks, callback)
        return { Disconnect = function() end }
    end
}

PlayersService.PlayerRemoving = {
    Connect = function(self, callback)
        table.insert(PlayersService._playerRemovingCallbacks, callback)
        return { Disconnect = function() end }
    end
}

PlayerMock.PlayersService = PlayersService

function PlayerMock.createPlayer(userId, name)
    return Player.new(userId, name)
end

function PlayerMock.createPlayersService()
    return PlayersService.new()
end

function PlayerMock.install()
    local service = PlayersService.new()
    _G.Players = service
    PlayerMock._installedService = service
    return service
end

function PlayerMock.uninstall()
    _G.Players = nil
    PlayerMock._installedService = nil
end

return PlayerMock
