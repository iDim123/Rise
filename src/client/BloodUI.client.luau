local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local drinkBloodRemote = ReplicatedStorage:WaitForChild("DrinkBloodRequest")

-- ===== UI полоска крови =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BloodHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local bloodFrame = Instance.new("Frame")
bloodFrame.Size = UDim2.new(0, 200, 0, 20)
bloodFrame.Position = UDim2.new(0.5, -100, 0, 55) -- под HP баром
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

-- ===== Надпись "Выпить кровь [F]" над врагами =====
local drinkLabels = {} -- [enemy] = BillboardGui

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

-- ===== Горячая клавиша F =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.Blood.DrinkKey then
        drinkBloodRemote:FireServer()
    end
end)

-- ===== Обновление каждый кадр =====
RunService.RenderStepped:Connect(function()
    local character = player.Character
    if not character then return end

    -- Обновляем полоску крови
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

    -- Обновляем надписи над врагами
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return end

    for _, enemy in enemiesFolder:GetChildren() do
        local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
        if not enemyRoot then
            removeDrinkLabel(enemy)
            continue
        end

        local currentHP = enemy:GetAttribute("CurrentHP")
        local maxHP = enemy:GetAttribute("MaxHP")

        if currentHP and maxHP and maxHP > 0 then
            local hpRatio = currentHP / maxHP
            local distance = (enemyRoot.Position - rootPart.Position).Magnitude

            if hpRatio <= Config.Blood.DrinkThreshold and distance <= Config.Blood.DrinkRange then
                createDrinkLabel(enemy)
            else
                removeDrinkLabel(enemy)
            end
        else
            removeDrinkLabel(enemy)
        end
    end
end)