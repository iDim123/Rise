local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local Config  = require(ReplicatedStorage:WaitForChild("Config"))
local ItemTooltip = require(script.Parent:WaitForChild("tooltip"))
local WindowManager = require(script.Parent:WaitForChild("WindowManager"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local hrp       = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(char)
    character = char
    hrp = char:WaitForChild("HumanoidRootPart")
end)

-- ═══ Стиль ═══
local BG_COLOR     = Color3.fromRGB(25, 25, 35)
local SLOT_BG      = Color3.fromRGB(50, 50, 65)
local SLOT_EMPTY   = Color3.fromRGB(40, 40, 55)
local TEXT_COLOR   = Color3.fromRGB(220, 220, 220)
local GOLD_COLOR   = Color3.fromRGB(220, 190, 80)
local GREEN_BTN    = Color3.fromRGB(50, 130, 50)
local BLUE_BTN     = Color3.fromRGB(50, 50, 70)
local STROKE_COLOR = Color3.fromRGB(60, 60, 80)
local DISABLED_BTN = Color3.fromRGB(35, 35, 45)
local DISABLED_TXT = Color3.fromRGB(100, 100, 100)

local SLOT_SIZE = 50
local PADDING   = 4
local COLS      = 6
local PAD       = 8
local HEADER_H  = 36
local BUTTON_H  = 30
local CORNER_R  = UDim.new(0, 8)
local SMALL_R   = UDim.new(0, 4)

local MINIMAP_LEFT_OFFSET = -256
local GAP_TO_MINIMAP      = 12
local TOP_OFFSET          = 40

if not playerGui:FindFirstChild("TooltipGui") then
    ItemTooltip.init(screenGui)
end

-- ═══ Связь с CharacterWindow ═══
local function fireCharacterToggle(forceOpen)
    local charGui = playerGui:FindFirstChild("CharacterGui")
    if charGui then
        local toggle = charGui:FindFirstChild("ToggleCharacterWindow")
        if toggle then
            toggle:Fire(forceOpen)
        end
    end
end

-- ═══ Проверка: открыто ли окно персонажа ═══
local function isCharacterWindowOpen()
    local charGui = playerGui:FindFirstChild("CharacterGui")
    if charGui then
        local win = charGui:FindFirstChild("CharacterWindow")
        if win then
            return win.Visible
        end
    end
    return false
end

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

local slotsFrame = Instance.new("Frame")
slotsFrame.Name                  = "SlotsFrame"
slotsFrame.Size                  = UDim2.new(1, -PAD * 2, 0, 200)
slotsFrame.Position              = UDim2.new(0, PAD, 0, HEADER_H + PAD)
slotsFrame.BackgroundTransparency = 1
slotsFrame.Parent                = window

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
-- Состояние кнопок (disabled при пустом сундуке)
-- ════════════════════════════════════════════════════════════
local function isChestEmpty(slots)
    for _, slot in slots do
        if slot and slot ~= false then
            return false
        end
    end
    return true
end

local function updateButtonStates(slots)
    local empty = isChestEmpty(slots)
    if empty then
        btnTakeAll.BackgroundColor3 = DISABLED_BTN
        btnTakeAll.TextColor3       = DISABLED_TXT
        btnTakeAll.AutoButtonColor  = false
        btnSort.BackgroundColor3    = DISABLED_BTN
        btnSort.TextColor3          = DISABLED_TXT
        btnSort.AutoButtonColor     = false
    else
        btnTakeAll.BackgroundColor3 = GREEN_BTN
        btnTakeAll.TextColor3       = Color3.fromRGB(255, 255, 255)
        btnTakeAll.AutoButtonColor  = true
        btnSort.BackgroundColor3    = BLUE_BTN
        btnSort.TextColor3          = TEXT_COLOR
        btnSort.AutoButtonColor     = true
    end
end

-- ════════════════════════════════════════════════════════════
-- Построение сетки слотов
-- ════════════════════════════════════════════════════════════
local function buildSlotGrid(slots)
    ItemTooltip.hide() 
    for _, btn in slotButtons do
        btn:Destroy()
    end
    slotButtons = {}

    local rows = math.ceil(#slots / COLS)
    local gridH = rows * (SLOT_SIZE + PADDING) + PADDING
    slotsFrame.Size = UDim2.new(1, -PAD * 2, 0, gridH)

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

        local slotStroke = Instance.new("UIStroke")
        slotStroke.Color     = STROKE_COLOR
        slotStroke.Thickness = 1
        slotStroke.Parent    = btn

        if slot and slot ~= false then
            local itemDef = Config.Items[slot.ItemId]

            local img = Instance.new("ImageLabel")
            img.Size                 = UDim2.new(0, 36, 0, 36)
            img.Position             = UDim2.new(0.5, -18, 0, 2)
            img.BackgroundTransparency = 1
            img.Image                = itemDef and itemDef.Icon or ""
            img.Parent               = btn

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

            -- Tooltip при наведении
            btn.MouseEnter:Connect(function()
                if slot and slot ~= false then
                    -- Формируем данные в формате, который понимает ItemTooltip
                    local tooltipData = {
                        Id     = slot.ItemId,
                        Name   = itemDef and itemDef.Name or slot.ItemId,
                        Amount = slot.Amount or 1,
                    }
                    ItemTooltip.show(tooltipData, btn)
                end
            end)

            btn.MouseLeave:Connect(function()
                ItemTooltip.hide()
            end)

            -- ЛКМ → TakeItem (забрать из сундука)
            local slotIndex = i
            btn.MouseButton1Click:Connect(function()
                if currentContainerId then
                    Remotes.ContainerTakeItem:FireServer(currentContainerId, slotIndex)
                end
            end)

            -- ПКМ → TakeItem (забрать из сундука в инвентарь)
            btn.MouseButton2Click:Connect(function()
                if currentContainerId then
                    Remotes.ContainerTakeItem:FireServer(currentContainerId, slotIndex)
                end
            end)
        end

        slotButtons[i] = btn
    end

    updateButtonStates(slots)
end

-- ════════════════════════════════════════════════════════════
-- Открыть / Закрыть окно
-- ════════════════════════════════════════════════════════════
local function openWindow(containerId, slots, name)
    currentContainerId = containerId
    currentSlots       = slots
    titleLabel.Text    = name or "Сундук"
    buildSlotGrid(slots)
    window.Visible = true
    fireCharacterToggle(true)
      WindowManager.push("ContainerUI", function()
        closeWindow() -- вызываем существующую функцию закрытия
    end)
end

local function closeWindow()
    if currentContainerId then
        Remotes.ContainerClose:FireServer(currentContainerId)
    end
    currentContainerId = nil
    window.Visible     = false

    fireCharacterToggle(false)
    WindowManager.remove("ContainerUI")
end

-- ════════════════════════════════════════════════════════════
-- Публичный API: узнать открыт ли сундук (для SlotBehavior)
-- ════════════════════════════════════════════════════════════
local containerState = Instance.new("BoolValue")
containerState.Name  = "ContainerOpen"
containerState.Value = false
containerState.Parent = screenGui

local containerIdValue = Instance.new("StringValue")
containerIdValue.Name  = "ContainerOpenId"
containerIdValue.Value = ""
containerIdValue.Parent = screenGui

-- Обновлять при открытии/закрытии
local function syncContainerState()
    containerState.Value = (currentContainerId ~= nil and window.Visible)
    containerIdValue.Value = currentContainerId or ""
end

-- ════════════════════════════════════════════════════════════
-- Сканирование (Heartbeat)
-- ════════════════════════════════════════════════════════════
local SCAN_INTERVAL = 0.2
local scanTimer     = 0

local function findContainerObject(containerId)
    local containersFolder = workspace:FindFirstChild("Containers")
    if containersFolder then
        for _, obj in containersFolder:GetDescendants() do
            if obj:GetAttribute("ContainerId") == containerId then
                return obj
            end
        end
    end
    local castlesFolder = workspace:FindFirstChild("Castles")
    if castlesFolder then
        for _, folder in castlesFolder:GetChildren() do
            for _, obj in folder:GetChildren() do
                if obj:GetAttribute("ContainerId") == containerId then
                    return obj
                end
            end
        end
    end
    return nil
end

local function getObjectPosition(obj)
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") and obj.PrimaryPart then
        return obj.PrimaryPart.Position
    end
    return nil
end

RunService.Heartbeat:Connect(function(dt)
    if currentContainerId and window.Visible and hrp then
        local model = findContainerObject(currentContainerId)
        if model then
            local pos = getObjectPosition(model)
            if pos and (hrp.Position - pos).Magnitude > interactRange + 3 then
                closeWindow()
                syncContainerState()
            end
        end
    end

    scanTimer += dt
    if scanTimer < SCAN_INTERVAL then return end
    scanTimer = 0

    if not hrp then
        billboardGui.Enabled = false
        nearbyContainer = nil
        return
    end

    local closest     = nil
    local closestDist = math.huge

    local containersFolder = workspace:FindFirstChild("Containers")
    if containersFolder then
        for _, obj in containersFolder:GetDescendants() do
            local cfgId = obj:GetAttribute("ContainerType")
            if cfgId then
                local isEmpty = obj:GetAttribute("ContainerEmpty")
                if not isEmpty and obj.Parent then
                    isEmpty = obj.Parent:GetAttribute("ContainerEmpty")
                end
                if isEmpty then continue end

                local pos = getObjectPosition(obj)
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
                            isCastle      = false,
                        }
                    end
                end
            end
        end
    end

    local castlesFolder = workspace:FindFirstChild("Castles")
    if castlesFolder then
        for _, folder in castlesFolder:GetChildren() do
            for _, obj in folder:GetChildren() do
                if obj:IsA("BasePart") and obj:GetAttribute("IsStructure") then
                    local typeId = obj:GetAttribute("BlockTypeId")
                    if typeId then
                        local bt = Config.Building and Config.Building.BlockTypes
                            and Config.Building.BlockTypes[typeId]
                        if bt and bt.Functional == "Chest" then
                            local cid = obj:GetAttribute("ContainerId")
                            if not cid then continue end

                            local pos = obj.Position
                            local range = (bt.FunctionalData and bt.FunctionalData.InteractRange) or 8
                            local dist = (hrp.Position - pos).Magnitude
                            if dist <= range and dist < closestDist then
                                closestDist = dist
                                closest = {
                                    model         = obj,
                                    containerId   = cid,
                                    interactRange = range,
                                    isCastle      = true,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    if closest then
        nearbyContainer = closest
        interactRange   = closest.interactRange

        if billboardGui.Adornee ~= closest.model then
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
-- Ввод: F → открыть/закрыть
-- ════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.F then
        -- Если сундук уже открыт — закрыть оба окна
        if window.Visible and currentContainerId then
            closeWindow()
            syncContainerState()
            return
        end

        if isCasting then return end

        if nearbyContainer and nearbyContainer.containerId then
            if not nearbyContainer.isCastle then
                if nearbyContainer.model and nearbyContainer.model:GetAttribute("ContainerEmpty") then
                    return
                end
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
    syncContainerState()
end)

Remotes.ContainerUpdate.OnClientEvent:Connect(function(containerId, slots)
    if currentContainerId == containerId then
        currentSlots = slots
        buildSlotGrid(slots)
    end
end)

Remotes.ContainerClosed.OnClientEvent:Connect(function(containerId)
    isCasting = false
    if currentContainerId == containerId then
        currentContainerId = nil
        window.Visible = false
        fireCharacterToggle(false)
        syncContainerState()
    end
end)

Remotes.CastCancel.OnClientEvent:Connect(function()
    isCasting = false
end)

-- ════════════════════════════════════════════════════════════
-- Кнопки
-- ════════════════════════════════════════════════════════════
closeBtn.MouseButton1Click:Connect(function()
    closeWindow()
    syncContainerState()
end)

btnTakeAll.MouseButton1Click:Connect(function()
    if not currentContainerId then return end
    if isChestEmpty(currentSlots) then return end
    Remotes.ContainerTakeAll:FireServer(currentContainerId)
end)

btnSort.MouseButton1Click:Connect(function()
    if not currentContainerId then return end
    if isChestEmpty(currentSlots) then return end
    Remotes.ContainerSort:FireServer(currentContainerId)
end)