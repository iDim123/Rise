local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SchoolInfoPanel = {}

local panelFrame = nil
local schoolNameLabel, schoolDescLabel, passiveNameLabel, passiveDescLabel

function SchoolInfoPanel.build(parent)
    panelFrame = Instance.new("Frame")
    panelFrame.Name = "SchoolInfoPanel"
    panelFrame.Size = UDim2.new(0, C.SCHOOL_INFO_W, 1, 0)
    panelFrame.Position = UDim2.new(0, 0, 0, 0)
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
    pad.PaddingTop = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14)
    pad.Parent = panelFrame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = panelFrame

    -- School name
    schoolNameLabel = Instance.new("TextLabel")
    schoolNameLabel.Name = "SchoolName"
    schoolNameLabel.Size = UDim2.new(1, 0, 0, 24)
    schoolNameLabel.BackgroundTransparency = 1
    schoolNameLabel.Font = Enum.Font.GothamBold
    schoolNameLabel.TextSize = 18
    schoolNameLabel.TextColor3 = C.TEXT_COLOR
    schoolNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    schoolNameLabel.LayoutOrder = 1
    schoolNameLabel.Parent = panelFrame

    -- School description
    schoolDescLabel = Instance.new("TextLabel")
    schoolDescLabel.Name = "SchoolDesc"
    schoolDescLabel.Size = UDim2.new(1, 0, 0, 0)
    schoolDescLabel.AutomaticSize = Enum.AutomaticSize.Y
    schoolDescLabel.BackgroundTransparency = 1
    schoolDescLabel.Font = Enum.Font.Gotham
    schoolDescLabel.TextSize = 12
    schoolDescLabel.TextColor3 = C.TEXT_DIM
    schoolDescLabel.TextXAlignment = Enum.TextXAlignment.Left
    schoolDescLabel.TextWrapped = true
    schoolDescLabel.LayoutOrder = 2
    schoolDescLabel.Parent = panelFrame

    -- Separator
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = C.SEPARATOR
    sep.BackgroundTransparency = 0.5
    sep.BorderSizePixel = 0
    sep.LayoutOrder = 3
    sep.Parent = panelFrame

    -- Passive name
    passiveNameLabel = Instance.new("TextLabel")
    passiveNameLabel.Name = "PassiveName"
    passiveNameLabel.Size = UDim2.new(1, 0, 0, 20)
    passiveNameLabel.BackgroundTransparency = 1
    passiveNameLabel.Font = Enum.Font.GothamBold
    passiveNameLabel.TextSize = 15
    passiveNameLabel.TextColor3 = C.TEXT_COLOR
    passiveNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    passiveNameLabel.LayoutOrder = 4
    passiveNameLabel.Parent = panelFrame

    -- Passive description
    passiveDescLabel = Instance.new("TextLabel")
    passiveDescLabel.Name = "PassiveDesc"
    passiveDescLabel.Size = UDim2.new(1, 0, 0, 0)
    passiveDescLabel.AutomaticSize = Enum.AutomaticSize.Y
    passiveDescLabel.BackgroundTransparency = 1
    passiveDescLabel.Font = Enum.Font.Gotham
    passiveDescLabel.TextSize = 12
    passiveDescLabel.TextColor3 = C.TEXT_DIM
    passiveDescLabel.TextXAlignment = Enum.TextXAlignment.Left
    passiveDescLabel.TextWrapped = true
    passiveDescLabel.LayoutOrder = 5
    passiveDescLabel.Parent = panelFrame

    return panelFrame
end

function SchoolInfoPanel.refresh(schoolId)
    local school = SpellConfig.MagicSchools[schoolId]
    if not school then
        return
    end

    local accent = C.SCHOOL_ACCENTS[schoolId] or C.STROKE_COLOR

    schoolNameLabel.Text = school.Name .. " Magic"
    schoolNameLabel.TextColor3 = accent

    -- Build description from school data
    local descParts = {}
    if school.Description then
        table.insert(descParts, school.Description)
    end
    -- Tier bonuses
    if school.TierBonuses then
        for tier, bonus in school.TierBonuses do
            local bonusText = "Tier " .. tier .. ": "
            local parts = {}
            for k, v in bonus do
                table.insert(parts, k .. " = " .. tostring(v))
            end
            bonusText = bonusText .. table.concat(parts, ", ")
            table.insert(descParts, bonusText)
        end
    end
    schoolDescLabel.Text = table.concat(descParts, "\n")

    -- Passive
    local passive = school.Passive
    if passive then
        passiveNameLabel.Text = passive.Name or "Passive"
        local passiveParts = {}
        if passive.HealPercent then
            table.insert(passiveParts, "Heals " .. (passive.HealPercent * 100) .. "% of damage dealt")
        end
        if passive.HealOnKillPercent then
            table.insert(passiveParts, (passive.HealOnKillPercent * 100) .. "% heal on kill")
        end
        if passive.DotPercent then
            table.insert(passiveParts,
                (passive.DotPercent * 100) .. "% magic DoT for " .. (passive.DotDuration or 5) .. "s")
        end
        if passive.ExplosionPercent then
            table.insert(passiveParts, (passive.ExplosionPercent * 100) .. "% explosion on death")
        end
        if passive.ChainIgniteChance then
            table.insert(passiveParts, (passive.ChainIgniteChance * 100) .. "% chain ignite chance")
        end
        passiveDescLabel.Text = table.concat(passiveParts, "\n")
    else
        passiveNameLabel.Text = ""
        passiveDescLabel.Text = ""
    end
end

function SchoolInfoPanel.setVisible(visible)
    if panelFrame then
        panelFrame.Visible = visible
    end
end

return SchoolInfoPanel
