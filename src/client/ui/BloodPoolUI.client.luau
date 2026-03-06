local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ Constants ═══
local FLASK_WIDTH = 50
local FLASK_HEIGHT = 80
local ICON_SIZE = 46
local MARGIN = 10

local BLOOD_DIM = Color3.fromRGB(60, 15, 15)
local BLOOD_BRIGHT = Color3.fromRGB(180, 15, 15)
local FLASK_BG = Color3.fromRGB(20, 18, 22)

local BLOOD_TWEEN_TIME = 0.4
local bloodSizeTween = nil
local bloodColorTween = nil

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BloodHUD"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 820
screenGui.Parent = playerGui

-- ═══ Container ═══
local container = Instance.new("Frame")
container.Name = "BloodPoolContainer"
container.Size = UDim2.new(0, FLASK_WIDTH + 40, 0, ICON_SIZE + 16 + FLASK_HEIGHT)
container.AnchorPoint = Vector2.new(0.5, 1)
container.Position = UDim2.new(0.5, 0, 1, -MARGIN)
container.BackgroundTransparency = 1
container.Parent = screenGui

-- ═══ Blood Type Icon ═══
local bloodIcon = Instance.new("ImageLabel")
bloodIcon.Name = "BloodIcon"
bloodIcon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
bloodIcon.AnchorPoint = Vector2.new(0.5, 0)
bloodIcon.Position = UDim2.new(0.5, 0, 0, 0)
bloodIcon.BackgroundTransparency = 1
bloodIcon.ScaleType = Enum.ScaleType.Fit
bloodIcon.Image = "rbxassetid://0"
bloodIcon.Parent = container

-- ═══ Quality % text ═══
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

-- ═══ Flask ═══
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

Instance.new("UICorner", bloodFrame).CornerRadius = UDim.new(0, 6)

local flaskStroke = Instance.new("UIStroke")
flaskStroke.Color = Color3.fromRGB(50, 40, 45)
flaskStroke.Thickness = 2
flaskStroke.Parent = bloodFrame

local bloodBar = Instance.new("Frame")
bloodBar.Name = "BloodBar"
bloodBar.AnchorPoint = Vector2.new(0, 1)
bloodBar.Position = UDim2.new(0, 0, 1, 0)
bloodBar.Size = UDim2.new(1, 0, 1, 0)
bloodBar.BackgroundColor3 = Color3.fromRGB(150, 20, 20)
bloodBar.BorderSizePixel = 0
bloodBar.Parent = bloodFrame

Instance.new("UICorner", bloodBar).CornerRadius = UDim.new(0, 6)

-- ═══ Helpers ═══
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

    local ratio = math.clamp(bloodAmount / 100, 0, 1)
    if bloodSizeTween then bloodSizeTween:Cancel() end
    bloodSizeTween = TweenService:Create(bloodBar, TweenInfo.new(BLOOD_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, ratio, 0)
    })
    bloodSizeTween:Play()

    local targetColor = getBloodColor(bloodQuality)
    if bloodColorTween then bloodColorTween:Cancel() end
    bloodColorTween = TweenService:Create(bloodBar, TweenInfo.new(BLOOD_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = targetColor
    })
    bloodColorTween:Play()

    local icon = typeConfig and typeConfig.Icon or ""
    if icon and icon ~= "" then
        bloodIcon.Image = icon
        bloodIcon.Visible = true
    else
        bloodIcon.Visible = false
    end

    if bloodType == "Outcast" then
        qualityText.Text = "0%"
    else
        qualityText.Text = bloodQuality .. "%"
    end
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

-- ═══ Hotkey [F] ═══
local function findNearbyDownedBoss()
    local character = player.Character
    if not character then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end

    for _, enemy in enemiesFolder:GetChildren() do
        if not enemy:GetAttribute("IsBoss") then continue end
        if enemy:GetAttribute("BossState") ~= "Downed" then continue end

        local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
        if not enemyRoot then continue end

        local distance = (enemyRoot.Position - rootPart.Position).Magnitude
        if distance <= 8 then
            return enemy:GetAttribute("BossId") or enemy:GetAttribute("EnemyType")
        end
    end
    return nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.Blood.DrinkKey then
        -- Check if there's a downed boss nearby first
        local bossId = findNearbyDownedBoss()
        if bossId then
            Remotes.BossFinish:FireServer(bossId)
        else
            Remotes.DrinkBloodRequest:FireServer()
        end
    end
end)