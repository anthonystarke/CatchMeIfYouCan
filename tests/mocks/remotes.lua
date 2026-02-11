--[[
    Remotes Mock
    Provides mock implementations of RemoteFunction and RemoteEvent for testing
]]

local RemotesMock = {}

-- RemoteFunction mock
local RemoteFunction = {}
RemoteFunction.__index = RemoteFunction

function RemoteFunction.new(name)
    local self = setmetatable({}, RemoteFunction)
    self.Name = name or "RemoteFunction"
    self.Parent = nil
    self.OnServerInvoke = nil
    self._className = "RemoteFunction"
    return self
end

function RemoteFunction:IsA(className)
    return className == "RemoteFunction"
end

function RemoteFunction:InvokeServer(player, ...)
    if self.OnServerInvoke then
        return self.OnServerInvoke(player, ...)
    end
    return nil
end

function RemoteFunction:__tostring()
    return "RemoteFunction: " .. self.Name
end

RemotesMock.RemoteFunction = RemoteFunction

-- RemoteEvent mock
local RemoteEvent = {}
RemoteEvent.__index = RemoteEvent

function RemoteEvent.new(name)
    local self = setmetatable({}, RemoteEvent)
    self.Name = name or "RemoteEvent"
    self.Parent = nil
    self._serverCallbacks = {}
    self._clientFires = {}
    self._className = "RemoteEvent"
    return self
end

function RemoteEvent:IsA(className)
    return className == "RemoteEvent"
end

RemoteEvent.OnServerEvent = {
    Connect = function(event, callback)
        table.insert(event._serverCallbacks, callback)
        return {
            Disconnect = function()
                for i, cb in ipairs(event._serverCallbacks) do
                    if cb == callback then
                        table.remove(event._serverCallbacks, i)
                        break
                    end
                end
            end
        }
    end
}

function RemoteEvent:FireServer(player, ...)
    for _, callback in ipairs(self._serverCallbacks) do
        callback(player, ...)
    end
end

function RemoteEvent:FireClient(player, ...)
    table.insert(self._clientFires, {
        player = player,
        args = {...}
    })
end

function RemoteEvent:FireAllClients(...)
    table.insert(self._clientFires, {
        player = "all",
        args = {...}
    })
end

function RemoteEvent:GetClientFires()
    return self._clientFires
end

function RemoteEvent:ClearFires()
    self._clientFires = {}
end

function RemoteEvent:__tostring()
    return "RemoteEvent: " .. self.Name
end

RemotesMock.RemoteEvent = RemoteEvent

-- Instance mock for creating remotes
local Instance = {}
Instance.__index = Instance

function Instance.new(className)
    if className == "RemoteFunction" then
        return RemoteFunction.new()
    elseif className == "RemoteEvent" then
        return RemoteEvent.new()
    elseif className == "Folder" then
        return {
            Name = "Folder",
            Parent = nil,
            _children = {},
            FindFirstChild = function(self, name)
                return self._children[name]
            end,
            WaitForChild = function(self, name)
                return self._children[name]
            end,
        }
    end
    return {
        Name = className,
        Parent = nil,
        _className = className,
        IsA = function(self, cn) return cn == className end,
    }
end

RemotesMock.Instance = Instance

function RemotesMock.createRemotesFolder()
    local folder = {
        Name = "Remotes",
        Parent = nil,
        _children = {},
        FindFirstChild = function(self, name)
            return self._children[name]
        end,
        WaitForChild = function(self, name)
            return self._children[name]
        end,
    }
    return folder
end

function RemotesMock.install()
    _G.Instance = Instance
end

function RemotesMock.uninstall()
    _G.Instance = nil
end

return RemotesMock
