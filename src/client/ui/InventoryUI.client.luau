local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local getInventory = ReplicatedStorage:WaitForChild("GetInventory")
local updateInventory = ReplicatedStorage:WaitForChild("UpdateInventory")
local swapSlots = ReplicatedStorage:WaitForChild("SwapSlots")

local rows = Config.Inventory.Rows
local cols = Config.Inventory.Columns
local slotSize = Config.Inventory.SlotSize
local padding = Config.Inventory.Padding

local isOpen = false
local slotFrames = {}
local dragFrom = nil

-- ===== Создаём UI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Главный фрейм
local totalWidth = cols * (slotSize + padding) + padding
local totalHeight = rows * (slotSize + padding) + padding + 30 -- +30 для заголовка

local mainFrame = Instance.new("Frame")
mainFrame.Name = "InventoryFrame"
mainFrame.Size = UDim2.new(0, totalWidth, 0, totalHeight)
mainFrame.Position = UDim2.new(0, 10, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Заголовок
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Inventory"
title.TextColor3 = Color3.fromRGB(220, 220, 220)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- Создаём слоты
for row = 0, rows - 1 do
    for col = 0, cols - 1 do
        local index = row * cols + col + 1

        local slot = Instance.new("TextButton")
        slot.Name = "Slot_" .. index
        slot.Size = UDim2.new(0, slotSize, 0, slotSize)
        slot.Position = UDim2.new(0, padding + col * (slotSize + padding), 0, 30 + padding + row * (slotSize + padding))
        slot.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        slot.BorderSizePixel = 1
        slot.BorderColor3 = Color3.fromRGB(80, 80, 100)
        slot.Text = ""
        slot.Parent = mainFrame

        local slotCorner = Instance.new("UICorner")
        slotCorner.CornerRadius = UDim.new(0, 4)
        slotCorner.Parent = slot

        -- Иконка предмета
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0.8, 0, 0.8, 0)
        icon.Position = UDim2.new(0.1, 0, 0.1, 0)
        icon.BackgroundTransparency = 1
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Image = ""
        icon.Visible = false
        icon.Parent = slot

        -- Название (если нет иконки)
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(1, -4, 0.6, 0)
        nameLabel.Position = UDim2.new(0, 2, 0.05, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        nameLabel.TextSize = 10
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextWrapped = true
        nameLabel.Text = ""
        nameLabel.Visible = false
        nameLabel.Parent = slot

        -- Количество
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

        -- Drag & Drop
        slot.MouseButton1Down:Connect(function()
            dragFrom = index
            slot.BackgroundColor3 = Color3.fromRGB(80, 80, 110)
        end)

        slot.MouseButton1Up:Connect(function()
            if dragFrom and dragFrom ~= index then
                swapSlots:FireServer(dragFrom, index)
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

-- ===== Обновление UI =====
local function refreshInventory(slots)
    for i, slotFrame in slotFrames do
        local itemData = slots[i]
        if itemData == false then itemData = nil end

        local icon = slotFrame:FindFirstChild("Icon")
        local nameLabel = slotFrame:FindFirstChild("NameLabel")
        local amountLabel = slotFrame:FindFirstChild("Amount")

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
    end
end

-- ===== Открытие / закрытие по клавише I =====
local function toggleInventory()
    isOpen = not isOpen
    mainFrame.Visible = isOpen

    if isOpen then
        local slots = getInventory:InvokeServer()
        refreshInventory(slots)
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.C then
        toggleInventory()
    end
end)

-- Сервер прислал обновление
updateInventory.OnClientEvent:Connect(function(slots)
    if isOpen then
        refreshInventory(slots)
    end
end)