--[[
    BuildingMenu.client.luau
    UI строительства. Открывается клавишей B.
    
    Показывает категории блоков (табы), сетку блоков с иконками и стоимостью.
    При клике — активирует BuildingPlacer.
    Кнопки: режим удаления (X), Castle Heart placement.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local BC = require(script.Parent:WaitForChild("BuildingConstants"))
local BuildingPlacer = require(script.Parent:WaitForChild("BuildingPlacer"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BuildingMenuUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 18
screenGui.Parent = playerGui

-- ═══ Окно ═══
local PAD = BC.WINDOW_PAD
local WINDOW_W = BC.WINDOW_WIDTH

local window = Instance.new("Frame")
window.Name = "BuildWindow"
window.Size = UDim2.new(0, WINDOW_W, 0, 500)  -- высота будет пересчитана
window.Position = UDim2.new(0, 12, 0.5, 0)
window.AnchorPoint = Vector2.new(0, 0.5)
window.BackgroundColor3 = BC.windowBg
window.BorderSizePixel = 0
window.Visible = false
window.ClipsDescendants = true
window.Parent = screenGui

Instance.new("UICorner", window).CornerRadius = UDim.new(0, BC.CORNER_RADIUS)
local winStroke = Instance.new("UIStroke")
winStroke.Color = BC.slotBorder
winStroke.Thickness = 1
winStroke.Parent = window

-- Заголовок
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 0, BC.HEADER_H)
titleLabel.Position = UDim2.new(0, PAD, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = BC.textColor
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "Строительство"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = window

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 4)
closeBtn.BackgroundColor3 = BC.btnRed
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.BorderSizePixel = 0
closeBtn.Parent = window
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, BC.SMALL_RADIUS)

-- ═══ Castle Heart кнопка (сверху, перед табами) ═══
local heartBtnY = BC.HEADER_H + 4

local heartBtn = Instance.new("TextButton")
heartBtn.Size = UDim2.new(1, -PAD * 2, 0, 36)
heartBtn.Position = UDim2.new(0, PAD, 0, heartBtnY)
heartBtn.BackgroundColor3 = BC.heartColor
heartBtn.Text = "Поставить Сердце замка"
heartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
heartBtn.Font = Enum.Font.GothamBold
heartBtn.TextSize = 14
heartBtn.BorderSizePixel = 0
heartBtn.Parent = window
Instance.new("UICorner", heartBtn).CornerRadius = UDim.new(0, BC.SMALL_RADIUS)
local heartStroke = Instance.new("UIStroke")
heartStroke.Color = BC.heartBorder
heartStroke.Thickness = 1
heartStroke.Parent = heartBtn

-- ═══ Табы категорий ═══
local tabsY = heartBtnY + 40 + 4
local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, -PAD * 2, 0, BC.TAB_H)
tabsFrame.Position = UDim2.new(0, PAD, 0, tabsY)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = window

local categories = BC.CATEGORIES
local tabButtons = {}
local activeCategory = categories[1] and categories[1].Id or "Foundation"

local tabWidth = (WINDOW_W - PAD * 2 - (#categories - 1) * 2) / #categories

for i, cat in categories do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, tabWidth, 1, 0)
    btn.Position = UDim2.new(0, (i - 1) * (tabWidth + 2), 0, 0)
    btn.BackgroundColor3 = BC.tabInactive
    btn.Text = cat.Name
    btn.TextColor3 = BC.textColor
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = tabsFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, BC.SMALL_RADIUS)

    tabButtons[cat.Id] = btn

    btn.MouseButton1Click:Connect(function()
        activeCategory = cat.Id
        -- Обновляем UI ниже
        for id, b in tabButtons do
            b.BackgroundColor3 = (id == activeCategory) and BC.tabActive or BC.tabInactive
        end
        -- Перестроить сетку блоков
        buildBlockGrid()
    end)
end

-- ═══ Сетка блоков ═══
local gridY = tabsY + BC.TAB_H + 6
local gridFrame = Instance.new("ScrollingFrame")
gridFrame.Name = "BlockGrid"
gridFrame.Size = UDim2.new(1, -PAD * 2, 1, -(gridY + BC.BUTTON_H + PAD + 6))
gridFrame.Position = UDim2.new(0, PAD, 0, gridY)
gridFrame.BackgroundTransparency = 1
gridFrame.ScrollBarThickness = 4
gridFrame.ScrollBarImageColor3 = BC.slotBorder
gridFrame.BorderSizePixel = 0
gridFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
gridFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
gridFrame.Parent = window

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, BC.SLOT_SIZE, 0, BC.SLOT_SIZE + 20)
gridLayout.CellPadding = UDim2.new(0, BC.PADDING, 0, BC.PADDING)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local blockSlots = {} -- для очистки

function buildBlockGrid()
    for _, slot in blockSlots do
        slot:Destroy()
    end
    blockSlots = {}

    local order = 0
    for typeId, bt in Config.Building.BlockTypes do
        if bt.Category == activeCategory then
            order += 1

            local slot = Instance.new("TextButton")
            slot.Name = typeId
            slot.LayoutOrder = order
            slot.BackgroundColor3 = BC.slotBg
            slot.BorderSizePixel = 0
            slot.Text = ""
            slot.AutoButtonColor = false
            slot.Parent = gridFrame
            Instance.new("UICorner", slot).CornerRadius = UDim.new(0, BC.SMALL_RADIUS)

            local slotStroke = Instance.new("UIStroke")
            slotStroke.Color = BC.slotBorder
            slotStroke.Thickness = 1
            slotStroke.Parent = slot

            -- Иконка (или первая буква)
            if bt.Icon and bt.Icon ~= "rbxassetid://0" and bt.Icon ~= "" then
                local img = Instance.new("ImageLabel")
                img.Size = UDim2.new(0, 40, 0, 40)
                img.Position = UDim2.new(0.5, -20, 0, 2)
                img.BackgroundTransparency = 1
                img.Image = bt.Icon
                img.Parent = slot
            else
                local fallback = Instance.new("TextLabel")
                fallback.Size = UDim2.new(1, 0, 0, BC.SLOT_SIZE - 4)
                fallback.Position = UDim2.new(0, 0, 0, 0)
                fallback.BackgroundTransparency = 1
                fallback.Font = Enum.Font.GothamBold
                fallback.TextSize = 14
                fallback.TextColor3 = BC.textColor
                fallback.Text = string.sub(bt.Name, 1, 3)
                fallback.TextWrapped = true
                fallback.Parent = slot
            end

            -- Название под иконкой
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -4, 0, 18)
            nameLabel.Position = UDim2.new(0, 2, 1, -18)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextSize = 9
            nameLabel.TextColor3 = BC.textDim
            nameLabel.Text = bt.Name
            nameLabel.TextWrapped = true
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.Parent = slot

            -- Hover
            slot.MouseEnter:Connect(function()
                slot.BackgroundColor3 = BC.slotBgHover
            end)
            slot.MouseLeave:Connect(function()
                slot.BackgroundColor3 = BC.slotBg
            end)

            -- Click → start placing
            local capturedTypeId = typeId
            slot.MouseButton1Click:Connect(function()
                BuildingPlacer.startPlacing(capturedTypeId)
            end)

            table.insert(blockSlots, slot)
        end
    end

    -- Обновляем цвет активного таба
    for id, btn in tabButtons do
        btn.BackgroundColor3 = (id == activeCategory) and BC.tabActive or BC.tabInactive
    end
end

-- ═══ Кнопки внизу ═══
local bottomBtnY = -BC.BUTTON_H - 6

local deleteModeBtn = Instance.new("TextButton")
deleteModeBtn.Size = UDim2.new(1, -PAD * 2, 0, BC.BUTTON_H)
deleteModeBtn.Position = UDim2.new(0, PAD, 1, bottomBtnY)
deleteModeBtn.BackgroundColor3 = BC.btnRed
deleteModeBtn.Text = "Режим удаления (X)"
deleteModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
deleteModeBtn.Font = Enum.Font.GothamBold
deleteModeBtn.TextSize = 13
deleteModeBtn.BorderSizePixel = 0
deleteModeBtn.Parent = window
Instance.new("UICorner", deleteModeBtn).CornerRadius = UDim.new(0, BC.SMALL_RADIUS)

-- ═══ События ═══

closeBtn.MouseButton1Click:Connect(function()
    window.Visible = false
    BuildingPlacer.cleanup()
end)

heartBtn.MouseButton1Click:Connect(function()
    -- Если у игрока уже есть замок — не даём ставить повторно
    -- (кнопка уже изменена через BuildingSync, но на всякий случай)
    local info = Remotes.GetCastleHeartInfo:InvokeServer()
    if info then
        -- Уже есть замок — ничего не делаем (или открываем CastleHeartUI)
        return
    end

    -- Запускаем ghost-режим размещения Castle Heart
    BuildingPlacer.startPlacingHeart()

    -- Закрываем меню чтобы не мешало
    window.Visible = false
end)

deleteModeBtn.MouseButton1Click:Connect(function()
    if BuildingPlacer.isDeleteMode() then
        BuildingPlacer.stopDeleteMode()
        deleteModeBtn.Text = "Режим удаления (X)"
        deleteModeBtn.BackgroundColor3 = BC.btnRed
    else
        BuildingPlacer.startDeleteMode()
        deleteModeBtn.Text = "Выход из удаления (X)"
        deleteModeBtn.BackgroundColor3 = BC.btnGreen
    end
end)

-- ═══ Горячие клавиши ═══
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- B — toggle меню
    if input.KeyCode == BC.KEY_TOGGLE_MENU then
        if window.Visible then
            window.Visible = false
            BuildingPlacer.cleanup()
        else
            window.Visible = true
            buildBlockGrid()
        end
        return
    end

    -- X — toggle delete mode
    if input.KeyCode == BC.KEY_DELETE_MODE then
        -- Блокируем X если окно строительства закрыто
        if not window.Visible and not BuildingPlacer.isDeleteMode() then
            return
        end

        if BuildingPlacer.isDeleteMode() then
            BuildingPlacer.stopDeleteMode()
            deleteModeBtn.Text = "Режим удаления (X)"
            deleteModeBtn.BackgroundColor3 = BC.btnRed
        else
            BuildingPlacer.startDeleteMode()
            deleteModeBtn.Text = "Выход из удаления (X)"
            deleteModeBtn.BackgroundColor3 = BC.btnGreen
        end
        return
    end
end)

-- ═══ Обновление кнопки Castle Heart ═══
-- Если у игрока уже есть замок — меняем текст
Remotes.BuildingSync.OnClientEvent:Connect(function(syncData)
    if syncData.OwnerId == player.UserId then
        heartBtn.Text = "Сердце замка (ур. " .. (syncData.HeartLevel or 1) .. ")"
        heartBtn.BackgroundColor3 = BC.tabInactive
    end
end)

-- Инициализация: проверяем есть ли замок
task.spawn(function()
    local info = Remotes.GetCastleHeartInfo:InvokeServer()
    if info then
        heartBtn.Text = "Сердце замка (ур. " .. info.HeartLevel .. ")"
        heartBtn.BackgroundColor3 = BC.tabInactive
    end
end)

-- Начальное построение
buildBlockGrid()