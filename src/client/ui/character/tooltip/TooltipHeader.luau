local TC = require(script.Parent:WaitForChild("TooltipConstants"))

local TooltipHeader = {}

local TYPE_LABELS = {
    Weapon      = "Weapon",
    Head        = "Head Armor",
    Chest       = "Chest Armor",
    Legs        = "Legs Armor",
    Feet        = "Feet Armor",
    Hands       = "Hands Armor",
    Amulet      = "Amulet",
    Ring        = "Ring",
    Consumable  = "Consumable",
    Resource    = "Resource",
    Misc        = "Miscellaneous",
}

function TooltipHeader.build(parent, itemDef, itemData)
    local headerH = TC.ICON_SIZE + TC.PAD * 2

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, headerH)
    header.BackgroundColor3 = TC.HEADER_BG
    header.BorderSizePixel = 0
    header.LayoutOrder = 1
    header.Parent = parent

    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, TC.CORNER)
    hCorner.Parent = header

    local hPad = Instance.new("UIPadding")
    hPad.PaddingLeft = UDim.new(0, TC.PAD)
    hPad.PaddingRight = UDim.new(0, TC.PAD)
    hPad.PaddingTop = UDim.new(0, TC.PAD)
    hPad.PaddingBottom = UDim.new(0, TC.PAD)
    hPad.Parent = header

    -- Icon
    local hasIcon = itemDef.Icon and itemDef.Icon ~= "" and itemDef.Icon ~= "rbxassetid://0"
    local textX = 0

    if hasIcon then
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, TC.ICON_SIZE, 0, TC.ICON_SIZE)
        icon.Position = UDim2.new(0, 0, 0, 0)
        icon.BackgroundTransparency = 1
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Image = itemDef.Icon
        icon.Parent = header
        textX = TC.ICON_SIZE + 8
    end

    -- LVL badge
    local itemLevel = itemData.ItemLevel or itemDef.ItemLevel or 0
    if itemLevel > 0 then
        local badge = Instance.new("Frame")
        badge.Name = "LvlBadge"
        badge.Size = UDim2.new(0, 42, 0, 18)
        badge.Position = UDim2.new(0, textX, 0, 0)
        badge.BackgroundColor3 = TC.LVL_BG
        badge.BorderSizePixel = 0
        badge.Parent = header

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 4)
        bCorner.Parent = badge

        local bStroke = Instance.new("UIStroke")
        bStroke.Color = TC.LVL_BORDER
        bStroke.Thickness = 1
        bStroke.Parent = badge

        local bLabel = Instance.new("TextLabel")
        bLabel.Size = UDim2.new(1, 0, 1, 0)
        bLabel.BackgroundTransparency = 1
        bLabel.TextColor3 = TC.LVL_BORDER
        bLabel.TextSize = 11
        bLabel.Font = Enum.Font.GothamBold
        bLabel.Text = "LVL " .. tostring(itemLevel)
        bLabel.Parent = badge
    end

    -- Name
    local nameY = itemLevel > 0 and 20 or 0
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -textX, 0, 20)
    nameLabel.Position = UDim2.new(0, textX, 0, nameY)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = TC.NAME_COLOR
    nameLabel.TextSize = 16
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Text = itemData.Name or itemDef.Name or "Unknown"
    nameLabel.Parent = header

    -- Subtitle
    local typeLabel = TYPE_LABELS[itemDef.Type] or itemDef.Type or ""
    local subLabel = Instance.new("TextLabel")
    subLabel.Name = "SubLabel"
    subLabel.Size = UDim2.new(1, -textX, 0, 14)
    subLabel.Position = UDim2.new(0, textX, 0, nameY + 22)
    subLabel.BackgroundTransparency = 1
    subLabel.TextColor3 = TC.SUB_COLOR
    subLabel.TextSize = 12
    subLabel.Font = Enum.Font.Gotham
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.Text = typeLabel
    subLabel.Parent = header

    return header
end

return TooltipHeader