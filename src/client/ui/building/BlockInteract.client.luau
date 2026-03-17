--[[
    BlockInteract.client.luau
    Клиентская обработка:
      - F: взаимодействие с функциональными блоками
      - ПКМ зажатие 1с: разбор блока (dismantle)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local NotifyModule = require(script.Parent.Parent:WaitForChild("NotifyModule"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local INTERACT_RANGE = 10
local DISMANTLE_RANGE = 50

local SCAN_INTERVAL = 0.15
local DISMANTLE_HOLD_TIME = 1.0

-- ═══ Состояние ═══
local nearbyBlock = nil
local scanTimer = 0

-- Dismantle state
local dismantleTarget = nil   -- { part, blockId, isHeart }
local dismantleHolding = false
local dismantleElapsed = 0
local dismantleHighlight = nil

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BlockInteractUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 12
screenGui.Parent = playerGui

-- ═══ Billboard подсказка [F] ═══
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

-- ═══ Dismantle progress bar (Billboard) ═══
local dismantleBillboard = Instance.new("BillboardGui")
dismantleBillboard.Name = "DismantleProgress"
dismantleBillboard.Size = UDim2.new(0, 120, 0, 14)
dismantleBillboard.StudsOffset = Vector3.new(0, 5.5, 0)
dismantleBillboard.AlwaysOnTop = true
dismantleBillboard.Enabled = false
dismantleBillboard.Parent = screenGui

local progressBg = Instance.new("Frame")
progressBg.Size = UDim2.new(1, 0, 1, 0)
progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
progressBg.BorderSizePixel = 0
progressBg.Parent = dismantleBillboard
Instance.new("UICorner", progressBg).CornerRadius = UDim.new(0, 4)

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBg
Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 4)

local progressStroke = Instance.new("UIStroke")
progressStroke.Color = Color3.fromRGB(100, 100, 100)
progressStroke.Thickness = 1
progressStroke.Parent = progressBg

-- ═══ Helpers ═══

local function getCharacterRoot()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local FUNCTIONAL_HINTS = {
    Door = "[F] Открыть / Закрыть",
    Chest = "[F] Открыть сундук",
    Station = "[F] Открыть станцию",
    CraftStation = "[F] Открыть станцию",
    BloodAltar = "[F] Алтарь крови",
    Coffin = "[F] Привязаться к гробу",
}

local INTERACTIVE_TYPES = {
    Door = true,
    Station = true,
    CraftStation = true,
    BloodAltar = true,
    Coffin = true,
}

-- ═══ Highlight для разбора ═══

local function createHighlight()
    if dismantleHighlight then return end
    dismantleHighlight = Instance.new("Highlight")
    dismantleHighlight.FillColor = Color3.fromRGB(255, 60, 60)
    dismantleHighlight.FillTransparency = 0.4
    dismantleHighlight.OutlineColor = Color3.fromRGB(255, 60, 60)
    dismantleHighlight.OutlineTransparency = 0.3
    dismantleHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
    dismantleHighlight.Enabled = false
    dismantleHighlight.Parent = playerGui
end

local function showHighlight(target)
    createHighlight()
    dismantleHighlight.Adornee = target
    dismantleHighlight.Enabled = true
end

local function hideHighlight()
    if dismantleHighlight then
        dismantleHighlight.Adornee = nil
        dismantleHighlight.Enabled = false
    end
end

-- ═══ Raycast для ПКМ ═══

local function getMouseTarget()
    local unitRay = mouse.UnitRay
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = {}
    if player.Character then
        table.insert(filterList, player.Character)
    end
    params.FilterDescendantsInstances = filterList

    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 200, params)
    if not result or not result.Instance then
        return nil
    end

    local hit = result.Instance
    local hrp = getCharacterRoot()
    if not hrp then return nil end

    -- Проверяем блок замка
    if hit:IsA("BasePart") and hit:GetAttribute("IsStructure") and hit:GetAttribute("BlockId") then
        local dist = (hrp.Position - hit.Position).Magnitude
        if dist <= DISMANTLE_RANGE then
            return {
                part = hit,
                blockId = hit:GetAttribute("BlockId"),
                isHeart = false,
            }
        end
    end

    -- Проверяем Castle Heart
    local parent = hit.Parent
    if parent and parent:IsA("Model") and parent:GetAttribute("IsCastleHeart") then
        local primary = parent.PrimaryPart or hit
        local dist = (hrp.Position - primary.Position).Magnitude
        if dist <= DISMANTLE_RANGE then
            return {
                part = parent,
                blockId = "__CASTLE_HEART__",
                isHeart = true,
            }
        end
    end

    return nil
end

-- ═══ Dismantle: начало/отмена ═══

local function startDismantle(target)
    task.spawn(function()
        local ok, err = Remotes.CanDismantleBlock:InvokeServer(target.blockId)
        if not ok then
            NotifyModule.show(err or "Нельзя разобрать", "warning")
            return
        end

        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            return
        end

        dismantleTarget = target
        dismantleHolding = true
        dismantleElapsed = 0
        showHighlight(target.part)
        dismantleBillboard.Adornee = target.isHeart
            and (target.part.PrimaryPart or target.part:FindFirstChildWhichIsA("BasePart"))
            or target.part
        dismantleBillboard.Enabled = true
        progressFill.Size = UDim2.new(0, 0, 1, 0)
    end)
end

local function cancelDismantle()
    dismantleHolding = false
    dismantleElapsed = 0
    dismantleTarget = nil
    hideHighlight()
    dismantleBillboard.Enabled = false
end

-- ═══ Input: ПКМ ═══

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.F then
        if nearbyBlock and nearbyBlock.blockId then
            Remotes.InteractBlock:FireServer(nearbyBlock.blockId)
        end
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        local target = getMouseTarget()
        if target then
            startDismantle(target)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        cancelDismantle()
    end
end)

-- ═══ Сканирование + Dismantle update ═══

RunService.Heartbeat:Connect(function(dt)
    scanTimer += dt

    -- F-подсказка (сканируем реже)
    if scanTimer >= SCAN_INTERVAL then
        scanTimer = 0

        local hrp = getCharacterRoot()
        if not hrp then
            billboard.Enabled = false
            nearbyBlock = nil
        else
            local castlesFolder = workspace:FindFirstChild("Castles")
            if not castlesFolder then
                billboard.Enabled = false
                nearbyBlock = nil
            else
                local closest = nil
                local closestDist = math.huge

                for _, folder in castlesFolder:GetChildren() do
                    for _, obj in folder:GetChildren() do
                        if obj:IsA("BasePart") and obj:GetAttribute("IsStructure") and obj:GetAttribute("BlockId") then
                            local typeId = obj:GetAttribute("BlockTypeId")
                            if typeId then
                                local bt = Config.Building.BlockTypes[typeId]
                                if bt and bt.Functional and INTERACTIVE_TYPES[bt.Functional] then
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
                    if billboard.Adornee ~= closest.part then
                        billboard.Adornee = closest.part
                        billboard.StudsOffset = Vector3.new(0, closest.part.Size.Y / 2 + 1.5, 0)
                    end
                    billboard.Enabled = true
                else
                    nearbyBlock = nil
                    billboard.Enabled = false
                end
            end
        end
    end

    -- Dismantle hold update
    if dismantleHolding and dismantleTarget then
        dismantleElapsed += dt
        local progress = math.clamp(dismantleElapsed / DISMANTLE_HOLD_TIME, 0, 1)
        progressFill.Size = UDim2.new(progress, 0, 1, 0)

        if progress >= 1 then
            -- Разобрать!
            Remotes.DismantleBlock:FireServer(dismantleTarget.blockId)
            cancelDismantle()
        end
    end
end)