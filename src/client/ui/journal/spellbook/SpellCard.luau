local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SpellCard = {}

--[[
    SpellCard.build(parent, spellId, isLearned, isSelected, schoolId, canLearn)
    
    canLearn = true  → spell not learned but player has a spell point for its tier
                       Shows: dimmed icon, NO "?" overlay, bright accent border
    canLearn = false → spell not learned, no point available
                       Shows: dimmed icon, "?" overlay, dim border
    isLearned = true → full brightness, accent border
]]
function SpellCard.build(parent, spellId, isLearned, isSelected, schoolId, canLearn)
    local spellDef = SpellConfig.Spells[spellId]
    if not spellDef then
        return nil
    end

    canLearn = canLearn or false
    local accent = C.SCHOOL_ACCENTS[schoolId] or C.STROKE_COLOR

    -- Background color
    local bgColor
    if isSelected then
        bgColor = C.CARD_BG_SELECTED
    elseif isLearned then
        bgColor = C.CARD_BG
    else
        bgColor = C.CARD_BG_LOCKED
    end

    local card = Instance.new("ImageButton")
    card.Name = "SpellCard_" .. spellId
    card.Size = UDim2.new(0, C.SPELL_ICON_SIZE, 0, C.SPELL_ICON_SIZE)
    card.BackgroundColor3 = bgColor
    card.AutoButtonColor = false
    card.Image = ""
    card.Parent = parent

    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    -- Stroke: bright accent for canLearn, normal for others
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    if isSelected then
        stroke.Color = accent
        stroke.Thickness = 2
        stroke.Transparency = 0
    elseif canLearn then
        stroke.Color = accent
        stroke.Thickness = 2.5
        stroke.Transparency = 0
    elseif isLearned then
        stroke.Color = C.STROKE_COLOR
        stroke.Thickness = 1
        stroke.Transparency = 0
    else
        stroke.Color = Color3.fromRGB(50, 50, 60)
        stroke.Thickness = 1
        stroke.Transparency = 0.4
    end
    stroke.Parent = card

    -- Icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0.7, 0, 0.7, 0)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.new(0.5, 0, 0.42, 0)
    icon.BackgroundTransparency = 1
    icon.Image = spellDef.Icon or ""
    icon.ImageTransparency = isLearned and 0 or 0.5
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = card

    -- Fallback text if no icon
    if not spellDef.Icon or spellDef.Icon == "" or spellDef.Icon == "rbxassetid://0" then
        icon.Visible = false
        local fallback = Instance.new("TextLabel")
        fallback.Name = "Fallback"
        fallback.Size = UDim2.new(1, -6, 0.6, 0)
        fallback.Position = UDim2.new(0, 3, 0.05, 0)
        fallback.BackgroundTransparency = 1
        fallback.Font = Enum.Font.GothamBold
        fallback.TextSize = 11
        fallback.TextColor3 = isLearned and C.TEXT_COLOR or C.TEXT_DIM
        fallback.TextTransparency = isLearned and 0 or 0.4
        fallback.Text = spellDef.Name or "?"
        fallback.TextWrapped = true
        fallback.Parent = card
    end

    -- Name below icon
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "SpellName"
    nameLabel.Size = UDim2.new(1, -4, 0, 12)
    nameLabel.AnchorPoint = Vector2.new(0.5, 1)
    nameLabel.Position = UDim2.new(0.5, 0, 1, -2)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = 9
    nameLabel.TextColor3 = isLearned and C.TEXT_DIM or Color3.fromRGB(80, 80, 90)
    nameLabel.Text = spellDef.Name or ""
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    -- Lock overlay: ONLY for locked spells (not learned AND not canLearn)
    if not isLearned and not canLearn then
        local lockOverlay = Instance.new("Frame")
        lockOverlay.Size = UDim2.new(1, 0, 1, 0)
        lockOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        lockOverlay.BackgroundTransparency = 0.5
        lockOverlay.BorderSizePixel = 0
        lockOverlay.ZIndex = 2
        lockOverlay.Parent = card
        Instance.new("UICorner", lockOverlay).CornerRadius = UDim.new(0, 8)

        local lockText = Instance.new("TextLabel")
        lockText.Size = UDim2.new(1, 0, 1, 0)
        lockText.BackgroundTransparency = 1
        lockText.Text = "?"
        lockText.TextColor3 = Color3.fromRGB(80, 80, 100)
        lockText.TextSize = 24
        lockText.Font = Enum.Font.GothamBold
        lockText.ZIndex = 3
        lockText.Parent = card
    end

    -- Hover
    card.MouseEnter:Connect(function()
        if not isSelected then
            card.BackgroundColor3 = C.CARD_BG_HOVER
        end
    end)
    card.MouseLeave:Connect(function()
        if not isSelected then
            card.BackgroundColor3 = bgColor
        end
    end)

    return card
end

return SpellCard
