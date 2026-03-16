--[[
    SawmillUI.client.luau
    Клиентский UI лесопилки.

    Открывается по F через SawmillOpened ремот.
    Стилистика и размеры слотов из UIConstants.
    Ширина окна больше CharacterWindow, высота — та же.
    Рецепты в 2 колонки с кнопкой toggle (зелёный/красный).
    Input (2×4) и Output (2×4) зоны внизу.
    Прогресс-бар текущего крафта.

    Зависимости: UIConstants, Config, Remotes, WindowManager, ItemTooltip
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local UC = require(script.Parent.Parent:WaitForChild("character"):WaitForChild("UIConstants"))
local ItemTooltip = require(script.Parent.Parent:WaitForChild("tooltip"))
local WindowManager = require(script.Parent.Parent:WaitForChild("WindowManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════
-- Константы раскладки
-- ═══════════════════════════════════════════════════════════

local SLOT_SIZE = UC.slotSize          -- 50
local PADDING = UC.padding             -- 5
local HEADER_H = UC.headerH            -- 36
local CORNER_R = UDim.new(0, 8)
local SMALL_R = UDim.new(0, 4)

-- Рецепты: 2 колонки
local RECIPE_ROW_H = 44
local RECIPE_PAD = 4
local RECIPE_COLS = 2
local TOGGLE_SIZE = 20

-- Input/Output: 4 колонки × 2 ряда = 8 слотов
local IO_COLS = 4
local IO_ROWS = 2

-- Размеры зон
local IO_GRID_W = PADDING + IO_COLS * (SLOT_SIZE + PADDING)
local IO_GRID_H = PADDING + IO_ROWS * (SLOT_SIZE + PADDING)

-- Ширина окна: input + gap + output + gap + padding
local IO_GAP = 16
local SECTION_PAD = 10
local WINDOW_PAD_X = 10

-- Рецепт-зона: ширина окна минус отступы
-- Сначала рассчитаем ширину по IO зонам
local WINDOW_WIDTH = WINDOW_PAD_X + IO_GRID_W + IO_GAP + IO_GRID_W + WINDOW_PAD_X
-- Убеждаемся что окно шире CharacterWindow
if WINDOW_WIDTH < UC.windowWidth + 80 then
    WINDOW_WIDTH = UC.windowWidth + 80
end

local WINDOW_HEIGHT = UC.windowHeight  -- высота как у CharacterWindow

-- Цвета (из UIConstants)
local BG_COLOR = UC.windowBg           -- Color3.fromRGB(25, 25, 35)
local PANEL_BG = UC.panelBg            -- Color3.fromRGB(35, 35, 50)
local SLOT_BG = UC.slotBg              -- Color3.fromRGB(50, 50, 65)
local SLOT_FILLED = UC.slotBgFilled    -- Color3.fromRGB(60, 60, 80)
local SLOT_BORDER = UC.slotBorder      -- Color3.fromRGB(80, 80, 100)
local TEXT_COLOR = UC.textColor         -- Color3.fromRGB(220, 220, 220)
local TAB_ACTIVE = UC.tabActive        -- Color3.fromRGB(60, 100, 60)
local TAB_INACTIVE = UC.tabInactive    -- Color3.fromRGB(50, 50, 70)

local TOGGLE_ON = Color3.fromRGB(50, 180, 50)
local TOGGLE_OFF = Color3.fromRGB(180, 50, 50)
local PROGRESS_BG = Color3.fromRGB(30, 30, 40)
local PROGRESS_FILL = Color3.fromRGB(80, 200, 80)
local GOLD_COLOR = Color3.fromRGB(220, 190, 80)
local LABEL_DIM = Color3.fromRGB(150, 150, 170)

-- ═══════════════════════════════════════════════════════════
-- ScreenGui
-- ═══════════════════════════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SawmillGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 14
screenGui.Parent = playerGui

-- ═══════════════════════════════════════════════════════════
-- Состояние
-- ═══════════════════════════════════════════════════════════

local isOpen = false
local currentSawmillId = nil
local currentInputSlots = {}
local currentOutputSlots = {}
local currentRecipeToggles = {}
local currentRecipes = {}
local currentCrafting = nil -- { RecipeId, Elapsed, Duration }

local inputSlotButtons = {}
local outputSlotButtons = {}
local recipeButtons = {}

-- ═══════════════════════════════════════════════════════════
-- Главное окно
-- ═══════════════════════════════════════════════════════════

local mainFrame = Instance.new("Frame")
mainFrame.Name = "SawmillWindow"
mainFrame.Size = UDim2.new(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT)
mainFrame.Position = UDim2.new(0.5, -WINDOW_WIDTH / 2, 0.5, -WINDOW_HEIGHT / 2)
mainFrame.BackgroundColor3 = BG_COLOR
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = CORNER_R
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = SLOT_BORDER
mainStroke.Thickness = 1
mainStroke.Parent = mainFrame

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 0, HEADER_H)
titleLabel.Position = UDim2.new(0, WINDOW_PAD_X, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = TEXT_COLOR
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "Лесопилка"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

-- Close button
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

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = SMALL_R
closeBtnCorner.Parent = closeBtn

-- ═══════════════════════════════════════════════════════════
-- Секция рецептов (верхняя часть)
-- ═══════════════════════════════════════════════════════════

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

local recipeFrameCorner = Instance.new("UICorner")
recipeFrameCorner.CornerRadius = UDim.new(0, 6)
recipeFrameCorner.Parent = recipeFrame

-- ═══════════════════════════════════════════════════════════
-- Прогресс-бар (между рецептами и IO)
-- ═══════════════════════════════════════════════════════════

local PROGRESS_H = 22

local progressFrame = Instance.new("Frame")
progressFrame.Name = "ProgressBar"
progressFrame.BackgroundColor3 = PROGRESS_BG
progressFrame.BorderSizePixel = 0
progressFrame.Parent = mainFrame

local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(0, 4)
progressCorner.Parent = progressFrame

local progressFill = Instance.new("Frame")
progressFill.Name = "Fill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = PROGRESS_FILL
progressFill.BorderSizePixel = 0
progressFill.Parent = progressFrame

local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(0, 4)
progressFillCorner.Parent = progressFill

local progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.new(1, 0, 1, 0)
progressLabel.BackgroundTransparency = 1
progressLabel.TextColor3 = TEXT_COLOR
progressLabel.TextSize = 11
progressLabel.Font = Enum.Font.GothamBold
progressLabel.Text = ""
progressLabel.ZIndex = 2
progressLabel.Parent = progressFrame

-- ═══════════════════════════════════════════════════════════
-- IO секции (нижняя часть)
-- ═══════════════════════════════════════════════════════════

-- Input label
local inputLabel = Instance.new("TextLabel")
inputLabel.Name = "InputLabel"
inputLabel.BackgroundTransparency = 1
inputLabel.TextColor3 = GOLD_COLOR
inputLabel.TextSize = 12
inputLabel.Font = Enum.Font.GothamBold
inputLabel.Text = "Вход"
inputLabel.TextXAlignment = Enum.TextXAlignment.Left
inputLabel.Parent = mainFrame

-- Input frame
local inputFrame = Instance.new("Frame")
inputFrame.Name = "InputFrame"
inputFrame.Size = UDim2.new(0, IO_GRID_W, 0, IO_GRID_H)
inputFrame.BackgroundColor3 = PANEL_BG
inputFrame.BorderSizePixel = 0
inputFrame.Parent = mainFrame

local inputFrameCorner = Instance.new("UICorner")
inputFrameCorner.CornerRadius = UDim.new(0, 6)
inputFrameCorner.Parent = inputFrame

-- Output label
local outputLabel = Instance.new("TextLabel")
outputLabel.Name = "OutputLabel"
outputLabel.BackgroundTransparency = 1
outputLabel.TextColor3 = GOLD_COLOR
outputLabel.TextSize = 12
outputLabel.Font = Enum.Font.GothamBold
outputLabel.Text = "Выход"
outputLabel.TextXAlignment = Enum.TextXAlignment.Left
outputLabel.Parent = mainFrame

-- Output frame
local outputFrame = Instance.new("Frame")
outputFrame.Name = "OutputFrame"
outputFrame.Size = UDim2.new(0, IO_GRID_W, 0, IO_GRID_H)
outputFrame.BackgroundColor3 = PANEL_BG
outputFrame.BorderSizePixel = 0
outputFrame.Parent = mainFrame

local outputFrameCorner = Instance.new("UICorner")
outputFrameCorner.CornerRadius = UDim.new(0, 6)
outputFrameCorner.Parent = outputFrame

-- Take All button (в зоне output)
local btnTakeAll = Instance.new("TextButton")
btnTakeAll.Size = UDim2.new(0, IO_GRID_W, 0, 24)
btnTakeAll.BackgroundColor3 = Color3.fromRGB(50, 130, 50)
btnTakeAll.Text = "Забрать всё"
btnTakeAll.TextColor3 = Color3.fromRGB(255, 255, 255)
btnTakeAll.Font = Enum.Font.GothamBold
btnTakeAll.TextSize = 12
btnTakeAll.BorderSizePixel = 0
btnTakeAll.Parent = mainFrame

local takeAllCorner = Instance.new("UICorner")
takeAllCorner.CornerRadius = SMALL_R
takeAllCorner.Parent = btnTakeAll

-- ═══════════════════════════════════════════════════════════
-- Расчёт раскладки (вызывается при открытии)
-- ═══════════════════════════════════════════════════════════

local function layoutWindow()
    -- Рецепт-секция: от recipeY до IO-секции
    -- IO-секция: фиксированная высота снизу
    local IO_SECTION_H = 18 + IO_GRID_H + 4 + 24 + SECTION_PAD -- label + grid + gap + takeAll + pad
    local PROGRESS_SECTION_H = PROGRESS_H + 8

    local recipeAreaH = WINDOW_HEIGHT - recipeY - PROGRESS_SECTION_H - IO_SECTION_H - SECTION_PAD
    if recipeAreaH < 60 then recipeAreaH = 60 end

    recipeFrame.Size = UDim2.new(0, recipeAreaW, 0, recipeAreaH)
    recipeFrame.Position = UDim2.new(0, WINDOW_PAD_X, 0, recipeY)

    -- Progress bar
    local progressY = recipeY + recipeAreaH + 4
    progressFrame.Size = UDim2.new(0, recipeAreaW, 0, PROGRESS_H)
    progressFrame.Position = UDim2.new(0, WINDOW_PAD_X, 0, progressY)

    -- IO section
    local ioY = progressY + PROGRESS_H + 8

    -- Input (left)
    local inputX = WINDOW_PAD_X
    inputLabel.Size = UDim2.new(0, IO_GRID_W, 0, 16)
    inputLabel.Position = UDim2.new(0, inputX, 0, ioY)
    inputFrame.Position = UDim2.new(0, inputX, 0, ioY + 18)

    -- Output (right)
    local outputX = WINDOW_WIDTH - WINDOW_PAD_X - IO_GRID_W
    outputLabel.Size = UDim2.new(0, IO_GRID_W, 0, 16)
    outputLabel.Position = UDim2.new(0, outputX, 0, ioY)
    outputFrame.Position = UDim2.new(0, outputX, 0, ioY + 18)

    -- Take All button (under output)
    btnTakeAll.Position = UDim2.new(0, outputX, 0, ioY + 18 + IO_GRID_H + 4)
end

-- ═══════════════════════════════════════════════════════════
-- Построение слотов
-- ═══════════════════════════════════════════════════════════

local function buildSlot(parent, slots, slotIndex, col, row, onClick)
    local slot = slots[slotIndex]
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    btn.Position = UDim2.new(0, PADDING + col * (SLOT_SIZE + PADDING), 0, PADDING + row * (SLOT_SIZE + PADDING))
    btn.BackgroundColor3 = (slot and slot ~= false) and SLOT_FILLED or SLOT_BG
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = SMALL_R
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = SLOT_BORDER
    stroke.Thickness = 1
    stroke.Parent = btn

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

        -- Tooltip
        btn.MouseEnter:Connect(function()
            local tooltipData = {
                Id = slot.ItemId,
                Name = itemDef and itemDef.Name or slot.ItemId,
                Amount = slot.Amount or 1,
            }
            ItemTooltip.show(tooltipData, btn)
        end)
        btn.MouseLeave:Connect(function()
            ItemTooltip.hide()
        end)
    end

    if onClick then
        btn.MouseButton1Click:Connect(onClick)
        btn.MouseButton2Click:Connect(onClick)
    end

    return btn
end

local function rebuildInputSlots()
    for _, btn in inputSlotButtons do btn:Destroy() end
    inputSlotButtons = {}

    for i = 1, 8 do
        local col = (i - 1) % IO_COLS
        local row = math.floor((i - 1) / IO_COLS)
        -- Клик по input слоту — ничего (предметы кладутся из инвентаря ПКМ)
        local btn = buildSlot(inputFrame, currentInputSlots, i, col, row, nil)
        inputSlotButtons[i] = btn
    end
end

local function rebuildOutputSlots()
    for _, btn in outputSlotButtons do btn:Destroy() end
    outputSlotButtons = {}

    for i = 1, 8 do
        local col = (i - 1) % IO_COLS
        local row = math.floor((i - 1) / IO_COLS)
        local slotIndex = i
        local btn = buildSlot(outputFrame, currentOutputSlots, i, col, row, function()
            if currentSawmillId then
                Remotes.SawmillTakeItem:FireServer(currentSawmillId, slotIndex)
            end
        end)
        outputSlotButtons[i] = btn
    end
end

-- ═══════════════════════════════════════════════════════════
-- Построение рецептов (2 колонки)
-- ═══════════════════════════════════════════════════════════

local function buildRecipeList()
    for _, entry in recipeButtons do
        if entry.frame then entry.frame:Destroy() end
    end
    recipeButtons = {}

    local totalH = RECIPE_PAD
    local rowIndex = 0

    for idx, recipe in currentRecipes do
        local col = (idx - 1) % RECIPE_COLS
        if col == 0 and idx > 1 then
            rowIndex += 1
        end

        local row = math.floor((idx - 1) / RECIPE_COLS)
        local xPos = RECIPE_PAD + col * (recipeColW + RECIPE_PAD)
        local yPos = RECIPE_PAD + row * (RECIPE_ROW_H + RECIPE_PAD)

        local recipeRow = Instance.new("Frame")
        recipeRow.Name = "Recipe_" .. recipe.Id
        recipeRow.Size = UDim2.new(0, recipeColW - RECIPE_PAD, 0, RECIPE_ROW_H)
        recipeRow.Position = UDim2.new(0, xPos, 0, yPos)
        recipeRow.BackgroundColor3 = Color3.fromRGB(45, 45, 62)
        recipeRow.BorderSizePixel = 0
        recipeRow.ClipsDescendants = true
        recipeRow.Parent = recipeFrame

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = SMALL_R
        rowCorner.Parent = recipeRow

        -- Toggle button (circle)
        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, TOGGLE_SIZE, 0, TOGGLE_SIZE)
        toggleBtn.Position = UDim2.new(0, 4, 0.5, -TOGGLE_SIZE / 2)
        toggleBtn.Text = ""
        toggleBtn.BorderSizePixel = 0
        toggleBtn.Parent = recipeRow

        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(0.5, 0) -- circle
        toggleCorner.Parent = toggleBtn

        local isActive = currentRecipeToggles[recipe.Id] ~= false
        toggleBtn.BackgroundColor3 = isActive and TOGGLE_ON or TOGGLE_OFF

        toggleBtn.MouseButton1Click:Connect(function()
            if currentSawmillId then
                Remotes.SawmillToggleRecipe:FireServer(currentSawmillId, recipe.Id)
            end
        end)

        -- Icon
        local iconFrame = Instance.new("Frame")
        iconFrame.Size = UDim2.new(0, 32, 0, 32)
        iconFrame.Position = UDim2.new(0, TOGGLE_SIZE + 10, 0.5, -16)
        iconFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
        iconFrame.BorderSizePixel = 0
        iconFrame.Parent = recipeRow

        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = SMALL_R
        iconCorner.Parent = iconFrame

        -- Показываем первый result как иконку
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

        -- Recipe name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -(TOGGLE_SIZE + 10 + 32 + 10 + 4), 0, RECIPE_ROW_H)
        nameLabel.Position = UDim2.new(0, TOGGLE_SIZE + 10 + 32 + 6, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = TEXT_COLOR
        nameLabel.TextSize = 11
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.TextWrapped = false
        nameLabel.Text = recipe.Name
        nameLabel.Parent = recipeRow

        recipeButtons[idx] = {
            frame = recipeRow,
            toggleBtn = toggleBtn,
            recipe = recipe,
        }

        totalH = math.max(totalH, yPos + RECIPE_ROW_H + RECIPE_PAD)
    end

    recipeFrame.CanvasSize = UDim2.new(0, 0, 0, totalH)
end

-- ═══════════════════════════════════════════════════════════
-- Обновление UI
-- ═══════════════════════════════════════════════════════════

local function updateToggles()
    for _, entry in recipeButtons do
        local isActive = currentRecipeToggles[entry.recipe.Id] ~= false
        entry.toggleBtn.BackgroundColor3 = isActive and TOGGLE_ON or TOGGLE_OFF
    end
end

local function updateProgress()
    if currentCrafting and currentCrafting.Duration and currentCrafting.Duration > 0 then
        local ratio = math.clamp((currentCrafting.Elapsed or 0) / currentCrafting.Duration, 0, 1)
        progressFill.Size = UDim2.new(ratio, 0, 1, 0)

        -- Найти имя рецепта
        local recipeName = currentCrafting.RecipeId
        for _, r in currentRecipes do
            if r.Id == currentCrafting.RecipeId then
                recipeName = r.Name
                break
            end
        end

        local elapsed = math.floor((currentCrafting.Elapsed or 0) * 10) / 10
        local duration = math.floor(currentCrafting.Duration * 10) / 10
        progressLabel.Text = recipeName .. "  " .. elapsed .. "s / " .. duration .. "s"
    else
        progressFill.Size = UDim2.new(0, 0, 1, 0)
        progressLabel.Text = "Ожидание..."
    end
end

local function refreshAll()
    rebuildInputSlots()
    rebuildOutputSlots()
    updateToggles()
    updateProgress()
end

-- ═══════════════════════════════════════════════════════════
-- Открыть / Закрыть
-- ═══════════════════════════════════════════════════════════

local function closeSawmill()
    if currentSawmillId then
        Remotes.SawmillClose:FireServer(currentSawmillId)
    end
    currentSawmillId = nil
    isOpen = false
    mainFrame.Visible = false
    WindowManager.remove("SawmillUI")
end

local function openSawmill(payload)
    currentSawmillId = payload.SawmillId
    currentInputSlots = payload.InputSlots or {}
    currentOutputSlots = payload.OutputSlots or {}
    currentRecipeToggles = payload.RecipeToggles or {}
    currentRecipes = payload.Recipes or {}
    currentCrafting = payload.Crafting

    isOpen = true
    mainFrame.Visible = true

    layoutWindow()
    buildRecipeList()
    refreshAll()

    WindowManager.push("SawmillUI", function()
        closeSawmill()
    end)
end

-- ═══════════════════════════════════════════════════════════
-- Deposit: ПКМ в инвентаре → кладём в input лесопилки
-- Публикуем состояние для SlotBehavior
-- ═══════════════════════════════════════════════════════════

local sawmillState = Instance.new("BoolValue")
sawmillState.Name = "SawmillOpen"
sawmillState.Value = false
sawmillState.Parent = screenGui

local sawmillIdValue = Instance.new("StringValue")
sawmillIdValue.Name = "SawmillOpenId"
sawmillIdValue.Value = ""
sawmillIdValue.Parent = screenGui

local function syncSawmillState()
    sawmillState.Value = isOpen and currentSawmillId ~= nil
    sawmillIdValue.Value = currentSawmillId or ""
end

-- ═══════════════════════════════════════════════════════════
-- Remotes
-- ═══════════════════════════════════════════════════════════

Remotes.SawmillOpened.OnClientEvent:Connect(function(payload)
    openSawmill(payload)
    syncSawmillState()
end)

Remotes.SawmillUpdate.OnClientEvent:Connect(function(payload)
    if not currentSawmillId or payload.SawmillId ~= currentSawmillId then return end

    currentInputSlots = payload.InputSlots or currentInputSlots
    currentOutputSlots = payload.OutputSlots or currentOutputSlots
    currentRecipeToggles = payload.RecipeToggles or currentRecipeToggles
    currentCrafting = payload.Crafting

    refreshAll()
end)

Remotes.SawmillClosed.OnClientEvent:Connect(function(sawmillId)
    if currentSawmillId == sawmillId then
        currentSawmillId = nil
        isOpen = false
        mainFrame.Visible = false
        WindowManager.remove("SawmillUI")
        syncSawmillState()
    end
end)

-- ═══════════════════════════════════════════════════════════
-- Кнопки
-- ═══════════════════════════════════════════════════════════

closeBtn.MouseButton1Click:Connect(function()
    closeSawmill()
    syncSawmillState()
end)

btnTakeAll.MouseButton1Click:Connect(function()
    if currentSawmillId then
        Remotes.SawmillTakeAll:FireServer(currentSawmillId)
    end
end)

-- ═══════════════════════════════════════════════════════════
-- Deposit из инвентаря (ПКМ по слоту в CharacterWindow)
-- Через BindableEvent — CharacterWindow fire → SawmillUI listen
-- ═══════════════════════════════════════════════════════════

local depositEvent = Instance.new("BindableEvent")
depositEvent.Name = "SawmillDeposit"
depositEvent.Parent = screenGui

depositEvent.Event:Connect(function(inventorySlotIndex)
    if currentSawmillId and isOpen then
        Remotes.SawmillDeposit:FireServer(currentSawmillId, inventorySlotIndex)
    end
end)
