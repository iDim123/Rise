local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LootGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Подсказка подбора
local pickupHint = Instance.new("BillboardGui")
pickupHint.Name = "PickupHint"
pickupHint.Size = UDim2.new(0, 200, 0, 50)
pickupHint.StudsOffset = Vector3.new(0, 2.5, 0)
pickupHint.AlwaysOnTop = true
pickupHint.Active = false
pickupHint.Parent = screenGui

local hintFrame = Instance.new("Frame")
hintFrame.Size = UDim2.new(1, 0, 1, 0)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
hintFrame.BackgroundTransparency = 0.3
hintFrame.BorderSizePixel = 0
hintFrame.Parent = pickupHint

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 6)
hintCorner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, 0, 1, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hintLabel.TextSize = 14
hintLabel.Font = Enum.Font.GothamBold
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local nearestLoot = nil

-- Находим ближайший лут
local function findNearestLoot()
    local character = player.Character
    if not character then
        return nil
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return nil
    end

    local lootFolder = workspace:FindFirstChild("Loot")
    if not lootFolder then
        return nil
    end

    local closest = nil
    local closestDist = Config.Loot.PickupRange

    for _, lootPart in lootFolder:GetChildren() do
        if lootPart:IsA("Part") and lootPart:GetAttribute("IsLoot") then
            local dist = (lootPart.Position - rootPart.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = lootPart
            end
        end
    end

    return closest
end

-- Обновляем подсказку каждый кадр
RunService.RenderStepped:Connect(function()
    nearestLoot = findNearestLoot()

    if nearestLoot then
        pickupHint.Adornee = nearestLoot
        pickupHint.Enabled = true

        local itemName = nearestLoot:GetAttribute("ItemName") or "???"
        local amount = nearestLoot:GetAttribute("Amount") or 1

        if amount > 1 then
            hintLabel.Text = "F  " .. itemName .. " (" .. amount .. ")"
        else
            hintLabel.Text = "F  " .. itemName
        end
    else
        pickupHint.Enabled = false
        pickupHint.Adornee = nil
    end
end)

-- Подбор по клавише F
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end
    if input.KeyCode == Config.Loot.PickupKey then
        if nearestLoot then
            Remotes.PickupLoot:FireServer(nearestLoot)
        end
    end
end)
