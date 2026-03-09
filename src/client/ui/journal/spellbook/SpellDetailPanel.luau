local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SpellDetailPanel = {}

local panelFrame = nil
local contentFrame = nil
local placeholderLabel = nil
local iconFrame, nameLabel, classLabel, castLabel, cooldownLabel, descLabel
local learnButton = nil
local requireLabel = nil
local currentSpellId = nil
local onLearnedCallback = nil

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

    -- ═══ Placeholder ═══
    placeholderLabel = Instance.new("TextLabel")
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

    -- ═══ Content ═══
    contentFrame = Instance.new("Frame")
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
    iconImage.Size = UDim2.new(1, 0, 1, 0)
    iconImage.BackgroundTransparency = 1
    iconImage.ScaleType = Enum.ScaleType.Crop
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
    classLabel.TextSize = 16
    classLabel.TextColor3 = C.TEXT_DIM
    classLabel.TextXAlignment = Enum.TextXAlignment.Left
    classLabel.Parent = headerRow

    -- Separator 1
    local sep1 = Instance.new("Frame")
    sep1.Size = UDim2.new(1, 0, 0, 1)
    sep1.BackgroundColor3 = C.SEPARATOR
    sep1.BackgroundTransparency = 0.5
    sep1.BorderSizePixel = 0
    sep1.LayoutOrder = 2
    sep1.Parent = contentFrame

    castLabel = Instance.new("TextLabel")
    castLabel.Name = "CastTime"
    castLabel.Size = UDim2.new(1, 0, 0, 18)
    castLabel.BackgroundTransparency = 1
    castLabel.Font = Enum.Font.Gotham
    castLabel.TextSize = 16
    castLabel.TextColor3 = C.TEXT_BRIGHT
    castLabel.TextXAlignment = Enum.TextXAlignment.Left
    castLabel.LayoutOrder = 3
    castLabel.Parent = contentFrame

    cooldownLabel = Instance.new("TextLabel")
    cooldownLabel.Name = "Cooldown"
    cooldownLabel.Size = UDim2.new(1, 0, 0, 18)
    cooldownLabel.BackgroundTransparency = 1
    cooldownLabel.Font = Enum.Font.Gotham
    cooldownLabel.TextSize = 16
    cooldownLabel.TextColor3 = C.TEXT_BRIGHT
    cooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
    cooldownLabel.LayoutOrder = 4
    cooldownLabel.Parent = contentFrame

    -- Separator 2
    local sep2 = Instance.new("Frame")
    sep2.Size = UDim2.new(1, 0, 0, 1)
    sep2.BackgroundColor3 = C.SEPARATOR
    sep2.BackgroundTransparency = 0.5
    sep2.BorderSizePixel = 0
    sep2.LayoutOrder = 5
    sep2.Parent = contentFrame

    descLabel = Instance.new("TextLabel")
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

    -- Separator 3
    local sep3 = Instance.new("Frame")
    sep3.Name = "Sep3"
    sep3.Size = UDim2.new(1, 0, 0, 1)
    sep3.BackgroundColor3 = C.SEPARATOR
    sep3.BackgroundTransparency = 0.5
    sep3.BorderSizePixel = 0
    sep3.LayoutOrder = 7
    sep3.Visible = false
    sep3.Parent = contentFrame

    -- Requirement text (not enough points)
    requireLabel = Instance.new("TextLabel")
    requireLabel.Name = "RequireLabel"
    requireLabel.Size = UDim2.new(1, 0, 0, 0)
    requireLabel.AutomaticSize = Enum.AutomaticSize.Y
    requireLabel.BackgroundTransparency = 1
    requireLabel.Font = Enum.Font.GothamBold
    requireLabel.TextSize = 14
    requireLabel.TextColor3 = Color3.fromRGB(200, 100, 100)
    requireLabel.TextXAlignment = Enum.TextXAlignment.Left
    requireLabel.TextWrapped = true
    requireLabel.LayoutOrder = 8
    requireLabel.Visible = false
    requireLabel.Parent = contentFrame

    -- Learn button
    learnButton = Instance.new("TextButton")
    learnButton.Name = "LearnButton"
    learnButton.Size = UDim2.new(1, 0, 0, 36)
    learnButton.BackgroundColor3 = Color3.fromRGB(40, 100, 40)
    learnButton.AutoButtonColor = false
    learnButton.Font = Enum.Font.GothamBold
    learnButton.TextSize = 16
    learnButton.TextColor3 = Color3.fromRGB(220, 255, 220)
    learnButton.Text = "Изучить"
    learnButton.LayoutOrder = 9
    learnButton.Visible = false
    learnButton.Parent = contentFrame

    Instance.new("UICorner", learnButton).CornerRadius = UDim.new(0, 6)

    local learnStroke = Instance.new("UIStroke")
    learnStroke.Color = Color3.fromRGB(60, 140, 60)
    learnStroke.Thickness = 1
    learnStroke.Parent = learnButton

    -- Hover effects
    learnButton.MouseEnter:Connect(function()
        learnButton.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
    end)
    learnButton.MouseLeave:Connect(function()
        learnButton.BackgroundColor3 = Color3.fromRGB(40, 100, 40)
    end)

    -- Click → learn
    learnButton.Activated:Connect(function()
        if currentSpellId then
            Remotes.LearnSpell:FireServer(currentSpellId)
            if onLearnedCallback then
                onLearnedCallback(currentSpellId)
            end
        end
    end)

    SpellDetailPanel._showPlaceholder()
    return panelFrame
end

function SpellDetailPanel._showPlaceholder()
    contentFrame.Visible = false
    placeholderLabel.Visible = true
    currentSpellId = nil
end

function SpellDetailPanel._showContent()
    placeholderLabel.Visible = false
    contentFrame.Visible = true
end

function SpellDetailPanel.refresh(spellId, spellData)
    if not spellId then
        SpellDetailPanel._showPlaceholder()
        return
    end

    local spell = SpellConfig.Spells[spellId]
    if not spell then
        SpellDetailPanel._showPlaceholder()
        return
    end

    currentSpellId = spellId
    SpellDetailPanel._showContent()

    local accent = C.SCHOOL_ACCENTS[spell.School] or C.TEXT_COLOR

    nameLabel.Text = spell.Name or spellId
    nameLabel.TextColor3 = accent

    local classParts = {}
    if spell.Tags then
        for _, tag in spell.Tags do
            table.insert(classParts, tag)
        end
    end
    classLabel.Text = table.concat(classParts, ", ")

    local castTime = spell.CastTime or 0
    castLabel.Text = castTime > 0 and ("Cast time: " .. castTime .. "s") or "Instant"
    castLabel.Visible = true

    local cd = spell.Cooldown or 0
    cooldownLabel.Text = cd > 0 and ("Cooldown: " .. cd .. "s") or ""
    cooldownLabel.Visible = cd > 0

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

    -- ═══ Learn / Requirement ═══
    local sep3 = contentFrame:FindFirstChild("Sep3")
    local isLearned = spellData and spellData.LearnedSpells and spellData.LearnedSpells[spellId]

    if isLearned then
        learnButton.Visible = false
        requireLabel.Visible = false
        if sep3 then
            sep3.Visible = false
        end
    else
        local school = spell.School
        local tier = spell.Tier
        local isUlt = spell.Class == "Ultimate"
        local cost = spell.UnlockCost or 1
        local pointsKey = spell.Class == "Ultimate" and "ULT" or tostring(tier)

        local available = 0
        if spellData and spellData.SpellPoints and spellData.SpellPoints[school] then
            available = spellData.SpellPoints[school][pointsKey] or 0
        end

        if sep3 then
            sep3.Visible = true
        end

        if available >= cost then
            learnButton.Visible = true
            requireLabel.Visible = false
            -- Tint button with school accent
            learnButton.BackgroundColor3 = Color3.fromRGB(40, 100, 40)
            local btnStroke = learnButton:FindFirstChildOfClass("UIStroke")
            if btnStroke then
                btnStroke.Color = accent
            end
        else
            learnButton.Visible = false
            requireLabel.Visible = true
            local tierName = isUlt and "Ultimate" or ("Tier " .. tier)
            requireLabel.Text = "Требуется: " .. cost .. " " .. school .. " " .. tierName ..
                                    " Spell Point (есть: " .. available .. ")"
        end
    end
end

function SpellDetailPanel.onLearned(callback)
    onLearnedCallback = callback
end

function SpellDetailPanel.getFrame()
    return panelFrame
end

function SpellDetailPanel.setVisible(visible)
    if panelFrame then
        panelFrame.Visible = visible
    end
end

return SpellDetailPanel
