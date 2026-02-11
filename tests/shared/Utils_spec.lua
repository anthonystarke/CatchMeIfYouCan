--[[
    Utils Tests
    Validates shared utility functions
]]

describe("Utils", function()
    local Utils

    setup(function()
        Utils = require("Utils")
    end)

    describe("FormatNumber", function()
        it("should format small numbers without commas", function()
            assert.equal("100", Utils.FormatNumber(100))
        end)

        it("should format thousands with commas", function()
            assert.equal("1,000", Utils.FormatNumber(1000))
        end)

        it("should format millions with commas", function()
            assert.equal("1,000,000", Utils.FormatNumber(1000000))
        end)

        it("should handle zero", function()
            assert.equal("0", Utils.FormatNumber(0))
        end)
    end)

    describe("FormatTime", function()
        it("should format seconds", function()
            assert.equal("30s", Utils.FormatTime(30))
        end)

        it("should format minutes and seconds", function()
            assert.equal("2m 30s", Utils.FormatTime(150))
        end)

        it("should format hours and minutes", function()
            assert.equal("1h 30m", Utils.FormatTime(5400))
        end)

        it("should handle zero", function()
            assert.equal("0s", Utils.FormatTime(0))
        end)

        it("should handle negative values as zero", function()
            assert.equal("0s", Utils.FormatTime(-10))
        end)
    end)

    describe("Clamp", function()
        it("should clamp below minimum", function()
            assert.equal(0, Utils.Clamp(-5, 0, 100))
        end)

        it("should clamp above maximum", function()
            assert.equal(100, Utils.Clamp(150, 0, 100))
        end)

        it("should not clamp within range", function()
            assert.equal(50, Utils.Clamp(50, 0, 100))
        end)
    end)

    describe("DeepCopy", function()
        it("should copy simple tables", function()
            local original = { a = 1, b = 2 }
            local copy = Utils.DeepCopy(original)
            assert.equal(1, copy.a)
            assert.equal(2, copy.b)
            copy.a = 99
            assert.equal(1, original.a)
        end)

        it("should copy nested tables", function()
            local original = { a = { b = { c = 3 } } }
            local copy = Utils.DeepCopy(original)
            assert.equal(3, copy.a.b.c)
            copy.a.b.c = 99
            assert.equal(3, original.a.b.c)
        end)

        it("should handle non-table values", function()
            assert.equal(42, Utils.DeepCopy(42))
            assert.equal("hello", Utils.DeepCopy("hello"))
            assert.equal(true, Utils.DeepCopy(true))
        end)
    end)

    describe("Shuffle", function()
        it("should return array of same length", function()
            local array = {1, 2, 3, 4, 5}
            local shuffled = Utils.Shuffle(array)
            assert.equal(#array, #shuffled)
        end)

        it("should not mutate original array", function()
            local array = {1, 2, 3}
            Utils.Shuffle(array)
            assert.equal(1, array[1])
            assert.equal(2, array[2])
            assert.equal(3, array[3])
        end)
    end)

    describe("Filter", function()
        it("should filter matching items", function()
            local array = {1, 2, 3, 4, 5}
            local evens = Utils.Filter(array, function(v) return v % 2 == 0 end)
            assert.equal(2, #evens)
            assert.equal(2, evens[1])
            assert.equal(4, evens[2])
        end)
    end)

    describe("Map", function()
        it("should transform all items", function()
            local array = {1, 2, 3}
            local doubled = Utils.Map(array, function(v) return v * 2 end)
            assert.equal(2, doubled[1])
            assert.equal(4, doubled[2])
            assert.equal(6, doubled[3])
        end)
    end)

    describe("Find", function()
        it("should find matching item", function()
            local array = {1, 2, 3, 4, 5}
            local item, index = Utils.Find(array, function(v) return v == 3 end)
            assert.equal(3, item)
            assert.equal(3, index)
        end)

        it("should return nil for no match", function()
            local array = {1, 2, 3}
            local item, index = Utils.Find(array, function(v) return v == 99 end)
            assert.is_nil(item)
            assert.is_nil(index)
        end)
    end)

    describe("Partition", function()
        it("should split array by predicate", function()
            local array = {1, 2, 3, 4, 5}
            local evens, odds = Utils.Partition(array, function(v) return v % 2 == 0 end)
            assert.equal(2, #evens)
            assert.equal(3, #odds)
        end)
    end)
end)
