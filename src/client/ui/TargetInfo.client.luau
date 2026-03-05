local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local LevelColor = require(ReplicatedStorage:WaitForChild("LevelColorUtil"))
-- ═══ Constants ═══
local BAR_WIDTH = 300
local BAR_HEIGHT = 18
local LEVEL_SIZE = 32
local LEVEL_GAP = 6
local CORNER = 4
local MARGIN = 10

local BAR_BG = Color3.fromRGB(30, 30, 38)
local BAR_STROKE = Color3.fromRGB(50, 0, 0)
local HP_COLOR = Color3.fromRGB(200, 30, 30)
local TEXT_COLOR = Color3.fromRGB(225, 225, 225)
local LEVEL_BG = Color3.fromRGB(30, 30, 38)
local BLOOD_COLOR = Color3.fromRGB(255, 255, 255)

local TOTAL_WIDTH = LEVEL_SIZE + LEVEL_GAP + BAR_WIDTH  -- 300

-- ═══ Animation ═══
local FADE_TIME = 0.25        -- fade in/out duration
local HP_TWEEN_TIME = 0.3     -- HP bar smooth transition
local fadeTween = nil
local hpTween = nil
local isVisible = false

-- ═══ State ═══
local currentTarget = nil
local lastTargetTime = 0
local TARGET_TIMEOUT = 1
local lastDisplayedTarget = nil

-- ═══ UI ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TargetInfoGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 850
screenGui.Parent = playerGui
screenGui.IgnoreGuiInset = true

-- Container — no background
local container = Instance.new("CanvasGroup")
container.GroupTransparency = 1
container.Name = "TargetInfo"
container.Size = UDim2.new(0, TOTAL_WIDTH + 20, 0, 70)
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.new(0.5, 0, 0, MARGIN)
container.BackgroundTransparency = 1
container.Visible = false
container.Parent = screenGui

local containerPad = Instance.new("UIPadding")
containerPad.PaddingLeft = UDim.new(0, 10)
containerPad.PaddingRight = UDim.new(0, 10)
containerPad.Parent = container

-- ── Target Name (centered, top) ──
local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "TargetName"
nameLabel.Size = UDim2.new(0, BAR_WIDTH, 0, 22)
nameLabel.Position = UDim2.new(0, LEVEL_SIZE + LEVEL_GAP, 0, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextSize = 16
nameLabel.TextColor3 = TEXT_COLOR
nameLabel.TextXAlignment = Enum.TextXAlignment.Center
nameLabel.TextStrokeTransparency = 0.5
nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
nameLabel.Text = ""
nameLabel.Parent = container

-- ── Level circle (left, below name) ──
local levelFrame = Instance.new("Frame")
levelFrame.Name = "LevelFrame"
levelFrame.Size = UDim2.new(0, LEVEL_SIZE, 0, LEVEL_SIZE)
levelFrame.Position = UDim2.new(0, 0, 0, 20)
levelFrame.BackgroundColor3 = LEVEL_BG
levelFrame.BackgroundTransparency = 0.2
levelFrame.BorderSizePixel = 0
levelFrame.Parent = container
Instance.new("UICorner", levelFrame).CornerRadius = UDim.new(0, 6)

local levelText = Instance.new("TextLabel")
levelText.Name = "LevelText"
levelText.Size = UDim2.new(1, 0, 1, 0)
levelText.BackgroundTransparency = 1
levelText.Font = Enum.Font.GothamBold
levelText.TextSize = 16
levelText.Text = ""
levelText.Parent = levelFrame

-- ── HP Bar (right of level, below name) ──
local hpBg = Instance.new("Frame")
hpBg.Name = "HPBarBg"
hpBg.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
hpBg.Position = UDim2.new(0, LEVEL_SIZE + LEVEL_GAP, 0, 20 + (LEVEL_SIZE - BAR_HEIGHT) / 2)
hpBg.BackgroundColor3 = BAR_BG
hpBg.BackgroundTransparency = 0.2
hpBg.BorderSizePixel = 0
hpBg.Parent = container
Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, CORNER)

local hpStroke = Instance.new("UIStroke")
hpStroke.Color = BAR_STROKE
hpStroke.Thickness = 1.5
hpStroke.Parent = hpBg

local hpBar = Instance.new("Frame")
hpBar.Name = "HPBar"
hpBar.Size = UDim2.new(1, 0, 1, 0)
hpBar.BackgroundColor3 = HP_COLOR
hpBar.BorderSizePixel = 0
hpBar.Parent = hpBg
Instance.new("UICorner", hpBar).CornerRadius = UDim.new(0, CORNER)

local hpText = Instance.new("TextLabel")
hpText.Name = "HPText"
hpText.Size = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.Font = Enum.Font.GothamBold
hpText.TextSize = 10
hpText.TextColor3 = TEXT_COLOR
hpText.TextStrokeTransparency = 0.5
hpText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
hpText.ZIndex = 2
hpText.Text = ""
hpText.Parent = hpBg

-- ── Blood % (below HP bar, only shown if target has blood) ──
local bloodLabel = Instance.new("TextLabel")
bloodLabel.Name = "BloodLabel"
bloodLabel.Size = UDim2.new(0, BAR_WIDTH, 0, 16)
bloodLabel.Position = UDim2.new(0, LEVEL_SIZE + LEVEL_GAP, 0, 20 + LEVEL_SIZE + 2)
bloodLabel.BackgroundTransparency = 1
bloodLabel.Font = Enum.Font.Gotham
bloodLabel.TextSize = 14
bloodLabel.TextColor3 = BLOOD_COLOR
bloodLabel.TextXAlignment = Enum.TextXAlignment.Center
-- bloodLabel.TextStrokeTransparency = 0.7
bloodLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
bloodLabel.Text = ""
bloodLabel.Visible = false
bloodLabel.Parent = container

local function fadeIn()
    if isVisible then return end
    isVisible = true
    container.Visible = true
    if fadeTween then fadeTween:Cancel() end
    container.GroupTransparency = 1
    fadeTween = TweenService:Create(container, TweenInfo.new(FADE_TIME), {
        GroupTransparency = 0
    })
    fadeTween:Play()
end

local function fadeOut()
    if not isVisible then return end
    isVisible = false
    if fadeTween then fadeTween:Cancel() end
    fadeTween = TweenService:Create(container, TweenInfo.new(FADE_TIME), {
        GroupTransparency = 1
    })
    fadeTween:Play()
    local thisTween = fadeTween
    task.delay(FADE_TIME + 0.05, function()
        if not isVisible and fadeTween == thisTween then
            container.Visible = false
        end
    end)
end
-- ═══ Helpers ═══
local function isValidTarget(model)
    if not model then return false end

    -- Enemy: lives in Enemies folder
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if enemiesFolder and model:IsDescendantOf(enemiesFolder) then
        return true
    end

    -- Other player character
    for _, p in Players:GetPlayers() do
        if p ~= player and p.Character and p.Character == model then
            return true
        end
    end

    return false
end

local function getModelFromPart(part)
    if not part then return nil end
    local current = part
    while current and current ~= workspace do
        if current:IsA("Model") then
            if current:FindFirstChildOfClass("Humanoid") or current:GetAttribute("CurrentHP") then
                return current
            end
        end
        current = current.Parent
    end
    return nil
end

local function updateTargetUI()
    local target = currentTarget

    if not target or not target.Parent then
        fadeOut()
        lastDisplayedTarget = nil
        return
    end

    local curHP = target:GetAttribute("CurrentHP")
    local maxHP = target:GetAttribute("MaxHP")
    local level = target:GetAttribute("Level")
    local enemyName = target:GetAttribute("EnemyType") or target.Name

    if not curHP or not maxHP then
        fadeOut()
        return
    end

    local targetChanged = (target ~= lastDisplayedTarget)

    fadeIn()
    lastDisplayedTarget = target

    -- Name
    nameLabel.Text = tostring(enemyName)

    -- Level
    local playerLevel = 1
    local character = player.Character
    if character then
        playerLevel = character:GetAttribute("Level") or 1
    end

    if level then
        local color = LevelColor.getColor(level, playerLevel)
        levelText.TextColor3 = color

        if LevelColor.isSkull(level, playerLevel) then
            levelText.Text = LevelColor.SkullText
        else
            levelText.Text = tostring(level)
        end
    else
        levelText.Text = "?"
        levelText.TextColor3 = LevelColor.Colors.White
    end

    -- HP
    local ratio = math.clamp(curHP / math.max(maxHP, 1), 0, 1)
    hpText.Text = tostring(math.ceil(curHP)) .. " / " .. tostring(math.ceil(maxHP))

    if targetChanged then
        if hpTween then hpTween:Cancel() end
        hpBar.Size = UDim2.new(ratio, 0, 1, 0)
    else
        if hpTween then hpTween:Cancel() end
        hpTween = TweenService:Create(hpBar, TweenInfo.new(HP_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(ratio, 0, 1, 0)
        })
        hpTween:Play()
    end

    -- Blood
    local bloodType = target:GetAttribute("BloodType")
    local bloodQuality = target:GetAttribute("BloodQuality")
    if bloodType and bloodQuality then
        bloodLabel.Text = tostring(bloodType) .. "  (" .. tostring(math.floor(bloodQuality)) .. "%)"
        bloodLabel.Visible = true
    else
        bloodLabel.Visible = false
    end
end

-- ═══ Target detection ═══
local function checkMouseTarget()
    local target = mouse.Target
    if target then
        local model = getModelFromPart(target)
        if model and isValidTarget(model) then
            currentTarget = model
            lastTargetTime = tick()
            return
        end
    end
end

-- ═══ Main loop ═══
RunService.RenderStepped:Connect(function()
    checkMouseTarget()
    updateTargetUI()
end)