local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ Constants ═══
local SLOT_SIZE = 40
local SLOT_MARGIN = 4
local CORNER_RADIUS = 6
local TOOLTIP_OFFSET = 6

local BG_COLOR = Color3.fromRGB(25, 25, 35)
local SLOT_COLOR = Color3.fromRGB(45, 45, 60)
local SLOT_HOVER = Color3.fromRGB(65, 65, 85)
local STROKE_COLOR = Color3.fromRGB(80, 80, 100)
local TEXT_COLOR = Color3.fromRGB(220, 220, 220)
local TOOLTIP_BG = Color3.fromRGB(20, 20, 30)
local TOOLTIP_BORDER = Color3.fromRGB(100, 100, 120)

-- ═══ Menu items ═══
local menuItems = {{
    Id = "CharacterWindow",
    Name = "Персонаж",
    Description = "Инвентарь и экипировка (C)",
    Icon = "rbxassetid://0"
}, {
    Id = "ServantWindow",
    Name = "Слуга",
    Description = "Управление слугой (V)",
    Icon = "rbxassetid://0"
}, {
    Id = "BossJournal",
    Name = "Журнал боссов",
    Description = "Список поверженных боссов (J)",
    Icon = "rbxassetid://0"
}, {
    Id = "Spellbook",
    Name = "Книга заклинаний",
    Description = "Магические школы и заклинания (P)",
    Icon = "rbxassetid://0"
}}

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MenuBarGui"
screenGui.DisplayOrder = 800
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- ═══ Container ═══
local totalWidth = #menuItems * (SLOT_SIZE + SLOT_MARGIN) - SLOT_MARGIN
local container = Instance.new("Frame")
container.Name = "MenuBarContainer"
container.Size = UDim2.new(0, totalWidth + SLOT_MARGIN * 2, 0, SLOT_SIZE + SLOT_MARGIN * 2)
container.AnchorPoint = Vector2.new(1, 1)
container.Position = UDim2.new(1, -10, 1, -10)
container.BackgroundColor3 = BG_COLOR
container.BackgroundTransparency = 0.3
container.Parent = screenGui

local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, CORNER_RADIUS)
containerCorner.Parent = container

local containerStroke = Instance.new("UIStroke")
containerStroke.Color = STROKE_COLOR
containerStroke.Thickness = 1
containerStroke.Parent = container

-- ═══ Tooltip ═══
local tooltip = Instance.new("Frame")
tooltip.Name = "Tooltip"
tooltip.Size = UDim2.new(0, 160, 0, 50)
tooltip.AnchorPoint = Vector2.new(1, 1)
tooltip.BackgroundColor3 = TOOLTIP_BG
tooltip.Visible = false
tooltip.ZIndex = 100
tooltip.Parent = screenGui

local tooltipCorner = Instance.new("UICorner")
tooltipCorner.CornerRadius = UDim.new(0, 4)
tooltipCorner.Parent = tooltip

local tooltipStroke = Instance.new("UIStroke")
tooltipStroke.Color = TOOLTIP_BORDER
tooltipStroke.Thickness = 1
tooltipStroke.Parent = tooltip

local tooltipPadding = Instance.new("UIPadding")
tooltipPadding.PaddingTop = UDim.new(0, 6)
tooltipPadding.PaddingBottom = UDim.new(0, 6)
tooltipPadding.PaddingLeft = UDim.new(0, 8)
tooltipPadding.PaddingRight = UDim.new(0, 8)
tooltipPadding.Parent = tooltip

local tooltipTitle = Instance.new("TextLabel")
tooltipTitle.Name = "Title"
tooltipTitle.Size = UDim2.new(1, 0, 0, 18)
tooltipTitle.BackgroundTransparency = 1
tooltipTitle.Font = Enum.Font.GothamBold
tooltipTitle.TextSize = 13
tooltipTitle.TextColor3 = TEXT_COLOR
tooltipTitle.TextXAlignment = Enum.TextXAlignment.Left
tooltipTitle.ZIndex = 101
tooltipTitle.Parent = tooltip

local tooltipDesc = Instance.new("TextLabel")
tooltipDesc.Name = "Desc"
tooltipDesc.Size = UDim2.new(1, 0, 0, 14)
tooltipDesc.Position = UDim2.new(0, 0, 0, 20)
tooltipDesc.BackgroundTransparency = 1
tooltipDesc.Font = Enum.Font.Gotham
tooltipDesc.TextSize = 11
tooltipDesc.TextColor3 = Color3.fromRGB(160, 160, 170)
tooltipDesc.TextXAlignment = Enum.TextXAlignment.Left
tooltipDesc.ZIndex = 101
tooltipDesc.Parent = tooltip

local function showTooltip(btn, item)
    tooltipTitle.Text = item.Name
    tooltipDesc.Text = item.Description or ""
    tooltip.Position = UDim2.new(0, btn.AbsolutePosition.X + SLOT_SIZE / 2, 0, btn.AbsolutePosition.Y - TOOLTIP_OFFSET)
    tooltip.Visible = true
end

local function hideTooltip()
    tooltip.Visible = false
end

-- ═══ Build slots ═══
local openCallbacks = {} -- [Id] = function

for i, item in menuItems do
    local btn = Instance.new("ImageButton")
    btn.Name = item.Id
    btn.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    btn.Position = UDim2.new(0, SLOT_MARGIN + (i - 1) * (SLOT_SIZE + SLOT_MARGIN), 0, SLOT_MARGIN)
    btn.BackgroundColor3 = SLOT_COLOR
    btn.AutoButtonColor = false
    btn.Image = item.Icon
    btn.ScaleType = Enum.ScaleType.Fit
    btn.Parent = container

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    -- Fallback text if no icon
    if item.Icon == "rbxassetid://0" or item.Icon == "" then
        local fallback = Instance.new("TextLabel")
        fallback.Size = UDim2.new(1, 0, 1, 0)
        fallback.BackgroundTransparency = 1
        fallback.Font = Enum.Font.GothamBold
        fallback.TextSize = 18
        fallback.TextColor3 = TEXT_COLOR
        fallback.Text = string.sub(item.Name, 1, 1)
        fallback.Parent = btn
    end

    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = SLOT_HOVER
        showTooltip(btn, item)
    end)

    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = SLOT_COLOR
        hideTooltip()
    end)

    btn.Activated:Connect(function()
        hideTooltip()
        local cb = openCallbacks[item.Id]
        if cb then
            cb()
        end
    end)
end

-- ═══ Public API ═══
local MenuBar = {}

function MenuBar.onButtonClick(itemId, callback)
    openCallbacks[itemId] = callback
end

return MenuBar
