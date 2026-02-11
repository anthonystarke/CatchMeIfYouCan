--[[
    ValidationHelper
    Consolidated validation patterns for service handlers
]]

local ValidationHelper = {}

-- Validate player is in expected role
function ValidationHelper:ValidatePlayerRole(roundState, player, expectedRole)
    if not roundState then
        return false, "No active round"
    end

    -- Check taggers
    if expectedRole == "Tagger" then
        for _, tagger in ipairs(roundState.Taggers) do
            if tagger.UserId == player.UserId then
                return true, nil
            end
        end
        return false, "Player is not a tagger"
    end

    -- Check runners
    if expectedRole == "Runner" then
        for _, runner in ipairs(roundState.Runners) do
            if runner.UserId == player.UserId then
                return true, nil
            end
        end
        return false, "Player is not a runner"
    end

    return false, "Unknown role: " .. tostring(expectedRole)
end

return ValidationHelper
