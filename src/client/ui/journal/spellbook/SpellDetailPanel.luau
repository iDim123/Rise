local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SpellDetailPanel = {}

local panelFrame = nil
local iconFrame, nameLabel, classLabel, castLabel, cooldownLabel, descLabel
local equipButton
local onEquipCallback = nil

function SpellDetailPanel.build(parent)
    panelFrame = Instance.new("Frame")
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

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 16)
    pad.PaddingBottom = UDim.new(0, 16)
    pad.PaddingLeft = UDim.new(0, 16)
    pad.PaddingRight = UDim.new(0, 16)
    pad.Parent = panelFrame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = panelFrame

    -- Header row: Icon + Name/Class
    local headerRow = Instance.new("Frame")
    headerRow.Name = "HeaderRow"
    headerRow.Size = UDim2.new(1, 0, 0, 56)
    headerRow.BackgroundTransparency = 1
    headerRow.LayoutOrder = 1
    headerRow.Parent = panelFrame

    iconFrame = Instance.new("Frame")
    iconFrame.Name = "SpellIcon"
    iconFrame.Size = UDim2.new(0, 50, 0, 50)
    iconFrame.Position = UDim2.new(0, 0, 0, 3)
    iconFrame.BackgroundColor3 = C.CARD_BG
    iconFrame.BorderSizePixel = 0
    iconFrame.Parent = headerRow

    Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(0, 6)

    local iconStroke = Instance.new("UIStroke")
    iconStroke.Color = C.STROKE_COLOR
    iconStroke.Thickness = 1
    iconStroke.Parent = iconFrame

    local iconImage = Instance.new("ImageLabel")
    iconImage.Name = "Icon"
    iconImage.Size = UDim2.new(0.8, 0, 0.8, 0)
    iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
    iconImage.Position = UDim2.new(0.5, 0, 0.5, 0)
    iconImage.BackgroundTransparency = 1
    iconImage.ScaleType = Enum.ScaleType.Fit
    iconImage.Parent = iconFrame

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

    nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "SpellName"
    nameLabel.Size = UDim2.new(1, -60, 0, 24)
    nameLabel.Position = UDim2.new(0, 60, 0, 2)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 18
    nameLabel.TextColor3 = C.TEXT_COLOR
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = headerRow

    classLabel = Instance.new("TextLabel")
    classLabel.Name = "SpellClass"
    classLabel.Size = UDim2.new(1, -60, 0, 16)
    classLabel.Position = UDim2.new(0, 60, 0, 26)
    classLabel.BackgroundTransparency = 1
    classLabel.Font = Enum.Font.Gotham
    classLabel.TextSize = 13
    classLabel.TextColor3 = C.TEXT_DIM
    classLabel.TextXAlignment = Enum.TextXAlignment.Left
    classLabel.Parent = headerRow

    -- Separator
    local sep1 = Instance.new("Frame")
    sep1.Size = UDim2.new(1, 0, 0, 1)
    sep1.BackgroundColor3 = C.SEPARATOR
    sep1.BackgroundTransparency = 0.5
    sep1.BorderSizePixel = 0
    sep1.LayoutOrder = 2
    sep1.Parent = panelFrame

    -- Stats: Cast time, Cooldown
    castLabel = Instance.new("TextLabel")
    castLabel.Name = "CastTime"
    castLabel.Size = UDim2.new(1, 0, 0, 18)
    castLabel.BackgroundTransparency = 1
    castLabel.Font = Enum.Font.Gotham
    castLabel.TextSize = 13
    castLabel.TextColor3 = C.TEXT_BRIGHT
    castLabel.TextXAlignment = Enum.TextXAlignment.Left
    castLabel.LayoutOrder = 3
    castLabel.Parent = panelFrame

    cooldownLabel = Instance.new("TextLabel")
    cooldownLabel.Name = "Cooldown"
    cooldownLabel.Size = UDim2.new(1, 0, 0, 18)
    cooldownLabel.BackgroundTransparency = 1
    cooldownLabel.Font = Enum.Font.Gotham
    cooldownLabel.TextSize = 13
    cooldownLabel.TextColor3 = C.TEXT_BRIGHT
    cooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
    cooldownLabel.LayoutOrder = 4
    cooldownLabel.Parent = panelFrame

    -- Separator 2
    local sep2 = Instance.new("Frame")
    sep2.Size = UDim2.new(1, 0, 0, 1)
    sep2.BackgroundColor3 = C.SEPARATOR
    sep2.BackgroundTransparency = 0.5
    sep2.BorderSizePixel = 0
    sep2.LayoutOrder = 5
    sep2.Parent = panelFrame

    -- Description
    descLabel = Instance.new("TextLabel")
    descLabel.Name = "Description"
    descLabel.Size = UDim2.new(1, 0, 0, 0)
    descLabel.AutomaticSize = Enum.AutomaticSize.Y
    descLabel.BackgroundTransparency = 1
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 12
    descLabel.TextColor3 = C.TEXT_DIM
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextWrapped = true
    descLabel.LayoutOrder = 6
    descLabel.Parent = panelFrame

    -- Placeholder (no spell selected)
    SpellDetailPanel._showPlaceholder()

    return panelFrame
end

function SpellDetailPanel._showPlaceholder()
    nameLabel.Text = "Selected spell"
    classLabel.Text = ""
    castLabel.Text = ""
    cooldownLabel.Text = ""
    descLabel.Text = ""

    local iconImg = iconFrame:FindFirstChild("Icon")
    local iconFb = iconFrame:FindFirstChild("Fallback")
    if iconImg then
        iconImg.Image = "";
        iconImg.Visible = false
    end
    if iconFb then
        iconFb.Text = "?";
        iconFb.Visible = true
    end
end

function SpellDetailPanel.refresh(spellId)
    if not spellId then
        SpellDetailPanel._showPlaceholder()
        return
    end

    local spell = SpellConfig.Spells[spellId]
    if not spell then
        SpellDetailPanel._showPlaceholder()
        return
    end

    local accent = C.SCHOOL_ACCENTS[spell.School] or C.TEXT_COLOR

    nameLabel.Text = spell.Name or spellId
    nameLabel.TextColor3 = accent

    -- Class label: "Projectile", "AoE", etc.
    local classParts = {}
    if spell.Tags then
        for _, tag in spell.Tags do
            table.insert(classParts, tag)
        end
    end
    classLabel.Text = table.concat(classParts, ", ")

    -- Cast time
    local castTime = spell.CastTime or 0
    castLabel.Text = castTime > 0 and ("Cast time: " .. castTime .. "s") or "Instant"
    castLabel.Visible = true

    -- Cooldown
    local cd = spell.Cooldown or 0
    cooldownLabel.Text = cd > 0 and ("Cooldown: " .. cd .. "s") or ""
    cooldownLabel.Visible = cd > 0

    -- Description
    descLabel.Text = spell.Description or ""

    -- Icon
    local iconImg = iconFrame:FindFirstChild("Icon")
    local iconFb = iconFrame:FindFirstChild("Fallback")
    if spell.Icon and spell.Icon ~= "" and spell.Icon ~= "rbxassetid://0" then
        if iconImg then
            iconImg.Image = spell.Icon;
            iconImg.Visible = true
        end
        if iconFb then
            iconFb.Visible = false
        end
    else
        if iconImg then
            iconImg.Visible = false
        end
        if iconFb then
            iconFb.Text = spell.Name or "?";
            iconFb.Visible = true
        end
    end
end

function SpellDetailPanel.onEquip(callback)
    onEquipCallback = callback
end

function SpellDetailPanel.setVisible(visible)
    if panelFrame then
        panelFrame.Visible = visible
    end
end

return SpellDetailPanel
