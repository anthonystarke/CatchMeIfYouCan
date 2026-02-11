--[[
    RemoteHelper
    Centralized remote creation and binding utilities
]]

local Helpers = script.Parent
local RateLimitHelper = require(Helpers:WaitForChild("RateLimitHelper"))

local RemoteHelper = {}

-- Standard rate-limited error response
local RATE_LIMIT_RESPONSE = {
    success = false,
    message = "Too many requests. Please wait.",
}

-- Create a RemoteFunction with the given name under the specified parent
function RemoteHelper:CreateFunction(name, parent)
    local remote = Instance.new("RemoteFunction")
    remote.Name = name
    remote.Parent = parent
    return remote
end

-- Create a RemoteEvent with the given name under the specified parent
function RemoteHelper:CreateEvent(name, parent)
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = parent
    return remote
end

-- Bind a handler to a RemoteFunction's OnServerInvoke
-- options.rateCategory: Rate limit category (Purchase, Action, DataMutation, Query, Default)
function RemoteHelper:BindFunction(remote, handler, options)
    options = options or {}
    local rateCategory = options.rateCategory

    if rateCategory then
        remote.OnServerInvoke = function(player, ...)
            if not RateLimitHelper:CheckLimit(player, rateCategory) then
                return RATE_LIMIT_RESPONSE
            end
            return handler(player, ...)
        end
    else
        remote.OnServerInvoke = handler
    end
end

-- Bind a handler to a RemoteEvent's OnServerEvent
-- options.rateCategory: Rate limit category (Purchase, Action, DataMutation, Query, Default)
function RemoteHelper:BindEvent(remote, handler, options)
    options = options or {}
    local rateCategory = options.rateCategory

    if rateCategory then
        remote.OnServerEvent:Connect(function(player, ...)
            if RateLimitHelper:CheckLimit(player, rateCategory) then
                handler(player, ...)
            end
        end)
    else
        remote.OnServerEvent:Connect(handler)
    end
end

-- Initialize rate limiting (call from server init)
function RemoteHelper:Init()
    RateLimitHelper:Init()
end

return RemoteHelper
