local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player = Players.LocalPlayer

-- ══════════════════════════════════
--  Level data (event-driven)
-- ══════════════════════════════════
local levelData = { Level = 1, XP = 0, XPToNext = 100, MaxHP = 100 }
local servantLevelData = { Level = 1, XP = 0, XPToNext = 100 }

-- ══════════════════════════════════
--  Layout constants
-- ══════════════════════════════════
local SLOT_SIZE = Config.Inventory.SlotSize       -- 50
local PADDING   = Config.Inventory.Padding        -- 4
local COLS      = Config.Inventory.Columns        -- 8
local ABILITY_SLOTS = 3                            -- LMB, Q, E

local AB_WIDTH     = PADDING + COLS * (SLOT_SIZE + PADDING)          -- 436
local ABIL_WIDTH   = PADDING + ABILITY_SLOTS * (SLOT_SIZE + PADDING) -- 166
local BAR_ROW_H    = SLOT_SIZE + 20                                   -- 70

local MARGIN       = 10   -- отступ от низа экрана
local BAR_GAP      = 4    -- зазор между элементами по вертикали

-- Константы (из ActionBar)
local FLASK_WIDTH = 50
local GAP = 8
local AB_HEIGHT = SLOT_SIZE + 20  -- 70
local BAR_GAP = 10

-- HP/XP bar dimensions  
local HP_HEIGHT    = 22
local XP_HEIGHT    = 6
local LEVEL_SIZE   = 34
local LEVEL_GAP    = 6
local HP_BAR_WIDTH = AB_WIDTH - LEVEL_GAP - LEVEL_SIZE  -- player HP bar width = ActionBar width

-- Vertical positions (from bottom up)
-- ActionBar bottom edge = 1, -MARGIN
-- ActionBar top edge    = 1, -(MARGIN + BAR_ROW_H)
-- HP block bottom       = 1, -(MARGIN + BAR_ROW_H + BAR_GAP)
local HP_BLOCK_BOTTOM = MARGIN + BAR_ROW_H + BAR_GAP
local HP_BLOCK_H      = HP_HEIGHT + 2 + XP_HEIGHT  -- 30

-- Servant HP bar width = abilities bar width
local SERVANT_BAR_WIDTH = HP_BAR_WIDTH

-- Servant Controls
local SERVANT_CTRL_COLS = 6
local SERVANT_CTRL_W = PADDING + SERVANT_CTRL_COLS * (SLOT_SIZE + PADDING) -- 328
local SERVANT_CTRL_H = BAR_ROW_H -- 70
-- Servant Controls bottom = HP_BLOCK_BOTTOM + HP_BLOCK_H + BAR_GAP
local SERVANT_CTRL_BOTTOM = HP_BLOCK_BOTTOM + HP_BLOCK_H + BAR_GAP

-- Colors
local BG_COLOR     = Color3.fromRGB(25, 25, 35)
local HP_GREEN     = Color3.fromRGB(50, 200, 50)
local HP_YELLOW    = Color3.fromRGB(220, 180, 30)
local HP_RED       = Color3.fromRGB(200, 30, 30)
local XP_COLOR     = Color3.fromRGB(100, 80, 220)
local XP_BG        = Color3.fromRGB(18, 18, 26)
local LEVEL_BG     = Color3.fromRGB(35, 30, 55)
local LEVEL_BORDER = Color3.fromRGB(60, 15, 15)
local TEXT_COLOR   = Color3.fromRGB(255, 255, 255)
local TEXT_DIM     = Color3.fromRGB(180, 180, 200)

-- ══════════════════════════════════
--  ScreenGui
-- ══════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerHUD"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 800
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ════════════════════════════════════════════
--  PLAYER SIDE (left) — HP + XP + Level circle
-- ════════════════════════════════════════════

local playerBlock = Instance.new("Frame")
playerBlock.Name = "PlayerHPBlock"
playerBlock.Size = UDim2.new(0, HP_BAR_WIDTH + LEVEL_GAP + LEVEL_SIZE, 0, HP_BLOCK_H)
playerBlock.AnchorPoint = Vector2.new(1, 1)
playerBlock.Position = UDim2.new(0.5, -(FLASK_WIDTH / 2) - GAP, 1, -(MARGIN + AB_HEIGHT + BAR_GAP))
playerBlock.BackgroundTransparency = 1
playerBlock.Parent = screenGui

-- HP Bar
local hpFrame = Instance.new("Frame")
hpFrame.Name = "HPBarFrame"
hpFrame.Size = UDim2.new(0, HP_BAR_WIDTH, 0, HP_HEIGHT)
hpFrame.Position = UDim2.new(0, 0, 0, 0)
hpFrame.BackgroundColor3 = BG_COLOR
hpFrame.BorderSizePixel = 0
hpFrame.Parent = playerBlock
Instance.new("UICorner", hpFrame).CornerRadius = UDim.new(0, 4)

local hpBar = Instance.new("Frame")
hpBar.Name = "HPBar"
hpBar.Size = UDim2.new(1, 0, 1, 0)
hpBar.BackgroundColor3 = HP_GREEN
hpBar.BorderSizePixel = 0
hpBar.Parent = hpFrame
Instance.new("UICorner", hpBar).CornerRadius = UDim.new(0, 4)

local hpText = Instance.new("TextLabel")
hpText.Name = "HPText"
hpText.Size = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.TextColor3 = TEXT_COLOR
hpText.TextSize = 13
hpText.Font = Enum.Font.GothamBold
hpText.Text = "100 / 100"
hpText.ZIndex = 2
hpText.Parent = hpFrame

-- XP Bar
local xpFrame = Instance.new("Frame")
xpFrame.Name = "XPBarFrame"
xpFrame.Size = UDim2.new(0, HP_BAR_WIDTH, 0, XP_HEIGHT)
xpFrame.Position = UDim2.new(0, 0, 0, HP_HEIGHT + 2)
xpFrame.BackgroundColor3 = XP_BG
xpFrame.BorderSizePixel = 0
xpFrame.Parent = playerBlock
Instance.new("UICorner", xpFrame).CornerRadius = UDim.new(0, 3)

local xpBar = Instance.new("Frame")
xpBar.Name = "XPBar"
xpBar.Size = UDim2.new(0, 0, 1, 0)
xpBar.BackgroundColor3 = XP_COLOR
xpBar.BorderSizePixel = 0
xpBar.Parent = xpFrame
Instance.new("UICorner", xpBar).CornerRadius = UDim.new(0, 3)

local xpText = Instance.new("TextLabel")
xpText.Name = "XPText"
xpText.Size = UDim2.new(1, 0, 1, 0)
xpText.BackgroundTransparency = 1
xpText.TextColor3 = TEXT_DIM
xpText.TextSize = 8
xpText.Font = Enum.Font.Gotham
xpText.Text = "0 / 100 XP"
xpText.ZIndex = 2
xpText.Parent = xpFrame

-- Level Circle (right of HP bar)
local levelFrame = Instance.new("Frame")
levelFrame.Name = "LevelFrame"
levelFrame.Size = UDim2.new(0, LEVEL_SIZE, 0, LEVEL_SIZE)
levelFrame.Position = UDim2.new(0, HP_BAR_WIDTH + LEVEL_GAP, 0.5, -LEVEL_SIZE / 2)
levelFrame.BackgroundColor3 = LEVEL_BG
levelFrame.BorderSizePixel = 0
levelFrame.Parent = playerBlock
Instance.new("UICorner", levelFrame).CornerRadius = UDim.new(0.5, 0)

local levelStroke = Instance.new("UIStroke")
levelStroke.Color = LEVEL_BORDER
levelStroke.Thickness = 2
levelStroke.Parent = levelFrame

local levelText = Instance.new("TextLabel")
levelText.Name = "LevelText"
levelText.Size = UDim2.new(1, 0, 1, 0)
levelText.BackgroundTransparency = 1
levelText.Text = "1"
levelText.TextColor3 = TEXT_COLOR
levelText.TextSize = 16
levelText.Font = Enum.Font.GothamBold
levelText.Parent = levelFrame

-- ════════════════════════════════════════════
--  SERVANT SIDE (right) — HP + XP + Level circle
--  Visible only when servant is active
-- ════════════════════════════════════════════

local servantBlock = Instance.new("Frame")
servantBlock.Name = "ServantHPBlock"
servantBlock.Size = UDim2.new(0, LEVEL_SIZE + LEVEL_GAP + SERVANT_BAR_WIDTH, 0, HP_BLOCK_H)
servantBlock.AnchorPoint = Vector2.new(0, 1)
servantBlock.Position = UDim2.new(0.5, (FLASK_WIDTH / 2) + GAP, 1, -(MARGIN + AB_HEIGHT + BAR_GAP))
servantBlock.BackgroundTransparency = 1
servantBlock.Visible = false
servantBlock.Parent = screenGui

-- Servant Level Circle (left side of servant block)
local sLevelFrame = Instance.new("Frame")
sLevelFrame.Name = "ServantLevelFrame"
sLevelFrame.Size = UDim2.new(0, LEVEL_SIZE, 0, LEVEL_SIZE)
sLevelFrame.Position = UDim2.new(0, 0, 0.5, -LEVEL_SIZE / 2)
sLevelFrame.BackgroundColor3 = LEVEL_BG
sLevelFrame.BorderSizePixel = 0
sLevelFrame.Parent = servantBlock
Instance.new("UICorner", sLevelFrame).CornerRadius = UDim.new(0.5, 0)

local sLevelStroke = Instance.new("UIStroke")
sLevelStroke.Color = LEVEL_BORDER
sLevelStroke.Thickness = 2
sLevelStroke.Parent = sLevelFrame

local sLevelText = Instance.new("TextLabel")
sLevelText.Name = "LevelText"
sLevelText.Size = UDim2.new(1, 0, 1, 0)
sLevelText.BackgroundTransparency = 1
sLevelText.Text = "1"
sLevelText.TextColor3 = TEXT_COLOR
sLevelText.TextSize = 16
sLevelText.Font = Enum.Font.GothamBold
sLevelText.Parent = sLevelFrame

-- Servant HP Bar (right of level circle)
local sHpFrame = Instance.new("Frame")
sHpFrame.Name = "ServantHPBarFrame"
sHpFrame.Size = UDim2.new(0, SERVANT_BAR_WIDTH, 0, HP_HEIGHT)
sHpFrame.Position = UDim2.new(0, LEVEL_SIZE + LEVEL_GAP, 0, 0)
sHpFrame.BackgroundColor3 = BG_COLOR
sHpFrame.BorderSizePixel = 0
sHpFrame.Parent = servantBlock
Instance.new("UICorner", sHpFrame).CornerRadius = UDim.new(0, 4)

local sHpBar = Instance.new("Frame")
sHpBar.Name = "HPBar"
sHpBar.Size = UDim2.new(1, 0, 1, 0)
sHpBar.BackgroundColor3 = HP_GREEN
sHpBar.BorderSizePixel = 0
sHpBar.Parent = sHpFrame
Instance.new("UICorner", sHpBar).CornerRadius = UDim.new(0, 4)

local sHpText = Instance.new("TextLabel")
sHpText.Name = "HPText"
sHpText.Size = UDim2.new(1, 0, 1, 0)
sHpText.BackgroundTransparency = 1
sHpText.TextColor3 = TEXT_COLOR
sHpText.TextSize = 13
sHpText.Font = Enum.Font.GothamBold
sHpText.Text = ""
sHpText.ZIndex = 2
sHpText.Parent = sHpFrame

-- Servant XP Bar
local sXpFrame = Instance.new("Frame")
sXpFrame.Name = "ServantXPBarFrame"
sXpFrame.Size = UDim2.new(0, SERVANT_BAR_WIDTH, 0, XP_HEIGHT)
sXpFrame.Position = UDim2.new(0, LEVEL_SIZE + LEVEL_GAP, 0, HP_HEIGHT + 2)
sXpFrame.BackgroundColor3 = XP_BG
sXpFrame.BorderSizePixel = 0
sXpFrame.Parent = servantBlock
Instance.new("UICorner", sXpFrame).CornerRadius = UDim.new(0, 3)

local sXpBar = Instance.new("Frame")
sXpBar.Name = "XPBar"
sXpBar.Size = UDim2.new(0, 0, 1, 0)
sXpBar.BackgroundColor3 = XP_COLOR
sXpBar.BorderSizePixel = 0
sXpBar.Parent = sXpFrame
Instance.new("UICorner", sXpBar).CornerRadius = UDim.new(0, 3)

local sXpText = Instance.new("TextLabel")
sXpText.Name = "XPText"
sXpText.Size = UDim2.new(1, 0, 1, 0)
sXpText.BackgroundTransparency = 1
sXpText.TextColor3 = TEXT_DIM
sXpText.TextSize = 8
sXpText.Font = Enum.Font.Gotham
sXpText.Text = ""
sXpText.ZIndex = 2
sXpText.Parent = sXpFrame

-- ══════════════════════════════════
--  Update functions
-- ══════════════════════════════════
local function getHPColor(ratio)
    return HP_RED
end

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
    hpBar.BackgroundColor3 = getHPColor(ratio)
    hpText.Text = cur .. " / " .. max
end

local function updateServant()
    local folder = workspace:FindFirstChild("Servants")
    if not folder then servantBlock.Visible = false return end
    local found = false
    for _, servant in folder:GetChildren() do
        if servant:GetAttribute("OwnerUserId") == player.UserId then
            local sHP = servant:GetAttribute("CurrentHP")
            local sMax = servant:GetAttribute("MaxHP")
            if sHP and sMax and sMax > 0 then
                local ratio = math.clamp(sHP / sMax, 0, 1)
                sHpBar.Size = UDim2.new(ratio, 0, 1, 0)
                sHpBar.BackgroundColor3 = getHPColor(ratio)
                sHpText.Text = sHP .. "/" .. sMax
                servantBlock.Visible = true
                found = true
            end
            break
        end
    end
    if not found then servantBlock.Visible = false end
end

local function updateServantLevel()
    sLevelText.Text = tostring(servantLevelData.Level)
    if servantLevelData.XPToNext > 0 then
        local r = math.clamp(servantLevelData.XP / servantLevelData.XPToNext, 0, 1)
        sXpBar.Size = UDim2.new(r, 0, 1, 0)
        sXpText.Text = servantLevelData.XP .. " / " .. servantLevelData.XPToNext .. " XP"
    else
        sXpBar.Size = UDim2.new(1, 0, 1, 0)
        sXpText.Text = "MAX"
    end
end

-- ══════════════════════════════════
--  Events
-- ══════════════════════════════════
Remotes.UpdateLevel.OnClientEvent:Connect(function(data)
    levelData.Level   = data.Level or levelData.Level
    levelData.XP      = data.XP or levelData.XP
    levelData.XPToNext = data.XPToNext or levelData.XPToNext
    levelData.MaxHP   = data.MaxHP or levelData.MaxHP
    updateLevelDisplay()
end)

Remotes.UpdateServantLevel.OnClientEvent:Connect(function(_servantId, data)
    servantLevelData.Level   = data.Level or servantLevelData.Level
    servantLevelData.XP      = data.XP or servantLevelData.XP
    servantLevelData.XPToNext = data.XPToNext or servantLevelData.XPToNext
    updateServantLevel()
end)

updateLevelDisplay()
updateServantLevel()

RunService.RenderStepped:Connect(function()
    updateHP()
    updateServant()
end)