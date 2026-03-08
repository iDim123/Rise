-- • Показывает подсказку "Открыть [F]" рядом с сундуком
-- • Открывает окно инвентаря контейнера при взаимодействии
-- • Auto-close при выходе за InteractRange
-- • Кнопки "Take All" и "Sort"

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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

-- ────────────────────────────────────────────────────────────
-- Создание ScreenGui
-- ────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "ContainerUI"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

-- ── Подсказка "Открыть [F]" (BillboardGui крепится к модели) ──
local billboardGui = Instance.new("BillboardGui")
billboardGui.Name       = "ContainerHint"
billboardGui.Size       = UDim2.new(0, 200, 0, 40)
billboardGui.StudsOffset = Vector3.new(0, 4, 0) 
billboardGui.AlwaysOnTop = true
billboardGui.Enabled    = false
billboardGui.Parent     = screenGui  -- пока без parent модели

local hintLabel = Instance.new("TextLabel")
hintLabel.Size            = UDim2.new(1, 0, 1, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3      = Color3.fromRGB(255, 220, 80)
hintLabel.TextScaled      = true
hintLabel.Font            = Enum.Font.GothamBold
hintLabel.Text            = "Открыть [F]"
hintLabel.Parent          = billboardGui

-- ── Окно контейнера ──────────────────────────────────────────
local SLOT_SIZE   = 60
local PADDING     = 8
local COLS        = 3

local window = Instance.new("Frame")
window.Name              = "ContainerWindow"
window.Size              = UDim2.new(0, 220, 0, 320)
window.Position          = UDim2.new(0.5, 10, 0.5, -160)
window.BackgroundColor3  = Color3.fromRGB(30, 25, 20)
window.BorderSizePixel   = 0
window.Visible           = false
window.Parent            = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = window

-- Заголовок
local titleBar = Instance.new("Frame")
titleBar.Size            = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(55, 40, 25)
titleBar.BorderSizePixel = 0
titleBar.Parent          = window

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size              = UDim2.new(1, -40, 1, 0)
titleLabel.Position          = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3        = Color3.fromRGB(255, 220, 100)
titleLabel.TextScaled        = true
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.Text              = "Сундук"
titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
titleLabel.Parent            = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size                = UDim2.new(0, 28, 0, 28)
closeBtn.Position            = UDim2.new(1, -34, 0, 4)
closeBtn.BackgroundColor3    = Color3.fromRGB(160, 40, 40)
closeBtn.Text                = "✕"
closeBtn.TextColor3          = Color3.fromRGB(255, 255, 255)
closeBtn.Font                = Enum.Font.GothamBold
closeBtn.TextScaled          = true
closeBtn.BorderSizePixel     = 0
closeBtn.Parent              = titleBar

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 4)
closeBtnCorner.Parent = closeBtn

-- Сетка слотов
local slotsFrame = Instance.new("Frame")
slotsFrame.Name             = "SlotsFrame"
slotsFrame.Size             = UDim2.new(1, -16, 0, 200)
slotsFrame.Position         = UDim2.new(0, 8, 0, 44)
slotsFrame.BackgroundTransparency = 1
slotsFrame.Parent           = window

-- Кнопки внизу
local btnTakeAll = Instance.new("TextButton")
btnTakeAll.Size              = UDim2.new(0.48, 0, 0, 30)
btnTakeAll.Position          = UDim2.new(0, 8, 1, -46)
btnTakeAll.BackgroundColor3  = Color3.fromRGB(60, 120, 60)
btnTakeAll.Text              = "Взять всё"
btnTakeAll.TextColor3        = Color3.fromRGB(255, 255, 255)
btnTakeAll.Font              = Enum.Font.Gotham
btnTakeAll.TextScaled        = true
btnTakeAll.BorderSizePixel   = 0
btnTakeAll.Parent            = window

local btnTakeAllCorner = Instance.new("UICorner")
btnTakeAllCorner.CornerRadius = UDim.new(0, 6)
btnTakeAllCorner.Parent = btnTakeAll

local btnSort = Instance.new("TextButton")
btnSort.Size                 = UDim2.new(0.48, 0, 0, 30)
btnSort.Position             = UDim2.new(0.52, 0, 1, -46)
btnSort.BackgroundColor3     = Color3.fromRGB(60, 80, 140)
btnSort.Text                 = "Сорт."
btnSort.TextColor3           = Color3.fromRGB(255, 255, 255)
btnSort.Font                 = Enum.Font.Gotham
btnSort.TextScaled           = true
btnSort.BorderSizePixel      = 0
btnSort.Parent               = window

local btnSortCorner = Instance.new("UICorner")
btnSortCorner.CornerRadius = UDim.new(0, 6)
btnSortCorner.Parent = btnSort

-- ────────────────────────────────────────────────────────────
-- Состояние
-- ────────────────────────────────────────────────────────────
local currentContainerId = nil
local currentSlots       = {}
local slotButtons        = {}
local nearbyContainer    = nil   -- { containerId, model, interactRange }
local interactRange      = 5

-- ────────────────────────────────────────────────────────────
-- Построение сетки слотов
-- ────────────────────────────────────────────────────────────
local function buildSlotGrid(slots)
    -- Очищаем старые
    for _, btn in slotButtons do
        btn:Destroy()
    end
    slotButtons = {}

    for i, slot in slots do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)

        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
        btn.Position         = UDim2.new(0, col * (SLOT_SIZE + PADDING), 0, row * (SLOT_SIZE + PADDING))
        btn.BackgroundColor3 = Color3.fromRGB(50, 45, 38)
        btn.BorderSizePixel  = 0
        btn.Text             = ""
        btn.Parent           = slotsFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        if slot and slot ~= false then
            -- Иконка предмета
            local img = Instance.new("ImageLabel")
            img.Size                = UDim2.new(0.75, 0, 0.75, 0)
            img.Position            = UDim2.new(0.125, 0, 0.05, 0)
            img.BackgroundTransparency = 1
            img.Image               = Config.Items[slot.ItemId] and Config.Items[slot.ItemId].Icon or ""
            img.Parent              = btn

            -- Количество
            if slot.Amount and slot.Amount > 1 then
                local amtLabel = Instance.new("TextLabel")
                amtLabel.Size        = UDim2.new(1, -4, 0, 16)
                amtLabel.Position    = UDim2.new(0, 2, 1, -18)
                amtLabel.BackgroundTransparency = 1
                amtLabel.Text        = tostring(slot.Amount)
                amtLabel.TextColor3  = Color3.fromRGB(220, 220, 150)
                amtLabel.Font        = Enum.Font.GothamBold
                amtLabel.TextScaled  = true
                amtLabel.TextXAlignment = Enum.TextXAlignment.Right
                amtLabel.Parent      = btn
            end

            -- Клик → TakeItem
            local slotIndex = i
            btn.MouseButton1Click:Connect(function()
                if currentContainerId then
                    Remotes.ContainerTakeItem:FireServer(currentContainerId, slotIndex)
                end
            end)
        else
            -- Пустой слот — серый
            btn.BackgroundColor3 = Color3.fromRGB(35, 32, 28)
        end

        slotButtons[i] = btn
    end
end

-- Обновить UI слотов без перестройки всей сетки
local function updateSlots(slots)
    currentSlots = slots
    buildSlotGrid(slots)
end

-- ────────────────────────────────────────────────────────────
-- Открыть / Закрыть окно
-- ────────────────────────────────────────────────────────────
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

-- ────────────────────────────────────────────────────────────
-- Сканирование ближайших контейнеров (Heartbeat)
-- ────────────────────────────────────────────────────────────
local SCAN_INTERVAL = 0.2
local scanTimer     = 0

RunService.Heartbeat:Connect(function(dt)
    -- Auto-close: игрок отошёл от открытого контейнера
    if currentContainerId and window.Visible then
        local containerFolder = workspace:FindFirstChild("Containers")
        if containerFolder then
            local model = nil
            for _, obj in containerFolder:GetDescendants() do
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

    -- Поиск ближайшего контейнера для подсказки
    scanTimer += dt
    if scanTimer < SCAN_INTERVAL then return end
    scanTimer = 0

    local containersFolder = workspace:FindFirstChild("Containers")
    if not containersFolder or not hrp then return end

    local closest     = nil
    local closestDist = math.huge

    for _, obj in containersFolder:GetDescendants() do
        local cfgId = obj:GetAttribute("ContainerType")
        if obj:IsA("BasePart") and cfgId then
            local cfg = Config.Containers[cfgId]
            if cfg then
                local pos = obj.Position
                local dist = (hrp.Position - pos).Magnitude
                local range = cfg.InteractRange or 5
                if dist <= range and dist < closestDist then
                    closestDist = dist
                    closest = {
                        model          = obj,
                        containerId    = obj:GetAttribute("ContainerId"),
                        interactRange  = range,
                    }
                end
            end
        end
    end

    if closest then
        nearbyContainer = closest
        interactRange   = closest.interactRange

        -- Прикрепляем BillboardGui к якорю или к модели
        if billboardGui.Parent ~= closest.model then
            local anchor = closest.model:FindFirstChild("HintAnchor")

            if anchor then
                -- Модель сама знает где показывать подсказку
                billboardGui.Parent      = anchor
                billboardGui.Adornee     = anchor
                billboardGui.StudsOffset = Vector3.new(0, 0, 0)
            else
                -- Fallback: вычисляем автоматически по размеру модели
                billboardGui.Parent  = closest.model
                billboardGui.Adornee = closest.model
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

-- ────────────────────────────────────────────────────────────
-- Ввод: F → открыть ближайший контейнер
-- ────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode ~= Enum.KeyCode.F then return end
    if window.Visible then return end  -- уже открыт

    if nearbyContainer and nearbyContainer.containerId then
        Remotes.ContainerOpen:FireServer(nearbyContainer.containerId, false)
    end
end)

-- ────────────────────────────────────────────────────────────
-- Remote: ContainerOpened — сервер дал добро на открытие
-- ────────────────────────────────────────────────────────────
Remotes.ContainerOpened.OnClientEvent:Connect(function(containerId, slots, name)
    openWindow(containerId, slots, name)
end)

-- ────────────────────────────────────────────────────────────
-- Remote: ContainerUpdate — кто-то взял предмет, обновляем UI
-- ────────────────────────────────────────────────────────────
Remotes.ContainerUpdate.OnClientEvent:Connect(function(containerId, slots)
    if currentContainerId == containerId then
        updateSlots(slots)
    end
end)

-- ────────────────────────────────────────────────────────────
-- Remote: ContainerClosed — сундук исчез / закрыт сервером
-- ────────────────────────────────────────────────────────────
Remotes.ContainerClosed.OnClientEvent:Connect(function(containerId)
    local myId = chestModel:GetAttribute("ContainerId")
    if myId ~= containerId then return end   -- ← теперь правильно фильтруем
    if isOpen then
        isOpen = false
        task.spawn(animateLid, 0)
    end
end)

-- ────────────────────────────────────────────────────────────
-- Кнопки
-- ────────────────────────────────────────────────────────────
closeBtn.MouseButton1Click:Connect(closeWindow)

btnTakeAll.MouseButton1Click:Connect(function()
    if currentContainerId then
        Remotes.ContainerTakeAll:FireServer(currentContainerId)
    end
end)

btnSort.MouseButton1Click:Connect(function()
    if currentContainerId then
        Remotes.ContainerSort:FireServer(currentContainerId)
    end
end)