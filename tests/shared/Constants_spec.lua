--[[
    Constants Tests
    Validates game constants are properly defined
]]

describe("Constants", function()
    local Constants

    setup(function()
        Constants = require("Constants")
    end)

    describe("Round roles", function()
        it("should define all roles", function()
            assert.is_not_nil(Constants.ROLES.TAGGER)
            assert.is_not_nil(Constants.ROLES.RUNNER)
            assert.is_not_nil(Constants.ROLES.SPECTATOR)
        end)
    end)

    describe("Round phases", function()
        it("should define all phases", function()
            assert.is_not_nil(Constants.PHASES.LOBBY)
            assert.is_not_nil(Constants.PHASES.COUNTDOWN)
            assert.is_not_nil(Constants.PHASES.PLAYING)
            assert.is_not_nil(Constants.PHASES.RESULTS)
            assert.is_not_nil(Constants.PHASES.INTERMISSION)
        end)
    end)

    describe("Default player values", function()
        it("should have positive default coins", function()
            assert.is_true(Constants.DEFAULT_COINS > 0)
        end)

        it("should have non-negative default gems", function()
            assert.is_true(Constants.DEFAULT_GEMS >= 0)
        end)
    end)

    describe("Round timing", function()
        it("should have positive round duration", function()
            assert.is_true(Constants.ROUND_DURATION > 0)
        end)

        it("should require at least 2 players", function()
            assert.is_true(Constants.MIN_PLAYERS >= 2)
        end)

        it("should have at least 1 tagger per round", function()
            assert.is_true(Constants.TAGGERS_PER_ROUND >= 1)
        end)

        it("should have countdown time", function()
            assert.is_true(Constants.COUNTDOWN_TIME > 0)
        end)
    end)

    describe("Tag mechanics", function()
        it("should have positive tag cooldown", function()
            assert.is_true(Constants.TAG_COOLDOWN > 0)
        end)

        it("should have positive tag range", function()
            assert.is_true(Constants.TAG_RANGE > 0)
        end)
    end)

    describe("Scoring", function()
        it("should award points for tagging", function()
            assert.is_true(Constants.POINTS_PER_TAG > 0)
        end)

        it("should award coins for winning", function()
            assert.is_true(Constants.COINS_PER_WIN > 0)
        end)
    end)

    describe("Data store", function()
        it("should have a data store key", function()
            assert.is_not_nil(Constants.DATA_STORE_KEY)
            assert.is_string(Constants.DATA_STORE_KEY)
        end)
    end)
end)
