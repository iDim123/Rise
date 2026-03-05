local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player = Players.LocalPlayer

-- ══════════════════════════════════
--  Данные уровня (event-driven)
-- ══════════════════════════════════
local levelData = { Level = 1, XP = 0, XPToNext = 100, MaxHP = 100 }

-- ══════════════════════════════════
--  Размеры (совпадают с ActionBar)
-- ══════════════════════════════════
local SLOT_SIZE = Config.Inventory.SlotSize   -- 50
local PADDING   = Config.Inventory.Padding    -- 4
local COLS      = Config.Inventory.Columns    -- 8

local AB_WIDTH  = PADDING + COLS * (SLOT_SIZE + PADDING)  -- 436
local AB_HEIGHT = SLOT_SIZE + 20                           -- 70

local BAR_WIDTH  = AB_WIDTH           -- ширина HP бара = ширина ActionBar
local BAR_HEIGHT = 22
local XP_HEIGHT  = 6
local LEVEL_SIZE = 34
local GAP        = 6
local MARGIN     = 10  -- отступ от низа экрана

-- Полная высота блока: HP + XP + gap + ActionBar
local HP_BLOCK_H = BAR_HEIGHT + 2 + XP_HEIGHT

-- Цвета
local BG_COLOR     = Color3.fromRGB(25, 25, 35)
local HP_GREEN     = Color3.fromRGB(50, 200, 50)
local HP_YELLOW    = Color3.fromRGB(220, 180, 30)
local HP_RED       = Color3.fromRGB(200, 30, 30)
local XP_COLOR     = Color3.fromRGB(100, 80, 220)
local XP_BG        = Color3.fromRGB(18, 18, 26)
local LEVEL_BG     = Color3.fromRGB(35, 30, 55)
local LEVEL_BORDER = Color3.fromRGB(100, 80, 220)
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

-- ══════════════════════════════════
--  Контейнер: HP + XP бары + кружок уровня
--  Позиция: привязан к низу, прямо над ActionBar
--  ActionBar: AnchorPoint(0.5, 1), Position(0.5, 0, 1, -MARGIN)
--  HP block: прямо над ним
-- ══════════════════════════════════

-- Сначала определяем X-позицию левого края (как у ActionBar)
-- ActionBar: центр экрана, ширина AB_WIDTH
-- Левый край ActionBar = 0.5 * viewport - AB_WIDTH/2
-- HP бар = BAR_WIDTH + GAP + LEVEL_SIZE (для круга уровня справа)

local TOTAL_W = BAR_WIDTH + GAP + LEVEL_SIZE

local container = Instance.new("Frame")
container.Name = "PlayerHPBlock"
container.Size = UDim2.new(0, TOTAL_W, 0, HP_BLOCK_H)
container.AnchorPoint = Vector2.new(0.5, 1)
-- Располагаем прямо над ActionBar: ActionBar bottom = 1, -MARGIN; ActionBar height = AB_HEIGHT
-- Значит верх ActionBar = 1, -(MARGIN + AB_HEIGHT)
-- HP block bottom = 1, -(MARGIN + AB_HEIGHT + 4)
container.Position = UDim2.new(0.5, -(AB_WIDTH / 2) + (TOTAL_W / 2), 1, -(MARGIN + AB_HEIGHT + 4))
container.BackgroundTransparency = 1
container.Parent = screenGui

-- НО: ActionBar центрирован по 0.5, а наш блок должен быть выровнен по ЛЕВОМУ краю ActionBar
-- Пересчитаем: ActionBar left = 0.5, -AB_WIDTH/2
-- HP block left = ActionBar left = 0.5, -AB_WIDTH/2
-- HP block AnchorPoint = (0, 1)

container.AnchorPoint = Vector2.new(0, 1)
container.Position = UDim2.new(0.5, -AB_WIDTH / 2, 1, -(MARGIN + AB_HEIGHT + 4))

-- ══════════════════════════════════
--  HP Bar
-- ══════════════════════════════════
local hpFrame = Instance.new("Frame")
hpFrame.Name = "HPBarFrame"
hpFrame.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
hpFrame.Position = UDim2.new(0, 0, 0, 0)
hpFrame.BackgroundColor3 = BG_COLOR
hpFrame.BorderSizePixel = 0
hpFrame.Parent = container

local hpFrameCorner = Instance.new("UICorner")
hpFrameCorner.CornerRadius = UDim.new(0, 4)
hpFrameCorner.Parent = hpFrame

local hpBar = Instance.new("Frame")
hpBar.Name = "HPBar"
hpBar.Size = UDim2.new(1, 0, 1, 0)
hpBar.BackgroundColor3 = HP_GREEN
hpBar.BorderSizePixel = 0
hpBar.Parent = hpFrame

local hpBarCorner = Instance.new("UICorner")
hpBarCorner.CornerRadius = UDim.new(0, 4)
hpBarCorner.Parent = hpBar

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

-- ══════════════════════════════════
--  XP Bar (под HP)
-- ══════════════════════════════════
local xpFrame = Instance.new("Frame")
xpFrame.Name = "XPBarFrame"
xpFrame.Size = UDim2.new(0, BAR_WIDTH, 0, XP_HEIGHT)
xpFrame.Position = UDim2.new(0, 0, 0, BAR_HEIGHT + 2)
xpFrame.BackgroundColor3 = XP_BG
xpFrame.BorderSizePixel = 0
xpFrame.Parent = container

local xpFrameCorner = Instance.new("UICorner")
xpFrameCorner.CornerRadius = UDim.new(0, 3)
xpFrameCorner.Parent = xpFrame

local xpBar = Instance.new("Frame")
xpBar.Name = "XPBar"
xpBar.Size = UDim2.new(0, 0, 1, 0)
xpBar.BackgroundColor3 = XP_COLOR
xpBar.BorderSizePixel = 0
xpBar.Parent = xpFrame

local xpBarCorner = Instance.new("UICorner")
xpBarCorner.CornerRadius = UDim.new(0, 3)
xpBarCorner.Parent = xpBar

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

-- ══════════════════════════════════
--  Level Circle (справа от HP бара, как на мокапе)
-- ══════════════════════════════════
local levelFrame = Instance.new("Frame")
levelFrame.Name = "LevelFrame"
levelFrame.Size = UDim2.new(0, LEVEL_SIZE, 0, LEVEL_SIZE)
-- Вертикально центрируем по HP блоку
levelFrame.Position = UDim2.new(0, BAR_WIDTH + GAP, 0.5, -LEVEL_SIZE / 2)
levelFrame.BackgroundColor3 = LEVEL_BG
levelFrame.BorderSizePixel = 0
levelFrame.Parent = container

-- Круг (CornerRadius = половина размера)
local levelCorner = Instance.new("UICorner")
levelCorner.CornerRadius = UDim.new(0.5, 0)
levelCorner.Parent = levelFrame

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

-- ══════════════════════════════════
--  Servant HP bar (справа вверху — пока оставляем)
--  Будет перенесён в шаге 7c
-- ══════════════════════════════════
local servantFrame = Instance.new("Frame")
servantFrame.Name = "ServantHPFrame"
servantFrame.Size = UDim2.new(0, 150, 0, 16)
servantFrame.AnchorPoint = Vector2.new(1, 1)
-- Временно: справа, над ActionBar (зеркально)
servantFrame.Position = UDim2.new(0.5, AB_WIDTH / 2, 1, -(MARGIN + AB_HEIGHT + 8))
servantFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
servantFrame.BorderSizePixel = 0
servantFrame.Visible = false
servantFrame.Parent = screenGui

local servantFrameCorner = Instance.new("UICorner")
servantFrameCorner.CornerRadius = UDim.new(0, 4)
servantFrameCorner.Parent = servantFrame

local servantBar = Instance.new("Frame")
servantBar.Name = "ServantBar"
servantBar.Size = UDim2.new(1, 0, 1, 0)
servantBar.BackgroundColor3 = Color3.fromRGB(80, 50, 180)
servantBar.BorderSizePixel = 0
servantBar.Parent = servantFrame

local servantBarCorner = Instance.new("UICorner")
servantBarCorner.CornerRadius = UDim.new(0, 4)
servantBarCorner.Parent = servantBar

local servantText = Instance.new("TextLabel")
servantText.Name = "ServantText"
servantText.Size = UDim2.new(1, 0, 1, 0)
servantText.BackgroundTransparency = 1
servantText.TextColor3 = TEXT_COLOR
servantText.TextSize = 10
servantText.Font = Enum.Font.GothamBold
servantText.Text = ""
servantText.ZIndex = 2
servantText.Parent = servantFrame

-- ══════════════════════════════════
--  Функции обновления
-- ══════════════════════════════════
local function getHPColor(ratio)
    if ratio > 0.5 then return HP_GREEN
    elseif ratio > 0.25 then return HP_YELLOW
    else return HP_RED end
end

local function updateLevelDisplay()
    levelText.Text = tostring(levelData.Level)
    if levelData.XPToNext > 0 then
        local xpRatio = math.clamp(levelData.XP / levelData.XPToNext, 0, 1)
        xpBar.Size = UDim2.new(xpRatio, 0, 1, 0)
        xpText.Text = levelData.XP .. " / " .. levelData.XPToNext .. " XP"
    else
        xpBar.Size = UDim2.new(1, 0, 1, 0)
        xpText.Text = "MAX"
    end
end

local function updateHP()
    local character = player.Character
    if not character then return end
    local currentHP = character:GetAttribute("CurrentHP")
    local maxHP = character:GetAttribute("MaxHP")
    if not currentHP or not maxHP or maxHP == 0 then return end
    local ratio = math.clamp(currentHP / maxHP, 0, 1)
    hpBar.Size = UDim2.new(ratio, 0, 1, 0)
    hpBar.BackgroundColor3 = getHPColor(ratio)
    hpText.Text = currentHP .. " / " .. maxHP
end

local function updateServant()
    local servantsFolder = workspace:FindFirstChild("Servants")
    if not servantsFolder then servantFrame.Visible = false return end
    local found = false
    for _, servant in servantsFolder:GetChildren() do
        if servant:GetAttribute("OwnerUserId") == player.UserId then
            local sHP = servant:GetAttribute("CurrentHP")
            local sMaxHP = servant:GetAttribute("MaxHP")
            if sHP and sMaxHP and sMaxHP > 0 then
                servantBar.Size = UDim2.new(math.clamp(sHP / sMaxHP, 0, 1), 0, 1, 0)
                servantText.Text = servant.Name .. " " .. sHP .. "/" .. sMaxHP
                servantFrame.Visible = true
                found = true
            end
            break
        end
    end
    if not found then servantFrame.Visible = false end
end

-- ══════════════════════════════════
--  Events
-- ══════════════════════════════════
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
    updateServant()
end)