local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local DragManager = require(script.Parent.Parent:WaitForChild("character"):WaitForChild("DragManager"))
local ItemTooltip = require(script.Parent.Parent:WaitForChild("character"):WaitForChild("tooltip"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local ServantEquipPanel = {}

local SLOT_SIZE = 50
local PAD = 4
local SLOT_BG = Color3.fromRGB(50, 50, 65)
local SLOT_FILLED = Color3.fromRGB(60, 60, 80)
local PANEL_BG = Color3.fromRGB(35, 35, 50)

local equipSlotFrames = {}
local unequipCallback = nil
local panelFrame = nil
local currentEquipment = nil

local SLOT_TYPE_MAP = {
    Head = "Head",
    Chest = "Chest",
    Legs = "Legs",
    Feet = "Feet",
    Hands = "Hands",
    Amulet = "Amulet",
    Ring1 = "Ring",
    Ring2 = "Ring",
}

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

    panelFrame = panel

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
        nameLabel.TextSize = 8
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextWrapped = true
        nameLabel.Text = ""
        nameLabel.Visible = false
        nameLabel.Parent = slot

        -- Tooltip
        slot.MouseEnter:Connect(function()
            if currentEquipment then
                local itemData = currentEquipment[slotConfig.Id]
                if itemData and itemData ~= false then
                    ItemTooltip.show(itemData, slot)
                end
            end
        end)

        slot.MouseLeave:Connect(function()
            ItemTooltip.hide()
        end)

        slot.MouseButton2Click:Connect(function()
            ItemTooltip.hide()
            if unequipCallback then
                unequipCallback(slotConfig.Id)
            end
        end)

        equipSlotFrames[slotConfig.Id] = slot
    end

    return panel
end

function ServantEquipPanel.refresh(equipment)
    currentEquipment = equipment
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
    if not panelFrame then return end

    DragManager.registerDropTarget(panelFrame, function(data)
        if not data or not data.item then return end

        local item = data.item
        local targetSlot = nil

        for slotName, expectedType in SLOT_TYPE_MAP do
            if item.Type == expectedType then
                if slotName == "Ring1" or slotName == "Ring2" then
                    if not targetSlot then
                        targetSlot = slotName
                    end
                else
                    targetSlot = slotName
                    break
                end
            elseif item.EquipSlot then
                if item.EquipSlot == slotName then
                    targetSlot = slotName
                    break
                end
                if (slotName == "Ring1" or slotName == "Ring2") and item.EquipSlot == "Ring" then
                    if not targetSlot then
                        targetSlot = slotName
                    end
                end
            end
        end

        if not targetSlot then return end

        Remotes.EquipServantItem:FireServer(servantId, data.slotIndex, targetSlot)
    end)
end

function ServantEquipPanel.unregisterDropTargets()
    if panelFrame then
        DragManager.unregisterDropTarget(panelFrame)
    end
end

return ServantEquipPanel