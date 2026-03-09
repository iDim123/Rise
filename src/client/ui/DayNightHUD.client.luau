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
local NIGHT_COLOR_ICON = Color3.fromRGB(230, 230, 230)

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

-- ════════════════════════════════════════════════════════════
-- Прогресс-бар: 3 зоны + маркер
-- ════════════════════════════════════════════════════════════
local BAR_TOTAL_W = BAR_WIDTH + ICON_SIZE - 4 -- вся ширина внутри фрейма

local barContainer = Instance.new("Frame")
barContainer.Name = "BarContainer"
barContainer.Size = UDim2.new(1, -8, 0, BAR_HEIGHT + 4)
barContainer.Position = UDim2.new(0, 4, 1, -BAR_HEIGHT - 5)
barContainer.BackgroundTransparency = 1
barContainer.ClipsDescendants = false
barContainer.Parent = frame

-- Фон бара
local barBg = Instance.new("Frame")
barBg.Name = "BarBg"
barBg.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
barBg.Position = UDim2.new(0, 0, 0, 2)
barBg.BackgroundColor3 = BAR_BG
barBg.BorderSizePixel = 0
barBg.ClipsDescendants = true
barBg.Parent = barContainer
Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 3)

local dawn = DNC.DawnHour -- 12
local day = DNC.DayHour -- 13
local dusk = DNC.DuskHour -- 18
local night = DNC.NightHour -- 19

local zones = {{
    from = 0,
    to = dawn / 24,
    color = NIGHT_COLOR
}, -- ночь
{
    from = dawn / 24,
    to = day / 24,
    color = Color3.fromRGB(140, 140, 180)
}, -- рассвет
{
    from = day / 24,
    to = dusk / 24,
    color = DAY_COLOR
}, -- день
{
    from = dusk / 24,
    to = night / 24,
    color = Color3.fromRGB(180, 120, 60)
}, -- закат
{
    from = night / 24,
    to = 1,
    color = NIGHT_COLOR
} -- ночь
}

for _, zone in zones do
    local zoneFrame = Instance.new("Frame")
    zoneFrame.Size = UDim2.new(zone.to - zone.from, 0, 1, 0)
    zoneFrame.Position = UDim2.new(zone.from, 0, 0, 0)
    zoneFrame.BackgroundColor3 = zone.color
    zoneFrame.BackgroundTransparency = 0.3
    zoneFrame.BorderSizePixel = 0
    zoneFrame.ZIndex = 1
    zoneFrame.Parent = barBg
end

-- Маркер (кружок)
local MARKER_SIZE = BAR_HEIGHT + 6

local marker = Instance.new("Frame")
marker.Name = "Marker"
marker.Size = UDim2.new(0, MARKER_SIZE, 0, MARKER_SIZE)
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Position = UDim2.new(0, 0, 0.5, 2) -- обновляется в updateUI
marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
marker.BorderSizePixel = 0
marker.ZIndex = 5
marker.Parent = barContainer

Instance.new("UICorner", marker).CornerRadius = UDim.new(1, 0)

local markerStroke = Instance.new("UIStroke")
markerStroke.Color = Color3.fromRGB(40, 40, 60)
markerStroke.Thickness = 2
markerStroke.Parent = marker

-- Иконка внутри маркера (☀/🌙)
local markerIcon = Instance.new("TextLabel")
markerIcon.Name = "Icon"
markerIcon.Size = UDim2.new(1, 0, 1, 0)
markerIcon.BackgroundTransparency = 1
markerIcon.TextSize = 10
markerIcon.Font = Enum.Font.GothamBold
markerIcon.Text = "🌙"
markerIcon.TextColor3 = Color3.fromRGB(40, 40, 60)
markerIcon.Parent = marker

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

-- ════════════════════════════════════════════════════════════
-- updateUI
-- ════════════════════════════════════════════════════════════
local function updateUI()
    local clock = syncData.ClockTime or 0
    local progress = math.clamp(clock / 24, 0, 0.9999)

    -- Маркер
    marker.Position = UDim2.new(progress, 0, 0.5, 0.9)

    if syncData.IsDay then
        phaseIcon.Text = "☀"
        phaseIcon.TextColor3 = DAY_COLOR
        phaseLabel.Text = "День"
        marker.BackgroundColor3 = DAY_COLOR
        markerIcon.Text = "☀"
        markerIcon.TextColor3 = Color3.fromRGB(120, 80, 0)
    else
        if syncData.LunarPhase == "blood_moon" then
            phaseIcon.Text = "🌑"
            phaseIcon.TextColor3 = BLOOD_COLOR
            marker.BackgroundColor3 = BLOOD_COLOR
            markerIcon.Text = "🌑"
            markerIcon.TextColor3 = Color3.fromRGB(255, 200, 200)
        else
            phaseIcon.Text = "🌙"
            phaseIcon.TextColor3 = NIGHT_COLOR
            marker.BackgroundColor3 = NIGHT_COLOR_ICON
            markerIcon.Text = "🌙"
            markerIcon.TextColor3 = Color3.fromRGB(200, 200, 255)
        end
        phaseLabel.Text = "Ночь"
    end

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

    local clock = syncData.ClockTime
    local progress = math.clamp(clock / 24, 0, 0.9999)
    marker.Position = UDim2.new(progress, 0, 0.5, 0.9)

    local hour = math.floor(clock) % 24
    local minutes = math.floor((clock % 1) * 60)
    timeLabel.Text = string.format("%02d:%02d", hour, minutes)
end)
