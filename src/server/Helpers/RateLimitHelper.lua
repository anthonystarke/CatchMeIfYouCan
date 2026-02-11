--[[
    RateLimitHelper
    Per-player rate limiting for remote calls to prevent abuse
]]

local Players = game:GetService("Players")

local RateLimitHelper = {}

-- Rate limit categories with their limits
-- maxCalls: maximum calls allowed within the time window
-- windowSeconds: sliding window duration in seconds
RateLimitHelper.Categories = {
    Purchase = { maxCalls = 5, windowSeconds = 10 },
    Action = { maxCalls = 10, windowSeconds = 5 },
    DataMutation = { maxCalls = 10, windowSeconds = 5 },
    Query = { maxCalls = 20, windowSeconds = 5 },
    Default = { maxCalls = 15, windowSeconds = 5 },
}

-- Per-player tracking
RateLimitHelper._playerLimits = {}

-- Warning cooldown (don't spam warnings)
local WARNING_COOLDOWN = 30

-- Check if a player is within rate limits for a category
function RateLimitHelper:CheckLimit(player, category)
    if not player or not player:IsA("Player") then
        return true
    end

    local playerId = player.UserId
    category = category or "Default"

    local config = self.Categories[category]
    if not config then
        config = self.Categories.Default
    end

    local now = os.time()

    if not self._playerLimits[playerId] then
        self._playerLimits[playerId] = {}
    end

    if not self._playerLimits[playerId][category] then
        self._playerLimits[playerId][category] = {
            calls = {},
            lastWarning = 0,
        }
    end

    local playerCategory = self._playerLimits[playerId][category]
    local calls = playerCategory.calls

    -- Remove old calls outside the window
    local windowStart = now - config.windowSeconds
    local newCalls = {}
    for _, callTime in ipairs(calls) do
        if callTime > windowStart then
            table.insert(newCalls, callTime)
        end
    end
    playerCategory.calls = newCalls

    -- Check if over limit
    if #newCalls >= config.maxCalls then
        if now - playerCategory.lastWarning >= WARNING_COOLDOWN then
            playerCategory.lastWarning = now
            warn("[RateLimitHelper] Player", player.Name, "rate limited on", category,
                "- calls:", #newCalls, "/", config.maxCalls,
                "in", config.windowSeconds, "seconds")
        end
        return false
    end

    -- Allow and record this call
    table.insert(playerCategory.calls, now)
    return true
end

-- Clear all rate limit data for a player (call on disconnect)
function RateLimitHelper:ClearPlayer(player)
    if player and player:IsA("Player") then
        self._playerLimits[player.UserId] = nil
    end
end

-- Initialize cleanup on player leaving
function RateLimitHelper:Init()
    Players.PlayerRemoving:Connect(function(player)
        self:ClearPlayer(player)
    end)
end

return RateLimitHelper
