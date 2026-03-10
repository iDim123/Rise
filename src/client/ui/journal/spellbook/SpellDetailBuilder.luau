local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SpellDetailBuilder = {}

function SpellDetailBuilder.build(parent)
    local elements = {}

    -- Main frame
    local panelFrame = Instance.new("Frame")
    panelFrame.Name = "SpellDetailPanel"
    panelFrame.Size = UDim2.new(0, C.DETAIL_W, 1, 0)
    panelFrame.AnchorPoint = Vector2.new(1, 0)
    panelFrame.Position = UDim2.new(1, 0, 0, 0)
    panelFrame.BackgroundColor3 = C.PANEL_BG
    panelFrame.BackgroundTransparency = 0.15
    panelFrame.BorderSizePixel = 0
    panelFrame.Parent = parent

    Instance.new("UICorner", panelFrame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = C.STROKE_COLOR
    stroke.Thickness = 1
    stroke.Parent = panelFrame

    -- Placeholder
    local placeholderLabel = Instance.new("TextLabel")
    placeholderLabel.Name = "Placeholder"
    placeholderLabel.Size = UDim2.new(1, 0, 1, 0)
    placeholderLabel.BackgroundTransparency = 1
    placeholderLabel.Font = Enum.Font.Gotham
    placeholderLabel.TextSize = 16
    placeholderLabel.TextColor3 = C.TEXT_DIM
    placeholderLabel.Text = "Select spell"
    placeholderLabel.Visible = true
    placeholderLabel.ZIndex = 2
    placeholderLabel.Parent = panelFrame

    -- Content
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "Content"
    contentFrame.Size = UDim2.new(1, 0, 1, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Visible = false
    contentFrame.Parent = panelFrame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 16)
    pad.PaddingBottom = UDim.new(0, 16)
    pad.PaddingLeft = UDim.new(0, 16)
    pad.PaddingRight = UDim.new(0, 16)
    pad.Parent = contentFrame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = contentFrame

    -- Header row
    local headerRow = Instance.new("Frame")
    headerRow.Name = "HeaderRow"
    headerRow.Size = UDim2.new(1, 0, 0, 56)
    headerRow.BackgroundTransparency = 1
    headerRow.LayoutOrder = 1
    headerRow.Parent = contentFrame

    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "SpellIcon"
    iconFrame.Size = UDim2.new(0, 50, 0, 50)
    iconFrame.Position = UDim2.new(0, 0, 0, 3)
    iconFrame.BackgroundColor3 = C.CARD_BG
    iconFrame.BorderSizePixel = 0
    iconFrame.ClipsDescendants = true
    iconFrame.Parent = headerRow
    Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(0, 6)
    local iconStroke = Instance.new("UIStroke")
    iconStroke.Color = C.STROKE_COLOR
    iconStroke.Thickness = 1
    iconStroke.Parent = iconFrame

    local iconImage = Instance.new("ImageLabel")
    iconImage.Name = "Icon"
    iconImage.Size = UDim2.new(1, 0, 1, 0)
    iconImage.BackgroundTransparency = 1
    iconImage.ScaleType = Enum.ScaleType.Stretch
    iconImage.Parent = iconFrame
    Instance.new("UICorner", iconImage).CornerRadius = UDim.new(0, 6)

    local iconFallback = Instance.new("TextLabel")
    iconFallback.Name = "Fallback"
    iconFallback.Size = UDim2.new(1, -4, 1, -4)
    iconFallback.Position = UDim2.new(0, 2, 0, 2)
    iconFallback.BackgroundTransparency = 1
    iconFallback.Font = Enum.Font.GothamBold
    iconFallback.TextSize = 12
    iconFallback.TextColor3 = C.TEXT_COLOR
    iconFallback.TextWrapped = true
    iconFallback.Parent = iconFrame

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "SpellName"
    nameLabel.Size = UDim2.new(1, -60, 0, 24)
    nameLabel.Position = UDim2.new(0, 60, 0, 2)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 18
    nameLabel.TextColor3 = C.TEXT_COLOR
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = headerRow

    local classLabel = Instance.new("TextLabel")
    classLabel.Name = "SpellClass"
    classLabel.Size = UDim2.new(1, -60, 0, 16)
    classLabel.Position = UDim2.new(0, 60, 0, 26)
    classLabel.BackgroundTransparency = 1
    classLabel.Font = Enum.Font.Gotham
    classLabel.TextSize = 16
    classLabel.TextColor3 = C.TEXT_DIM
    classLabel.TextXAlignment = Enum.TextXAlignment.Left
    classLabel.Parent = headerRow

    -- Sep 1
    local sep1 = Instance.new("Frame")
    sep1.Size = UDim2.new(1, 0, 0, 1)
    sep1.BackgroundColor3 = C.SEPARATOR
    sep1.BackgroundTransparency = 0.5
    sep1.BorderSizePixel = 0
    sep1.LayoutOrder = 2
    sep1.Parent = contentFrame

    local castLabel = Instance.new("TextLabel")
    castLabel.Name = "CastTime"
    castLabel.Size = UDim2.new(1, 0, 0, 18)
    castLabel.BackgroundTransparency = 1
    castLabel.Font = Enum.Font.Gotham
    castLabel.TextSize = 16
    castLabel.TextColor3 = C.TEXT_BRIGHT
    castLabel.TextXAlignment = Enum.TextXAlignment.Left
    castLabel.LayoutOrder = 3
    castLabel.Parent = contentFrame

    local cooldownLabel = Instance.new("TextLabel")
    cooldownLabel.Name = "Cooldown"
    cooldownLabel.Size = UDim2.new(1, 0, 0, 18)
    cooldownLabel.BackgroundTransparency = 1
    cooldownLabel.Font = Enum.Font.Gotham
    cooldownLabel.TextSize = 16
    cooldownLabel.TextColor3 = C.TEXT_BRIGHT
    cooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
    cooldownLabel.LayoutOrder = 4
    cooldownLabel.Parent = contentFrame

    -- Sep 2
    local sep2 = Instance.new("Frame")
    sep2.Size = UDim2.new(1, 0, 0, 1)
    sep2.BackgroundColor3 = C.SEPARATOR
    sep2.BackgroundTransparency = 0.5
    sep2.BorderSizePixel = 0
    sep2.LayoutOrder = 5
    sep2.Parent = contentFrame

    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "Description"
    descLabel.Size = UDim2.new(1, 0, 0, 0)
    descLabel.AutomaticSize = Enum.AutomaticSize.Y
    descLabel.BackgroundTransparency = 1
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 15
    descLabel.TextColor3 = C.TEXT_DIM
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextWrapped = true
    descLabel.LayoutOrder = 6
    descLabel.Parent = contentFrame

    -- Sep 3 (before learn/equip section)
    local sep3 = Instance.new("Frame")
    sep3.Name = "Sep3"
    sep3.Size = UDim2.new(1, 0, 0, 1)
    sep3.BackgroundColor3 = C.SEPARATOR
    sep3.BackgroundTransparency = 0.5
    sep3.BorderSizePixel = 0
    sep3.LayoutOrder = 7
    sep3.Visible = false
    sep3.Parent = contentFrame

    elements.panelFrame = panelFrame
    elements.placeholderLabel = placeholderLabel
    elements.contentFrame = contentFrame
    elements.iconFrame = iconFrame
    elements.nameLabel = nameLabel
    elements.classLabel = classLabel
    elements.castLabel = castLabel
    elements.cooldownLabel = cooldownLabel
    elements.descLabel = descLabel
    elements.sep3 = sep3

    return elements
end

return SpellDetailBuilder
