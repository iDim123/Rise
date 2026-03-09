-- UI индикатор цикла дня/ночи + лунная фаза
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DNC = Config.DayNight
local LC = Config.LunarCycle

-- ════════════════════════════════════════════════════════════
-- Константы
-- ════════════════════════════════════════════════════════════
local BAR_WIDTH = 160
local BAR_HEIGHT = 8
local ICON_SIZE = 22
local MARGIN = 16
local BG_COLOR = Color3.fromRGB(18, 18, 28)
local BAR_BG = Color3.fromRGB(35, 35, 50)
local DAY_COLOR = Color3.fromRGB(255, 200, 60)
local NIGHT_COLOR = Color3.fromRGB(80, 80, 180)
local BLOOD_COLOR = Color3.fromRGB(180, 30, 30)
local STROKE = Color3.fromRGB(60, 60, 80)
local TEXT_COLOR = Color3.fromRGB(220, 220, 220)
local TEXT_DIM = Color3.fromRGB(150, 150, 170)

-- ════════════════════════════════════════════════════════════
-- UI
-- ════════════════════════════════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DayNightHUD"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 4
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Контейнер — под миникартой
local frame = Instance.new("Frame")
frame.Name = "DayNightFrame"
frame.Size = UDim2.new(0, BAR_WIDTH + ICON_SIZE + 8, 0, ICON_SIZE + 20)
frame.Position = UDim2.new(1, -256 - 8, 0, MARGIN) -- 8px зазор от миникарты, верх = 0
frame.AnchorPoint = Vector2.new(1, 0) -- привязка правый-верхний
frame.BackgroundColor3 = BG_COLOR
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = screenGui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = STROKE
frameStroke.Thickness = 1
frameStroke.Parent = frame

-- Иконка (солнце/луна)
local phaseIcon = Instance.new("TextLabel")
phaseIcon.Name = "PhaseIcon"
phaseIcon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
phaseIcon.Position = UDim2.new(0, 4, 0, 2)
phaseIcon.BackgroundTransparency = 1
phaseIcon.TextSize = 18
phaseIcon.Font = Enum.Font.GothamBold
phaseIcon.TextColor3 = DAY_COLOR
phaseIcon.Text = "☀"
phaseIcon.Parent = frame

-- Текст фазы
local phaseLabel = Instance.new("TextLabel")
phaseLabel.Name = "PhaseLabel"
phaseLabel.Size = UDim2.new(1, -ICON_SIZE - 12, 0, 14)
phaseLabel.Position = UDim2.new(0, ICON_SIZE + 8, 0, 2)
phaseLabel.BackgroundTransparency = 1
phaseLabel.TextColor3 = TEXT_COLOR
phaseLabel.TextSize = 11
phaseLabel.Font = Enum.Font.GothamBold
phaseLabel.Text = "Ночь"
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
phaseLabel.Parent = frame

-- Лунная фаза (текст)
local lunarLabel = Instance.new("TextLabel")
lunarLabel.Name = "LunarLabel"
lunarLabel.Size = UDim2.new(1, -ICON_SIZE - 12, 0, 12)
lunarLabel.Position = UDim2.new(0, ICON_SIZE + 8, 0, 15)
lunarLabel.BackgroundTransparency = 1
lunarLabel.TextColor3 = TEXT_DIM
lunarLabel.TextSize = 9
lunarLabel.Font = Enum.Font.Gotham
lunarLabel.Text = ""
lunarLabel.TextXAlignment = Enum.TextXAlignment.Left
lunarLabel.Parent = frame

local timeLabel = Instance.new("TextLabel")
timeLabel.Name = "TimeLabel"
timeLabel.Size = UDim2.new(0, 40, 0, 16)
timeLabel.Position = UDim2.new(1, -44, 0, 4) -- правый верхний угол фрейма
timeLabel.AnchorPoint = Vector2.new(0, 0)
timeLabel.BackgroundTransparency = 1
timeLabel.Font = Enum.Font.GothamBold
timeLabel.TextSize = 14
timeLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
timeLabel.TextXAlignment = Enum.TextXAlignment.Right
timeLabel.Text = "0"
timeLabel.Parent = frame

-- Прогресс-бар цикла
local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, -8, 0, BAR_HEIGHT)
barBg.Position = UDim2.new(0, 4, 1, -BAR_HEIGHT - 3)
barBg.BackgroundColor3 = BAR_BG
barBg.BorderSizePixel = 0
barBg.ClipsDescendants = true
barBg.Parent = frame

Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 3)

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.new(0.5, 0, 1, 0)
barFill.BackgroundColor3 = NIGHT_COLOR
barFill.BorderSizePixel = 0
barFill.Parent = barBg

Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 3)

-- ════════════════════════════════════════════════════════════
-- Состояние (от сервера)
-- ════════════════════════════════════════════════════════════
local syncData = {
    CycleTimer = 0,
    TotalCycle = DNC.CycleDuration, -- было: DNC.DayDuration + DNC.NightDuration
    IsDay = false,
    Phase = "night",
    LunarPhase = "new_moon",
    LunarTimer = 0,
    ClockTime = DNC.StartHour or 0
}

local LUNAR_NAMES = {
    new_moon = "Новолуние",
    waxing = "Растущая луна",
    full_moon = "Полнолуние",
    waning = "Убывающая луна",
    blood_moon = "Кровавая луна"
}

local function updateUI()
    local progress = syncData.CycleTimer / syncData.TotalCycle
    barFill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)

    if syncData.IsDay then
        phaseIcon.Text = "☀"
        phaseIcon.TextColor3 = DAY_COLOR
        phaseLabel.Text = "День"
        barFill.BackgroundColor3 = DAY_COLOR
    else
        if syncData.LunarPhase == "blood_moon" then
            phaseIcon.Text = "🌑"
            phaseIcon.TextColor3 = BLOOD_COLOR
            barFill.BackgroundColor3 = BLOOD_COLOR
        else
            phaseIcon.Text = "🌙"
            phaseIcon.TextColor3 = NIGHT_COLOR
            barFill.BackgroundColor3 = NIGHT_COLOR
        end
        phaseLabel.Text = "Ночь"
    end

    local clock = syncData.ClockTime or 0
    local hour = math.floor(clock) % 24
    local minutes = math.floor((clock % 1) * 60)
    timeLabel.Text = string.format("%02d:%02d", hour, minutes)
    lunarLabel.Text = LUNAR_NAMES[syncData.LunarPhase] or ""
end

-- ════════════════════════════════════════════════════════════
-- Получение данных от сервера + клиентская интерполяция
-- ════════════════════════════════════════════════════════════
Remotes.DayNightSync.OnClientEvent:Connect(function(data)
    syncData = data
    updateUI()
end)

-- Клиентский тик — интерполируем между синхронизациями
RunService.Heartbeat:Connect(function(dt)
    if not syncData.CycleTimer or not syncData.TotalCycle then
        return
    end

    syncData.CycleTimer = (syncData.CycleTimer + dt) % syncData.TotalCycle
    syncData.ClockTime = (syncData.CycleTimer / syncData.TotalCycle) * 24

    local progress = syncData.CycleTimer / syncData.TotalCycle
    barFill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)

    -- Обновляем часы между синками
    local clock = syncData.ClockTime
    local hour = math.floor(clock) % 24
    local minutes = math.floor((clock % 1) * 60)
    timeLabel.Text = string.format("%02d:%02d", hour, minutes)
end)
