local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SpellCard = {}

function SpellCard.build(parent, spellConfig, isLearned, isSelected, layoutOrder, canLearn)
    canLearn = canLearn or false
    local accent = C.SCHOOL_ACCENTS[spellConfig.School] or C.STROKE_COLOR

    local card = Instance.new("ImageButton")
    card.Name = "SpellCard_" .. spellConfig.Id
    card.Size = UDim2.new(0, C.SPELL_ICON_SIZE, 0, C.SPELL_ICON_SIZE)
    card.BackgroundColor3 = isSelected and C.CARD_BG_SELECTED or (isLearned and C.CARD_BG or C.CARD_BG_LOCKED)
    card.AutoButtonColor = false
    card.Image = ""
    card.LayoutOrder = layoutOrder or 0
    card.Parent = parent

    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    if isSelected then
        stroke.Color = accent
        stroke.Thickness = 2
    elseif canLearn then
        stroke.Color = accent
        stroke.Thickness = 2.5
    elseif isLearned then
        stroke.Color = C.STROKE_COLOR
        stroke.Thickness = 1
    else
        stroke.Color = Color3.fromRGB(50, 50, 60)
        stroke.Thickness = 1
    end
    stroke.Parent = card

    -- Icon — fills entire card
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, -6, 1, -6)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    icon.BackgroundTransparency = 1
    icon.Image = spellConfig.Icon or ""
    icon.ImageTransparency = isLearned and 0 or 0.5
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = card

    -- Fallback text (when no icon)
    if not spellConfig.Icon or spellConfig.Icon == "" or spellConfig.Icon == "rbxassetid://0" then
        icon.Visible = false
        local fallback = Instance.new("TextLabel")
        fallback.Name = "Fallback"
        fallback.Size = UDim2.new(1, -6, 1, -6)
        fallback.AnchorPoint = Vector2.new(0.5, 0.5)
        fallback.Position = UDim2.new(0.5, 0, 0.5, 0)
        fallback.BackgroundTransparency = 1
        fallback.Font = Enum.Font.GothamBold
        fallback.TextSize = 11
        fallback.TextColor3 = isLearned and C.TEXT_COLOR or C.TEXT_DIM
        fallback.TextTransparency = isLearned and 0 or 0.4
        fallback.Text = spellConfig.Name or "?"
        fallback.TextWrapped = true
        fallback.Parent = card
    end

    -- Lock overlay: ONLY for fully locked (not learned AND not canLearn)
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
            card.BackgroundColor3 = isLearned and C.CARD_BG_HOVER or C.CARD_BG_LOCKED
        end
    end)
    card.MouseLeave:Connect(function()
        if not isSelected then
            card.BackgroundColor3 = isLearned and C.CARD_BG or C.CARD_BG_LOCKED
        end
    end)

    return card
end

return SpellCard
