local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UC = require(script.Parent:WaitForChild("UIConstants"))
local SlotFactory = require(script.Parent:WaitForChild("SlotFactory"))
local ItemTooltip = require(script.Parent:WaitForChild("tooltip"))

local EquipmentPanel = {}

local equipSlotFrames = {}
local currentEquipment = nil

function EquipmentPanel.build(parent, contentY, unequipRemote)
    local panel = Instance.new("Frame")
    panel.Name = "EquipPanel"
    panel.Size = UDim2.new(0, UC.equipPanelInner, 0, UC.equipPanelHeight)
    panel.Position = UDim2.new(0, UC.windowPadX, 0, contentY)
    panel.BackgroundColor3 = UC.panelBg
    panel.BorderSizePixel = 0
    panel.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = panel

    for i, slotConfig in Config.Equipment.Slots do
        local slot = Instance.new("TextButton")
        slot.Name = "Equip_" .. slotConfig.Id
        slot.Size = UDim2.new(0, UC.slotSize, 0, UC.slotSize)
        slot.Position = UDim2.new(0, UC.padding, 0, UC.padding + (i - 1) * (UC.slotSize + UC.padding))
        slot.BackgroundColor3 = UC.slotBg
        slot.BorderSizePixel = 1
        slot.BorderColor3 = UC.slotBorder
        slot.Text = ""
        slot.Parent = panel

        local sc = Instance.new("UICorner")
        sc.CornerRadius = UDim.new(0, 4)
        sc.Parent = slot

        local label = Instance.new("TextLabel")
        label.Name = "SlotLabel"
        label.Size = UDim2.new(0, 40, 0, UC.slotSize)
        label.Position = UDim2.new(0, UC.padding + UC.slotSize + 6, 0, UC.padding + (i - 1) * (UC.slotSize + UC.padding))
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(150, 150, 170)
        label.TextSize = 10
        label.Font = Enum.Font.Gotham
        label.Text = slotConfig.Name
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = panel

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

        -- Tooltip on hover
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
            unequipRemote:FireServer(slotConfig.Id)
        end)

        equipSlotFrames[slotConfig.Id] = slot
    end

    return panel
end

function EquipmentPanel.refresh(equipmentData)
    currentEquipment = equipmentData
    if not equipmentData then return end
    for slotId, slotFrame in equipSlotFrames do
        local itemData = equipmentData[slotId]
        if itemData == false then itemData = nil end

        local icon = slotFrame:FindFirstChild("Icon")
        local nameLabel = slotFrame:FindFirstChild("NameLabel")

        if itemData then
            if itemData.Icon and itemData.Icon ~= "" and itemData.Icon ~= "rbxassetid://0" then
                icon.Image = itemData.Icon
                icon.Visible = true
                if nameLabel then nameLabel.Visible = false end
            else
                icon.Visible = false
                if nameLabel then
                    nameLabel.Text = itemData.Name
                    nameLabel.Visible = true
                end
            end
            slotFrame.BackgroundColor3 = UC.slotBgFilled
        else
            icon.Visible = false
            if nameLabel then nameLabel.Visible = false end
            slotFrame.BackgroundColor3 = UC.slotBg
        end
    end
end

function EquipmentPanel.getSlotFrames()
    return equipSlotFrames
end

return EquipmentPanel