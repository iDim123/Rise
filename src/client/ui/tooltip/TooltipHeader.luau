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

    -- Icon справа
    local hasIcon = itemDef.Icon and itemDef.Icon ~= "" and itemDef.Icon ~= "rbxassetid://0"
    local textRightMargin = 0

    if hasIcon then
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, TC.ICON_SIZE, 0, TC.ICON_SIZE)
        icon.Position = UDim2.new(1, -TC.ICON_SIZE, 0, 0)
        icon.BackgroundTransparency = 1
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Image = itemDef.Icon
        icon.Parent = header
        textRightMargin = TC.ICON_SIZE + 8
    end

    -- LVL слева — большая цифра + подпись
    local itemLevel = itemData.ItemLevel or itemDef.ItemLevel or 0
    local textX = 0

    if itemLevel > 0 then
        local lvlWidth = 40

        local lvlNumber = Instance.new("TextLabel")
        lvlNumber.Name = "LvlNumber"
        lvlNumber.Size = UDim2.new(0, lvlWidth, 0, 36)
        lvlNumber.Position = UDim2.new(0, 0, 0, 0)
        lvlNumber.BackgroundTransparency = 1
        lvlNumber.TextColor3 = TC.NAME_COLOR
        lvlNumber.TextSize = 28
        lvlNumber.Font = Enum.Font.GothamBold
        lvlNumber.Text = tostring(itemLevel)
        lvlNumber.TextXAlignment = Enum.TextXAlignment.Center
        lvlNumber.Parent = header

        local lvlLabel = Instance.new("TextLabel")
        lvlLabel.Name = "LvlLabel"
        lvlLabel.Size = UDim2.new(0, lvlWidth, 0, 12)
        lvlLabel.Position = UDim2.new(0, 0, 0, 36)
        lvlLabel.BackgroundTransparency = 1
        lvlLabel.TextColor3 = TC.SUB_COLOR
        lvlLabel.TextSize = 10
        lvlLabel.Font = Enum.Font.GothamBold
        lvlLabel.Text = "LVL"
        lvlLabel.TextXAlignment = Enum.TextXAlignment.Center
        lvlLabel.Parent = header

        textX = lvlWidth + 8
    end

    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -textX - textRightMargin, 0, 20)
    nameLabel.Position = UDim2.new(0, textX, 0, 6)
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
    subLabel.Size = UDim2.new(1, -textX - textRightMargin, 0, 14)
    subLabel.Position = UDim2.new(0, textX, 0, 28)
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