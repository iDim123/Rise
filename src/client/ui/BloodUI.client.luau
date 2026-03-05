local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== Blood Bar UI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BloodHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local bloodFrame = Instance.new("Frame")
bloodFrame.Size = UDim2.new(0, 200, 0, 20)
bloodFrame.AnchorPoint = Vector2.new(0.5, 1)
bloodFrame.Position = UDim2.new(0.5, 0, 1, -10)
bloodFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
bloodFrame.BorderSizePixel = 0
bloodFrame.Parent = screenGui

local bloodCorner = Instance.new("UICorner")
bloodCorner.CornerRadius = UDim.new(0, 4)
bloodCorner.Parent = bloodFrame

local bloodBar = Instance.new("Frame")
bloodBar.Name = "BloodBar"
bloodBar.Size = UDim2.new(1, 0, 1, 0)
bloodBar.BackgroundColor3 = Color3.fromRGB(150, 20, 20)
bloodBar.BorderSizePixel = 0
bloodBar.Parent = bloodFrame

local bloodBarCorner = Instance.new("UICorner")
bloodBarCorner.CornerRadius = UDim.new(0, 4)
bloodBarCorner.Parent = bloodBar

local bloodText = Instance.new("TextLabel")
bloodText.Size = UDim2.new(1, 0, 1, 0)
bloodText.BackgroundTransparency = 1
bloodText.TextColor3 = Color3.fromRGB(255, 255, 255)
bloodText.TextSize = 12
bloodText.Font = Enum.Font.GothamBold
bloodText.Text = "Изгой 100%"
bloodText.Parent = bloodFrame

-- ===== Обновление полоски крови по событию =====
local function updateBloodBar()
    local character = player.Character
    if not character then return end

    local bloodType = character:GetAttribute("BloodType") or "Outcast"
    local bloodQuality = character:GetAttribute("BloodQuality") or 0
    local bloodAmount = character:GetAttribute("BloodAmount") or 0

    local typeConfig = Config.Blood.Types[bloodType]
    local displayName = typeConfig and typeConfig.DisplayName or bloodType
    local color = typeConfig and typeConfig.Color or Color3.fromRGB(120, 120, 120)

    bloodBar.Size = UDim2.new(bloodAmount / 100, 0, 1, 0)
    bloodBar.BackgroundColor3 = color

    local qualityText = bloodType ~= "Outcast" and (" " .. bloodQuality .. "% кач.") or ""
    bloodText.Text = displayName .. " " .. math.floor(bloodAmount) .. "%" .. qualityText
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

-- ===== Enemy labels (Drink + Capture) =====
local drinkLabels = {}
local captureLabels = {}

local function createDrinkLabel(enemy)
    if drinkLabels[enemy] then return end
    local head = enemy:FindFirstChild("Head")
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
    local head = enemy:FindFirstChild("Head")
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

-- ===== Единый цикл проверки врагов (каждые 0.2с) =====
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

            -- Drink label
            if hpRatio <= Config.Blood.DrinkThreshold and distance <= Config.Blood.DrinkRange then
                createDrinkLabel(enemy)
            else
                removeDrinkLabel(enemy)
            end

            -- Capture label
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

-- ===== Hotkeys =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.Blood.DrinkKey then
        Remotes.DrinkBloodRequest:FireServer()
    end
end)