local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ Constants ═══
local ICON_SIZE = 48
local ICON_PAD = 6
local CORNER_RADIUS = 6
local TIMER_HEIGHT = 16
local TOOLTIP_WIDTH = 220
local TOOLTIP_PAD = 10
local TOOLTIP_CORNER = 8

local BUFF_BORDER_COLOR = Color3.fromRGB(50, 50, 65)
local DEBUFF_BORDER_COLOR = Color3.fromRGB(220, 60, 60)
local BORDER_THICKNESS = 2
local BG_COLOR = Color3.fromRGB(30, 30, 30)
local TIMER_COLOR = Color3.fromRGB(255, 255, 255)
local TOOLTIP_BG = Color3.fromRGB(20, 20, 20)
local TOOLTIP_BORDER = Color3.fromRGB(100, 100, 100)
local TOOLTIP_TEXT = Color3.fromRGB(230, 230, 230)
local TOOLTIP_SUB = Color3.fromRGB(160, 160, 160)

-- ═══ State ═══
local currentBuffs = {}   -- { {Id, Name, Description, Icon, Type, Remaining, Duration}, ... }
local buffFrames = {}      -- [buffId] = frame
local tooltipFrame = nil
local hoveredBuff = nil

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BuffBarGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 800
screenGui.Parent = playerGui

-- Buff row (top-right)
local buffRow = Instance.new("Frame")
buffRow.Name = "BuffRow"
buffRow.BackgroundTransparency = 1
buffRow.AnchorPoint = Vector2.new(0, 0)
buffRow.Position = UDim2.new(0, 10, 0, 10)
buffRow.Size = UDim2.new(0, (ICON_SIZE + ICON_PAD) * 10, 0, ICON_SIZE + TIMER_HEIGHT)
buffRow.Parent = screenGui

local buffLayout = Instance.new("UIListLayout")
buffLayout.FillDirection = Enum.FillDirection.Horizontal
buffLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
buffLayout.Padding = UDim.new(0, ICON_PAD)
buffLayout.SortOrder = Enum.SortOrder.Name
buffLayout.Parent = buffRow

-- Debuff row (below buffs)
local debuffRow = Instance.new("Frame")
debuffRow.Name = "DebuffRow"
debuffRow.BackgroundTransparency = 1
debuffRow.AnchorPoint = Vector2.new(0, 0)
debuffRow.Position = UDim2.new(0, 10, 0, 10 + ICON_SIZE + TIMER_HEIGHT + 6)
debuffRow.Size = UDim2.new(0, (ICON_SIZE + ICON_PAD) * 10, 0, ICON_SIZE + TIMER_HEIGHT)
debuffRow.Parent = screenGui

local debuffLayout = Instance.new("UIListLayout")
debuffLayout.FillDirection = Enum.FillDirection.Horizontal
debuffLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
debuffLayout.Padding = UDim.new(0, ICON_PAD)
debuffLayout.SortOrder = Enum.SortOrder.Name
debuffLayout.Parent = debuffRow

-- ═══ Tooltip ═══
local function createTooltip()
    local frame = Instance.new("Frame")
    frame.Name = "BuffTooltip"
    frame.BackgroundColor3 = TOOLTIP_BG
    frame.Size = UDim2.new(0, TOOLTIP_WIDTH, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Visible = false
    frame.ZIndex = 100
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, TOOLTIP_CORNER)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = TOOLTIP_BORDER
    stroke.Thickness = 1
    stroke.Parent = frame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, TOOLTIP_PAD)
    pad.PaddingBottom = UDim.new(0, TOOLTIP_PAD)
    pad.PaddingLeft = UDim.new(0, TOOLTIP_PAD)
    pad.PaddingRight = UDim.new(0, TOOLTIP_PAD)
    pad.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 18)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = TOOLTIP_TEXT
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.LayoutOrder = 1
    title.ZIndex = 101
    title.Parent = frame

    local desc = Instance.new("TextLabel")
    desc.Name = "Description"
    desc.BackgroundTransparency = 1
    desc.Size = UDim2.new(1, 0, 0, 0)
    desc.AutomaticSize = Enum.AutomaticSize.Y
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 12
    desc.TextColor3 = TOOLTIP_SUB
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextWrapped = true
    desc.LayoutOrder = 2
    desc.ZIndex = 101
    desc.Parent = frame

    local remaining = Instance.new("TextLabel")
    remaining.Name = "Remaining"
    remaining.BackgroundTransparency = 1
    remaining.Size = UDim2.new(1, 0, 0, 16)
    remaining.Font = Enum.Font.Gotham
    remaining.TextSize = 12
    remaining.TextColor3 = TOOLTIP_SUB
    remaining.TextXAlignment = Enum.TextXAlignment.Left
    remaining.LayoutOrder = 3
    remaining.ZIndex = 101
    remaining.Parent = frame

    return frame
end

local function showTooltip(buffData, iconFrame)
    if not tooltipFrame then
        tooltipFrame = createTooltip()
    end
    tooltipFrame.Title.Text = buffData.Name or buffData.Id
    tooltipFrame.Description.Text = buffData.Description or ""
    local rem = buffData.Remaining or 0
    if rem >= 60 then
        tooltipFrame.Remaining.Text = string.format("Remaining: %d:%02d", math.floor(rem / 60), math.floor(rem % 60))
    else
        tooltipFrame.Remaining.Text = string.format("Remaining: %.1fs", rem)
    end

    -- Position below icon, clamped to screen
    local absPos = iconFrame.AbsolutePosition
    local absSize = iconFrame.AbsoluteSize
    local viewportSize = workspace.CurrentCamera.ViewportSize

    local x = absPos.X + absSize.X / 2 - TOOLTIP_WIDTH / 2
    local y = absPos.Y + absSize.Y + 4

    -- Clamp right edge
    if x + TOOLTIP_WIDTH > viewportSize.X - 4 then
        x = viewportSize.X - TOOLTIP_WIDTH - 4
    end
    -- Clamp left edge
    if x < 4 then
        x = 4
    end
    -- If goes below screen, show above icon
    if y + 80 > viewportSize.Y then
        y = absPos.Y - 80 - 4
    end

    tooltipFrame.Position = UDim2.new(0, x, 0, y)
    tooltipFrame.Visible = true
    hoveredBuff = buffData.Id
end

local function hideTooltip()
    if tooltipFrame then
        tooltipFrame.Visible = false
    end
    hoveredBuff = nil
end

-- ═══ Icon builder ═══
local function formatTime(seconds)
    if seconds >= 3600 then
        return string.format("%dh", math.floor(seconds / 3600))
    elseif seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
    else
        return string.format("%.0f", math.ceil(seconds))
    end
end

local function createBuffIcon(buffData)
    local isDebuff = buffData.Type == "Debuff"
    local borderColor = isDebuff and DEBUFF_BORDER_COLOR or BUFF_BORDER_COLOR
    local parentRow = isDebuff and debuffRow or buffRow

    local frame = Instance.new("Frame")
    frame.Name = "Buff_" .. buffData.Id
    frame.BackgroundColor3 = BG_COLOR
    frame.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE + TIMER_HEIGHT)
    frame.BackgroundTransparency = 1
    frame.Parent = parentRow

    -- Icon container
    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "IconFrame"
    iconFrame.BackgroundColor3 = BG_COLOR
    iconFrame.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
    iconFrame.Parent = frame

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, CORNER_RADIUS)
    iconCorner.Parent = iconFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = borderColor
    stroke.Thickness = BORDER_THICKNESS
    stroke.Parent = iconFrame

    -- Icon image
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(1, -4, 1, -4)
    icon.Position = UDim2.new(0, 2, 0, 2)
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Image = buffData.Icon or ""
    icon.Parent = iconFrame

    -- Fallback text if no icon
    if not buffData.Icon or buffData.Icon == "" or buffData.Icon == "rbxassetid://0" then
        icon.Visible = false
        local fallback = Instance.new("TextLabel")
        fallback.Name = "Fallback"
        fallback.BackgroundTransparency = 1
        fallback.Size = UDim2.new(1, 0, 1, 0)
        fallback.Font = Enum.Font.GothamBold
        fallback.TextSize = 10
        fallback.TextColor3 = TIMER_COLOR
        fallback.Text = string.sub(buffData.Name or buffData.Id, 1, 3)
        fallback.Parent = iconFrame
    end

    -- Timer label below icon
    local timer = Instance.new("TextLabel")
    timer.Name = "Timer"
    timer.BackgroundTransparency = 1
    timer.Size = UDim2.new(1, 0, 0, TIMER_HEIGHT)
    timer.Position = UDim2.new(0, 0, 0, ICON_SIZE)
    timer.Font = Enum.Font.GothamBold
    timer.TextSize = 11
    timer.TextColor3 = TIMER_COLOR
    timer.Text = formatTime(buffData.Remaining or 0)
    timer.Parent = frame

    -- Tooltip hover
    iconFrame.MouseEnter:Connect(function()
        local data = nil
        for _, b in currentBuffs do
            if b.Id == buffData.Id then data = b; break end
        end
        if data then showTooltip(data, iconFrame) end
    end)
    iconFrame.MouseLeave:Connect(function()
        if hoveredBuff == buffData.Id then hideTooltip() end
    end)

    return frame
end

-- ═══ Update logic ═══
local function rebuildUI()
    -- Clear old frames
    for id, frame in buffFrames do
        frame:Destroy()
    end
    buffFrames = {}

    -- Build new
    for _, buffData in currentBuffs do
        local frame = createBuffIcon(buffData)
        buffFrames[buffData.Id] = frame
    end
end

local function updateTimers()
    for _, buffData in currentBuffs do
        local frame = buffFrames[buffData.Id]
        if frame then
            local timer = frame:FindFirstChild("Timer")
            if timer then
                timer.Text = formatTime(buffData.Remaining or 0)
            end
        end
    end

    -- Update tooltip if visible
    if hoveredBuff and tooltipFrame and tooltipFrame.Visible then
        for _, b in currentBuffs do
            if b.Id == hoveredBuff then
                local rem = b.Remaining or 0
                if rem >= 60 then
                    tooltipFrame.Remaining.Text = string.format("Remaining: %d:%02d", math.floor(rem / 60), math.floor(rem % 60))
                else
                    tooltipFrame.Remaining.Text = string.format("Remaining: %.1fs", rem)
                end
                break
            end
        end
    end
end

-- ═══ Remote listener ═══
Remotes.UpdateBuffs.OnClientEvent:Connect(function(buffsData)
     if typeof(buffsData) ~= "table" then
        warn("[BuffBar] Received non-table data:", typeof(buffsData))
        return
    end
    local oldIds = {}
    for _, b in currentBuffs do oldIds[b.Id] = true end

    currentBuffs = buffsData or {}

    local newIds = {}
    for _, b in currentBuffs do newIds[b.Id] = true end

    -- Check if set of buffs changed (need rebuild) or just timers
    local changed = false
    if #currentBuffs ~= #(buffsData or {}) then changed = true end
    for id in oldIds do
        if not newIds[id] then changed = true; break end
    end
    if not changed then
        for id in newIds do
            if not oldIds[id] then changed = true; break end
        end
    end

    if changed then
        rebuildUI()
    else
        updateTimers()
    end
end)

-- ═══ Client-side tick for smooth countdown ═══
local tickAccum = 0
RunService.RenderStepped:Connect(function(dt)
    tickAccum = tickAccum + dt
    if tickAccum < 0.5 then return end
    tickAccum = 0

    for _, buffData in currentBuffs do
        buffData.Remaining = math.max(0, (buffData.Remaining or 0) - 0.5)
    end
    updateTimers()
end)