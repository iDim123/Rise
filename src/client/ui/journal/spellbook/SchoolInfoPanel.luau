local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SchoolInfoPanel = {}

local panelFrame = nil
local schoolNameLabel, schoolDescLabel
local passiveNameLabel, passiveDescLabel
local tierBonusHeaderLabel, tierBonusDescLabel

function SchoolInfoPanel.build(parent)
    panelFrame = Instance.new("ScrollingFrame")
    panelFrame.Name = "SchoolInfoPanel"
    panelFrame.Size = UDim2.new(0, C.SCHOOL_INFO_W, 1, 0)
    panelFrame.Position = UDim2.new(0, 0, 0, 0)
    panelFrame.BackgroundColor3 = C.PANEL_BG
    panelFrame.BackgroundTransparency = 0.15
    panelFrame.BorderSizePixel = 0
    panelFrame.ScrollBarThickness = 3
    panelFrame.ScrollBarImageColor3 = C.STROKE_COLOR
    panelFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    panelFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    panelFrame.Parent = parent

    Instance.new("UICorner", panelFrame).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = C.STROKE_COLOR
    stroke.Thickness = 1
    stroke.Parent = panelFrame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14)
    pad.Parent = panelFrame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = panelFrame

    -- ═══ Section 1: School name + description ═══
    schoolNameLabel = Instance.new("TextLabel")
    schoolNameLabel.Name = "SchoolName"
    schoolNameLabel.Size = UDim2.new(1, 0, 0, 26)
    schoolNameLabel.BackgroundTransparency = 1
    schoolNameLabel.Font = Enum.Font.GothamBold
    schoolNameLabel.TextSize = 20
    schoolNameLabel.TextColor3 = C.TEXT_COLOR
    schoolNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    schoolNameLabel.LayoutOrder = 1
    schoolNameLabel.Parent = panelFrame

    schoolDescLabel = Instance.new("TextLabel")
    schoolDescLabel.Name = "SchoolDesc"
    schoolDescLabel.Size = UDim2.new(1, 0, 0, 0)
    schoolDescLabel.AutomaticSize = Enum.AutomaticSize.Y
    schoolDescLabel.BackgroundTransparency = 1
    schoolDescLabel.Font = Enum.Font.Gotham
    schoolDescLabel.TextSize = 16
    schoolDescLabel.TextColor3 = C.TEXT_DIM
    schoolDescLabel.TextXAlignment = Enum.TextXAlignment.Left
    schoolDescLabel.TextWrapped = true
    schoolDescLabel.LayoutOrder = 2
    schoolDescLabel.Parent = panelFrame

    -- ═══ Spacer + Separator 1 ═══
    local spacer1 = Instance.new("Frame")
    spacer1.Name = "Spacer1"
    spacer1.Size = UDim2.new(1, 0, 0, 8)
    spacer1.BackgroundTransparency = 1
    spacer1.LayoutOrder = 3
    spacer1.Parent = panelFrame

    local sep1 = Instance.new("Frame")
    sep1.Size = UDim2.new(1, 0, 0, 1)
    sep1.BackgroundColor3 = C.SEPARATOR
    sep1.BackgroundTransparency = 0.5
    sep1.BorderSizePixel = 0
    sep1.LayoutOrder = 4
    sep1.Parent = panelFrame

    local spacer2 = Instance.new("Frame")
    spacer2.Name = "Spacer2"
    spacer2.Size = UDim2.new(1, 0, 0, 8)
    spacer2.BackgroundTransparency = 1
    spacer2.LayoutOrder = 5
    spacer2.Parent = panelFrame

    -- ═══ Section 2: Passive ═══
    passiveNameLabel = Instance.new("TextLabel")
    passiveNameLabel.Name = "PassiveName"
    passiveNameLabel.Size = UDim2.new(1, 0, 0, 22)
    passiveNameLabel.BackgroundTransparency = 1
    passiveNameLabel.Font = Enum.Font.GothamBold
    passiveNameLabel.TextSize = 18
    passiveNameLabel.TextColor3 = C.TEXT_COLOR
    passiveNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    passiveNameLabel.LayoutOrder = 6
    passiveNameLabel.Parent = panelFrame

    passiveDescLabel = Instance.new("TextLabel")
    passiveDescLabel.Name = "PassiveDesc"
    passiveDescLabel.Size = UDim2.new(1, 0, 0, 0)
    passiveDescLabel.AutomaticSize = Enum.AutomaticSize.Y
    passiveDescLabel.BackgroundTransparency = 1
    passiveDescLabel.Font = Enum.Font.Gotham
    passiveDescLabel.TextSize = 16
    passiveDescLabel.TextColor3 = C.TEXT_DIM
    passiveDescLabel.TextXAlignment = Enum.TextXAlignment.Left
    passiveDescLabel.TextWrapped = true
    passiveDescLabel.LayoutOrder = 7
    passiveDescLabel.Parent = panelFrame

    -- ═══ Spacer + Separator 2 ═══
    local spacer3 = Instance.new("Frame")
    spacer3.Name = "Spacer3"
    spacer3.Size = UDim2.new(1, 0, 0, 8)
    spacer3.BackgroundTransparency = 1
    spacer3.LayoutOrder = 8
    spacer3.Parent = panelFrame

    local sep2 = Instance.new("Frame")
    sep2.Name = "Sep2"
    sep2.Size = UDim2.new(1, 0, 0, 1)
    sep2.BackgroundColor3 = C.SEPARATOR
    sep2.BackgroundTransparency = 0.5
    sep2.BorderSizePixel = 0
    sep2.LayoutOrder = 9
    sep2.Parent = panelFrame

    local spacer4 = Instance.new("Frame")
    spacer4.Name = "Spacer4"
    spacer4.Size = UDim2.new(1, 0, 0, 8)
    spacer4.BackgroundTransparency = 1
    spacer4.LayoutOrder = 10
    spacer4.Parent = panelFrame

    -- ═══ Section 3: Tier Bonuses ═══
    tierBonusHeaderLabel = Instance.new("TextLabel")
    tierBonusHeaderLabel.Name = "TierBonusHeader"
    tierBonusHeaderLabel.Size = UDim2.new(1, 0, 0, 22)
    tierBonusHeaderLabel.BackgroundTransparency = 1
    tierBonusHeaderLabel.Font = Enum.Font.GothamBold
    tierBonusHeaderLabel.TextSize = 18
    tierBonusHeaderLabel.TextColor3 = C.TEXT_COLOR
    tierBonusHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
    tierBonusHeaderLabel.Text = "Tier Bonuses"
    tierBonusHeaderLabel.LayoutOrder = 11
    tierBonusHeaderLabel.Parent = panelFrame

    tierBonusDescLabel = Instance.new("TextLabel")
    tierBonusDescLabel.Name = "TierBonusDesc"
    tierBonusDescLabel.Size = UDim2.new(1, 0, 0, 0)
    tierBonusDescLabel.AutomaticSize = Enum.AutomaticSize.Y
    tierBonusDescLabel.BackgroundTransparency = 1
    tierBonusDescLabel.Font = Enum.Font.Gotham
    tierBonusDescLabel.TextSize = 16
    tierBonusDescLabel.TextColor3 = C.TEXT_DIM
    tierBonusDescLabel.TextXAlignment = Enum.TextXAlignment.Left
    tierBonusDescLabel.TextWrapped = true
    tierBonusDescLabel.LayoutOrder = 12
    tierBonusDescLabel.Parent = panelFrame

    return panelFrame
end

function SchoolInfoPanel.refresh(schoolId)
    local school = SpellConfig.MagicSchools[schoolId]
    if not school then
        return
    end

    local accent = C.SCHOOL_ACCENTS[schoolId] or C.STROKE_COLOR

    -- Section 1
    schoolNameLabel.Text = school.Name or schoolId
    schoolNameLabel.TextColor3 = accent
    schoolDescLabel.Text = school.Description or ""

    -- Section 2
    local passiveName = school.PassiveName or (school.Passive and school.Passive.Name) or "Passive"
    passiveNameLabel.Text = passiveName
    passiveDescLabel.Text = school.PassiveDescription or ""

    -- Section 3
    local tierLines = {}

    if school.TierBonuses then
        local sortedTiers = {}
        for tier in school.TierBonuses do
            table.insert(sortedTiers, tier)
        end
        table.sort(sortedTiers)

        for _, tier in sortedTiers do
            local bonus = school.TierBonuses[tier]
            local desc = bonus.Description or ("Tier " .. tier .. " bonus")
            table.insert(tierLines, "Tier " .. tier .. ": " .. desc)
        end
    end

    if school.UltTierBonus then
        local ultDesc = school.UltTierBonus.Description or "Ultimate tier bonus"
        table.insert(tierLines, "Ultimate: " .. ultDesc)
    end

    if #tierLines > 0 then
        tierBonusHeaderLabel.Visible = true
        tierBonusDescLabel.Visible = true
        tierBonusDescLabel.Text = table.concat(tierLines, "\n\n")
    else
        tierBonusHeaderLabel.Visible = false
        tierBonusDescLabel.Visible = false
    end
end

function SchoolInfoPanel.setVisible(visible)
    if panelFrame then
        panelFrame.Visible = visible
    end
end

return SchoolInfoPanel
