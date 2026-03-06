local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local C = require(script.Parent:WaitForChild("BossJournalConstants"))
local BossTooltip = require(script.Parent:WaitForChild("BossTooltip"))

local BossCard = {}

-- ═══ Essence Progress Bar ═══
local function createEssenceBar(parent, current, required)
    local barHeight = 16

    local barFrame = Instance.new("Frame")
    barFrame.Name = "EssenceBarContainer"
    barFrame.Size = UDim2.new(1, 0, 0, barHeight + 20)
    barFrame.BackgroundTransparency = 1
    barFrame.Parent = parent

    -- Label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = "Поглощение эссенции"
    label.TextColor3 = C.TEXT_DIM
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = barFrame

    -- Bar background
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.Size = UDim2.new(1, 0, 0, barHeight)
    barBg.Position = UDim2.new(0, 0, 0, 24) -- было 18, стало 24
    barBg.BackgroundColor3 = C.ESSENCE_EMPTY
    barBg.BorderSizePixel = 0
    barBg.ClipsDescendants = true
    barBg.Parent = barFrame

    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 4)

    local barStroke = Instance.new("UIStroke")
    barStroke.Color = C.STROKE_COLOR
    barStroke.Thickness = 1
    barStroke.Parent = barBg

    -- Fill
    local fillRatio = math.clamp(current / math.max(required, 1), 0, 1)
    local isFull = current >= required

    local barFill = Instance.new("Frame")
    barFill.Name = "BarFill"
    barFill.Size = UDim2.new(fillRatio, 0, 1, 0)
    barFill.BackgroundColor3 = isFull and C.ESSENCE_FULL or C.ESSENCE_FILLED
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg

    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 4)

    -- Dividers
    if required > 1 then
        for i = 1, required - 1 do
            local divider = Instance.new("Frame")
            divider.Size = UDim2.new(0, 2, 1, 0)
            divider.Position = UDim2.new(i / required, -1, 0, 0)
            divider.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
            divider.BorderSizePixel = 0
            divider.ZIndex = 2
            divider.Parent = barBg
        end
    end

    -- Count text
    local countLabel = Instance.new("TextLabel")
    countLabel.Size = UDim2.new(1, 0, 1, 0)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = current .. " / " .. required
    countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    countLabel.TextSize = 14
    countLabel.Font = Enum.Font.GothamBold
    countLabel.ZIndex = 3
    countLabel.Parent = barBg

    return barFrame
end

-- ═══ Separator line ═══
local function createSeparator(parent)
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = C.STROKE_COLOR
    sep.BackgroundTransparency = 0.5
    sep.BorderSizePixel = 0
    sep.Parent = parent
    return sep
end

-- ═══ Build Card ═══
function BossCard.build(parent, bossId, bConfig, pData, yOffset)
    local card = Instance.new("Frame")
    card.Name = "BossCard_" .. bossId
    card.Size = UDim2.new(1, -C.CARD_PADDING * 2, 0, C.CARD_HEIGHT)
    card.Position = UDim2.new(0, C.CARD_PADDING, 0, yOffset)
    card.BackgroundColor3 = C.CARD_BG
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.Parent = parent

    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = C.STROKE_COLOR
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local currentEssence = pData and pData.Essence or 0
    local requiredEssence = bConfig.EssenceRequired or 1
    local techUnlocked = pData and pData.TechUnlocked

    -- ═══ Left: Boss Image (no padding, full height) ═══
    local imageWidth = C.IMAGE_SIZE

    local imageContainer = Instance.new("Frame")
    imageContainer.Name = "ImageContainer"
    imageContainer.Size = UDim2.new(0, imageWidth, 1, 0)
    imageContainer.Position = UDim2.new(0, 0, 0, 0)
    imageContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    imageContainer.ClipsDescendants = true
    imageContainer.BorderSizePixel = 0
    imageContainer.ZIndex = 1
    imageContainer.Parent = card

    -- Round only left corners
    Instance.new("UICorner", imageContainer).CornerRadius = UDim.new(0, 8)

    local bossImage = Instance.new("ImageLabel")
    bossImage.Name = "BossImage"
    bossImage.Size = UDim2.new(1, 0, 1, 0) -- fill entire container
    bossImage.Position = UDim2.new(0, 0, 0, 0)
    bossImage.BackgroundTransparency = 1
    bossImage.Image = bConfig.Image or ""
    bossImage.ScaleType = Enum.ScaleType.Crop -- fill and crop overflow
    bossImage.Parent = imageContainer

    Instance.new("UICorner", bossImage).CornerRadius = UDim.new(0, 8)

    if not bConfig.Image or bConfig.Image == "rbxassetid://0" or bConfig.Image == "" then
        local fallback = Instance.new("TextLabel")
        fallback.Size = UDim2.new(1, 0, 1, 0)
        fallback.BackgroundTransparency = 1
        fallback.Font = Enum.Font.GothamBold
        fallback.TextSize = 40
        fallback.TextColor3 = C.ACCENT_COLOR
        fallback.Text = string.sub(bConfig.Name or "?", 1, 2)
        fallback.Parent = imageContainer
    end

    -- Vertical separator after image
    local imgSep = Instance.new("Frame")
    imgSep.Size = UDim2.new(0, 1, 1, 0)
    imgSep.Position = UDim2.new(0, imageWidth, 0, 0)
    imgSep.BackgroundColor3 = C.STROKE_COLOR
    imgSep.BackgroundTransparency = 0.5
    imgSep.BorderSizePixel = 0
    imgSep.Parent = card

    -- ═══ Right: Info section with UIListLayout ═══
    local infoX = imageWidth + 1
    local infoPad = 16

    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoSection"
    infoFrame.Size = UDim2.new(1, -(infoX + infoPad * 2), 1, -infoPad * 2)
    infoFrame.Position = UDim2.new(0, infoX + infoPad, 0, infoPad)
    infoFrame.BackgroundTransparency = 1
    infoFrame.Parent = card

    -- Use UIListLayout for vertical stacking
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 4)
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.Parent = infoFrame

    -- Row 1: Name + Level
    local nameRow = Instance.new("Frame")
    nameRow.Name = "NameRow"
    nameRow.Size = UDim2.new(1, 0, 0, 26)
    nameRow.BackgroundTransparency = 1
    nameRow.LayoutOrder = 1
    nameRow.Parent = infoFrame

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.7, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = bConfig.Name or bossId
    nameLabel.TextColor3 = C.TEXT_COLOR
    nameLabel.TextSize = 20
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = nameRow

    local levelLabel = Instance.new("TextLabel")
    levelLabel.Size = UDim2.new(0.3, 0, 1, 0)
    levelLabel.Position = UDim2.new(0.7, 0, 0, 0)
    levelLabel.BackgroundTransparency = 1
    levelLabel.Text = "Level: " .. (bConfig.Level or "?")
    levelLabel.TextColor3 = C.TEXT_COLOR
    levelLabel.TextSize = 20
    levelLabel.Font = Enum.Font.GothamBold
    levelLabel.TextXAlignment = Enum.TextXAlignment.Right
    levelLabel.Parent = nameRow

    -- Location
    local locLabel = Instance.new("TextLabel")
    locLabel.Size = UDim2.new(1, 0, 0, 18)
    locLabel.BackgroundTransparency = 1
    locLabel.Text = bConfig.Location or ""
    locLabel.TextColor3 = C.TEXT_DIM
    locLabel.TextSize = 16
    locLabel.Font = Enum.Font.Gotham
    locLabel.TextXAlignment = Enum.TextXAlignment.Left
    locLabel.LayoutOrder = 2
    locLabel.Parent = infoFrame

    -- Separator 1
    local sep1 = createSeparator(infoFrame)
    sep1.LayoutOrder = 3

    -- Description (fills available space)
    -- Calculate remaining height: card - padding*2 - nameRow - loc - sep - sep - techRow - essenceBar - gaps
    local fixedHeight = 26 + 18 + 1 + 1 + 48 + 42 + (4 * 7)
    local descHeight = C.CARD_HEIGHT - infoPad * 2 - fixedHeight

    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, 0, 0, math.max(descHeight, 30))
    descLabel.BackgroundTransparency = 1
    descLabel.Text = bConfig.Description or ""
    descLabel.TextColor3 = C.TEXT_DIM
    descLabel.TextSize = 16
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.TextWrapped = true
    descLabel.LayoutOrder = 4
    descLabel.Parent = infoFrame
    descLabel.TextTruncate = Enum.TextTruncate.AtEnd

    -- Separator 2
    local sep2 = createSeparator(infoFrame)
    sep2.LayoutOrder = 5

    -- Tech unlock row
    local unlocksRow = Instance.new("Frame")
    unlocksRow.Name = "UnlocksRow"
    unlocksRow.Size = UDim2.new(1, 0, 0, 48)
    unlocksRow.BackgroundTransparency = 1
    unlocksRow.LayoutOrder = 6
    unlocksRow.Parent = infoFrame

    local iconSize = 40
    local iconGap = 8

    local unlocks = bConfig.Unlocks or {}
    for i, unlock in unlocks do
        local iconFrame = Instance.new("ImageButton")
        iconFrame.Name = "UnlockIcon_" .. i
        iconFrame.Size = UDim2.new(0, iconSize, 0, iconSize)
        iconFrame.Position = UDim2.new(0, (i - 1) * (iconSize + iconGap), 0.5, 0)
        iconFrame.AnchorPoint = Vector2.new(0, 0.5)
        iconFrame.BackgroundColor3 = techUnlocked and Color3.fromRGB(40, 40, 55) or Color3.fromRGB(25, 25, 35)
        iconFrame.BorderSizePixel = 0
        iconFrame.AutoButtonColor = false
        iconFrame.Image = ""
        iconFrame.Parent = unlocksRow

        Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(0, 6)

        local iconStroke = Instance.new("UIStroke")
        iconStroke.Color = techUnlocked and C.TECH_UNLOCKED or C.TECH_LOCKED
        iconStroke.Thickness = 1
        iconStroke.Parent = iconFrame

        -- Icon image
        local iconImage = Instance.new("ImageLabel")
        iconImage.Size = UDim2.new(0.8, 0, 0.8, 0)
        iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
        iconImage.Position = UDim2.new(0.5, 0, 0.5, 0)
        iconImage.BackgroundTransparency = 1
        iconImage.Image = unlock.Icon or ""
        iconImage.ImageTransparency = techUnlocked and 0 or 0.5
        iconImage.ScaleType = Enum.ScaleType.Fit
        iconImage.Parent = iconFrame

        -- Lock overlay
        if not techUnlocked then
            local lockOverlay = Instance.new("Frame")
            lockOverlay.Size = UDim2.new(1, 0, 1, 0)
            lockOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            lockOverlay.BackgroundTransparency = 0.5
            lockOverlay.BorderSizePixel = 0
            lockOverlay.ZIndex = 2
            lockOverlay.Parent = iconFrame

            Instance.new("UICorner", lockOverlay).CornerRadius = UDim.new(0, 6)

            local lockIcon = Instance.new("TextLabel")
            lockIcon.Size = UDim2.new(1, 0, 1, 0)
            lockIcon.BackgroundTransparency = 1
            lockIcon.Text = "?"
            lockIcon.TextColor3 = C.TECH_LOCKED
            lockIcon.TextSize = 20
            lockIcon.Font = Enum.Font.GothamBold
            lockIcon.ZIndex = 3
            lockIcon.Parent = iconFrame
        end

        -- Tooltip on hover
        BossTooltip.attach(iconFrame, unlock.Name or "Награда", unlock.Description)
    end

    -- Separator 3
    local sep3 = createSeparator(infoFrame)
    sep3.LayoutOrder = 7

    -- Essence bar
    local essenceContainer = Instance.new("Frame")
    essenceContainer.Name = "EssenceContainer"
    essenceContainer.Size = UDim2.new(1, 0, 0, 38)
    essenceContainer.BackgroundTransparency = 1
    essenceContainer.LayoutOrder = 8
    essenceContainer.Parent = infoFrame

    createEssenceBar(essenceContainer, currentEssence, requiredEssence)

    -- ═══ Level lock overlay ═══
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    local character = localPlayer.Character
    local playerLevel = 1
    if character then
        playerLevel = character:GetAttribute("Level") or 1
    end

    local bossLevel = bConfig.Level or 1
    if bossLevel - playerLevel > 10 then
        -- Dark blur overlay
        local lockOverlay = Instance.new("Frame")
        lockOverlay.Name = "LevelLockOverlay"
        lockOverlay.Size = UDim2.new(1, 0, 1, 0)
        lockOverlay.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
        lockOverlay.BackgroundTransparency = 0.1
        lockOverlay.BorderSizePixel = 0
        lockOverlay.ZIndex = 10
        lockOverlay.Parent = card

        Instance.new("UICorner", lockOverlay).CornerRadius = UDim.new(0, 8)

        -- Blurred inner panels to hide content
        local blurPanel = Instance.new("Frame")
        blurPanel.Size = UDim2.new(1, 0, 1, 0)
        blurPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
        blurPanel.BackgroundTransparency = 0.3
        blurPanel.BorderSizePixel = 0
        blurPanel.ZIndex = 11
        blurPanel.Parent = lockOverlay

        Instance.new("UICorner", blurPanel).CornerRadius = UDim.new(0, 8)

        -- Level text
        local lockLevel = Instance.new("TextLabel")
        lockLevel.Size = UDim2.new(1, 0, 0, 30)
        lockLevel.AnchorPoint = Vector2.new(0.5, 0.5)
        lockLevel.Position = UDim2.new(0.5, 0, 0.5, 0)
        lockLevel.BackgroundTransparency = 1
        lockLevel.Text = "Lvl: " .. bossLevel
        lockLevel.TextColor3 = C.ACCENT_COLOR
        lockLevel.TextSize = 28
        lockLevel.Font = Enum.Font.GothamBold
        lockLevel.ZIndex = 12
        lockLevel.Parent = lockOverlay

    end

    return card, {
        frame = card,
        nameLabel = nameLabel,
        techLabel = techTooltip
    }
end

return BossCard
