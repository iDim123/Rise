local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local getInventory = ReplicatedStorage:WaitForChild("GetInventory")
local updateInventory = ReplicatedStorage:WaitForChild("UpdateInventory")
local swapSlots = ReplicatedStorage:WaitForChild("SwapSlots")
local equipItem = ReplicatedStorage:WaitForChild("EquipItem")
local unequipItem = ReplicatedStorage:WaitForChild("UnequipItem")
local setActiveWeapon = ReplicatedStorage:WaitForChild("SetActiveWeapon")

local isOpen = false
local slotFrames = {}
local equipSlotFrames = {}
local dragFrom = nil
local currentData = nil

local rows = Config.Inventory.Rows
local cols = Config.Inventory.Columns
local slotSize = Config.Inventory.SlotSize
local padding = Config.Inventory.Padding

-- ===== MAIN GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CharacterGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- ===== CHARACTER WINDOW =====
local windowWidth = cols * (slotSize + padding) + padding + 200 -- +200 для экипировки
local windowHeight = 40 + 220 + rows * (slotSize + padding) + padding + 40
local mainFrame = Instance.new("Frame")
mainFrame.Name = "CharacterWindow"
mainFrame.Size = UDim2.new(0, windowWidth, 0, windowHeight)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

-- Заголовок
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundTransparency = 1
title.Text = "Персонаж"
title.TextColor3 = Color3.fromRGB(220, 220, 220)
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- ===== TABS =====
local tabs = { "Equipment", "Crafting", "Blood Pool", "Attributes" }
local tabNames = { Equipment = "Equipment", Crafting = "Crafting", ["Blood Pool"] = "Blood Pool", Attributes = "Attributes" }
local activeTab = "Equipment"
local tabButtons = {}

for i, tab in tabs do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 0, 25)
    btn.Position = UDim2.new(0, 5 + (i - 1) * 105, 0, 35)
    btn.BackgroundColor3 = tab == activeTab and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(50, 50, 70)
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Text = tab
    btn.Parent = mainFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    tabButtons[tab] = btn
end

-- ===== EQUIPMENT PANEL (left side) =====
local equipPanel = Instance.new("Frame")
equipPanel.Name = "EquipPanel"
equipPanel.Size = UDim2.new(0, 90, 0, 210)
equipPanel.Position = UDim2.new(0, 10, 0, 70)
equipPanel.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
equipPanel.BorderSizePixel = 0
equipPanel.Parent = mainFrame

local equipCorner = Instance.new("UICorner")
equipCorner.CornerRadius = UDim.new(0, 6)
equipCorner.Parent = equipPanel

for i, slotConfig in Config.Equipment.Slots do
    local slot = Instance.new("TextButton")
    slot.Name = "Equip_" .. slotConfig.Id
    slot.Size = UDim2.new(0, slotSize, 0, slotSize)
    slot.Position = UDim2.new(0, 5, 0, 5 + (i - 1) * (slotSize + padding))
    slot.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    slot.BorderSizePixel = 1
    slot.BorderColor3 = Color3.fromRGB(80, 80, 100)
    slot.Text = ""
    slot.Parent = equipPanel

    local slotCorner = Instance.new("UICorner")
    slotCorner.CornerRadius = UDim.new(0, 4)
    slotCorner.Parent = slot

    -- Лейбл
    local label = Instance.new("TextLabel")
    label.Name = "SlotLabel"
    label.Size = UDim2.new(0, 40, 0, slotSize)
    label.Position = UDim2.new(0, slotSize + 8, 0, 5 + (i - 1) * (slotSize + padding))
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(150, 150, 170)
    label.TextSize = 10
    label.Font = Enum.Font.Gotham
    label.Text = slotConfig.Name
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = equipPanel

    -- Иконка
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0.8, 0, 0.8, 0)
    icon.Position = UDim2.new(0.1, 0, 0.1, 0)
    icon.BackgroundTransparency = 1
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Image = ""
    icon.Visible = false
    icon.Parent = slot

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -4, 0.6, 0)
    nameLabel.Position = UDim2.new(0, 2, 0.05, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    nameLabel.TextSize = 9
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextWrapped = true
    nameLabel.Text = ""
    nameLabel.Visible = false
    nameLabel.Parent = slot

    -- Клик — снять экипировку
    slot.MouseButton1Click:Connect(function()
        unequipItem:FireServer(slotConfig.Id)
    end)

    equipSlotFrames[slotConfig.Id] = slot
end

-- ===== CHARACTER NAME (center) =====
local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(0, 200, 0, 30)
nameLabel.Position = UDim2.new(0, 105, 0, 140)
nameLabel.BackgroundTransparency = 1
nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLabel.TextSize = 22
nameLabel.Font = Enum.Font.GothamBold
nameLabel.Text = player.Name
nameLabel.Parent = mainFrame

-- ===== INVENTORY GRID =====
local invStartY = 290

for row = 0, rows - 1 do
    for col = 0, cols - 1 do
        local index = row * cols + col + 1

        local slot = Instance.new("TextButton")
        slot.Name = "Slot_" .. index
        slot.Size = UDim2.new(0, slotSize, 0, slotSize)
        slot.Position = UDim2.new(0, padding + col * (slotSize + padding), 0, invStartY + row * (slotSize + padding))
        slot.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        slot.BorderSizePixel = 1
        slot.BorderColor3 = Color3.fromRGB(80, 80, 100)
        slot.Text = ""
        slot.Parent = mainFrame

        local slotCorner = Instance.new("UICorner")
        slotCorner.CornerRadius = UDim.new(0, 4)
        slotCorner.Parent = slot

        -- Номер ActionBar (первая строка)
        if row == 0 then
            local numLabel = Instance.new("TextLabel")
            numLabel.Name = "ActionBarNum"
            numLabel.Size = UDim2.new(0, 15, 0, 12)
            numLabel.Position = UDim2.new(0, 2, 1, 2)
            numLabel.BackgroundTransparency = 1
            numLabel.TextColor3 = Color3.fromRGB(180, 180, 100)
            numLabel.TextSize = 11
            numLabel.Font = Enum.Font.GothamBold
            numLabel.Text = tostring(col + 1)
            numLabel.Parent = slot
        end

        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0.8, 0, 0.8, 0)
        icon.Position = UDim2.new(0.1, 0, 0.1, 0)
        icon.BackgroundTransparency = 1
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Image = ""
        icon.Visible = false
        icon.Parent = slot

        local itemName = Instance.new("TextLabel")
        itemName.Name = "NameLabel"
        itemName.Size = UDim2.new(1, -4, 0.6, 0)
        itemName.Position = UDim2.new(0, 2, 0.05, 0)
        itemName.BackgroundTransparency = 1
        itemName.TextColor3 = Color3.fromRGB(200, 200, 200)
        itemName.TextSize = 9
        itemName.Font = Enum.Font.Gotham
        itemName.TextWrapped = true
        itemName.Text = ""
        itemName.Visible = false
        itemName.Parent = slot

        local amountLabel = Instance.new("TextLabel")
        amountLabel.Name = "Amount"
        amountLabel.Size = UDim2.new(0, 20, 0, 16)
        amountLabel.Position = UDim2.new(1, -22, 1, -18)
        amountLabel.BackgroundTransparency = 1
        amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        amountLabel.TextSize = 12
        amountLabel.Font = Enum.Font.GothamBold
        amountLabel.Text = ""
        amountLabel.Visible = false
        amountLabel.Parent = slot

        -- Рамка активного оружия
        local activeFrame = Instance.new("Frame")
        activeFrame.Name = "ActiveFrame"
        activeFrame.Size = UDim2.new(1, 4, 1, 4)
        activeFrame.Position = UDim2.new(0, -2, 0, -2)
        activeFrame.BackgroundTransparency = 1
        activeFrame.BorderSizePixel = 2
        activeFrame.BorderColor3 = Color3.fromRGB(255, 200, 50)
        activeFrame.Visible = false
        activeFrame.Parent = slot

        -- Drag & Drop
        slot.MouseButton1Down:Connect(function()
            dragFrom = index
            slot.BackgroundColor3 = Color3.fromRGB(80, 80, 110)
        end)

        slot.MouseButton1Up:Connect(function()
            if dragFrom and dragFrom ~= index then
                swapSlots:FireServer(dragFrom, index)
            elseif dragFrom and dragFrom == index then
                -- Одиночный клик — экипируем если это броня
                if currentData then
                    local item = currentData.slots[index]
                    if item and item ~= false and item.EquipSlot then
                        equipItem:FireServer(index)
                    end
                end
            end
            dragFrom = nil
            slot.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        end)

        slot.MouseLeave:Connect(function()
            if not dragFrom or dragFrom ~= index then
                slot.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
            end
        end)

        slot.MouseEnter:Connect(function()
            if dragFrom then
                slot.BackgroundColor3 = Color3.fromRGB(70, 70, 95)
            end
        end)

        slotFrames[index] = slot
    end
end

-- ===== SORT BUTTON =====
local sortBtn = Instance.new("TextButton")
sortBtn.Size = UDim2.new(0, 60, 0, 25)
sortBtn.Position = UDim2.new(0.5, -30, 1, -30)
sortBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 85)
sortBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
sortBtn.TextSize = 12
sortBtn.Font = Enum.Font.GothamBold
sortBtn.Text = "Sort"
sortBtn.Parent = mainFrame

local sortCorner = Instance.new("UICorner")
sortCorner.CornerRadius = UDim.new(0, 4)
sortCorner.Parent = sortBtn

-- ===== ACTION BAR (always visible) =====
local actionBarGui = Instance.new("ScreenGui")
actionBarGui.Name = "ActionBarGui"
actionBarGui.ResetOnSpawn = false
actionBarGui.Parent = playerGui

local actionBarFrame = Instance.new("Frame")
actionBarFrame.Name = "ActionBar"
actionBarFrame.Size = UDim2.new(0, cols * (slotSize + padding) + padding, 0, slotSize + 20)
actionBarFrame.AnchorPoint = Vector2.new(0.5, 1)
actionBarFrame.Position = UDim2.new(0.5, 0, 1, -10)
actionBarFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
actionBarFrame.BackgroundTransparency = 0.3
actionBarFrame.BorderSizePixel = 0
actionBarFrame.Parent = actionBarGui

local abCorner = Instance.new("UICorner")
abCorner.CornerRadius = UDim.new(0, 6)
abCorner.Parent = actionBarFrame

local actionBarSlots = {}

for col = 0, cols - 1 do
    local index = col + 1

    local slot = Instance.new("TextButton")
    slot.Name = "AB_" .. index
    slot.Size = UDim2.new(0, slotSize, 0, slotSize)
    slot.Position = UDim2.new(0, padding + col * (slotSize + padding), 0, 2)
    slot.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    slot.BorderSizePixel = 1
    slot.BorderColor3 = Color3.fromRGB(80, 80, 100)
    slot.Text = ""
    slot.Parent = actionBarFrame

    local slotCorner = Instance.new("UICorner")
    slotCorner.CornerRadius = UDim.new(0, 4)
    slotCorner.Parent = slot

    local numLabel = Instance.new("TextLabel")
    numLabel.Size = UDim2.new(0, 15, 0, 12)
    numLabel.Position = UDim2.new(0, 2, 1, 2)
    numLabel.BackgroundTransparency = 1
    numLabel.TextColor3 = Color3.fromRGB(180, 180, 100)
    numLabel.TextSize = 11
    numLabel.Font = Enum.Font.GothamBold
    numLabel.Text = tostring(index)
    numLabel.Parent = slot

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0.8, 0, 0.8, 0)
    icon.Position = UDim2.new(0.1, 0, 0.1, 0)
    icon.BackgroundTransparency = 1
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Image = ""
    icon.Visible = false
    icon.Parent = slot

    local itemName = Instance.new("TextLabel")
    itemName.Name = "NameLabel"
    itemName.Size = UDim2.new(1, -4, 0.6, 0)
    itemName.Position = UDim2.new(0, 2, 0.05, 0)
    itemName.BackgroundTransparency = 1
    itemName.TextColor3 = Color3.fromRGB(200, 200, 200)
    itemName.TextSize = 9
    itemName.Font = Enum.Font.Gotham
    itemName.TextWrapped = true
    itemName.Text = ""
    itemName.Visible = false
    itemName.Parent = slot

    local amountLabel = Instance.new("TextLabel")
    amountLabel.Name = "Amount"
    amountLabel.Size = UDim2.new(0, 20, 0, 16)
    amountLabel.Position = UDim2.new(1, -22, 1, -18)
    amountLabel.BackgroundTransparency = 1
    amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    amountLabel.TextSize = 12
    amountLabel.Font = Enum.Font.GothamBold
    amountLabel.Text = ""
    amountLabel.Visible = false
    amountLabel.Parent = slot

    local activeFrame = Instance.new("Frame")
    activeFrame.Name = "ActiveFrame"
    activeFrame.Size = UDim2.new(1, 4, 1, 4)
    activeFrame.Position = UDim2.new(0, -2, 0, -2)
    activeFrame.BackgroundTransparency = 1
    activeFrame.BorderSizePixel = 2
    activeFrame.BorderColor3 = Color3.fromRGB(255, 200, 50)
    activeFrame.Visible = false
    activeFrame.Parent = slot

    slot.MouseButton1Click:Connect(function()
        setActiveWeapon:FireServer(index)
    end)

    actionBarSlots[index] = slot
end

-- ===== REFRESH FUNCTIONS =====
local function updateSlot(slotFrame, itemData, activeWeaponSlot, slotIndex)
    local icon = slotFrame:FindFirstChild("Icon")
    local nameLabel = slotFrame:FindFirstChild("NameLabel")
    local amountLabel = slotFrame:FindFirstChild("Amount")
    local activeFrame = slotFrame:FindFirstChild("ActiveFrame")

    if itemData and itemData ~= false then
        if itemData.Icon and itemData.Icon ~= "" and itemData.Icon ~= "rbxassetid://0" then
            icon.Image = itemData.Icon
            icon.Visible = true
            nameLabel.Visible = false
        else
            icon.Visible = false
            nameLabel.Text = itemData.Name
            nameLabel.Visible = true
        end

        if itemData.Amount and itemData.Amount > 1 then
            amountLabel.Text = tostring(itemData.Amount)
            amountLabel.Visible = true
        else
            amountLabel.Visible = false
        end

        slotFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    else
        icon.Visible = false
        nameLabel.Visible = false
        amountLabel.Visible = false
        slotFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    end

    if activeFrame then
        activeFrame.Visible = (activeWeaponSlot ~= nil and activeWeaponSlot == slotIndex)
    end
end

local function refreshUI(data)
    if not data then return end
    currentData = data

    -- Инвентарь
    for i, slotFrame in slotFrames do
        local itemData = data.slots[i]
        if itemData == false then itemData = nil end
        updateSlot(slotFrame, itemData, data.activeWeaponSlot, i)
    end

    -- ActionBar (первая строка инвентаря)
    for i, abSlot in actionBarSlots do
        local itemData = data.slots[i]
        if itemData == false then itemData = nil end
        updateSlot(abSlot, itemData, data.activeWeaponSlot, i)
    end

    -- Экипировка
    for slotId, slotFrame in equipSlotFrames do
        local itemData = data.equipment[slotId]
        if itemData == false then itemData = nil end

        local icon = slotFrame:FindFirstChild("Icon")
        local nameLabel = slotFrame:FindFirstChild("NameLabel")

        if itemData then
            if itemData.Icon and itemData.Icon ~= "" and itemData.Icon ~= "rbxassetid://0" then
                icon.Image = itemData.Icon
                icon.Visible = true
                nameLabel.Visible = false
            else
                icon.Visible = false
                nameLabel.Text = itemData.Name
                nameLabel.Visible = true
            end
            slotFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        else
            icon.Visible = false
            nameLabel.Visible = false
            slotFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        end
    end
end

-- ===== HOTKEYS =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- C — открыть/закрыть окно персонажа
    if input.KeyCode == Enum.KeyCode.C then
        isOpen = not isOpen
        mainFrame.Visible = isOpen
        if isOpen then
            local data = getInventory:InvokeServer()
            refreshUI(data)
        end
    end

    -- 1-8 — активировать оружие из ActionBar
    local keyNumber = nil
    if input.KeyCode == Enum.KeyCode.One then keyNumber = 1
    elseif input.KeyCode == Enum.KeyCode.Two then keyNumber = 2
    elseif input.KeyCode == Enum.KeyCode.Three then keyNumber = 3
    elseif input.KeyCode == Enum.KeyCode.Four then keyNumber = 4
    elseif input.KeyCode == Enum.KeyCode.Five then keyNumber = 5
    elseif input.KeyCode == Enum.KeyCode.Six then keyNumber = 6
    elseif input.KeyCode == Enum.KeyCode.Seven then keyNumber = 7
    elseif input.KeyCode == Enum.KeyCode.Eight then keyNumber = 8
    end

    if keyNumber then
        setActiveWeapon:FireServer(keyNumber)
    end
end)

-- Сервер прислал обновление
updateInventory.OnClientEvent:Connect(function(data)
    refreshUI(data)
end)