local C = require(script.Parent:WaitForChild("AbilitiesConstants"))
local AbilityCooldowns = require(script.Parent:WaitForChild("AbilityCooldowns"))

local SlotFactory = {}

function SlotFactory.create(parent, key, column, style)
    local posX = C.PADDING + column * (C.SLOT_SIZE + C.PADDING)

    local slot = Instance.new("Frame")
    slot.Name = "Ability_" .. key
    slot.Size = UDim2.new(0, C.SLOT_SIZE, 0, C.SLOT_SIZE)
    slot.Position = UDim2.new(0, posX, 0, 2)
    slot.BackgroundColor3 = style.bg
    slot.BorderSizePixel = 0
    slot.ClipsDescendants = true
    slot.Parent = parent
    Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 4)

    local stroke = Instance.new("UIStroke")
    stroke.Color = style.borderEmpty
    stroke.Thickness = 1
    stroke.Parent = slot

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(1, 0, 1, 0)
    -- icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    -- icon.Size = UDim2.new(1, -6, 1, -6)
    -- icon.Position = UDim2.new(0, 3, 0, 3)
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Image = ""
    icon.Visible = false
    icon.ZIndex = 2
    icon.Parent = slot

    local fallback = Instance.new("TextLabel")
    fallback.Name = "Fallback"
    fallback.BackgroundTransparency = 1
    fallback.Size = UDim2.new(1, 0, 1, 0)
    fallback.Font = Enum.Font.GothamBold
    fallback.TextSize = 10
    fallback.TextColor3 = Color3.fromRGB(150, 150, 150)
    fallback.Text = key
    fallback.Visible = true
    fallback.ZIndex = 2
    fallback.Parent = slot

    local chargeLabel = Instance.new("TextLabel")
    chargeLabel.Name = "ChargeLabel"
    chargeLabel.BackgroundTransparency = 1
    chargeLabel.Size = UDim2.new(0, 20, 0, 14)
    chargeLabel.AnchorPoint = Vector2.new(1, 1)
    chargeLabel.Position = UDim2.new(1, -2, 1, -2)
    chargeLabel.Font = Enum.Font.GothamBold
    chargeLabel.TextSize = 12
    chargeLabel.TextColor3 = C.CHARGE_COLOR_ACTIVE
    chargeLabel.Text = ""
    chargeLabel.Visible = false
    chargeLabel.ZIndex = 5
    chargeLabel.Parent = slot

    local overlay = Instance.new("Frame")
    overlay.Name = "CooldownOverlay"
    overlay.BackgroundColor3 = C.COOLDOWN_COLOR
    overlay.BackgroundTransparency = C.COOLDOWN_TRANSPARENCY
    overlay.BorderSizePixel = 0
    overlay.Size = UDim2.new(1, 0, 0, 0)
    overlay.ZIndex = 3
    overlay.Visible = false
    overlay.Parent = slot

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "TimerLabel"
    timerLabel.BackgroundTransparency = 1
    timerLabel.Size = UDim2.new(1, 0, 1, 0)
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.TextSize = 18
    timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timerLabel.Text = ""
    timerLabel.Visible = false
    timerLabel.ZIndex = 4
    timerLabel.Parent = slot

    local keyLabel = Instance.new("TextLabel")
    keyLabel.Name = "KeyLabel_" .. key
    keyLabel.Size = UDim2.new(0, C.SLOT_SIZE, 0, 14)
    keyLabel.Position = UDim2.new(0, posX, 0, C.SLOT_SIZE + 4)
    keyLabel.BackgroundTransparency = 1
    keyLabel.TextColor3 = C.BIND_COLOR
    keyLabel.TextSize = 11
    keyLabel.Font = Enum.Font.GothamBold
    keyLabel.Text = key
    keyLabel.TextXAlignment = Enum.TextXAlignment.Center
    keyLabel.Parent = parent

    AbilityCooldowns.registerSlot(key, overlay, timerLabel, stroke, style.border, style.borderEmpty)

    return {
        key = key,
        frame = slot,
        icon = icon,
        fallback = fallback,
        stroke = stroke,
        chargeLabel = chargeLabel,
        keyLabel = keyLabel,
        style = style
    }
end

function SlotFactory.setIcon(slotData, iconId, name, style)
    if iconId and iconId ~= "" and iconId ~= "rbxassetid://0" then
        slotData.icon.Image = iconId
        slotData.icon.Visible = true
        slotData.fallback.Visible = false
    else
        slotData.icon.Visible = false
        slotData.fallback.Text = string.sub(name or "?", 1, 4)
        slotData.fallback.Visible = true
    end
    if not AbilityCooldowns.isOnCooldown(slotData.key) then
        slotData.stroke.Color = style.border
    end
end

function SlotFactory.setEmpty(slotData, key, style)
    slotData.icon.Visible = false
    slotData.fallback.Text = key
    slotData.fallback.Visible = true
    if not AbilityCooldowns.isOnCooldown(slotData.key) then
        slotData.stroke.Color = style.borderEmpty
    end
    slotData.chargeLabel.Visible = false
end

function SlotFactory.setCharges(slotData, charges, maxCharges)
    if maxCharges and maxCharges > 1 then
        slotData.chargeLabel.Text = tostring(charges)
        slotData.chargeLabel.Visible = true
        slotData.chargeLabel.TextColor3 = charges > 0 and C.CHARGE_COLOR_ACTIVE or C.CHARGE_COLOR_EMPTY
    else
        slotData.chargeLabel.Visible = false
    end
end

return SlotFactory
