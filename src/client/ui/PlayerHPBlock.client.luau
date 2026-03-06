local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UIConstants
local uiFolder = script.Parent:WaitForChild("character")
local C = require(uiFolder:WaitForChild("UIConstants"))

-- Level data
local levelData = { Level = 1, XP = 0, XPToNext = 100, MaxHP = 100 }

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerHUD"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 800
screenGui.Parent = playerGui

-- ═══ Player Block ═══
local playerBlock = Instance.new("Frame")
playerBlock.Name = "PlayerHPBlock"
playerBlock.Size = UDim2.new(0, C.HP_BAR_WIDTH + C.LEVEL_GAP + C.LEVEL_SIZE, 0, C.HP_BLOCK_H)
playerBlock.AnchorPoint = Vector2.new(1, 1)
playerBlock.Position = UDim2.new(0.5, -(C.FLASK_WIDTH / 2) - C.GAP, 1, -(C.MARGIN + C.AB_HEIGHT + C.GAP))
playerBlock.BackgroundTransparency = 1
playerBlock.Parent = screenGui

-- HP Bar
local hpFrame = Instance.new("Frame")
hpFrame.Name = "HPBarFrame"
hpFrame.Size = UDim2.new(0, C.HP_BAR_WIDTH, 0, C.HP_HEIGHT)
hpFrame.Position = UDim2.new(0, 0, 0, 0)
hpFrame.BackgroundColor3 = C.BG_COLOR
hpFrame.BorderSizePixel = 0
hpFrame.Parent = playerBlock
Instance.new("UICorner", hpFrame).CornerRadius = UDim.new(0, 4)

local hpBar = Instance.new("Frame")
hpBar.Name = "HPBar"
hpBar.Size = UDim2.new(1, 0, 1, 0)
hpBar.BackgroundColor3 = C.HP_RED
hpBar.BorderSizePixel = 0
hpBar.Parent = hpFrame
Instance.new("UICorner", hpBar).CornerRadius = UDim.new(0, 4)

local hpText = Instance.new("TextLabel")
hpText.Name = "HPText"
hpText.Size = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.TextColor3 = C.TEXT_COLOR
hpText.TextSize = 13
hpText.Font = Enum.Font.GothamBold
hpText.Text = "100 / 100"
hpText.ZIndex = 2
hpText.Parent = hpFrame

-- XP Bar
local xpFrame = Instance.new("Frame")
xpFrame.Name = "XPBarFrame"
xpFrame.Size = UDim2.new(0, C.HP_BAR_WIDTH, 0, C.XP_HEIGHT)
xpFrame.Position = UDim2.new(0, 0, 0, C.HP_HEIGHT + 2)
xpFrame.BackgroundColor3 = C.XP_BG
xpFrame.BorderSizePixel = 0
xpFrame.Parent = playerBlock
Instance.new("UICorner", xpFrame).CornerRadius = UDim.new(0, 3)

local xpBar = Instance.new("Frame")
xpBar.Name = "XPBar"
xpBar.Size = UDim2.new(0, 0, 1, 0)
xpBar.BackgroundColor3 = C.XP_COLOR
xpBar.BorderSizePixel = 0
xpBar.Parent = xpFrame
Instance.new("UICorner", xpBar).CornerRadius = UDim.new(0, 3)

local xpText = Instance.new("TextLabel")
xpText.Name = "XPText"
xpText.Size = UDim2.new(1, 0, 1, 0)
xpText.BackgroundTransparency = 1
xpText.TextColor3 = C.TEXT_DIM
xpText.TextSize = 8
xpText.Font = Enum.Font.Gotham
xpText.Text = "0 / 100 XP"
xpText.ZIndex = 2
xpText.Parent = xpFrame

-- Level Circle
local levelFrame = Instance.new("Frame")
levelFrame.Name = "LevelFrame"
levelFrame.Size = UDim2.new(0, C.LEVEL_SIZE, 0, C.LEVEL_SIZE)
levelFrame.Position = UDim2.new(0, C.HP_BAR_WIDTH + C.LEVEL_GAP, 0.5, -C.LEVEL_SIZE / 2)
levelFrame.BackgroundColor3 = C.LEVEL_BG
levelFrame.BorderSizePixel = 0
levelFrame.Parent = playerBlock
Instance.new("UICorner", levelFrame).CornerRadius = UDim.new(0.5, 0)

local levelStroke = Instance.new("UIStroke")
levelStroke.Color = C.LEVEL_BORDER
levelStroke.Thickness = 2
levelStroke.Parent = levelFrame

local levelText = Instance.new("TextLabel")
levelText.Name = "LevelText"
levelText.Size = UDim2.new(1, 0, 1, 0)
levelText.BackgroundTransparency = 1
levelText.Text = "1"
levelText.TextColor3 = C.TEXT_COLOR
levelText.TextSize = 16
levelText.Font = Enum.Font.GothamBold
levelText.Parent = levelFrame

-- ═══ Update ═══
local function updateLevelDisplay()
    levelText.Text = tostring(levelData.Level)
    if levelData.XPToNext > 0 then
        local r = math.clamp(levelData.XP / levelData.XPToNext, 0, 1)
        xpBar.Size = UDim2.new(r, 0, 1, 0)
        xpText.Text = levelData.XP .. " / " .. levelData.XPToNext .. " XP"
    else
        xpBar.Size = UDim2.new(1, 0, 1, 0)
        xpText.Text = "MAX"
    end
end

local function updateHP()
    local character = player.Character
    if not character then return end
    local cur = character:GetAttribute("CurrentHP")
    local max = character:GetAttribute("MaxHP")
    if not cur or not max or max == 0 then return end
    local ratio = math.clamp(cur / max, 0, 1)
    hpBar.Size = UDim2.new(ratio, 0, 1, 0)
    hpBar.BackgroundColor3 = C.HP_RED
    hpText.Text = cur .. " / " .. max
end

-- ═══ Events ═══
Remotes.UpdateLevel.OnClientEvent:Connect(function(data)
    levelData.Level = data.Level or levelData.Level
    levelData.XP = data.XP or levelData.XP
    levelData.XPToNext = data.XPToNext or levelData.XPToNext
    levelData.MaxHP = data.MaxHP or levelData.MaxHP
    updateLevelDisplay()
end)

updateLevelDisplay()

RunService.RenderStepped:Connect(function()
    updateHP()
end)