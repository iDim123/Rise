local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local NotifyModule = {}

-- ═══ Constants ═══
local DURATION = 3
local FADE_TIME = 0.4
local MAX_NOTIFICATIONS = 5
local NOTIFY_HEIGHT = 32
local NOTIFY_GAP = 4
local NOTIFY_WIDTH = 400

local COLORS = {
    error = Color3.fromRGB(200, 40, 40),
    warning = Color3.fromRGB(220, 160, 30),
    info = Color3.fromRGB(60, 140, 220),
    success = Color3.fromRGB(50, 180, 50)
}

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NotifyGui"
screenGui.DisplayOrder = 900
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "NotifyContainer"
container.Size = UDim2.new(0, NOTIFY_WIDTH, 1, 0)
container.AnchorPoint = Vector2.new(0.5, 1)
container.Position = UDim2.new(0.5, 0, 1, -180)
container.BackgroundTransparency = 1
container.Parent = screenGui

local activeNotifications = {}

local function repositionAll()
    for i, notif in activeNotifications do
        local targetY = -(i - 1) * (NOTIFY_HEIGHT + NOTIFY_GAP)
        TweenService:Create(notif, TweenInfo.new(0.2), {
            Position = UDim2.new(0, 0, 1, targetY - NOTIFY_HEIGHT)
        }):Play()
    end
end

function NotifyModule.show(text, notifType)
    notifType = notifType or "info"
    local color = COLORS[notifType] or COLORS.info

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, NOTIFY_HEIGHT)
    frame.Position = UDim2.new(0, 0, 1, 0)
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.5
    frame.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    -- local stroke = Instance.new("UIStroke")
    -- stroke.Color = color
    -- stroke.Thickness = 1
    -- stroke.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = color
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.Text = text
    label.Parent = frame

    -- Insert at front
    table.insert(activeNotifications, 1, frame)

    -- Remove oldest if too many
    if #activeNotifications > MAX_NOTIFICATIONS then
        local oldest = table.remove(activeNotifications)
        oldest:Destroy()
    end

    repositionAll()

    -- Auto-remove after duration
    task.delay(DURATION, function()
        local idx = table.find(activeNotifications, frame)
        if idx then
            table.remove(activeNotifications, idx)
        end

        local fadeOut = TweenService:Create(frame, TweenInfo.new(FADE_TIME), {
            BackgroundTransparency = 1
        })
        TweenService:Create(label, TweenInfo.new(FADE_TIME), {
            TextTransparency = 1
        }):Play()
        -- TweenService:Create(stroke, TweenInfo.new(FADE_TIME), {
        --     Transparency = 1
        -- }):Play()
        fadeOut:Play()
        fadeOut.Completed:Wait()
        frame:Destroy()
        repositionAll()
    end)
end

return NotifyModule
