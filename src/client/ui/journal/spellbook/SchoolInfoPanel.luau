local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SchoolInfoPanel = {}

local panelFrame = nil
local schoolNameLabel, schoolDescLabel
local passiveNameLabel, passiveDescLabel
local tierBonusHeaderLabel
local tierBonusContainer = nil

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

    -- Container for individual tier bonus labels (so we can color each one)
    tierBonusContainer = Instance.new("Frame")
    tierBonusContainer.Name = "TierBonusContainer"
    tierBonusContainer.Size = UDim2.new(1, 0, 0, 0)
    tierBonusContainer.AutomaticSize = Enum.AutomaticSize.Y
    tierBonusContainer.BackgroundTransparency = 1
    tierBonusContainer.LayoutOrder = 12
    tierBonusContainer.Parent = panelFrame

    local containerLayout = Instance.new("UIListLayout")
    containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    containerLayout.Padding = UDim.new(0, 6)
    containerLayout.Parent = tierBonusContainer

    return panelFrame
end

--[[
    SchoolInfoPanel.refresh(schoolId, spellData)
    
    spellData.SchoolProgress[school].CompletedTiers = { ["1"] = true, ... }
    Used to highlight completed tier bonuses with ✓ and white text.
]]
function SchoolInfoPanel.refresh(schoolId, spellData)
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

    -- Section 3: Clear old bonus labels
    for _, child in tierBonusContainer:GetChildren() do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    -- Determine completed tiers
    local completedTiers = {}
    if spellData and spellData.SchoolProgress and spellData.SchoolProgress[schoolId] then
        completedTiers = spellData.SchoolProgress[schoolId].CompletedTiers or {}
    end

    -- Check ULT completion: all Ultimate spells of this school learned
    local ultComplete = true
    local hasUltSpell = false
    for spellId, spell in SpellConfig.Spells do
        if spell.School == schoolId and spell.Class == "Ultimate" then
            hasUltSpell = true
            if not (spellData and spellData.LearnedSpells and spellData.LearnedSpells[spellId]) then
                ultComplete = false
            end
        end
    end
    if not hasUltSpell then
        ultComplete = false
    end

    local order = 0
    local hasAny = false

    if school.TierBonuses then
        local sortedTiers = {}
        for tier in school.TierBonuses do
            table.insert(sortedTiers, tier)
        end
        table.sort(sortedTiers)

        for _, tier in sortedTiers do
            local bonus = school.TierBonuses[tier]
            local desc = bonus.Description or ("Tier " .. tier .. " bonus")
            local isComplete = completedTiers[tostring(tier)] == true

            order = order + 1
            local label = Instance.new("TextLabel")
            label.Name = "Bonus_" .. tier
            label.Size = UDim2.new(1, 0, 0, 0)
            label.AutomaticSize = Enum.AutomaticSize.Y
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.Gotham
            label.TextSize = 16
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.TextWrapped = true
            label.LayoutOrder = order
            label.Parent = tierBonusContainer

            if isComplete then
                label.Text = "✓ Tier " .. tier .. ": " .. desc
                label.TextColor3 = C.TEXT_COLOR
            else
                label.Text = "○ Tier " .. tier .. ": " .. desc
                label.TextColor3 = C.TEXT_DIM
            end

            hasAny = true
        end
    end

    if school.UltTierBonus then
        local ultDesc = school.UltTierBonus.Description or "Ultimate tier bonus"
        order = order + 1

        local label = Instance.new("TextLabel")
        label.Name = "Bonus_ULT"
        label.Size = UDim2.new(1, 0, 0, 0)
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.TextSize = 16
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextWrapped = true
        label.LayoutOrder = order
        label.Parent = tierBonusContainer

        if ultComplete then
            label.Text = "✓ Ultimate: " .. ultDesc
            label.TextColor3 = C.ULT_COLOR
        else
            label.Text = "○ Ultimate: " .. ultDesc
            label.TextColor3 = C.TEXT_DIM
        end

        hasAny = true
    end

    tierBonusHeaderLabel.Visible = hasAny
    tierBonusContainer.Visible = hasAny
end

function SchoolInfoPanel.setVisible(visible)
    if panelFrame then
        panelFrame.Visible = visible
    end
end

return SchoolInfoPanel
