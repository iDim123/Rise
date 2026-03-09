local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SpellCard = {}

function SpellCard.build(parent, spellId, isLearned, isSelected, schoolId, canLearn)
    local spellDef = SpellConfig.Spells[spellId]
    if not spellDef then
        return nil
    end

    canLearn = canLearn or false
    local accentColor = C.SCHOOL_ACCENTS[schoolId] or C.STROKE_COLOR

    -- Определяем цвет фона
    local bgColor
    if isSelected then
        bgColor = C.CARD_BG_SELECTED
    elseif isLearned then
        bgColor = C.CARD_BG
    else
        bgColor = C.CARD_BG_LOCKED
    end

    local card = Instance.new("TextButton")
    card.Name = "SpellCard_" .. spellId
    card.Size = UDim2.new(0, C.SPELL_ICON_SIZE, 0, C.SPELL_ICON_SIZE + 22)
    card.BackgroundColor3 = bgColor
    card.BorderSizePixel = 0
    card.AutoButtonColor = false
    card.Text = ""
    card.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card

    -- Рамка: яркая для canLearn, обычная для остальных
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    if canLearn then
        stroke.Color = accentColor
        stroke.Thickness = 2.5
        stroke.Transparency = 0
    elseif isLearned then
        stroke.Color = accentColor
        stroke.Thickness = 1
        stroke.Transparency = 0.4
    else
        stroke.Color = C.STROKE_COLOR
        stroke.Thickness = 1
        stroke.Transparency = 0.6
    end
    stroke.Parent = card

    -- Иконка заклинания
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, C.SPELL_ICON_SIZE - 12, 0, C.SPELL_ICON_SIZE - 12)
    icon.Position = UDim2.new(0.5, 0, 0, 6)
    icon.AnchorPoint = Vector2.new(0.5, 0)
    icon.BackgroundTransparency = 1
    icon.ScaleType = Enum.ScaleType.Fit

    if spellDef.Icon and spellDef.Icon ~= "" then
        icon.Image = spellDef.Icon
    else
        icon.Image = ""
    end

    -- Затемнение для неизученных (и canLearn тоже — остаётся затемнённой)
    if isLearned then
        icon.ImageTransparency = 0
    else
        icon.ImageTransparency = 0.55
    end
    icon.Parent = card

    -- Fallback текст если нет иконки
    if not spellDef.Icon or spellDef.Icon == "" then
        local fallback = Instance.new("TextLabel")
        fallback.Name = "Fallback"
        fallback.Size = UDim2.new(1, -8, 0, C.SPELL_ICON_SIZE - 12)
        fallback.Position = UDim2.new(0, 4, 0, 6)
        fallback.BackgroundTransparency = 1
        fallback.Text = string.sub(spellDef.Name or spellId, 1, 6)
        fallback.TextColor3 = C.TEXT_DIM
        fallback.TextScaled = true
        fallback.Font = Enum.Font.GothamBold
        fallback.Parent = card
    end

    -- Имя заклинания
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "SpellName"
    nameLabel.Size = UDim2.new(1, -4, 0, 16)
    nameLabel.Position = UDim2.new(0, 2, 1, -18)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = spellDef.Name or spellId
    nameLabel.TextColor3 = isLearned and C.TEXT_COLOR or C.TEXT_DIM
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    -- Оверлей с "?" ТОЛЬКО для заблокированных (нет очков)
    -- canLearn — НЕ показываем "?"
    if not isLearned and not canLearn then
        local overlay = Instance.new("Frame")
        overlay.Name = "LockOverlay"
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        overlay.BackgroundTransparency = 0.55
        overlay.BorderSizePixel = 0
        overlay.ZIndex = 2
        overlay.Parent = card

        local overlayCorner = Instance.new("UICorner")
        overlayCorner.CornerRadius = UDim.new(0, 6)
        overlayCorner.Parent = overlay

        local lockIcon = Instance.new("TextLabel")
        lockIcon.Name = "LockIcon"
        lockIcon.Size = UDim2.new(1, 0, 1, -18)
        lockIcon.BackgroundTransparency = 1
        lockIcon.Text = "?"
        lockIcon.TextColor3 = C.TEXT_DIM
        lockIcon.TextScaled = true
        lockIcon.Font = Enum.Font.GothamBold
        lockIcon.ZIndex = 3
        lockIcon.Parent = overlay
    end

    -- Ховер эффект
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
