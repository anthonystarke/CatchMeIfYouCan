--[[
    UIController
    Manages the main HUD and UI elements
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Config"):WaitForChild("Constants"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Utils = require(Shared:WaitForChild("Utils"))

local UIController = {}

-- State
UIController._coins = 0
UIController._screenGui = nil
UIController._timerLabel = nil
UIController._roleBanner = nil
UIController._roleText = nil
UIController._runnersLabel = nil
UIController._coinsLabel = nil
UIController._phaseLabel = nil
UIController._tagNotification = nil
UIController._countdownLabel = nil
UIController._statusFrame = nil
UIController._statusTitle = nil
UIController._statusSubtitle = nil

function UIController:Init()
    print("[UIController] Initializing...")
end

function UIController:Start()
    print("[UIController] Starting...")
    self:_createHUD()
end

function UIController:_createHUD()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- Create main ScreenGui
    self._screenGui = Instance.new("ScreenGui")
    self._screenGui.Name = "MainHUD"
    self._screenGui.ResetOnSpawn = false
    self._screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self._screenGui.Parent = playerGui

    self:_createTimerDisplay()
    self:_createRoleBanner()
    self:_createRunnersCounter()
    self:_createCoinsDisplay()
    self:_createPhaseIndicator()
    self:_createTagNotification()
    self:_createCountdownDisplay()
    self:_createStatusDisplay()
end

-- Helper: create a styled HUD container with rounded corners
function UIController:_createHUDContainer(name, size, position, cornerRadius, transparency)
    local container = Instance.new("Frame")
    container.Name = name
    container.Size = size
    container.Position = position
    container.BackgroundColor3 = GameConfig.StateBackgrounds.Dark
    container.BackgroundTransparency = transparency or 0.3
    container.BorderSizePixel = 0
    container.Parent = self._screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, cornerRadius or 8)
    corner.Parent = container

    return container
end

function UIController:_createTimerDisplay()
    local container = self:_createHUDContainer("TimerContainer", UDim2.new(0, 160, 0, 50), UDim2.new(0.5, -80, 0, 10))

    self._timerLabel = Instance.new("TextLabel")
    self._timerLabel.Name = "TimerLabel"
    self._timerLabel.Text = ""
    self._timerLabel.TextSize = 28
    self._timerLabel.Font = Enum.Font.GothamBold
    self._timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    self._timerLabel.BackgroundTransparency = 1
    self._timerLabel.Size = UDim2.new(1, 0, 1, 0)
    self._timerLabel.Parent = container
end

function UIController:_createRoleBanner()
    self._roleBanner = Instance.new("Frame")
    self._roleBanner.Name = "RoleBanner"
    self._roleBanner.Size = UDim2.new(0, 400, 0, 60)
    self._roleBanner.Position = UDim2.new(0.5, -200, 0, 70)
    self._roleBanner.BackgroundColor3 = GameConfig.RoleColors.Runner
    self._roleBanner.BackgroundTransparency = 0.2
    self._roleBanner.BorderSizePixel = 0
    self._roleBanner.Visible = false
    self._roleBanner.Parent = self._screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = self._roleBanner

    self._roleText = Instance.new("TextLabel")
    self._roleText.Name = "RoleText"
    self._roleText.Text = ""
    self._roleText.TextSize = 32
    self._roleText.Font = Enum.Font.GothamBold
    self._roleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    self._roleText.BackgroundTransparency = 1
    self._roleText.Size = UDim2.new(1, 0, 1, 0)
    self._roleText.Parent = self._roleBanner
end

function UIController:_createRunnersCounter()
    local container = self:_createHUDContainer("RunnersContainer", UDim2.new(0, 160, 0, 36), UDim2.new(1, -170, 0, 10))

    self._runnersLabel = Instance.new("TextLabel")
    self._runnersLabel.Name = "RunnersLabel"
    self._runnersLabel.Text = ""
    self._runnersLabel.TextSize = 18
    self._runnersLabel.Font = Enum.Font.GothamBold
    self._runnersLabel.TextColor3 = GameConfig.RoleColors.Runner
    self._runnersLabel.BackgroundTransparency = 1
    self._runnersLabel.Size = UDim2.new(1, -10, 1, 0)
    self._runnersLabel.Position = UDim2.new(0, 5, 0, 0)
    self._runnersLabel.TextXAlignment = Enum.TextXAlignment.Center
    self._runnersLabel.Parent = container
end

function UIController:_createCoinsDisplay()
    local container = self:_createHUDContainer("CoinsContainer", UDim2.new(0, 140, 0, 36), UDim2.new(0, 10, 0, 10))

    self._coinsLabel = Instance.new("TextLabel")
    self._coinsLabel.Name = "CoinsLabel"
    self._coinsLabel.Text = "Coins: 0"
    self._coinsLabel.TextSize = 18
    self._coinsLabel.Font = Enum.Font.GothamBold
    self._coinsLabel.TextColor3 = GameConfig.MenuColors.RewardCoins
    self._coinsLabel.BackgroundTransparency = 1
    self._coinsLabel.Size = UDim2.new(1, -10, 1, 0)
    self._coinsLabel.Position = UDim2.new(0, 5, 0, 0)
    self._coinsLabel.TextXAlignment = Enum.TextXAlignment.Center
    self._coinsLabel.Parent = container
end

function UIController:_createPhaseIndicator()
    self._phaseLabel = Instance.new("TextLabel")
    self._phaseLabel.Name = "PhaseLabel"
    self._phaseLabel.Text = "Lobby"
    self._phaseLabel.TextSize = 14
    self._phaseLabel.Font = Enum.Font.Gotham
    self._phaseLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    self._phaseLabel.BackgroundTransparency = 1
    self._phaseLabel.Size = UDim2.new(0, 160, 0, 20)
    self._phaseLabel.Position = UDim2.new(0.5, -80, 0, 62)
    self._phaseLabel.Parent = self._screenGui
end

function UIController:_createTagNotification()
    self._tagNotification = Instance.new("TextLabel")
    self._tagNotification.Name = "TagNotification"
    self._tagNotification.Text = "You were tagged!"
    self._tagNotification.TextSize = 36
    self._tagNotification.Font = Enum.Font.GothamBold
    self._tagNotification.TextColor3 = GameConfig.RoleColors.Tagger
    self._tagNotification.TextStrokeTransparency = 0.5
    self._tagNotification.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    self._tagNotification.BackgroundTransparency = 1
    self._tagNotification.Size = UDim2.new(0, 400, 0, 50)
    self._tagNotification.Position = UDim2.new(0.5, -200, 0.4, 0)
    self._tagNotification.Visible = false
    self._tagNotification.Parent = self._screenGui
end

function UIController:_createCountdownDisplay()
    self._countdownLabel = Instance.new("TextLabel")
    self._countdownLabel.Name = "CountdownLabel"
    self._countdownLabel.Text = ""
    self._countdownLabel.TextSize = 72
    self._countdownLabel.Font = Enum.Font.GothamBold
    self._countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    self._countdownLabel.TextStrokeTransparency = 0.3
    self._countdownLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    self._countdownLabel.BackgroundTransparency = 1
    self._countdownLabel.Size = UDim2.new(0, 200, 0, 100)
    self._countdownLabel.Position = UDim2.new(0.5, -100, 0.35, 0)
    self._countdownLabel.Visible = false
    self._countdownLabel.Parent = self._screenGui
end

function UIController:_createStatusDisplay()
    self._statusFrame = self:_createHUDContainer("StatusDisplay", UDim2.new(0, 420, 0, 140), UDim2.new(0.5, -210, 0.3, 0), 12, 0.25)
    self._statusFrame.Visible = false

    self._statusTitle = Instance.new("TextLabel")
    self._statusTitle.Name = "StatusTitle"
    self._statusTitle.Text = ""
    self._statusTitle.TextSize = 28
    self._statusTitle.Font = Enum.Font.GothamBold
    self._statusTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    self._statusTitle.BackgroundTransparency = 1
    self._statusTitle.Size = UDim2.new(1, -20, 0, 50)
    self._statusTitle.Position = UDim2.new(0, 10, 0, 15)
    self._statusTitle.Parent = self._statusFrame

    self._statusSubtitle = Instance.new("TextLabel")
    self._statusSubtitle.Name = "StatusSubtitle"
    self._statusSubtitle.Text = ""
    self._statusSubtitle.TextSize = 20
    self._statusSubtitle.Font = Enum.Font.Gotham
    self._statusSubtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
    self._statusSubtitle.BackgroundTransparency = 1
    self._statusSubtitle.Size = UDim2.new(1, -20, 0, 40)
    self._statusSubtitle.Position = UDim2.new(0, 10, 0, 70)
    self._statusSubtitle.Parent = self._statusFrame
end

-- Public methods called by RoundController

function UIController:ShowRoleBanner(role)
    if not self._roleBanner then
        return
    end

    if role == Constants.ROLES.TAGGER then
        self._roleText.Text = "YOU ARE THE TAGGER!"
        self._roleBanner.BackgroundColor3 = GameConfig.RoleColors.Tagger
    elseif role == Constants.ROLES.RUNNER then
        self._roleText.Text = "RUN!"
        self._roleBanner.BackgroundColor3 = GameConfig.RoleColors.Runner
    else
        self._roleBanner.Visible = false
        return
    end

    -- Cancel any existing banner tweens
    if self._bannerTween then
        self._bannerTween:Cancel()
        self._bannerTween = nil
    end
    if self._bannerTextTween then
        self._bannerTextTween:Cancel()
        self._bannerTextTween = nil
    end

    self._roleBanner.Visible = true
    self._roleBanner.BackgroundTransparency = 0.2
    self._roleText.TextTransparency = 0

    -- Fade out after 3 seconds
    task.delay(3, function()
        if self._roleBanner and self._roleBanner.Visible then
            self._bannerTween = TweenService:Create(self._roleBanner, TweenInfo.new(0.5), {
                BackgroundTransparency = 1,
            })
            self._bannerTextTween = TweenService:Create(self._roleText, TweenInfo.new(0.5), {
                TextTransparency = 1,
            })
            self._bannerTween:Play()
            self._bannerTextTween:Play()
            self._bannerTween.Completed:Once(function()
                self._roleBanner.Visible = false
                self._roleBanner.BackgroundTransparency = 0.2
                self._roleText.TextTransparency = 0
                self._bannerTween = nil
                self._bannerTextTween = nil
            end)
        end
    end)
end

function UIController:HideRoleBanner()
    if self._roleBanner then
        self._roleBanner.Visible = false
    end
end

function UIController:UpdateTimer(seconds)
    if not self._timerLabel then
        return
    end

    if seconds <= 0 then
        self._timerLabel.Text = ""
        return
    end

    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    self._timerLabel.Text = string.format("%d:%02d", minutes, secs)

    -- Turn red when time is low
    if seconds <= 10 then
        self._timerLabel.TextColor3 = GameConfig.RoleColors.Tagger
    else
        self._timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

function UIController:UpdateRunnersRemaining(remaining, total)
    if self._runnersLabel then
        self._runnersLabel.Text = "Runners: " .. remaining .. "/" .. total
    end
end

function UIController:UpdateCoins(coins)
    self._coins = coins
    if self._coinsLabel then
        self._coinsLabel.Text = "Coins: " .. Utils.FormatNumber(coins)
    end
end

function UIController:SetPhaseText(phase)
    if self._phaseLabel then
        self._phaseLabel.Text = phase
    end

    -- Show/hide timer based on phase
    if self._timerLabel then
        if phase == Constants.PHASES.PLAYING then
            self._timerLabel.Parent.Visible = true
        else
            self._timerLabel.Parent.Visible = false
        end
    end

    -- Show/hide runners counter
    if self._runnersLabel then
        if phase == Constants.PHASES.PLAYING then
            self._runnersLabel.Parent.Visible = true
        else
            self._runnersLabel.Parent.Visible = false
        end
    end

    -- Manage status display per phase
    if phase == Constants.PHASES.LOBBY then
        self:HideRoleBanner()
        self:_showStatus("WAITING FOR PLAYERS", "Looking for players...")
    elseif phase == Constants.PHASES.COUNTDOWN then
        self:_showStatus("GET READY!", "")
    elseif phase == Constants.PHASES.PLAYING then
        self:_hideStatus()
    elseif phase == Constants.PHASES.RESULTS then
        self:_hideStatus()
    elseif phase == Constants.PHASES.INTERMISSION then
        self:_showStatus("INTERMISSION", "Next round starting soon...")
    end
end

function UIController:_showStatus(title, subtitle)
    if self._statusFrame then
        self._statusFrame.Visible = true
    end
    if self._statusTitle then
        self._statusTitle.Text = title or ""
    end
    if self._statusSubtitle then
        self._statusSubtitle.Text = subtitle or ""
    end
end

function UIController:_hideStatus()
    if self._statusFrame then
        self._statusFrame.Visible = false
    end
end

function UIController:UpdateLobbyStatus(lobbyStatus, playerCount, targetCount, timeRemaining)
    if not self._statusFrame or not self._statusTitle or not self._statusSubtitle then
        return
    end

    if lobbyStatus == "waiting" then
        self._statusTitle.Text = "WAITING FOR PLAYERS"
        self._statusSubtitle.Text = playerCount .. "/" .. targetCount .. " players"
        self._statusFrame.Visible = true
    elseif lobbyStatus == "starting" then
        self._statusTitle.Text = "GAME STARTING"
        self._statusSubtitle.Text = "Starting in " .. timeRemaining .. "s"
        self._statusFrame.Visible = true
    end
end

function UIController:UpdateIntermissionTimer(timeRemaining)
    if not self._statusFrame or not self._statusTitle or not self._statusSubtitle then
        return
    end

    self._statusTitle.Text = "NEXT ROUND"
    self._statusSubtitle.Text = timeRemaining .. "s"
    self._statusFrame.Visible = true
end

function UIController:ShowCountdown(number)
    if not self._countdownLabel then
        return
    end

    self._countdownLabel.Text = tostring(number)
    self._countdownLabel.Visible = true
    self._countdownLabel.TextTransparency = 0
    self._countdownLabel.TextSize = 72

    -- Keep the status display showing "GET READY!" during countdown
    self:_showStatus("GET READY!", "")
end

function UIController:HideCountdown()
    if self._countdownLabel then
        self._countdownLabel.Visible = false
    end
end

function UIController:NotifyTag(message)
    if not self._tagNotification then
        return
    end

    -- Cancel any existing notification tween
    if self._notifyTween then
        self._notifyTween:Cancel()
        self._notifyTween = nil
    end

    self._tagNotification.Text = message or "You were tagged!"
    self._tagNotification.Visible = true
    self._tagNotification.TextTransparency = 0

    -- Fade out after 2 seconds
    task.delay(2, function()
        if self._tagNotification and self._tagNotification.Visible then
            self._notifyTween = TweenService:Create(self._tagNotification, TweenInfo.new(0.5), {
                TextTransparency = 1,
            })
            self._notifyTween:Play()
            self._notifyTween.Completed:Once(function()
                self._tagNotification.Visible = false
                self._tagNotification.TextTransparency = 0
                self._notifyTween = nil
            end)
        end
    end)
end

function UIController:ShowResults(results, taggerWon)
    -- Simple results display for MVP
    local localPlayer = Players.LocalPlayer
    local myResult = results and results[localPlayer.UserId]

    if not myResult then
        return
    end

    local resultText = ""
    if myResult.won then
        resultText = "You Win! +" .. myResult.coins .. " Coins"
    else
        resultText = "Round Over! +" .. myResult.coins .. " Coins"
    end

    self:NotifyTag(resultText)
end

return UIController
