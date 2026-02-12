--[[
    Roblox Mocks
    Provides mock implementations of Roblox globals for testing outside of Roblox Studio
]]

local RobloxMocks = {}

-- Color3 mock
local Color3 = {}
Color3.__index = Color3

function Color3.new(r, g, b)
    local self = setmetatable({}, Color3)
    self.R = r or 0
    self.G = g or 0
    self.B = b or 0
    return self
end

function Color3.fromRGB(r, g, b)
    return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end

function Color3.fromHSV(h, s, v)
    local r, g, b = v, v, v
    if s > 0 then
        local i = math.floor(h * 6)
        local f = h * 6 - i
        local p = v * (1 - s)
        local q = v * (1 - f * s)
        local t = v * (1 - (1 - f) * s)
        i = i % 6
        if i == 0 then r, g, b = v, t, p
        elseif i == 1 then r, g, b = q, v, p
        elseif i == 2 then r, g, b = p, v, t
        elseif i == 3 then r, g, b = p, q, v
        elseif i == 4 then r, g, b = t, p, v
        elseif i == 5 then r, g, b = v, p, q
        end
    end
    return Color3.new(r, g, b)
end

function Color3:Lerp(other, alpha)
    return Color3.new(
        self.R + (other.R - self.R) * alpha,
        self.G + (other.G - self.G) * alpha,
        self.B + (other.B - self.B) * alpha
    )
end

function Color3:__eq(other)
    if getmetatable(other) ~= Color3 then return false end
    return self.R == other.R and self.G == other.G and self.B == other.B
end

function Color3:__tostring()
    return string.format("Color3(%f, %f, %f)", self.R, self.G, self.B)
end

RobloxMocks.Color3 = Color3

-- Vector3 mock
local Vector3 = {}
Vector3.__index = Vector3

function Vector3.new(x, y, z)
    local self = setmetatable({}, Vector3)
    self.X = x or 0
    self.Y = y or 0
    self.Z = z or 0
    self.Magnitude = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
    return self
end

Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

function Vector3:__add(other)
    return Vector3.new(self.X + other.X, self.Y + other.Y, self.Z + other.Z)
end

function Vector3:__sub(other)
    return Vector3.new(self.X - other.X, self.Y - other.Y, self.Z - other.Z)
end

function Vector3:__mul(other)
    if type(other) == "number" then
        return Vector3.new(self.X * other, self.Y * other, self.Z * other)
    end
    return Vector3.new(self.X * other.X, self.Y * other.Y, self.Z * other.Z)
end

function Vector3:__div(other)
    if type(other) == "number" then
        return Vector3.new(self.X / other, self.Y / other, self.Z / other)
    end
    return Vector3.new(self.X / other.X, self.Y / other.Y, self.Z / other.Z)
end

function Vector3:__eq(other)
    if getmetatable(other) ~= Vector3 then return false end
    return self.X == other.X and self.Y == other.Y and self.Z == other.Z
end

function Vector3:__tostring()
    return string.format("Vector3(%f, %f, %f)", self.X, self.Y, self.Z)
end

function Vector3:Dot(other)
    return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end

function Vector3:Cross(other)
    return Vector3.new(
        self.Y * other.Z - self.Z * other.Y,
        self.Z * other.X - self.X * other.Z,
        self.X * other.Y - self.Y * other.X
    )
end

function Vector3:Lerp(other, alpha)
    return Vector3.new(
        self.X + (other.X - self.X) * alpha,
        self.Y + (other.Y - self.Y) * alpha,
        self.Z + (other.Z - self.Z) * alpha
    )
end

RobloxMocks.Vector3 = Vector3

-- Vector2 mock
local Vector2 = {}
Vector2.__index = Vector2

function Vector2.new(x, y)
    local self = setmetatable({}, Vector2)
    self.X = x or 0
    self.Y = y or 0
    return self
end

Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)

function Vector2:__add(other)
    return Vector2.new(self.X + other.X, self.Y + other.Y)
end

function Vector2:__sub(other)
    return Vector2.new(self.X - other.X, self.Y - other.Y)
end

function Vector2:__mul(other)
    if type(other) == "number" then
        return Vector2.new(self.X * other, self.Y * other)
    end
    return Vector2.new(self.X * other.X, self.Y * other.Y)
end

function Vector2:__eq(other)
    if getmetatable(other) ~= Vector2 then return false end
    return self.X == other.X and self.Y == other.Y
end

function Vector2:__tostring()
    return string.format("Vector2(%f, %f)", self.X, self.Y)
end

RobloxMocks.Vector2 = Vector2

-- Enum mock
local Enum = {}
local EnumMeta = {
    __index = function(self, key)
        if rawget(self, "_items") and rawget(self, "_items")[key] then
            return rawget(self, "_items")[key]
        end
        local items = rawget(self, "_items") or {}
        local enumItem = { Name = key, Value = #items, EnumType = self }
        items[key] = enumItem
        rawset(self, "_items", items)
        return enumItem
    end
}

setmetatable(Enum, {
    __index = function(_, enumName)
        local enumType = setmetatable({ _name = enumName, _items = {} }, EnumMeta)
        return enumType
    end
})

RobloxMocks.Enum = Enum

-- UDim2 mock
local UDim2 = {}
UDim2.__index = UDim2

function UDim2.new(scaleX, offsetX, scaleY, offsetY)
    local self = setmetatable({}, UDim2)
    self.X = { Scale = scaleX or 0, Offset = offsetX or 0 }
    self.Y = { Scale = scaleY or 0, Offset = offsetY or 0 }
    return self
end

function UDim2.fromScale(x, y)
    return UDim2.new(x, 0, y, 0)
end

function UDim2.fromOffset(x, y)
    return UDim2.new(0, x, 0, y)
end

RobloxMocks.UDim2 = UDim2

-- CFrame mock (simplified)
local CFrame = {}
CFrame.__index = CFrame

function CFrame.new(x, y, z)
    local self = setmetatable({}, CFrame)
    self.Position = Vector3.new(x or 0, y or 0, z or 0)
    return self
end

CFrame.identity = CFrame.new(0, 0, 0)

RobloxMocks.CFrame = CFrame

-- ColorSequence mock
local ColorSequence = {}
ColorSequence.__index = ColorSequence

function ColorSequence.new(val)
    local self = setmetatable({}, ColorSequence)
    self.Keypoints = val
    return self
end

RobloxMocks.ColorSequence = ColorSequence

-- NumberRange mock
local NumberRange = {}
NumberRange.__index = NumberRange

function NumberRange.new(min, max)
    local self = setmetatable({}, NumberRange)
    self.Min = min or 0
    self.Max = max or min or 0
    return self
end

RobloxMocks.NumberRange = NumberRange

-- NumberSequenceKeypoint mock
local NumberSequenceKeypoint = {}
NumberSequenceKeypoint.__index = NumberSequenceKeypoint

function NumberSequenceKeypoint.new(time, value, envelope)
    local self = setmetatable({}, NumberSequenceKeypoint)
    self.Time = time or 0
    self.Value = value or 0
    self.Envelope = envelope or 0
    return self
end

RobloxMocks.NumberSequenceKeypoint = NumberSequenceKeypoint

-- NumberSequence mock
local NumberSequence = {}
NumberSequence.__index = NumberSequence

function NumberSequence.new(val)
    local self = setmetatable({}, NumberSequence)
    self.Keypoints = val
    return self
end

RobloxMocks.NumberSequence = NumberSequence

-- Install mocks globally
function RobloxMocks.install()
    _G.Color3 = RobloxMocks.Color3
    _G.Vector3 = RobloxMocks.Vector3
    _G.Vector2 = RobloxMocks.Vector2
    _G.Enum = RobloxMocks.Enum
    _G.UDim2 = RobloxMocks.UDim2
    _G.CFrame = RobloxMocks.CFrame
    _G.ColorSequence = RobloxMocks.ColorSequence
    _G.NumberRange = RobloxMocks.NumberRange
    _G.NumberSequenceKeypoint = RobloxMocks.NumberSequenceKeypoint
    _G.NumberSequence = RobloxMocks.NumberSequence

    Color3 = RobloxMocks.Color3
    Vector3 = RobloxMocks.Vector3
    Vector2 = RobloxMocks.Vector2
    Enum = RobloxMocks.Enum
    UDim2 = RobloxMocks.UDim2
    CFrame = RobloxMocks.CFrame
    ColorSequence = RobloxMocks.ColorSequence
    NumberRange = RobloxMocks.NumberRange
    NumberSequenceKeypoint = RobloxMocks.NumberSequenceKeypoint
    NumberSequence = RobloxMocks.NumberSequence
end

-- Uninstall mocks
function RobloxMocks.uninstall()
    _G.Color3 = nil
    _G.Vector3 = nil
    _G.Vector2 = nil
    _G.Enum = nil
    _G.UDim2 = nil
    _G.CFrame = nil
    _G.ColorSequence = nil
    _G.NumberRange = nil
    _G.NumberSequenceKeypoint = nil
    _G.NumberSequence = nil
end

return RobloxMocks
