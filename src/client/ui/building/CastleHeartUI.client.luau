--[[
    CastleHeartUI.client.luau
    UI при взаимодействии (F) с Castle Heart.

    Показывает: уровень, HP, эссенцию, блоки/лимит, гробы/лимит,
    кнопка Upgrade, permissions, союзники, кнопка Destroy.

    Castle Heart — Model с PrimaryPart = Platform.
    Атрибуты IsCastleHeart, CastleOwnerId находятся на Model и на PrimaryPart.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local BC = require(script.Parent:WaitForChild("BuildingConstants"))
local WindowManager = require(script.Parent.Parent:WaitForChild("WindowManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CastleHeartUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

-- ═══ Окно ═══
local WINDOW_W = 320
local WINDOW_H = 580 -- увеличено: добавлены эссенция и союзники
local PAD = BC.WINDOW_PAD

local window = Instance.new("Frame")
window.Name = "HeartWindow"
window.Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)
window.Position = UDim2.new(0.5, 0, 0.5, 0)
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.BackgroundColor3 = BC.windowBg
window.BorderSizePixel = 0
window.Visible = false
window.Parent = screenGui

Instance.new("UICorner", window).CornerRadius = UDim.new(0, BC.CORNER_RADIUS)
local winStroke = Instance.new("UIStroke")
winStroke.Color = BC.slotBorder
winStroke.Thickness = 1
winStroke.Parent = window

-- Заголовок
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -90, 0, BC.HEADER_H)
titleLabel.Position = UDim2.new(0, PAD, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = BC.textColor
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "Сердце замка"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = window

-- Уровень (справа от заголовка)
local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.new(0, 40, 0, BC.HEADER_H)
levelLabel.Position = UDim2.new(1, -80, 0, 0)
levelLabel.BackgroundTransparency = 1
levelLabel.TextColor3 = BC.btnGold
levelLabel.TextSize = 22
levelLabel.Font = Enum.Font.GothamBold
levelLabel.Text = "Ур. 1"
levelLabel.Parent = window

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 4)
closeBtn.BackgroundColor3 = BC.btnRed
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.BorderSizePixel = 0
closeBtn.Parent = window
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, BC.SMALL_RADIUS)

-- ═══ Контент ═══
local contentY = BC.HEADER_H + 8

-- ── HP Bar ──
local hpFrame = Instance.new("Frame")
hpFrame.Size = UDim2.new(1, -PAD * 2, 0, 24)
hpFrame.Position = UDim2.new(0, PAD, 0, contentY)
hpFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
hpFrame.BorderSizePixel = 0
hpFrame.Parent = window
Instance.new("UICorner", hpFrame).CornerRadius = UDim.new(0, 4)

local hpFill = Instance.new("Frame")
hpFill.Name = "HPFill"
hpFill.Size = UDim2.new(1, 0, 1, 0)
hpFill.BackgroundColor3 = BC.hpBarGreen
hpFill.BorderSizePixel = 0
hpFill.Parent = hpFrame
Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 4)

local hpText = Instance.new("TextLabel")
hpText.Size = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
hpText.TextSize = 12
hpText.Font = Enum.Font.GothamBold
hpText.Text = "1000 / 1000"
hpText.ZIndex = 2
hpText.Parent = hpFrame

contentY += 32

-- ── Essence Bar (новое) ──
local essenceFrame = Instance.new("Frame")
essenceFrame.Size = UDim2.new(1, -PAD * 2, 0, 20)
essenceFrame.Position = UDim2.new(0, PAD, 0, contentY)
essenceFrame.BackgroundColor3 = Color3.fromRGB(30, 12, 12)
essenceFrame.BorderSizePixel = 0
essenceFrame.Parent = window
Instance.new("UICorner", essenceFrame).CornerRadius = UDim.new(0, 4)

local essenceFill = Instance.new("Frame")
essenceFill.Name = "EssenceFill"
essenceFill.Size = UDim2.new(0, 0, 1, 0)
essenceFill.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
essenceFill.BorderSizePixel = 0
essenceFill.Parent = essenceFrame
Instance.new("UICorner", essenceFill).CornerRadius = UDim.new(0, 4)

local essenceText = Instance.new("TextLabel")
essenceText.Size = UDim2.new(1, 0, 1, 0)
essenceText.BackgroundTransparency = 1
essenceText.TextColor3 = Color3.fromRGB(255, 200, 200)
essenceText.TextSize = 11
essenceText.Font = Enum.Font.GothamBold
essenceText.Text = "Эссенция: 0 / 500"
essenceText.ZIndex = 2
essenceText.Parent = essenceFrame

contentY += 28

-- ── Инфо-строки ──
local function createInfoLine(yPos, label)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -PAD * 2, 0, 22)
    frame.Position = UDim2.new(0, PAD, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.Parent = window

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = BC.textDim
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.Text = label
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local val = Instance.new("TextLabel")
    val.Name = "Value"
    val.Size = UDim2.new(0.5, 0, 1, 0)
    val.Position = UDim2.new(0.5, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.TextColor3 = BC.textColor
    val.TextSize = 13
    val.Font = Enum.Font.GothamBold
    val.Text = "0 / 0"
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Parent = frame

    return val
end

local blocksValue = createInfoLine(contentY, "Блоки:")
contentY += 26
local coffinsValue = createInfoLine(contentY, "Гробы:")
contentY += 26
local radiusValue = createInfoLine(contentY, "Территория:")
contentY += 34

-- ═══ Кнопка Upgrade ═══
local upgradeBtn = Instance.new("TextButton")
upgradeBtn.Size = UDim2.new(1, -PAD * 2, 0, BC.BUTTON_H)
upgradeBtn.Position = UDim2.new(0, PAD, 0, contentY)
upgradeBtn.BackgroundColor3 = BC.btnGold
upgradeBtn.Text = "Улучшить"
upgradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
upgradeBtn.Font = Enum.Font.GothamBold
upgradeBtn.TextSize = 15
upgradeBtn.BorderSizePixel = 0
upgradeBtn.Parent = window
Instance.new("UICorner", upgradeBtn).CornerRadius = UDim.new(0, BC.SMALL_RADIUS)

local upgradeCostLabel = Instance.new("TextLabel")
upgradeCostLabel.Size = UDim2.new(1, -PAD * 2, 0, 16)
upgradeCostLabel.Position = UDim2.new(0, PAD, 0, contentY + BC.BUTTON_H + 2)
upgradeCostLabel.BackgroundTransparency = 1
upgradeCostLabel.TextColor3 = BC.textDim
upgradeCostLabel.TextSize = 11
upgradeCostLabel.Font = Enum.Font.Gotham
upgradeCostLabel.Text = ""
upgradeCostLabel.TextXAlignment = Enum.TextXAlignment.Center
upgradeCostLabel.Parent = window

contentY += BC.BUTTON_H + 22

-- ═══ Разделитель ═══
local function createSeparator(yPos)
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, -PAD * 2, 0, 1)
    sep.Position = UDim2.new(0, PAD, 0, yPos)
    sep.BackgroundColor3 = BC.slotBorder
    sep.BorderSizePixel = 0
    sep.Parent = window
    return sep
end

createSeparator(contentY)
contentY += 10

-- ═══ Permissions ═══
local permLabel = Instance.new("TextLabel")
permLabel.Size = UDim2.new(1, -PAD * 2, 0, 20)
permLabel.Position = UDim2.new(0, PAD, 0, contentY)
permLabel.BackgroundTransparency = 1
permLabel.TextColor3 = BC.textColor
permLabel.TextSize = 14
permLabel.Font = Enum.Font.GothamBold
permLabel.Text = "Права доступа"
permLabel.TextXAlignment = Enum.TextXAlignment.Left
permLabel.Parent = window
contentY += 24

local permToggles = {}

local function createPermToggle(yPos, key, displayName)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -PAD * 2, 0, 24)
    frame.Position = UDim2.new(0, PAD, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.Parent = window

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = BC.textDim
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.Text = displayName
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 50, 0, 20)
    btn.Position = UDim2.new(1, -50, 0, 2)
    btn.BackgroundColor3 = BC.btnRed
    btn.Text = "ВЫКЛ"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.BorderSizePixel = 0
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)

    permToggles[key] = { btn = btn, label = lbl }

    btn.MouseButton1Click:Connect(function()
        local current = btn.Text == "ВКЛ"
        Remotes.SetBuildPermission:FireServer(key, not current)
    end)
end

createPermToggle(contentY, "AllowCoopBuild", "Совместное строительство")
contentY += 28
createPermToggle(contentY, "AllowCoopRemove", "Совместное удаление")
contentY += 28
createPermToggle(contentY, "AllowCoopInteract", "Совместное взаимодействие")
contentY += 34

-- ═══ Разделитель ═══
createSeparator(contentY)
contentY += 10

-- ═══ Союзники ═══
local alliesLabel = Instance.new("TextLabel")
alliesLabel.Size = UDim2.new(1, -PAD * 2, 0, 20)
alliesLabel.Position = UDim2.new(0, PAD, 0, contentY)
alliesLabel.BackgroundTransparency = 1
alliesLabel.TextColor3 = BC.textColor
alliesLabel.TextSize = 14
alliesLabel.Font = Enum.Font.GothamBold
alliesLabel.Text = "Союзники"
alliesLabel.TextXAlignment = Enum.TextXAlignment.Left
alliesLabel.Parent = window
contentY += 24

-- Скроллинг-контейнер для списка союзников
local ALLIES_LIST_H = 60
local alliesScroll = Instance.new("ScrollingFrame")
alliesScroll.Size = UDim2.new(1, -PAD * 2, 0, ALLIES_LIST_H)
alliesScroll.Position = UDim2.new(0, PAD, 0, contentY)
alliesScroll.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
alliesScroll.BorderSizePixel = 0
alliesScroll.ScrollBarThickness = 4
alliesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
alliesScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
alliesScroll.Parent = window
Instance.new("UICorner", alliesScroll).CornerRadius = UDim.new(0, 4)

local alliesLayout = Instance.new("UIListLayout")
alliesLayout.SortOrder = Enum.SortOrder.LayoutOrder
alliesLayout.Padding = UDim.new(0, 2)
alliesLayout.Parent = alliesScroll

local noAlliesLabel = Instance.new("TextLabel")
noAlliesLabel.Size = UDim2.new(1, 0, 0, 20)
noAlliesLabel.BackgroundTransparency = 1
noAlliesLabel.TextColor3 = BC.textDim
noAlliesLabel.TextSize = 11
noAlliesLabel.Font = Enum.Font.Gotham
noAlliesLabel.Text = "Нет союзников"
noAlliesLabel.Parent = alliesScroll

contentY += ALLIES_LIST_H + 12

-- ═══ Кнопка уничтожения замка ═══
local destroyBtn = Instance.new("TextButton")
destroyBtn.Size = UDim2.new(1, -PAD * 2, 0, BC.BUTTON_H)
destroyBtn.Position = UDim2.new(0, PAD, 0, contentY)
destroyBtn.BackgroundColor3 = BC.btnRed
destroyBtn.Text = "Уничтожить замок"
destroyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
destroyBtn.Font = Enum.Font.GothamBold
destroyBtn.TextSize = 14
destroyBtn.BorderSizePixel = 0
destroyBtn.Parent = window
Instance.new("UICorner", destroyBtn).CornerRadius = UDim.new(0, BC.SMALL_RADIUS)

contentY += BC.BUTTON_H + PAD

-- Корректируем размер окна
WINDOW_H = contentY
window.Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)

-- ═══ Состояние ═══
local currentInfo = nil
local confirmingDestroy = false

-- ═══ Хелпер: заполнить список союзников ═══
local function updateAlliesList(allies)
    -- Очищаем старые элементы (кроме noAlliesLabel и layout)
    for _, child in alliesScroll:GetChildren() do
        if child:IsA("TextLabel") and child ~= noAlliesLabel then
            child:Destroy()
        end
    end

    if not allies or #allies == 0 then
        noAlliesLabel.Visible = true
        return
    end

    noAlliesLabel.Visible = false

    for i, allyId in allies do
        local allyName = "Игрок #" .. tostring(allyId)

        -- Попробуем получить имя игрока (если он онлайн)
        local success, name = pcall(function()
            local p = Players:GetPlayerByUserId(allyId)
            if p then return p.Name end
            return nil
        end)
        if success and name then
            allyName = name
        end

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -4, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = BC.textColor
        lbl.TextSize = 11
        lbl.Font = Enum.Font.Gotham
        lbl.Text = "  " .. allyName
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = i
        lbl.Parent = alliesScroll
    end
end

-- ═══ Обновление UI ═══
local function updateUI(info)
    if not info then
        window.Visible = false
        return
    end

    currentInfo = info

    levelLabel.Text = "Ур. " .. info.HeartLevel

    -- HP
    local hpRatio = info.MaxHP > 0 and info.CurrentHP / info.MaxHP or 0
    hpFill.Size = UDim2.new(math.clamp(hpRatio, 0, 1), 0, 1, 0)
    hpText.Text = info.CurrentHP .. " / " .. info.MaxHP
    if hpRatio > 0.5 then
        hpFill.BackgroundColor3 = BC.hpBarGreen
    elseif hpRatio > 0.25 then
        hpFill.BackgroundColor3 = BC.hpBarYellow
    else
        hpFill.BackgroundColor3 = BC.hpBarRed
    end

    -- Essence
    local essenceAmount = info.BloodEssence or 0
    local essenceMax = info.MaxEssenceCapacity or 500
    local essenceRatio = essenceMax > 0 and essenceAmount / essenceMax or 0
    essenceFill.Size = UDim2.new(math.clamp(essenceRatio, 0, 1), 0, 1, 0)
    essenceText.Text = "Эссенция: " .. essenceAmount .. " / " .. essenceMax

    -- Инфо
    blocksValue.Text = info.BlockCount .. " / " .. info.MaxBlocks
    coffinsValue.Text = info.CoffinCount .. " / " .. info.MaxCoffins
    radiusValue.Text = info.ClaimRadius .. " studs"

    -- Upgrade
    if info.HeartLevel >= info.MaxLevel then
        upgradeBtn.Text = "Макс. уровень"
        upgradeBtn.BackgroundColor3 = BC.tabInactive
        upgradeBtn.Active = false
        upgradeCostLabel.Text = ""
    else
        upgradeBtn.Text = "Улучшить до ур. " .. (info.HeartLevel + 1)
        upgradeBtn.BackgroundColor3 = BC.btnGold
        upgradeBtn.Active = true
        if info.UpgradeCost then
            local costParts = {}
            for _, cost in info.UpgradeCost do
                local itemDef = Config.Items and Config.Items[cost.ItemId]
                local name = itemDef and itemDef.Name or cost.ItemId
                table.insert(costParts, name .. " x" .. cost.Amount)
            end
            upgradeCostLabel.Text = "Стоимость: " .. table.concat(costParts, ", ")
        else
            upgradeCostLabel.Text = ""
        end
    end

    -- Permissions
    local perms = info.Permissions or {}
    for key, data in permToggles do
        local value = perms[key]
        if value then
            data.btn.Text = "ВКЛ"
            data.btn.BackgroundColor3 = BC.btnGreen
        else
            data.btn.Text = "ВЫКЛ"
            data.btn.BackgroundColor3 = BC.btnRed
        end
    end

    -- Allies
    updateAlliesList(info.Allies)

    -- Destroy reset
    confirmingDestroy = false
    destroyBtn.Text = "Уничтожить замок"
    destroyBtn.BackgroundColor3 = BC.btnRed

    window.Visible = true
end

local function closeCastleHeartUI()
    if not window.Visible then return end
    window.Visible = false
    WindowManager.remove("CastleHeartUI")
end

local function openCastleHeartUI(info)
    updateUI(info)
    WindowManager.push("CastleHeartUI", closeCastleHeartUI)
end

-- ═══ Кнопки ═══
closeBtn.MouseButton1Click:Connect(function()
    closeCastleHeartUI()
end)

upgradeBtn.MouseButton1Click:Connect(function()
    if not upgradeBtn.Active then return end
    Remotes.UpgradeCastleHeart:FireServer()
end)

destroyBtn.MouseButton1Click:Connect(function()
    if not confirmingDestroy then
        confirmingDestroy = true
        destroyBtn.Text = "Точно уничтожить? (нажмите ещё раз)"
        destroyBtn.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
        task.delay(3, function()
            if confirmingDestroy then
                confirmingDestroy = false
                destroyBtn.Text = "Уничтожить замок"
                destroyBtn.BackgroundColor3 = BC.btnRed
            end
        end)
    else
        confirmingDestroy = false
        destroyBtn.Text = "Уничтожить замок"
        destroyBtn.BackgroundColor3 = BC.btnRed
        Remotes.DestroyCastle:FireServer()
        closeCastleHeartUI()
    end
end)

-- ═══ Открытие UI — по нажатию F рядом с Castle Heart ═══
local INTERACT_RANGE = 10

--- Ищет Castle Heart (Model) рядом с игроком.
--- Castle Heart — Model с PrimaryPart (Platform).
--- Атрибут IsCastleHeart стоит и на Model, и на PrimaryPart.
--- Проверяем оба варианта для надёжности.
local function findNearbyHeart()
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local castlesFolder = workspace:FindFirstChild("Castles")
    if not castlesFolder then return nil end

    for _, folder in castlesFolder:GetChildren() do
        for _, obj in folder:GetChildren() do
            -- Вариант 1: Castle Heart это Model
            if obj:IsA("Model") and obj:GetAttribute("IsCastleHeart") then
                local primary = obj.PrimaryPart
                if primary then
                    local dist = (hrp.Position - primary.Position).Magnitude
                    if dist <= INTERACT_RANGE then
                        return obj
                    end
                end
            end
            -- Вариант 2: обратная совместимость — Castle Heart это BasePart
            if obj:IsA("BasePart") and obj:GetAttribute("IsCastleHeart") then
                local dist = (hrp.Position - obj.Position).Magnitude
                if dist <= INTERACT_RANGE then
                    return obj
                end
            end
        end
    end
    return nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == BC.KEY_INTERACT then
        if window.Visible then
            closeCastleHeartUI()
            return
        end

        local heart = findNearbyHeart()
        if heart then
            local info = Remotes.GetCastleHeartInfo:InvokeServer()
            if info then
                openCastleHeartUI(info)
            end
        end
    end
end)

-- ═══ Обновление от сервера (push) ═══
Remotes.CastleHeartInfo.OnClientEvent:Connect(function(info)
    if window.Visible then
        updateUI(info)
    end
end)