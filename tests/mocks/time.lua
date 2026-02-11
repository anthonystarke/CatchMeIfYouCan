--[[
    Time Mock
    Provides deterministic time control for testing time-based functions
]]

local TimeMock = {}

local originalOsTime = os.time
local originalOsClock = os.clock
local originalOsDate = os.date

local mockTime = nil
local mockClock = nil
local mockEnabled = false

function TimeMock.setTime(timestamp)
    mockTime = timestamp
    mockEnabled = true
end

function TimeMock.advance(seconds)
    if mockTime then
        mockTime = mockTime + seconds
    else
        mockTime = originalOsTime() + seconds
        mockEnabled = true
    end
end

function TimeMock.reset()
    mockTime = nil
    mockClock = nil
    mockEnabled = false
end

function TimeMock.getTime()
    if mockEnabled and mockTime then
        return mockTime
    end
    return originalOsTime()
end

function TimeMock.install()
    os.time = function(table)
        if table then
            return originalOsTime(table)
        end
        if mockEnabled and mockTime then
            return mockTime
        end
        return originalOsTime()
    end

    os.clock = function()
        if mockEnabled and mockClock then
            return mockClock
        end
        return originalOsClock()
    end

    os.date = function(format, time)
        if not time and mockEnabled and mockTime then
            time = mockTime
        end
        return originalOsDate(format, time)
    end

    mockEnabled = true
end

function TimeMock.uninstall()
    os.time = originalOsTime
    os.clock = originalOsClock
    os.date = originalOsDate
    mockEnabled = false
end

function TimeMock.isEnabled()
    return mockEnabled
end

function TimeMock.setClock(clock)
    mockClock = clock
    mockEnabled = true
end

function TimeMock.advanceClock(seconds)
    if mockClock then
        mockClock = mockClock + seconds
    else
        mockClock = originalOsClock() + seconds
        mockEnabled = true
    end
end

return TimeMock
