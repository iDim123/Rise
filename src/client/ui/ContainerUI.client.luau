local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local Config  = require(ReplicatedStorage:WaitForChild("Config"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local hrp       = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(char)
    character = char
    hrp = char:WaitForChild("HumanoidRootPart")
end)

-- ═══ Стиль из UIConstants (как CharacterWindow / ServantWindow) ═══
local BG_COLOR     = Color3.fromRGB(25, 25, 35)
local PANEL_BG     = Color3.fromRGB(35, 35, 50)
local SLOT_BG      = Color3.fromRGB(50, 50, 65)
local SLOT_EMPTY   = Color3.fromRGB(40, 40, 55)
local TEXT_COLOR   = Color3.fromRGB(220, 220, 220)
local GOLD_COLOR   = Color3.fromRGB(220, 190, 80)
local GREEN_BTN    = Color3.fromRGB(50, 130, 50)
local BLUE_BTN     = Color3.fromRGB(50, 50, 70)
local STROKE_COLOR = Color3.fromRGB(60, 60, 80)

local SLOT_SIZE = 50
local PADDING   = 4
local COLS      = 6
local PAD       = 8
local HEADER_H  = 36
local BUTTON_H  = 30
local CORNER_R  = UDim.new(0, 8)
local SMALL_R   = UDim.new(0, 4)

local MINIMAP_LEFT_OFFSET = -256   -- из Minimap.client.luau
local GAP_TO_MINIMAP      = 12
local TOP_OFFSET          = 40     -- как CharacterWindow

-- ════════════════════════════════════════════════════════════
-- ScreenGui
-- ════════════════════════════════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "ContainerUI"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder   = 15
screenGui.Parent         = playerGui

-- ═══ Подсказка "Открыть [F]" ═══
local billboardGui = Instance.new("BillboardGui")
billboardGui.Name        = "ContainerHint"
billboardGui.Size        = UDim2.new(0, 200, 0, 40)
billboardGui.StudsOffset = Vector3.new(0, 4, 0)
billboardGui.AlwaysOnTop = true
billboardGui.Enabled     = false
billboardGui.Parent      = screenGui

local hintLabel = Instance.new("TextLabel")
hintLabel.Size                 = UDim2.new(1, 0, 1, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3           = GOLD_COLOR
hintLabel.TextSize             = 16
hintLabel.Font                 = Enum.Font.GothamBold
hintLabel.Text                 = "Открыть [F]"
hintLabel.Parent               = billboardGui

-- ═══ Окно контейнера ═══
-- Размер динамический, зависит от кол-ва слотов (рассчитываем при открытии)
local MAX_SLOTS = 12
local function calcWindowSize(slotCount)
    local rows = math.ceil(slotCount / COLS)
    local gridH = rows * (SLOT_SIZE + PADDING) + PADDING
    local totalH = HEADER_H + PAD + gridH + PAD + BUTTON_H + PAD
    local totalW = PAD * 2 + COLS * (SLOT_SIZE + PADDING) + PADDING
    return totalW, totalH
end

local defaultW, defaultH = calcWindowSize(6)

local window = Instance.new("Frame")
window.Name             = "ContainerWindow"
window.Size             = UDim2.new(0, defaultW, 0, defaultH)
window.Position         = UDim2.new(1, MINIMAP_LEFT_OFFSET - GAP_TO_MINIMAP, 0, TOP_OFFSET)
window.AnchorPoint      = Vector2.new(1, 0)
window.BackgroundColor3 = BG_COLOR
window.BorderSizePixel  = 0
window.Visible          = false
window.ClipsDescendants = true
window.Parent           = screenGui

local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = CORNER_R
winCorner.Parent = window

local winStroke = Instance.new("UIStroke")
winStroke.Color     = STROKE_COLOR
winStroke.Thickness = 1
winStroke.Parent    = window

-- Заголовок (прозрачный фон, как в CharacterWindow)
local titleLabel = Instance.new("TextLabel")
titleLabel.Size                 = UDim2.new(1, -40, 0, HEADER_H)
titleLabel.Position             = UDim2.new(0, PAD, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3           = TEXT_COLOR
titleLabel.TextSize             = 20
titleLabel.Font                 = Enum.Font.GothamBold
titleLabel.Text                 = "Сундук"
titleLabel.TextXAlignment       = Enum.TextXAlignment.Left
titleLabel.Parent               = window

-- Кнопка закрытия (стиль ServantWindow)
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 28, 0, 28)
closeBtn.Position         = UDim2.new(1, -34, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
closeBtn.Text             = "X"
closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 16
closeBtn.BorderSizePixel  = 0
closeBtn.Parent           = window

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = SMALL_R
closeBtnCorner.Parent = closeBtn

-- Сетка слотов
local slotsFrame = Instance.new("Frame")
slotsFrame.Name                  = "SlotsFrame"
slotsFrame.Size                  = UDim2.new(1, -PAD * 2, 0, 200)
slotsFrame.Position              = UDim2.new(0, PAD, 0, HEADER_H + PAD)
slotsFrame.BackgroundTransparency = 1
slotsFrame.Parent                = window

-- Кнопки внизу
local btnFrame = Instance.new("Frame")
btnFrame.Name                  = "ButtonFrame"
btnFrame.Size                  = UDim2.new(1, -PAD * 2, 0, BUTTON_H)
btnFrame.BackgroundTransparency = 1
btnFrame.Parent                = window

local btnTakeAll = Instance.new("TextButton")
btnTakeAll.Size             = UDim2.new(0.48, 0, 1, 0)
btnTakeAll.Position         = UDim2.new(0, 0, 0, 0)
btnTakeAll.BackgroundColor3 = GREEN_BTN
btnTakeAll.Text             = "Взять всё"
btnTakeAll.TextColor3       = Color3.fromRGB(255, 255, 255)
btnTakeAll.Font             = Enum.Font.GothamBold
btnTakeAll.TextSize         = 14
btnTakeAll.BorderSizePixel  = 0
btnTakeAll.Parent           = btnFrame

local takeAllCorner = Instance.new("UICorner")
takeAllCorner.CornerRadius = SMALL_R
takeAllCorner.Parent = btnTakeAll

local btnSort = Instance.new("TextButton")
btnSort.Size             = UDim2.new(0.48, 0, 1, 0)
btnSort.Position         = UDim2.new(0.52, 0, 0, 0)
btnSort.BackgroundColor3 = BLUE_BTN
btnSort.Text             = "Сорт."
btnSort.TextColor3       = TEXT_COLOR
btnSort.Font             = Enum.Font.GothamBold
btnSort.TextSize         = 14
btnSort.BorderSizePixel  = 0
btnSort.Parent           = btnFrame

local sortCorner = Instance.new("UICorner")
sortCorner.CornerRadius = SMALL_R
sortCorner.Parent = btnSort

-- ════════════════════════════════════════════════════════════
-- Состояние
-- ════════════════════════════════════════════════════════════
local currentContainerId = nil
local currentSlots       = {}
local slotButtons        = {}
local nearbyContainer    = nil
local interactRange      = 5
local isCasting          = false

-- ════════════════════════════════════════════════════════════
-- Построение сетки слотов
-- ════════════════════════════════════════════════════════════
local function buildSlotGrid(slots)
    for _, btn in slotButtons do
        btn:Destroy()
    end
    slotButtons = {}

    local rows = math.ceil(#slots / COLS)
    local gridH = rows * (SLOT_SIZE + PADDING) + PADDING
    slotsFrame.Size = UDim2.new(1, -PAD * 2, 0, gridH)

    -- Пересчитываем размер окна и позицию кнопок
    local totalH = HEADER_H + PAD + gridH + PAD + BUTTON_H + PAD
    window.Size = UDim2.new(0, window.Size.X.Offset, 0, totalH)
    btnFrame.Position = UDim2.new(0, PAD, 0, HEADER_H + PAD + gridH + PAD)

    for i, slot in slots do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)

        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
        btn.Position         = UDim2.new(0, col * (SLOT_SIZE + PADDING), 0, row * (SLOT_SIZE + PADDING))
        btn.BackgroundColor3 = slot and SLOT_BG or SLOT_EMPTY
        btn.BorderSizePixel  = 0
        btn.Text             = ""
        btn.AutoButtonColor  = slot and true or false
        btn.Parent           = slotsFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = SMALL_R
        btnCorner.Parent = btn

        -- Обводка слота
        local slotStroke = Instance.new("UIStroke")
        slotStroke.Color     = STROKE_COLOR
        slotStroke.Thickness = 1
        slotStroke.Parent    = btn

        if slot and slot ~= false then
            local itemDef = Config.Items[slot.ItemId]

            -- Иконка
            local img = Instance.new("ImageLabel")
            img.Size                 = UDim2.new(0, 36, 0, 36)
            img.Position             = UDim2.new(0.5, -18, 0, 2)
            img.BackgroundTransparency = 1
            img.Image                = itemDef and itemDef.Icon or ""
            img.Parent               = btn

            -- Количество
            if slot.Amount and slot.Amount > 1 then
                local amtLabel = Instance.new("TextLabel")
                amtLabel.Size                 = UDim2.new(1, -4, 0, 14)
                amtLabel.Position             = UDim2.new(0, 2, 1, -16)
                amtLabel.BackgroundTransparency = 1
                amtLabel.Text                 = tostring(slot.Amount)
                amtLabel.TextColor3           = TEXT_COLOR
                amtLabel.Font                 = Enum.Font.GothamBold
                amtLabel.TextSize             = 12
                amtLabel.TextXAlignment       = Enum.TextXAlignment.Right
                amtLabel.Parent               = btn
            end

            -- Клик → TakeItem
            local slotIndex = i
            btn.MouseButton1Click:Connect(function()
                if currentContainerId then
                    Remotes.ContainerTakeItem:FireServer(currentContainerId, slotIndex)
                end
            end)
        end

        slotButtons[i] = btn
    end
end

local function updateSlots(slots)
    currentSlots = slots
    buildSlotGrid(slots)
end

-- ════════════════════════════════════════════════════════════
-- Открыть / Закрыть окно
-- ════════════════════════════════════════════════════════════
local function openWindow(containerId, slots, name)
    currentContainerId = containerId
    currentSlots       = slots
    titleLabel.Text    = name or "Сундук"
    buildSlotGrid(slots)
    window.Visible     = true
end

local function closeWindow()
    if currentContainerId then
        Remotes.ContainerClose:FireServer(currentContainerId)
    end
    currentContainerId = nil
    window.Visible     = false
end

-- ════════════════════════════════════════════════════════════
-- Сканирование ближайших контейнеров (Heartbeat)
-- ════════════════════════════════════════════════════════════
local SCAN_INTERVAL = 0.2
local scanTimer     = 0

RunService.Heartbeat:Connect(function(dt)
    -- Auto-close
    if currentContainerId and window.Visible then
        local containersFolder = workspace:FindFirstChild("Containers")
        if containersFolder then
            local model = nil
            for _, obj in containersFolder:GetDescendants() do
                if obj:GetAttribute("ContainerId") == currentContainerId then
                    model = obj
                    break
                end
            end
            if model and hrp then
                local pos = model:IsA("BasePart") and model.Position
                    or (model.PrimaryPart and model.PrimaryPart.Position)
                if pos then
                    local dist = (hrp.Position - pos).Magnitude
                    if dist > interactRange + 3 then
                        closeWindow()
                    end
                end
            end
        end
    end

    -- Подсказка
    scanTimer += dt
    if scanTimer < SCAN_INTERVAL then return end
    scanTimer = 0

    local containersFolder = workspace:FindFirstChild("Containers")
    if not containersFolder or not hrp then return end

    local closest     = nil
    local closestDist = math.huge

    for _, obj in containersFolder:GetDescendants() do
        local cfgId = obj:GetAttribute("ContainerType")
        if cfgId then
            -- Проверяем пустоту на этом объекте или его предке
            local isEmpty = obj:GetAttribute("ContainerEmpty")
            if not isEmpty and obj.Parent then
                isEmpty = obj.Parent:GetAttribute("ContainerEmpty")
            end
            if isEmpty then
                continue
            end

            -- Находим позицию для расчёта дальности
            local pos = nil
            if obj:IsA("BasePart") then
                pos = obj.Position
            elseif obj:IsA("Model") and obj.PrimaryPart then
                pos = obj.PrimaryPart.Position
            end
            if not pos then continue end

            local cfg = Config.Containers[cfgId]
            if cfg then
                local dist = (hrp.Position - pos).Magnitude
                local range = cfg.InteractRange or 5
                if dist <= range and dist < closestDist then
                    closestDist = dist
                    closest = {
                        model         = obj,
                        containerId   = obj:GetAttribute("ContainerId"),
                        interactRange = range,
                    }
                end
            end
        end
    end

    if closest then
        nearbyContainer = closest
        interactRange   = closest.interactRange

        if billboardGui.Parent ~= closest.model then
            local anchor = closest.model:FindFirstChild("HintAnchor")
            if anchor then
                billboardGui.Parent      = anchor
                billboardGui.Adornee     = anchor
                billboardGui.StudsOffset = Vector3.new(0, 0, 0)
            else
                billboardGui.Parent      = closest.model
                billboardGui.Adornee     = closest.model
                local size = closest.model:IsA("BasePart")
                    and closest.model.Size
                    or closest.model:GetExtentsSize()
                billboardGui.StudsOffset = Vector3.new(0, size.Y / 2 + 1.5, 0)
            end
            billboardGui.AlwaysOnTop = true
        end
        billboardGui.Enabled = true
    else
        nearbyContainer      = nil
        billboardGui.Enabled = false
    end
end)

-- ════════════════════════════════════════════════════════════
-- Ввод: F → открыть, Escape → закрыть
-- ════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.F then
        if window.Visible then return end
        if isCasting then return end

        if nearbyContainer and nearbyContainer.containerId then
            -- NEW: не открывать пустой сундук
            if nearbyContainer.model and nearbyContainer.model:GetAttribute("ContainerEmpty") then
                return
            end
            isCasting = true
            Remotes.ContainerOpen:FireServer(nearbyContainer.containerId, false)
        end
    end
end)

-- ════════════════════════════════════════════════════════════
-- Remotes
-- ════════════════════════════════════════════════════════════
Remotes.ContainerOpened.OnClientEvent:Connect(function(containerId, slots, name)
    isCasting = false
    openWindow(containerId, slots, name)
end)


Remotes.ContainerClosed.OnClientEvent:Connect(function(containerId)
    isCasting = false
    if currentContainerId == containerId then
        currentContainerId = nil
        window.Visible = false
    end
end)

Remotes.CastCancel.OnClientEvent:Connect(function()
    isCasting = false   -- NEW
end)

-- ════════════════════════════════════════════════════════════
-- Кнопки
-- ════════════════════════════════════════════════════════════
closeBtn.MouseButton1Click:Connect(closeWindow)

btnTakeAll.MouseButton1Click:Connect(function()
    print("[ContainerUI] TakeAll clicked, currentContainerId =", currentContainerId)
    if currentContainerId then
        print("[ContainerUI] Firing ContainerTakeAll:", currentContainerId)
        Remotes.ContainerTakeAll:FireServer(currentContainerId)
    else
        print("[ContainerUI] TakeAll SKIP: no currentContainerId")
    end
end)

btnSort.MouseButton1Click:Connect(function()
    if currentContainerId then
        Remotes.ContainerSort:FireServer(currentContainerId)
    end
end)