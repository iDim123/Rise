--[[
    CraftStationUI.client.luau
    Универсальный клиентский UI крафтовых станций (Workbench, Forge, ...).
    Структура: заголовок → рецепты (2 колонки, как CraftPanel) → контейнер (1 ряд N слотов).
    При открытии автоматически открывает CharacterWindow.
]] local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local UC = require(script.Parent.Parent:WaitForChild("character"):WaitForChild("UIConstants"))
local ItemTooltip = require(script.Parent.Parent:WaitForChild("tooltip"))
local WindowManager = require(script.Parent.Parent:WaitForChild("WindowManager"))
local DragManager = require(script.Parent.Parent:WaitForChild("character"):WaitForChild("DragManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ Константы ═══
local SLOT_SIZE = UC.slotSize
local PADDING = UC.padding
local HEADER_H = UC.headerH
local CORNER_R = UDim.new(0, 8)
local SMALL_R = UDim.new(0, 4)

local RECIPE_ROW_H = 40
local RECIPE_PAD = 4
local RECIPE_COLS = 2
local PROGRESS_BAR_H = 4 -- полоска внутри рецепта

local SLOT_COLS = 9
local SLOT_SECTION_H = PADDING + SLOT_SIZE + PADDING
local SECTION_PAD = 10
local WINDOW_PAD_X = 10

local SLOT_AREA_W = PADDING + SLOT_COLS * (SLOT_SIZE + PADDING)
local WINDOW_WIDTH = math.max(SLOT_AREA_W + WINDOW_PAD_X * 2, UC.windowWidth + 80)
local WINDOW_HEIGHT = UC.windowHeight

local BG_COLOR = UC.windowBg
local PANEL_BG = UC.panelBg
local SLOT_BG = UC.slotBg
local SLOT_FILLED = UC.slotBgFilled
local SLOT_BORDER = UC.slotBorder
local TEXT_COLOR = UC.textColor

local GOLD_COLOR = Color3.fromRGB(220, 190, 80)
local LABEL_DIM = Color3.fromRGB(150, 150, 170)
local DROP_HIGHLIGHT = Color3.fromRGB(80, 140, 80)
local RECIPE_BG = Color3.fromRGB(45, 45, 62)
local RECIPE_HOVER = Color3.fromRGB(55, 55, 78)
local PROGRESS_FILL_COLOR = Color3.fromRGB(80, 200, 80)
local PROGRESS_BG_COLOR = Color3.fromRGB(30, 30, 40)
local QUEUE_COLOR = Color3.fromRGB(255, 200, 80)

local RIGHT_MARGIN = 40
local TOP_OFFSET = 40

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CraftStationGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 816
screenGui.Parent = playerGui

-- ═══ CharacterWindow link ═══
local function fireCharacterToggle(forceOpen)
    local charGui = playerGui:FindFirstChild("CharacterGui")
    if charGui then
        local toggle = charGui:FindFirstChild("ToggleCharacterWindow")
        if toggle then
            toggle:Fire(forceOpen)
        end
    end
end

-- ═══ Состояние ═══
local isOpen = false
local currentCsId = nil
local currentStationType = nil
local currentSlots = {}
local currentRecipes = {}
local currentCrafting = nil -- { RecipeId, Elapsed, Duration }
local currentQueueCounts = {}

local craftStartTime = 0
local craftStartElapsed = 0

local slotButtons = {}
local recipeButtons = {} -- { [idx] = { frame, recipe, queueLabel, progressBg, progressFill } }

-- ═══ Главное окно ═══
local mainFrame = Instance.new("Frame")
mainFrame.Name = "CraftStationWindow"
mainFrame.Size = UDim2.new(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT)
mainFrame.Position = UDim2.new(1, -RIGHT_MARGIN - WINDOW_WIDTH, 0, TOP_OFFSET)
mainFrame.BackgroundColor3 = BG_COLOR
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = CORNER_R
local ms = Instance.new("UIStroke", mainFrame)
ms.Color = SLOT_BORDER
ms.Thickness = 1

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 0, HEADER_H)
titleLabel.Position = UDim2.new(0, WINDOW_PAD_X, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = TEXT_COLOR
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "Верстак"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.BorderSizePixel = 0
closeBtn.Parent = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = SMALL_R

-- ═══ Recipe section ═══
local recipeSectionLabel = Instance.new("TextLabel")
recipeSectionLabel.Size = UDim2.new(1, -WINDOW_PAD_X * 2, 0, 18)
recipeSectionLabel.Position = UDim2.new(0, WINDOW_PAD_X, 0, HEADER_H + 4)
recipeSectionLabel.BackgroundTransparency = 1
recipeSectionLabel.TextColor3 = LABEL_DIM
recipeSectionLabel.TextSize = 12
recipeSectionLabel.Font = Enum.Font.Gotham
recipeSectionLabel.Text = "Рецепты"
recipeSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
recipeSectionLabel.Parent = mainFrame

local recipeY = HEADER_H + 24
local recipeAreaW = WINDOW_WIDTH - WINDOW_PAD_X * 2
local recipeColW = math.floor((recipeAreaW - RECIPE_PAD) / RECIPE_COLS)

local recipeFrame = Instance.new("ScrollingFrame")
recipeFrame.Name = "RecipeFrame"
recipeFrame.BackgroundColor3 = PANEL_BG
recipeFrame.BorderSizePixel = 0
recipeFrame.ScrollBarThickness = 3
recipeFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130)
recipeFrame.ClipsDescendants = true
recipeFrame.Parent = mainFrame
Instance.new("UICorner", recipeFrame).CornerRadius = UDim.new(0, 6)

-- ═══ Container section ═══
local containerLabel = Instance.new("TextLabel")
containerLabel.Name = "ContainerLabel"
containerLabel.BackgroundTransparency = 1
containerLabel.TextColor3 = GOLD_COLOR
containerLabel.TextSize = 12
containerLabel.Font = Enum.Font.GothamBold
containerLabel.Text = "Контейнер"
containerLabel.TextXAlignment = Enum.TextXAlignment.Left
containerLabel.Parent = mainFrame

local containerFrame = Instance.new("Frame")
containerFrame.Name = "ContainerFrame"
containerFrame.BackgroundColor3 = PANEL_BG
containerFrame.BorderSizePixel = 0
containerFrame.Parent = mainFrame
Instance.new("UICorner", containerFrame).CornerRadius = UDim.new(0, 6)

-- ═══ Layout ═══
local function layoutWindow()
    local containerH = PADDING + SLOT_SIZE + PADDING
    local containerLabelH = 18
    local bottomSection = containerLabelH + containerH + SECTION_PAD
    local recipeAreaH = WINDOW_HEIGHT - recipeY - bottomSection - SECTION_PAD
    if recipeAreaH < 60 then
        recipeAreaH = 60
    end

    recipeFrame.Size = UDim2.new(0, recipeAreaW, 0, recipeAreaH)
    recipeFrame.Position = UDim2.new(0, WINDOW_PAD_X, 0, recipeY)

    local containerY = recipeY + recipeAreaH + SECTION_PAD
    containerLabel.Size = UDim2.new(0, recipeAreaW, 0, 16)
    containerLabel.Position = UDim2.new(0, WINDOW_PAD_X, 0, containerY)

    local slotAreaW = PADDING + SLOT_COLS * (SLOT_SIZE + PADDING)
    containerFrame.Size = UDim2.new(0, slotAreaW, 0, containerH)
    containerFrame.Position = UDim2.new(0, WINDOW_PAD_X, 0, containerY + containerLabelH)
end

-- ═══ Build slot ═══
local function buildContainerSlot(slotIndex, col)
    local slot = currentSlots[slotIndex]

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    btn.Position = UDim2.new(0, PADDING + col * (SLOT_SIZE + PADDING), 0, PADDING)
    btn.BackgroundColor3 = (slot and slot ~= false) and SLOT_FILLED or SLOT_BG
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = containerFrame
    Instance.new("UICorner", btn).CornerRadius = SMALL_R
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = SLOT_BORDER
    stroke.Thickness = 1

    if slot and slot ~= false then
        local itemDef = Config.Items[slot.ItemId]
        if itemDef and itemDef.Icon and itemDef.Icon ~= "" and itemDef.Icon ~= "rbxassetid://0" then
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.new(0, 36, 0, 36)
            img.Position = UDim2.new(0.5, -18, 0, 2)
            img.BackgroundTransparency = 1
            img.Image = itemDef.Icon
            img.ScaleType = Enum.ScaleType.Fit
            img.Parent = btn
        else
            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1, -4, 0, 36)
            txt.Position = UDim2.new(0, 2, 0, 2)
            txt.BackgroundTransparency = 1
            txt.TextColor3 = TEXT_COLOR
            txt.TextSize = 8
            txt.Font = Enum.Font.GothamBold
            txt.TextWrapped = true
            txt.Text = itemDef and itemDef.Name or slot.ItemId
            txt.Parent = btn
        end
        if slot.Amount and slot.Amount > 1 then
            local amtLabel = Instance.new("TextLabel")
            amtLabel.Size = UDim2.new(1, -4, 0, 14)
            amtLabel.Position = UDim2.new(0, 2, 1, -16)
            amtLabel.BackgroundTransparency = 1
            amtLabel.Text = tostring(slot.Amount)
            amtLabel.TextColor3 = TEXT_COLOR
            amtLabel.Font = Enum.Font.GothamBold
            amtLabel.TextSize = 12
            amtLabel.TextXAlignment = Enum.TextXAlignment.Right
            amtLabel.Parent = btn
        end
    end

    return btn
end

-- ═══ Rebuild container slots ═══
local function unregisterSlotDropTargets()
    for _, btn in slotButtons do
        DragManager.unregisterDropTarget(btn)
    end
end

local function rebuildContainerSlots()
    unregisterSlotDropTargets()
    for _, btn in slotButtons do
        btn:Destroy()
    end
    slotButtons = {}

    local slotCount = #currentSlots
    for i = 1, slotCount do
        local col = i - 1
        local si = i
        local btn = buildContainerSlot(i, col)

        -- ЛКМ — drag
        btn.MouseButton1Down:Connect(function()
            local slot = currentSlots[si]
            if slot and slot ~= false then
                local itemDef = Config.Items[slot.ItemId]
                DragManager.startDrag(si, {
                    Id = slot.ItemId,
                    Name = itemDef and itemDef.Name or slot.ItemId,
                    Icon = itemDef and itemDef.Icon or "",
                    Amount = slot.Amount or 1
                }, "craftStationSlot", {
                    csId = currentCsId
                })
                btn.BackgroundColor3 = UC.slotBgDrag or Color3.fromRGB(80, 80, 100)
            end
        end)

        -- ПКМ — забрать в инвентарь
        btn.MouseButton2Click:Connect(function()
            if currentCsId then
                Remotes.CraftStationTakeItem:FireServer(currentCsId, si)
            end
        end)

        -- Hover для tooltip
        btn.MouseEnter:Connect(function()
            if DragManager.isDragging() then
                btn.BackgroundColor3 = DROP_HIGHLIGHT
            else
                local slot = currentSlots[si]
                if slot and slot ~= false then
                    local itemDef = Config.Items[slot.ItemId]
                    ItemTooltip.show({
                        Id = slot.ItemId,
                        Name = itemDef and itemDef.Name or slot.ItemId,
                        Amount = slot.Amount or 1
                    }, btn)
                end
            end
        end)
        btn.MouseLeave:Connect(function()
            ItemTooltip.hide()
            local slot = currentSlots[si]
            btn.BackgroundColor3 = (slot and slot ~= false) and SLOT_FILLED or SLOT_BG
        end)

        -- Drop target (deposit из инвентаря)
        DragManager.registerDropTarget(btn, function(dd)
            if not dd then
                return
            end
            if dd.source == "inventory" and currentCsId then
                Remotes.CraftStationDeposit:FireServer(currentCsId, dd.slotIndex)
            end
        end)

        slotButtons[si] = btn
    end
end

-- ═══ Recipe list (2 columns, like CraftPanel) ═══
local function buildRecipeList()
    for _, entry in recipeButtons do
        if entry.frame then
            entry.frame:Destroy()
        end
    end
    recipeButtons = {}

    local totalH = RECIPE_PAD

    for idx, recipe in currentRecipes do
        local col = (idx - 1) % RECIPE_COLS
        local row = math.floor((idx - 1) / RECIPE_COLS)
        local xPos = RECIPE_PAD + col * (recipeColW + RECIPE_PAD)
        local yPos = RECIPE_PAD + row * (RECIPE_ROW_H + RECIPE_PAD)

        local recipeRow = Instance.new("TextButton")
        recipeRow.Name = "Recipe_" .. recipe.Id
        recipeRow.Size = UDim2.new(0, recipeColW - RECIPE_PAD, 0, RECIPE_ROW_H)
        recipeRow.Position = UDim2.new(0, xPos, 0, yPos)
        recipeRow.BackgroundColor3 = RECIPE_BG
        recipeRow.BorderSizePixel = 0
        recipeRow.Text = ""
        recipeRow.AutoButtonColor = false
        recipeRow.ClipsDescendants = true
        recipeRow.Parent = recipeFrame
        Instance.new("UICorner", recipeRow).CornerRadius = SMALL_R

        -- Иконка
        local iconFrame = Instance.new("Frame")
        iconFrame.Size = UDim2.new(0, 32, 0, 32)
        iconFrame.Position = UDim2.new(0, 4, 0.5, -16)
        iconFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
        iconFrame.BorderSizePixel = 0
        iconFrame.Parent = recipeRow
        Instance.new("UICorner", iconFrame).CornerRadius = SMALL_R

        local firstResult = recipe.Results and recipe.Results[1] or recipe.Result
        if firstResult then
            local resultDef = Config.Items[firstResult.ItemId]
            if resultDef and resultDef.Icon and resultDef.Icon ~= "" and resultDef.Icon ~= "rbxassetid://0" then
                local img = Instance.new("ImageLabel")
                img.Size = UDim2.new(0.8, 0, 0.8, 0)
                img.Position = UDim2.new(0.1, 0, 0.1, 0)
                img.BackgroundTransparency = 1
                img.Image = resultDef.Icon
                img.ScaleType = Enum.ScaleType.Fit
                img.Parent = iconFrame
            else
                local txt = Instance.new("TextLabel")
                txt.Size = UDim2.new(1, -4, 1, -4)
                txt.Position = UDim2.new(0, 2, 0, 2)
                txt.BackgroundTransparency = 1
                txt.TextColor3 = TEXT_COLOR
                txt.TextSize = 7
                txt.Font = Enum.Font.GothamBold
                txt.TextWrapped = true
                txt.Text = resultDef and resultDef.Name or firstResult.ItemId
                txt.Parent = iconFrame
            end
        end

        -- Название
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -90, 0, RECIPE_ROW_H)
        nameLabel.Position = UDim2.new(0, 42, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(220, 220, 200)
        nameLabel.TextSize = 11
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Text = recipe.Name
        nameLabel.Parent = recipeRow

        -- Счётчик очереди
        local queueLabel = Instance.new("TextLabel")
        queueLabel.Name = "QueueLabel"
        queueLabel.Size = UDim2.new(0, 40, 0, RECIPE_ROW_H)
        queueLabel.Position = UDim2.new(1, -44, 0, 0)
        queueLabel.BackgroundTransparency = 1
        queueLabel.TextColor3 = QUEUE_COLOR
        queueLabel.TextSize = 13
        queueLabel.Font = Enum.Font.GothamBold
        queueLabel.TextXAlignment = Enum.TextXAlignment.Right
        queueLabel.Text = ""
        queueLabel.Visible = false
        queueLabel.Parent = recipeRow

        -- Progress bar (внизу рецепта)
        local progressBg = Instance.new("Frame")
        progressBg.Name = "ProgressBg"
        progressBg.Size = UDim2.new(1, 0, 0, PROGRESS_BAR_H)
        progressBg.Position = UDim2.new(0, 0, 1, -PROGRESS_BAR_H)
        progressBg.BackgroundColor3 = PROGRESS_BG_COLOR
        progressBg.BorderSizePixel = 0
        progressBg.Visible = false
        progressBg.Parent = recipeRow

        local progressFill = Instance.new("Frame")
        progressFill.Name = "ProgressFill"
        progressFill.Size = UDim2.new(0, 0, 1, 0)
        progressFill.BackgroundColor3 = PROGRESS_FILL_COLOR
        progressFill.BorderSizePixel = 0
        progressFill.Parent = progressBg
        Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 2)

        -- Hover → tooltip
        recipeRow.MouseEnter:Connect(function()
            recipeRow.BackgroundColor3 = RECIPE_HOVER
            showTooltip(recipe)
        end)
        recipeRow.MouseLeave:Connect(function()
            recipeRow.BackgroundColor3 = RECIPE_BG
            hideTooltip()
        end)

        -- Click → craft
        recipeRow.MouseButton1Click:Connect(function()
            if currentCsId then
                Remotes.CraftStationCraft:FireServer(currentCsId, recipe.Id)
            end
        end)

        recipeButtons[idx] = {
            frame = recipeRow,
            recipe = recipe,
            queueLabel = queueLabel,
            progressBg = progressBg,
            progressFill = progressFill
        }

        totalH = math.max(totalH, yPos + RECIPE_ROW_H + RECIPE_PAD)
    end

    recipeFrame.CanvasSize = UDim2.new(0, 0, 0, totalH)
end

-- ═══ Update queue display + progress ═══
local function updateQueueDisplay()
    for _, entry in recipeButtons do
        local count = currentQueueCounts[entry.recipe.Id] or 0
        local queueLabel = entry.queueLabel
        local progressBg = entry.progressBg
        local progressFill = entry.progressFill

        if count > 0 then
            queueLabel.Text = "x" .. count
            queueLabel.Visible = true
        else
            queueLabel.Text = ""
            queueLabel.Visible = false
        end

        -- Прогресс — только для текущего крафтящегося рецепта
        if currentCrafting and currentCrafting.RecipeId == entry.recipe.Id then
            progressBg.Visible = true
            local now = os.clock()
            local elapsed = craftStartElapsed + (now - craftStartTime)
            local ratio = math.clamp(elapsed / currentCrafting.Duration, 0, 1)
            progressFill.Size = UDim2.new(ratio, 0, 1, 0)
        elseif count > 0 then
            progressBg.Visible = true
            progressFill.Size = UDim2.new(0, 0, 1, 0)
        else
            progressBg.Visible = false
            progressFill.Size = UDim2.new(0, 0, 1, 0)
        end
    end
end

-- ═══ Refresh all ═══
local function refreshAll()
    rebuildContainerSlots()
    updateQueueDisplay()
end

-- ═══ Public state for SlotBehavior ═══
local csOpenState = Instance.new("BoolValue")
csOpenState.Name = "CraftStationOpen"
csOpenState.Value = false
csOpenState.Parent = screenGui

local csIdValue = Instance.new("StringValue")
csIdValue.Name = "CraftStationOpenId"
csIdValue.Value = ""
csIdValue.Parent = screenGui

local function syncState()
    csOpenState.Value = isOpen and currentCsId ~= nil
    csIdValue.Value = currentCsId or ""
end

-- ═══ Tooltip (реюз паттерна из CraftPanel) ═══
local tooltip = nil

local function createTooltip()
    local frame = Instance.new("Frame")
    frame.Name = "CraftStationTooltip"
    frame.Size = UDim2.new(0, 280, 0, 200)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = 50
    frame.Parent = screenGui

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(80, 80, 110)
    stroke.Thickness = 1

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
    titleLabel.ZIndex = 51
    titleLabel.Parent = frame

    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "IconFrame"
    iconFrame.Size = UDim2.new(0, 44, 0, 44)
    iconFrame.Position = UDim2.new(1, -52, 0, 6)
    iconFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 68)
    iconFrame.BorderSizePixel = 0
    iconFrame.ZIndex = 51
    iconFrame.Parent = frame
    Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(0, 4)
    local iconStroke = Instance.new("UIStroke", iconFrame)
    iconStroke.Color = Color3.fromRGB(80, 130, 220)
    iconStroke.Thickness = 1

    local iconImage = Instance.new("ImageLabel")
    iconImage.Name = "Icon"
    iconImage.Size = UDim2.new(0.8, 0, 0.8, 0)
    iconImage.Position = UDim2.new(0.1, 0, 0.1, 0)
    iconImage.BackgroundTransparency = 1
    iconImage.ScaleType = Enum.ScaleType.Fit
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
    iconText.Visible = false
    iconText.ZIndex = 52
    iconText.Parent = iconFrame

    local subtitleLabel = Instance.new("TextLabel")
    subtitleLabel.Name = "Subtitle"
    subtitleLabel.Size = UDim2.new(1, -70, 0, 14)
    subtitleLabel.Position = UDim2.new(0, 10, 0, 32)
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    subtitleLabel.TextSize = 11
    subtitleLabel.Font = Enum.Font.Gotham
    subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    subtitleLabel.ZIndex = 51
    subtitleLabel.Parent = frame

    local sep1 = Instance.new("Frame")
    sep1.Size = UDim2.new(1, -20, 0, 1)
    sep1.Position = UDim2.new(0, 10, 0, 52)
    sep1.BackgroundColor3 = Color3.fromRGB(70, 100, 200)
    sep1.BorderSizePixel = 0
    sep1.ZIndex = 51
    sep1.Parent = frame

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
    descLabel.ZIndex = 51
    descLabel.Parent = frame

    local sep2 = Instance.new("Frame")
    sep2.Size = UDim2.new(1, -20, 0, 1)
    sep2.Position = UDim2.new(0, 10, 0, 104)
    sep2.BackgroundColor3 = Color3.fromRGB(70, 100, 200)
    sep2.BorderSizePixel = 0
    sep2.ZIndex = 51
    sep2.Parent = frame

    local ingContainer = Instance.new("Frame")
    ingContainer.Name = "Ingredients"
    ingContainer.Size = UDim2.new(1, -20, 0, 80)
    ingContainer.Position = UDim2.new(0, 10, 0, 112)
    ingContainer.BackgroundTransparency = 1
    ingContainer.ZIndex = 51
    ingContainer.Parent = frame

    tooltip = frame
end

local function updateTooltip(recipe)
    if not tooltip then return end

    local titleLabel = tooltip:FindFirstChild("Title")
    local iconFrame = tooltip:FindFirstChild("IconFrame")
    local subtitleLabel = tooltip:FindFirstChild("Subtitle")
    local descLabel = tooltip:FindFirstChild("Description")
    local ingContainer = tooltip:FindFirstChild("Ingredients")

    local firstResult = recipe.Results and recipe.Results[1] or recipe.Result
    local resultItem = firstResult and Config.Items[firstResult.ItemId]

    titleLabel.Text = recipe.Name

    local iconImage = iconFrame:FindFirstChild("Icon")
    local iconText = iconFrame:FindFirstChild("IconText")
    if recipe.Icon and recipe.Icon ~= "" and recipe.Icon ~= "rbxassetid://0" then
        iconImage.Image = recipe.Icon
        iconImage.Visible = true
        iconText.Visible = false
    else
        iconImage.Visible = false
        iconText.Text = resultItem and resultItem.Name or (firstResult and firstResult.ItemId or "?")
        iconText.Visible = true
    end

    local craftTimeStr = recipe.CraftTime and recipe.CraftTime > 0 and (recipe.CraftTime .. "s") or "Instant"
    local resultType = resultItem and resultItem.Type or "Item"
    subtitleLabel.Text = resultType .. "    " .. craftTimeStr

    descLabel.Text = recipe.Description or ""

    for _, child in ingContainer:GetChildren() do
        child:Destroy()
    end

    -- Подсчёт ресурсов: контейнер + инвентарь
    local itemCounts = {}
    for _, slot in currentSlots do
        if slot and slot ~= false then
            local id = slot.ItemId or slot.Id
            itemCounts[id] = (itemCounts[id] or 0) + (slot.Amount or 1)
        end
    end

    -- Запрашиваем данные инвентаря из CharacterGui
    local invData = nil
    pcall(function()
        invData = Remotes.GetInventory:InvokeServer()
    end)
    if invData and invData.slots then
        for _, slot in invData.slots do
            if slot and slot ~= false then
                local id = slot.Id or slot.ItemId
                itemCounts[id] = (itemCounts[id] or 0) + (slot.Amount or 1)
            end
        end
    end

    local ingY = 4
    for _, ing in recipe.Ingredients do
        local itemDef = Config.Items[ing.ItemId]
        local ingName = itemDef and itemDef.Name or ing.ItemId
        local have = itemCounts[ing.ItemId] or 0

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 28)
        row.Position = UDim2.new(0, 0, 0, ingY)
        row.BackgroundTransparency = 1
        row.ZIndex = 52
        row.Parent = ingContainer

        local miniIcon = Instance.new("Frame")
        miniIcon.Size = UDim2.new(0, 24, 0, 24)
        miniIcon.Position = UDim2.new(0, 0, 0, 2)
        miniIcon.BackgroundColor3 = Color3.fromRGB(50, 50, 68)
        miniIcon.BorderSizePixel = 0
        miniIcon.ZIndex = 52
        miniIcon.Parent = row
        Instance.new("UICorner", miniIcon).CornerRadius = UDim.new(0, 3)
        local ms = Instance.new("UIStroke", miniIcon)
        ms.Color = Color3.fromRGB(80, 130, 220)
        ms.Thickness = 1

        if itemDef and itemDef.Icon and itemDef.Icon ~= "" and itemDef.Icon ~= "rbxassetid://0" then
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.new(0.8, 0, 0.8, 0)
            img.Position = UDim2.new(0.1, 0, 0.1, 0)
            img.BackgroundTransparency = 1
            img.Image = itemDef.Icon
            img.ZIndex = 53
            img.Parent = miniIcon
        end

        local countColor = have >= ing.Amount and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(200, 100, 100)

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

        ingY += 32
    end

    local totalH = 112 + 8 + ingY
    tooltip.Size = UDim2.new(0, 280, 0, totalH)
end

local function positionTooltip()
    if not tooltip then return end
    -- Ставим справа от окна
    local x = mainFrame.AbsolutePosition.X + WINDOW_WIDTH + 8
    tooltip.Position = UDim2.new(0, x, 0, TOP_OFFSET)
end

local function showTooltip(recipe)
    if not tooltip then return end
    updateTooltip(recipe)
    positionTooltip()
    tooltip.Visible = true
end

local function hideTooltip()
    if tooltip then
        tooltip.Visible = false
    end
end

-- ═══ Open / Close ═══
local function closeStation()
    unregisterSlotDropTargets()
    hideTooltip()
    if currentCsId then
        Remotes.CraftStationClose:FireServer(currentCsId)
    end
    currentCsId = nil
    currentStationType = nil
    isOpen = false
    mainFrame.Visible = false
    WindowManager.remove("CraftStationUI")
    fireCharacterToggle(false)
    syncState()
end

local function openStation(payload)
    currentCsId = payload.CsId
    currentStationType = payload.StationType
    currentSlots = payload.Slots or {}
    currentRecipes = payload.Recipes or {}
    currentCrafting = payload.Crafting
    currentQueueCounts = payload.QueueCounts or {}

    titleLabel.Text = payload.StationName or payload.StationType or "Крафтовая станция"

    if currentCrafting then
        craftStartElapsed = currentCrafting.Elapsed or 0
        craftStartTime = os.clock()
    end

    isOpen = true
    mainFrame.Visible = true

    layoutWindow()
    buildRecipeList()
    refreshAll()

    fireCharacterToggle(true)

    WindowManager.push("CraftStationUI", function()
        closeStation()
    end)

    syncState()
end

-- ═══ Remotes ═══
Remotes.CraftStationOpened.OnClientEvent:Connect(function(payload)
    openStation(payload)
end)

Remotes.CraftStationUpdate.OnClientEvent:Connect(function(payload)
    if not currentCsId or payload.CsId ~= currentCsId then
        return
    end
    currentSlots = payload.Slots or currentSlots
    currentQueueCounts = payload.QueueCounts or currentQueueCounts
    currentCrafting = payload.Crafting
    if currentCrafting then
        craftStartElapsed = currentCrafting.Elapsed or 0
        craftStartTime = os.clock()
    end
    refreshAll()
end)

Remotes.CraftStationClosed.OnClientEvent:Connect(function(csId)
    if currentCsId == csId then
        unregisterSlotDropTargets()
        hideTooltip()
        currentCsId = nil
        currentStationType = nil
        isOpen = false
        mainFrame.Visible = false
        WindowManager.remove("CraftStationUI")
        syncState()
    end
end)

-- ═══ Buttons ═══
closeBtn.MouseButton1Click:Connect(function()
    closeStation()
end)

-- ═══ RenderStepped — интерполяция прогресса ═══
RunService.RenderStepped:Connect(function()
    if isOpen and currentCrafting then
        updateQueueDisplay()
    end
end)

-- ═══ Tooltip init ═══
createTooltip()
