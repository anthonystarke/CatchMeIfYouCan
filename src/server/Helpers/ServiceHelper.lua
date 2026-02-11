--[[
    ServiceHelper
    Common service patterns to reduce boilerplate across server services
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Helpers = script.Parent
local ResponseHelper = require(Helpers:WaitForChild("ResponseHelper"))

local ServiceHelper = {}

-- Get player data or return error response
-- Returns: data, errorResponse
function ServiceHelper:RequireDataOrError(player, DataService)
    local data = DataService:GetData(player)
    if not data then
        return nil, ResponseHelper:Error("Data not loaded")
    end
    return data, nil
end

return ServiceHelper
