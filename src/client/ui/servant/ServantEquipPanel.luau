local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local DragManager = require(script.Parent:WaitForChild("DragManager"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local ServantEquipPanel = {}

local SLOT_SIZE = 50
local PAD = 4
local SLOT_BG = Color3.fromRGB(50, 50, 65)
local SLOT_FILLED = Color3.fromRGB(60, 60, 80)
local PANEL_BG = Color3.fromRGB(35, 35, 50)

local equipSlotFrames = {}
local unequipCallback = nil

-- Маппинг слотов слуги → допустимый тип предмета
local SLOT_TYPE_MAP = {
    Head = "HeadArmor",
    Chest = "ChestArmor",
    Legs = "LegsArmor",
    Feet = "FeetArmor",
    Hands = "HandsArmor",
    Amulet = "Amulet",
    Ring1 = "Ring",
    Ring2 = "Ring",
}

local function matchesSlot(item, slotName)
    local expectedType = SLOT_TYPE_MAP[slotName]
    if not expectedType then return false end

    -- Проверяем по Type предмета
    if item.Type == expectedType then return true end

    -- Проверяем по EquipSlot (для Ring1/Ring2 EquipSlot может быть "Ring")
    if item.EquipSlot then
        if item.EquipSlot == slotName then return true end
        -- Ring1 и Ring2 принимают предметы с EquipSlot = "Ring"
        if (slotName == "Ring1" or slotName == "Ring2") and item.EquipSlot == "Ring" then
            return true
        end
    end

    return false
end

function ServantEquipPanel.build(parent, x, y, w, h)
    local panel = Instance.new("Frame")
    panel.Name = "ServantEquipPanel"
    panel.Size = UDim2.new(0, w, 0, h)
    panel.Position = UDim2.new(0, x, 0, y)
    panel.BackgroundColor3 = PANEL_BG
    panel.BorderSizePixel = 0
    panel.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = panel

    local slots = Config.Servants.EquipmentSlots
    for _, slotConfig in slots do
        local col = slotConfig.Col
        local row = slotConfig.Row

        local posX = PAD + (col - 1) * (SLOT_SIZE + 40 + PAD)
        local posY = PAD + (row - 1) * (SLOT_SIZE + PAD)

        local slot = Instance.new("TextButton")
        slot.Name = "ServEquip_" .. slotConfig.Id
        slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
        slot.Position = UDim2.new(0, posX, 0, posY)
        slot.BackgroundColor3 = SLOT_BG
        slot.BorderSizePixel = 0
        slot.Text = ""
        slot.AutoButtonColor = false
        slot.Parent = panel

        local slotCorner = Instance.new("UICorner")
        slotCorner.CornerRadius = UDim.new(0, 4)
        slotCorner.Parent = slot

        local slotStroke = Instance.new("UIStroke")
        slotStroke.Color = Color3.fromRGB(80, 80, 100)
        slotStroke.Thickness = 1
        slotStroke.Parent = slot

        -- Slot label
        local label = Instance.new("TextLabel")
        label.Name = "SlotLabel"
        label.Size = UDim2.new(0, 40, 0, SLOT_SIZE)
        label.Position = UDim2.new(0, SLOT_SIZE + 2, 0, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(140, 140, 160)
        label.TextSize = 11
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = slotConfig.Name
        label.Parent = slot

        -- Icon
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0.8, 0, 0.8, 0)
        icon.Position = UDim2.new(0.1, 0, 0.1, 0)
        icon.BackgroundTransparency = 1
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Image = ""
        icon.Visible = false
        icon.Parent = slot

        -- Name label
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(1, -4, 0.6, 0)
        nameLabel.Position = UDim2.new(0, 2, 0.05, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        nameLabel.TextSize = 8
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextWrapped = true
        nameLabel.Text = ""
        nameLabel.Visible = false
        nameLabel.Parent = slot

        -- Right-click to unequip
        slot.MouseButton2Click:Connect(function()
            if unequipCallback then
                unequipCallback(slotConfig.Id)
            end
        end)

        equipSlotFrames[slotConfig.Id] = slot
    end

    return panel
end

function ServantEquipPanel.refresh(equipment)
    for slotId, slot in equipSlotFrames do
        local itemData = equipment and equipment[slotId]
        local icon = slot:FindFirstChild("Icon")
        local nameLabel = slot:FindFirstChild("NameLabel")

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
            slot.BackgroundColor3 = SLOT_FILLED
        else
            icon.Visible = false
            nameLabel.Visible = false
            slot.BackgroundColor3 = SLOT_BG
        end
    end
end

function ServantEquipPanel.onUnequip(callback)
    unequipCallback = callback
end

function ServantEquipPanel.getSlotFrames()
    return equipSlotFrames
end

function ServantEquipPanel.registerDropTargets(servantId)
    for slotName, slotFrame in equipSlotFrames do
        DragManager.registerDropTarget(slotFrame, function(data)
            if not data or not data.item then return end

            if not matchesSlot(data.item, slotName) then
                return
            end

            Remotes.EquipServantItem:FireServer(servantId, data.slotIndex, slotName)
        end)
    end
end

function ServantEquipPanel.unregisterDropTargets()
    for _, slotFrame in equipSlotFrames do
        DragManager.unregisterDropTarget(slotFrame)
    end
end

return ServantEquipPanel