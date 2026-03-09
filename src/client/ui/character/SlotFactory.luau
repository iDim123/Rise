local UC = require(script.Parent:WaitForChild("UIConstants"))

local SlotFactory = {}

function SlotFactory.createSlot(parent, name, posX, posY)
    local slot = Instance.new("TextButton")
    slot.Name = name
    slot.Size = UDim2.new(0, UC.slotSize, 0, UC.slotSize)
    slot.Position = UDim2.new(0, posX, 0, posY)
    slot.BackgroundColor3 = UC.slotBg
    slot.BorderSizePixel = 1
    slot.BorderColor3 = UC.slotBorder
    slot.Text = ""
    slot.AutoButtonColor = false -- <<< ДОБАВИТЬ
    slot.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = slot

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, 0, 1, 0)
    -- icon.Position = UDim2.new(0.1, 0, 0.1, 0)
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
    activeFrame.Size = UDim2.new(1, 0, 1, 0)
    activeFrame.BackgroundTransparency = 1
    activeFrame.BorderSizePixel = 0
    activeFrame.Visible = false
    activeFrame.Parent = slot

    local activeStroke = Instance.new("UIStroke")
    activeStroke.Color = UC.activeStrokeColor
    activeStroke.Thickness = 2
    activeStroke.Parent = activeFrame

    local activeCorner = Instance.new("UICorner")
    activeCorner.CornerRadius = UDim.new(0, 4)
    activeCorner.Parent = activeFrame

    -- Cooldown overlay (затемнение)
    local cooldownOverlay = Instance.new("Frame")
    cooldownOverlay.Name = "CooldownOverlay"
    cooldownOverlay.Size = UDim2.new(1, 0, 1, 0)
    cooldownOverlay.Position = UDim2.new(0, 0, 0, 0)
    cooldownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    cooldownOverlay.BackgroundTransparency = 0.35
    cooldownOverlay.BorderSizePixel = 0
    cooldownOverlay.ZIndex = slot.ZIndex + 3
    cooldownOverlay.Visible = false
    cooldownOverlay.Parent = slot

    local overlayCorner = Instance.new("UICorner")
    overlayCorner.CornerRadius = UDim.new(0, 4)
    overlayCorner.Parent = cooldownOverlay

    -- Cooldown text (секунды по центру)
    local cooldownText = Instance.new("TextLabel")
    cooldownText.Name = "CooldownText"
    cooldownText.Size = UDim2.new(1, 0, 1, 0)
    cooldownText.Position = UDim2.new(0, 0, 0, 0)
    cooldownText.BackgroundTransparency = 1
    cooldownText.TextColor3 = Color3.fromRGB(255, 255, 255)
    cooldownText.TextSize = 20
    cooldownText.Font = Enum.Font.GothamBold
    cooldownText.Text = ""
    cooldownText.ZIndex = slot.ZIndex + 4
    cooldownText.Visible = false
    cooldownText.Parent = slot

    local textStroke = Instance.new("UIStroke")
    textStroke.Color = Color3.fromRGB(0, 0, 0)
    textStroke.Thickness = 2
    textStroke.Parent = cooldownText

    return slot
end

function SlotFactory.updateSlot(slotFrame, itemData, activeWeaponSlot, slotIndex)
    local icon = slotFrame:FindFirstChild("Icon")
    local nameLabel = slotFrame:FindFirstChild("NameLabel")
    local amountLabel = slotFrame:FindFirstChild("Amount")
    local activeFrame = slotFrame:FindFirstChild("ActiveFrame")

    if itemData and itemData ~= false then
        if itemData.Icon and itemData.Icon ~= "" and itemData.Icon ~= "rbxassetid://0" then
            icon.Image = itemData.Icon
            icon.Visible = true
            if nameLabel then
                nameLabel.Visible = false
            end
        else
            icon.Visible = false
            if nameLabel then
                nameLabel.Text = itemData.Name
                nameLabel.Visible = true
            end
        end

        if amountLabel then
            if itemData.Amount and itemData.Amount > 1 then
                amountLabel.Text = tostring(itemData.Amount)
                amountLabel.Visible = true
            else
                amountLabel.Visible = false
            end
        end

        slotFrame.BackgroundColor3 = UC.slotBgFilled
    else
        icon.Visible = false
        if nameLabel then
            nameLabel.Visible = false
        end
        if amountLabel then
            amountLabel.Visible = false
        end
        slotFrame.BackgroundColor3 = UC.slotBg
    end

    if activeFrame then
        activeFrame.Visible = (activeWeaponSlot ~= nil and activeWeaponSlot == slotIndex)
    end
end

return SlotFactory
