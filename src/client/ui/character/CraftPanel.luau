local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UC = require(script.Parent:WaitForChild("UIConstants"))
local GuiService = game:GetService("GuiService")

local CraftPanel = {}

local craftPanel = nil
local recipeButtons = {}
local tooltip = nil
local currentData = nil

-- ===== TOOLTIP =====
local function createTooltip(screenGui)
    local frame = Instance.new("Frame")
    frame.Name = "CraftTooltip"
    frame.Size = UDim2.new(0, 280, 0, 200)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = 50
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 80, 110)
    stroke.Thickness = 1
    stroke.Parent = frame

    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -70, 0, 24)
    titleLabel.Position = UDim2.new(0, 10, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(240, 240, 220)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Text = ""
    titleLabel.ZIndex = 51
    titleLabel.Parent = frame

    -- Icon (top right)
    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "IconFrame"
    iconFrame.Size = UDim2.new(0, 44, 0, 44)
    iconFrame.Position = UDim2.new(1, -52, 0, 6)
    iconFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 68)
    iconFrame.BorderSizePixel = 0
    iconFrame.ZIndex = 51
    iconFrame.Parent = frame

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 4)
    iconCorner.Parent = iconFrame

    local iconStroke = Instance.new("UIStroke")
    iconStroke.Color = Color3.fromRGB(80, 130, 220)
    iconStroke.Thickness = 1
    iconStroke.Parent = iconFrame

    local iconImage = Instance.new("ImageLabel")
    iconImage.Name = "Icon"
    iconImage.Size = UDim2.new(0.8, 0, 0.8, 0)
    iconImage.Position = UDim2.new(0.1, 0, 0.1, 0)
    iconImage.BackgroundTransparency = 1
    iconImage.ScaleType = Enum.ScaleType.Fit
    iconImage.Image = ""
    iconImage.Visible = false
    iconImage.ZIndex = 52
    iconImage.Parent = iconFrame

    local iconText = Instance.new("TextLabel")
    iconText.Name = "IconText"
    iconText.Size = UDim2.new(1, -4, 1, -4)
    iconText.Position = UDim2.new(0, 2, 0, 2)
    iconText.BackgroundTransparency = 1
    iconText.TextColor3 = Color3.fromRGB(200, 200, 200)
    iconText.TextSize = 7
    iconText.Font = Enum.Font.GothamBold
    iconText.TextWrapped = true
    iconText.Text = ""
    iconText.Visible = false
    iconText.ZIndex = 52
    iconText.Parent = iconFrame

    -- Type + Time
    local subtitleLabel = Instance.new("TextLabel")
    subtitleLabel.Name = "Subtitle"
    subtitleLabel.Size = UDim2.new(1, -70, 0, 14)
    subtitleLabel.Position = UDim2.new(0, 10, 0, 32)
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    subtitleLabel.TextSize = 11
    subtitleLabel.Font = Enum.Font.Gotham
    subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    subtitleLabel.Text = ""
    subtitleLabel.ZIndex = 51
    subtitleLabel.Parent = frame

    -- Separator 1
    local sep1 = Instance.new("Frame")
    sep1.Name = "Sep1"
    sep1.Size = UDim2.new(1, -20, 0, 1)
    sep1.Position = UDim2.new(0, 10, 0, 52)
    sep1.BackgroundColor3 = Color3.fromRGB(70, 100, 200)
    sep1.BorderSizePixel = 0
    sep1.ZIndex = 51
    sep1.Parent = frame

    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "Description"
    descLabel.Size = UDim2.new(1, -20, 0, 40)
    descLabel.Position = UDim2.new(0, 10, 0, 58)
    descLabel.BackgroundTransparency = 1
    descLabel.TextColor3 = Color3.fromRGB(180, 180, 195)
    descLabel.TextSize = 11
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.TextWrapped = true
    descLabel.Text = ""
    descLabel.ZIndex = 51
    descLabel.Parent = frame

    -- Separator 2
    local sep2 = Instance.new("Frame")
    sep2.Name = "Sep2"
    sep2.Size = UDim2.new(1, -20, 0, 1)
    sep2.Position = UDim2.new(0, 10, 0, 104)
    sep2.BackgroundColor3 = Color3.fromRGB(70, 100, 200)
    sep2.BorderSizePixel = 0
    sep2.ZIndex = 51
    sep2.Parent = frame

    -- Ingredients container
    local ingContainer = Instance.new("Frame")
    ingContainer.Name = "Ingredients"
    ingContainer.Size = UDim2.new(1, -20, 0, 80)
    ingContainer.Position = UDim2.new(0, 10, 0, 112)
    ingContainer.BackgroundTransparency = 1
    ingContainer.ZIndex = 51
    ingContainer.Parent = frame

    tooltip = frame
    return frame
end

local function updateTooltip(recipe)
    if not tooltip then return end

    local titleLabel = tooltip:FindFirstChild("Title")
    local iconFrame = tooltip:FindFirstChild("IconFrame")
    local subtitleLabel = tooltip:FindFirstChild("Subtitle")
    local descLabel = tooltip:FindFirstChild("Description")
    local ingContainer = tooltip:FindFirstChild("Ingredients")

    -- Title
    titleLabel.Text = recipe.Name

    -- Icon
    local iconImage = iconFrame:FindFirstChild("Icon")
    local iconText = iconFrame:FindFirstChild("IconText")
    if recipe.Icon and recipe.Icon ~= "" and recipe.Icon ~= "rbxassetid://0" then
        iconImage.Image = recipe.Icon
        iconImage.Visible = true
        iconText.Visible = false
    else
        iconImage.Visible = false
        iconText.Text = recipe.Result.Name
        iconText.Visible = true
    end

    -- Subtitle: type + craft time
    local craftTimeStr = recipe.CraftTime and recipe.CraftTime > 0
        and (recipe.CraftTime .. "s") or "Instant"
    subtitleLabel.Text = (recipe.Result.Type or "Item") .. "    " .. craftTimeStr

    -- Description
    local desc = recipe.Description or recipe.Result.Description or ""
    descLabel.Text = desc

    -- Ingredients
    for _, child in ingContainer:GetChildren() do
        child:Destroy()
    end

    local itemCounts = {}
    if currentData and currentData.slots then
        for _, slot in currentData.slots do
            if slot and slot ~= false then
                itemCounts[slot.Id] = (itemCounts[slot.Id] or 0) + (slot.Amount or 1)
            end
        end
    end

    local ingY = 4
    for _, ing in recipe.Ingredients do
        local itemDef = Config.Items[ing.ItemId]
        local ingName = itemDef and itemDef.Name or ing.ItemId
        local have = itemCounts[ing.ItemId] or 0

        -- Row frame
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 28)
        row.Position = UDim2.new(0, 0, 0, ingY)
        row.BackgroundTransparency = 1
        row.ZIndex = 52
        row.Parent = ingContainer

        -- Mini icon
        local miniIcon = Instance.new("Frame")
        miniIcon.Size = UDim2.new(0, 24, 0, 24)
        miniIcon.Position = UDim2.new(0, 0, 0, 2)
        miniIcon.BackgroundColor3 = Color3.fromRGB(50, 50, 68)
        miniIcon.BorderSizePixel = 0
        miniIcon.ZIndex = 52
        miniIcon.Parent = row

        local miniCorner = Instance.new("UICorner")
        miniCorner.CornerRadius = UDim.new(0, 3)
        miniCorner.Parent = miniIcon

        local miniStroke = Instance.new("UIStroke")
        miniStroke.Color = Color3.fromRGB(80, 130, 220)
        miniStroke.Thickness = 1
        miniStroke.Parent = miniIcon

        if itemDef and itemDef.Icon and itemDef.Icon ~= "" and itemDef.Icon ~= "rbxassetid://0" then
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.new(0.8, 0, 0.8, 0)
            img.Position = UDim2.new(0.1, 0, 0.1, 0)
            img.BackgroundTransparency = 1
            img.Image = itemDef.Icon
            img.ZIndex = 53
            img.Parent = miniIcon
        end

        -- Count: have / cost
        local countColor = have >= ing.Amount
            and Color3.fromRGB(100, 200, 100)
            or Color3.fromRGB(200, 100, 100)

        local countLabel = Instance.new("TextLabel")
        countLabel.Size = UDim2.new(0, 60, 0, 28)
        countLabel.Position = UDim2.new(0, 30, 0, 0)
        countLabel.BackgroundTransparency = 1
        countLabel.TextColor3 = countColor
        countLabel.TextSize = 11
        countLabel.Font = Enum.Font.Gotham
        countLabel.TextXAlignment = Enum.TextXAlignment.Left
        countLabel.Text = have .. " / " .. ing.Amount
        countLabel.ZIndex = 52
        countLabel.Parent = row

        -- Resource name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -100, 0, 28)
        nameLabel.Position = UDim2.new(0, 96, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        nameLabel.TextSize = 13
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Text = ingName
        nameLabel.ZIndex = 52
        nameLabel.Parent = row

        ingY = ingY + 32
    end

    -- Resize tooltip
    local totalH = 112 + 8 + ingY
    tooltip.Size = UDim2.new(0, 280, 0, totalH)
end

local activeRow = nil
local mainFrameRef = nil

local function positionTooltip()
    if not tooltip or not tooltip.Visible or not mainFrameRef then return end
    local mainSize = mainFrameRef.AbsoluteSize
    local mainPos = mainFrameRef.AbsolutePosition
    local guiInset = GuiService:GetGuiInset()
    
    local tooltipX = mainPos.X + mainSize.X + 8 - guiInset.X
    local tooltipY = mainPos.Y - guiInset.Y
    
    tooltip.Position = UDim2.new(0, tooltipX, 0, tooltipY)
end

local function showTooltip(recipe, row)
    if not tooltip then return end
    activeRow = row
    updateTooltip(recipe)
    positionTooltip()
    tooltip.Visible = true
end

local function hideTooltip()
    if tooltip then tooltip.Visible = false end
    activeRow = nil
end
-- ===== BUILD =====
function CraftPanel.build(parent, contentY, craftRemote, screenGui)
    mainFrameRef = parent

    createTooltip(screenGui)

    craftPanel = Instance.new("ScrollingFrame")
    craftPanel.Name = "CraftPanel"
    craftPanel.Size = UDim2.new(0, UC.contentWidth, 0, UC.contentH)
    craftPanel.Position = UDim2.new(0, UC.windowPadX, 0, contentY)
    craftPanel.BackgroundColor3 = UC.panelBg
    craftPanel.BorderSizePixel = 0
    craftPanel.ScrollBarThickness = 4
    craftPanel.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130)
    craftPanel.Visible = false
    craftPanel.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = craftPanel

    local recipes = Config.Crafting and Config.Crafting.Recipes or {}
    local recipeRowH = 40
    local recipePadding = 4
    local totalH = recipePadding

    for idx, recipe in recipes do
        local row = Instance.new("TextButton")
        row.Name = "Recipe_" .. recipe.Id
        row.Size = UDim2.new(1, -recipePadding * 2, 0, recipeRowH)
        row.Position = UDim2.new(0, recipePadding, 0, totalH)
        row.BackgroundColor3 = Color3.fromRGB(45, 45, 62)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = craftPanel

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 4)
        rowCorner.Parent = row

        -- Иконка
        local iconFrame = Instance.new("Frame")
        iconFrame.Size = UDim2.new(0, 32, 0, 32)
        iconFrame.Position = UDim2.new(0, 4, 0.5, -16)
        iconFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
        iconFrame.BorderSizePixel = 0
        iconFrame.Parent = row

        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(0, 4)
        iconCorner.Parent = iconFrame

        if recipe.Icon and recipe.Icon ~= "" and recipe.Icon ~= "rbxassetid://0" then
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.new(0.8, 0, 0.8, 0)
            img.Position = UDim2.new(0.1, 0, 0.1, 0)
            img.BackgroundTransparency = 1
            img.ScaleType = Enum.ScaleType.Fit
            img.Image = recipe.Icon
            img.Parent = iconFrame
        else
            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1, -4, 1, -4)
            txt.Position = UDim2.new(0, 2, 0, 2)
            txt.BackgroundTransparency = 1
            txt.TextColor3 = Color3.fromRGB(200, 200, 200)
            txt.TextSize = 7
            txt.Font = Enum.Font.GothamBold
            txt.TextWrapped = true
            txt.Text = recipe.Result.Name
            txt.Parent = iconFrame
        end

        -- Название
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -46, 0, recipeRowH)
        nameLabel.Position = UDim2.new(0, 42, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(220, 220, 200)
        nameLabel.TextSize = 13
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Text = recipe.Name
        nameLabel.Parent = row

        -- Hover → tooltip
        row.MouseEnter:Connect(function()
            row.BackgroundColor3 = Color3.fromRGB(55, 55, 78)
            showTooltip(recipe, row)
        end)

        row.MouseLeave:Connect(function()
            row.BackgroundColor3 = Color3.fromRGB(45, 45, 62)
            hideTooltip()
        end)

        -- Click → craft
        row.MouseButton1Click:Connect(function()
            craftRemote:FireServer(recipe.Id)
        end)

        recipeButtons[idx] = {
            frame = row,
            recipe = recipe,
        }

        totalH = totalH + recipeRowH + recipePadding
    end

    craftPanel.CanvasSize = UDim2.new(0, 0, 0, totalH)

    return craftPanel
end

function CraftPanel.refresh(slotsData)
    if not slotsData then return end
    -- Сохраняем для tooltip
    currentData = { slots = slotsData }

    -- Обновляем tooltip если он видим
    if tooltip and tooltip.Visible then
        for _, entry in recipeButtons do
            if entry.frame.BackgroundColor3 == Color3.fromRGB(55, 55, 78) then
                updateTooltip(entry.recipe)
                break
            end
        end
    end
end

function CraftPanel.setVisible(v)
    if craftPanel then craftPanel.Visible = v end
    if not v then hideTooltip() end
end

return CraftPanel