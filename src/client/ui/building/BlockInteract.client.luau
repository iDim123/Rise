--[[
    BlockInteract.client.luau
    Клиентская обработка взаимодействия (F) с функциональными блоками замка.
    
    Сканирует ближайшие блоки с Functional атрибутом,
    показывает подсказку и отправляет InteractBlock на сервер.
    
    Приоритет: CastleHeartUI обрабатывает F для Castle Heart,
    этот скрипт — для остальных функциональных блоков (Door, Chest и т.д.)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local INTERACT_RANGE = 10 -- studs
local SCAN_INTERVAL = 0.15

-- ═══ Состояние ═══
local nearbyBlock = nil -- { part, blockId, functionalType }
local scanTimer = 0

-- ═══ Подсказка Billboard ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BlockInteractUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 12
screenGui.Parent = playerGui

local billboard = Instance.new("BillboardGui")
billboard.Name = "BlockHint"
billboard.Size = UDim2.new(0, 200, 0, 36)
billboard.StudsOffset = Vector3.new(0, 4, 0)
billboard.AlwaysOnTop = true
billboard.Enabled = false
billboard.Parent = screenGui

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, 0, 1, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.fromRGB(220, 190, 80)
hintLabel.TextSize = 16
hintLabel.Font = Enum.Font.GothamBold
hintLabel.Text = "[F] Взаимодействие"
hintLabel.Parent = billboard

-- ═══ Helpers ═══

local function getCharacterRoot()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local FUNCTIONAL_HINTS = {
    Door = "[F] Открыть / Закрыть",
    Chest = "[F] Открыть сундук",
    Sawmill = "[F] Лесопилка",       
    Workbench = "[F] Верстак",
    BloodAltar = "[F] Алтарь крови",
    Coffin = "[F] Гроб",
}

-- ═══ Сканирование ═══

RunService.Heartbeat:Connect(function(dt)
    scanTimer += dt
    if scanTimer < SCAN_INTERVAL then return end
    scanTimer = 0

    local hrp = getCharacterRoot()
    if not hrp then
        billboard.Enabled = false
        nearbyBlock = nil
        return
    end

    local castlesFolder = workspace:FindFirstChild("Castles")
    if not castlesFolder then
        billboard.Enabled = false
        nearbyBlock = nil
        return
    end

    local closest = nil
    local closestDist = math.huge

    for _, folder in castlesFolder:GetChildren() do
        for _, obj in folder:GetChildren() do
            if obj:IsA("BasePart") and obj:GetAttribute("IsStructure") and obj:GetAttribute("BlockId") then
                local typeId = obj:GetAttribute("BlockTypeId")
                if typeId then
                    local bt = Config.Building.BlockTypes[typeId]
                    if bt and bt.Functional and bt.Functional ~= "Chest" then
                        local dist = (hrp.Position - obj.Position).Magnitude
                        local range = (bt.FunctionalData and bt.FunctionalData.InteractRange) or INTERACT_RANGE
                        if dist <= range and dist < closestDist then
                            closestDist = dist
                            closest = {
                                part = obj,
                                blockId = obj:GetAttribute("BlockId"),
                                functionalType = bt.Functional,
                            }
                        end
                    end
                end
            end
        end
    end

    if closest then
        nearbyBlock = closest
        hintLabel.Text = FUNCTIONAL_HINTS[closest.functionalType] or "[F] Взаимодействие"

        -- Привязать billboard к блоку
        if billboard.Adornee ~= closest.part then
            billboard.Adornee = closest.part
            billboard.StudsOffset = Vector3.new(0, closest.part.Size.Y / 2 + 1.5, 0)
        end
        billboard.Enabled = true
    else
        nearbyBlock = nil
        billboard.Enabled = false
    end
end)

-- ═══ Ввод: F ═══

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.F then
        if nearbyBlock and nearbyBlock.blockId then
            Remotes.InteractBlock:FireServer(nearbyBlock.blockId)
        end
    end
end)