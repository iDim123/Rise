local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ Constants ═══
local FLASK_WIDTH = 50
local FLASK_HEIGHT = 80
local ICON_SIZE = 46
local MARGIN = 10

-- Цвета крови по качеству (0% = тусклый, 100% = насыщенный)
local BLOOD_DIM = Color3.fromRGB(60, 15, 15)       -- 0% quality
local BLOOD_BRIGHT = Color3.fromRGB(180, 15, 15)    -- 100% quality
local FLASK_BG = Color3.fromRGB(20, 18, 22)

local function getEnemyHead(enemy)
    return enemy:FindFirstChild("Head")
        or enemy:FindFirstChild("UpperTorso")
        or enemy:FindFirstChild("Torso")
        or enemy:FindFirstChild("HumanoidRootPart")
        or enemy.PrimaryPart
end

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BloodHUD"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 820
screenGui.Parent = playerGui

-- ═══ Container (icon + text + flask) ═══
local container = Instance.new("Frame")
container.Name = "BloodPoolContainer"
container.Size = UDim2.new(0, FLASK_WIDTH + 40, 0, ICON_SIZE + 16 + FLASK_HEIGHT)
container.AnchorPoint = Vector2.new(0.5, 1)
container.Position = UDim2.new(0.5, 0, 1, -MARGIN)
container.BackgroundTransparency = 1
container.Parent = screenGui

-- ═══ Blood Type Icon (top, no border) ═══
local bloodIcon = Instance.new("ImageLabel")
bloodIcon.Name = "BloodIcon"
bloodIcon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
bloodIcon.AnchorPoint = Vector2.new(0.5, 0)
bloodIcon.Position = UDim2.new(0.5, 0, 0, 0)
bloodIcon.BackgroundTransparency = 1
bloodIcon.ScaleType = Enum.ScaleType.Fit
bloodIcon.Image = "rbxassetid://0" -- placeholder, will be updated
bloodIcon.Parent = container

-- ═══ Quality % text (below icon) ═══
local qualityText = Instance.new("TextLabel")
qualityText.Name = "QualityText"
qualityText.Size = UDim2.new(1, 0, 0, 14)
qualityText.Position = UDim2.new(0, 0, 0, ICON_SIZE - 1)
qualityText.BackgroundTransparency = 1
qualityText.TextColor3 = Color3.fromRGB(255, 255, 255)
qualityText.TextSize = 12
qualityText.Font = Enum.Font.GothamBold
qualityText.Text = "100%"
qualityText.Parent = container

-- ═══ Flask (blood pool bar) ═══
local flaskY = ICON_SIZE + 16

local bloodFrame = Instance.new("Frame")
bloodFrame.Name = "BloodFlask"
bloodFrame.Size = UDim2.new(0, FLASK_WIDTH, 0, FLASK_HEIGHT)
bloodFrame.AnchorPoint = Vector2.new(0.5, 0)
bloodFrame.Position = UDim2.new(0.5, 0, 0, flaskY)
bloodFrame.BackgroundColor3 = FLASK_BG
bloodFrame.BorderSizePixel = 0
bloodFrame.ClipsDescendants = true
bloodFrame.Parent = container

-- Rounded top corners (flask shape)
local flaskCorner = Instance.new("UICorner")
flaskCorner.CornerRadius = UDim.new(0, 6)
flaskCorner.Parent = bloodFrame

-- Dark border
local flaskStroke = Instance.new("UIStroke")
flaskStroke.Color = Color3.fromRGB(50, 40, 45)
flaskStroke.Thickness = 2
flaskStroke.Parent = bloodFrame

-- Fill bar (grows from bottom up)
local bloodBar = Instance.new("Frame")
bloodBar.Name = "BloodBar"
bloodBar.AnchorPoint = Vector2.new(0, 1)
bloodBar.Position = UDim2.new(0, 0, 1, 0)
bloodBar.Size = UDim2.new(1, 0, 1, 0)
bloodBar.BackgroundColor3 = Color3.fromRGB(150, 20, 20)
bloodBar.BorderSizePixel = 0
bloodBar.Parent = bloodFrame

local bloodBarCorner = Instance.new("UICorner")
bloodBarCorner.CornerRadius = UDim.new(0, 6)
bloodBarCorner.Parent = bloodBar

-- Amount text inside flask
-- local amountText = Instance.new("TextLabel")
-- amountText.Name = "AmountText"
-- amountText.Size = UDim2.new(1, 0, 1, 0)
-- amountText.BackgroundTransparency = 1
-- amountText.TextColor3 = Color3.fromRGB(255, 255, 255)
-- amountText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
-- amountText.TextStrokeTransparency = 0.5
-- amountText.TextSize = 14
-- amountText.Font = Enum.Font.GothamBold
-- amountText.Text = "100%"
-- amountText.ZIndex = 2
-- amountText.Parent = bloodFrame

-- ═══ Blood color by quality ═══
local function getBloodColor(quality)
    local t = math.clamp(quality / 100, 0, 1)
    return BLOOD_DIM:Lerp(BLOOD_BRIGHT, t)
end

-- ═══ Update ═══
local function updateBloodBar()
    local character = player.Character
    if not character then return end

    local bloodType = character:GetAttribute("BloodType") or "Outcast"
    local bloodQuality = character:GetAttribute("BloodQuality") or 0
    local bloodAmount = character:GetAttribute("BloodAmount") or 0

    local typeConfig = Config.Blood.Types[bloodType]
    local displayName = typeConfig and typeConfig.DisplayName or bloodType

    -- Fill ratio (amount)
    local ratio = math.clamp(bloodAmount / 100, 0, 1)
    bloodBar.Size = UDim2.new(1, 0, ratio, 0)

    -- Color by quality
    bloodBar.BackgroundColor3 = getBloodColor(bloodQuality)

    -- Icon (from blood type config)
    local icon = typeConfig and typeConfig.Icon or ""
    if icon and icon ~= "" then
        bloodIcon.Image = icon
        bloodIcon.Visible = true
    else
        bloodIcon.Visible = false
    end

    -- Quality text above flask
    if bloodType == "Outcast" then
        qualityText.Text = "0%"
    else
        qualityText.Text = bloodQuality .. "%"
    end

    -- Amount inside flask
    -- amountText.Text = math.floor(bloodAmount) .. "%"
end

local function connectBloodAttributes(character)
    character:GetAttributeChangedSignal("BloodAmount"):Connect(updateBloodBar)
    character:GetAttributeChangedSignal("BloodType"):Connect(updateBloodBar)
    character:GetAttributeChangedSignal("BloodQuality"):Connect(updateBloodBar)
    updateBloodBar()
end

player.CharacterAdded:Connect(connectBloodAttributes)
if player.Character then
    connectBloodAttributes(player.Character)
end

-- ═══ Enemy labels (Drink + Capture) ═══
local drinkLabels = {}
local captureLabels = {}

local function createDrinkLabel(enemy)
    if drinkLabels[enemy] then return end
    local head = getEnemyHead(enemy)
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DrinkLabel"
    billboard.Size = UDim2.new(0, 150, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = head
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(200, 30, 30)
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.Text = "Выпить кровь [F]"
    label.Parent = billboard

    drinkLabels[enemy] = billboard
end

local function removeDrinkLabel(enemy)
    if drinkLabels[enemy] then
        drinkLabels[enemy]:Destroy()
        drinkLabels[enemy] = nil
    end
end

local function createCaptureLabel(enemy)
    if captureLabels[enemy] then return end
    local head = getEnemyHead(enemy)
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CaptureLabel"
    billboard.Size = UDim2.new(0, 150, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 5.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = head
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(180, 50, 220)
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.Text = "Захватить [T]"
    label.Parent = billboard

    captureLabels[enemy] = billboard
end

local function removeCaptureLabel(enemy)
    if captureLabels[enemy] then
        captureLabels[enemy]:Destroy()
        captureLabels[enemy] = nil
    end
end

-- ═══ Enemy scan (every 0.2s) ═══
local SCAN_INTERVAL = 0.2
local scanTimer = 0

RunService.RenderStepped:Connect(function(dt)
    scanTimer += dt
    if scanTimer < SCAN_INTERVAL then return end
    scanTimer = 0

    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return end

    for _, enemy in enemiesFolder:GetChildren() do
        local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
        if not enemyRoot then
            removeDrinkLabel(enemy)
            removeCaptureLabel(enemy)
            continue
        end

        local currentHP = enemy:GetAttribute("CurrentHP")
        local maxHP = enemy:GetAttribute("MaxHP")
        local distance = (enemyRoot.Position - rootPart.Position).Magnitude

        if currentHP and maxHP and maxHP > 0 then
            local hpRatio = currentHP / maxHP

            if hpRatio <= Config.Blood.DrinkThreshold and distance <= Config.Blood.DrinkRange then
                createDrinkLabel(enemy)
            else
                removeDrinkLabel(enemy)
            end

            if enemy:GetAttribute("CanCapture") == false then
                removeCaptureLabel(enemy)
            elseif hpRatio <= (Config.Servants.CaptureThreshold or 0.2) and distance <= (Config.Servants.CaptureRange or 8) then
                createCaptureLabel(enemy)
            else
                removeCaptureLabel(enemy)
            end
        else
            removeDrinkLabel(enemy)
            removeCaptureLabel(enemy)
        end
    end
end)

-- ═══ Hotkeys ═══
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.Blood.DrinkKey then
        Remotes.DrinkBloodRequest:FireServer()
    end
end)