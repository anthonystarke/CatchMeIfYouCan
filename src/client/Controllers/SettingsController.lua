--[[
    SettingsController
    Handles player settings (music, SFX, etc.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsController = {}

-- State
SettingsController._settings = {
    MusicEnabled = true,
    SFXEnabled = true,
}

function SettingsController:Init()
    print("[SettingsController] Initializing...")
end

function SettingsController:Start()
    print("[SettingsController] Starting...")

    -- Load settings from server
    task.defer(function()
        local Remotes = ReplicatedStorage:WaitForChild("Remotes")
        local getSettings = Remotes:WaitForChild("GetSettings")
        local settings = getSettings:InvokeServer()
        if settings then
            self._settings = settings
            self:_applySettings()
        end
    end)
end

function SettingsController:_applySettings()
    -- Apply music/SFX settings
    print("[SettingsController] Applied settings:", self._settings.MusicEnabled, self._settings.SFXEnabled)
end

function SettingsController:GetSetting(key)
    return self._settings[key]
end

function SettingsController:SetSetting(key, value)
    self._settings[key] = value
    self:_applySettings()

    -- Persist to server
    task.spawn(function()
        local Remotes = ReplicatedStorage:WaitForChild("Remotes")
        local updateSetting = Remotes:WaitForChild("UpdateSetting")
        updateSetting:InvokeServer(key, value)
    end)
end

return SettingsController
