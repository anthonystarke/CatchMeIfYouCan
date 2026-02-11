--[[
    ResponseHelper
    Standardized response formatting for service functions
]]

local ResponseHelper = {}

-- Return a standardized error response
function ResponseHelper:Error(message, extra)
    local response = {
        success = false,
        message = message or "An error occurred",
    }

    if extra and type(extra) == "table" then
        for key, value in pairs(extra) do
            if key ~= "success" and key ~= "message" then
                response[key] = value
            end
        end
    end

    return response
end

-- Return a standardized success response
function ResponseHelper:Success(data)
    local response = {
        success = true,
    }

    if data and type(data) == "table" then
        for key, value in pairs(data) do
            if key ~= "success" then
                response[key] = value
            end
        end
    end

    return response
end

return ResponseHelper
