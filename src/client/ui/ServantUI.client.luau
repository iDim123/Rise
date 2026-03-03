local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local isOpen = false

-- ===== GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ServantGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "ServantFrame"
mainFrame.Size = UDim2.new(0, 450, 0, 400)
mainFrame.AnchorPoint = Vector2.new(1, 0.5)
mainFrame.Position = UDim2.new(1, -50, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

-- Заголовок
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundTransparency = 1
title.Text = "Слуги"
title.TextColor3 = Color3.fromRGB(220, 220, 220)
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- Левая панель: список слуг
local listFrame = Instance.new("ScrollingFrame")
listFrame.Name = "ServantList"
listFrame.Size = UDim2.new(0, 180, 1, -40)
listFrame.Position = UDim2.new(0, 5, 0, 35)
listFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 4
listFrame.Parent = mainFrame

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 6)
listCorner.Parent = listFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 3)
listLayout.Parent = listFrame

-- Правая панель: детали
local detailFrame = Instance.new("Frame")
detailFrame.Name = "DetailPanel"
detailFrame.Size = UDim2.new(0, 250, 1, -40)
detailFrame.Position = UDim2.new(0, 190, 0, 35)
detailFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
detailFrame.BorderSizePixel = 0
detailFrame.Parent = mainFrame

local detailCorner = Instance.new("UICorner")
detailCorner.CornerRadius = UDim.new(0, 6)
detailCorner.Parent = detailFrame

-- Детали: имя
local nameInput = Instance.new("TextBox")
nameInput.Name = "NameInput"
nameInput.Size = UDim2.new(1, -10, 0, 30)
nameInput.Position = UDim2.new(0, 5, 0, 5)
nameInput.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
nameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
nameInput.PlaceholderText = "Имя слуги..."
nameInput.TextSize = 14
nameInput.Font = Enum.Font.GothamBold
nameInput.Text = ""
nameInput.ClearTextOnFocus = false
nameInput.Parent = detailFrame

-- Детали: характеристики
local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "Stats"
statsLabel.Size = UDim2.new(1, -10, 0, 80)
statsLabel.Position = UDim2.new(0, 5, 0, 40)
statsLabel.BackgroundTransparency = 1
statsLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
statsLabel.TextSize = 13
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = ""
statsLabel.Parent = detailFrame

-- Детали: режим
local modeLabel = Instance.new("TextLabel")
modeLabel.Size = UDim2.new(1, -10, 0, 20)
modeLabel.Position = UDim2.new(0, 5, 0, 125)
modeLabel.BackgroundTransparency = 1
modeLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
modeLabel.TextSize = 12
modeLabel.Font = Enum.Font.Gotham
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Text = "Режим:"
modeLabel.Parent = detailFrame

-- Кнопки режимов
local modes = {"Aggressive", "Defensive", "Passive"}
local modeNames = {
    Aggressive = "Агрессивный",
    Defensive = "Защитный",
    Passive = "Пассивный"
}
local modeButtons = {}
local currentMode = "Aggressive"

for i, mode in modes do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 75, 0, 25)
    btn.Position = UDim2.new(0, 5 + (i - 1) * 80, 0, 148)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 85)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextSize = 11
    btn.Font = Enum.Font.Gotham
    btn.Text = modeNames[mode]
    btn.Parent = detailFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        currentMode = mode
        Remotes.SetServantMode:FireServer(mode)
        updateModeButtons()
    end)

    modeButtons[mode] = btn
end

function updateModeButtons()
    for mode, btn in modeButtons do
        if mode == currentMode then
            btn.BackgroundColor3 = Color3.fromRGB(100, 80, 180)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 85)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
end

-- Кнопки команд
local commandNames = {
    Follow = "Следуй",
    Stay = "Стой",
    AttackTarget = "Атакуй"
}
local commandList = {"Follow", "Stay", "AttackTarget"}

for i, cmd in commandList do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 75, 0, 25)
    btn.Position = UDim2.new(0, 5 + (i - 1) * 80, 0, 180)
    btn.BackgroundColor3 = Color3.fromRGB(50, 70, 60)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextSize = 11
    btn.Font = Enum.Font.Gotham
    btn.Text = commandNames[cmd]
    btn.Parent = detailFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        Remotes.ServantCommand:FireServer(cmd)
    end)
end

-- Кнопки призыва/отзыва
local summonBtn = Instance.new("TextButton")
summonBtn.Size = UDim2.new(0, 115, 0, 30)
summonBtn.Position = UDim2.new(0, 5, 0, 215)
summonBtn.BackgroundColor3 = Color3.fromRGB(50, 130, 50)
summonBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
summonBtn.TextSize = 14
summonBtn.Font = Enum.Font.GothamBold
summonBtn.Text = "Призвать"
summonBtn.Parent = detailFrame

local summonCorner = Instance.new("UICorner")
summonCorner.CornerRadius = UDim.new(0, 4)
summonCorner.Parent = summonBtn

local dismissBtn = Instance.new("TextButton")
dismissBtn.Size = UDim2.new(0, 115, 0, 30)
dismissBtn.Position = UDim2.new(0, 125, 0, 215)
dismissBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
dismissBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dismissBtn.TextSize = 14
dismissBtn.Font = Enum.Font.GothamBold
dismissBtn.Text = "Отозвать"
dismissBtn.Parent = detailFrame

local dismissCorner = Instance.new("UICorner")
dismissCorner.CornerRadius = UDim.new(0, 4)
dismissCorner.Parent = dismissBtn

-- Оружейный слот
local weaponLabel = Instance.new("TextLabel")
weaponLabel.Size = UDim2.new(1, -10, 0, 20)
weaponLabel.Position = UDim2.new(0, 5, 0, 255)
weaponLabel.BackgroundTransparency = 1
weaponLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
weaponLabel.TextSize = 12
weaponLabel.Font = Enum.Font.Gotham
weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponLabel.Text = "Оружие:"
weaponLabel.Parent = detailFrame

local weaponSlot = Instance.new("TextButton")
weaponSlot.Size = UDim2.new(0, 60, 0, 60)
weaponSlot.Position = UDim2.new(0, 5, 0, 278)
weaponSlot.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
weaponSlot.TextColor3 = Color3.fromRGB(180, 180, 180)
weaponSlot.TextSize = 10
weaponSlot.Font = Enum.Font.Gotham
weaponSlot.Text = "Пусто"
weaponSlot.Parent = detailFrame

local weaponSlotCorner = Instance.new("UICorner")
weaponSlotCorner.CornerRadius = UDim.new(0, 4)
weaponSlotCorner.Parent = weaponSlot

-- ===== Логика =====
local selectedServantId = nil

local function clearList()
    for _, child in listFrame:GetChildren() do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

local function refreshUI()
    local data = Remotes.GetServants:InvokeServer()
    if not data then
        return
    end

    clearList()
    selectedServantId = selectedServantId or data.activeId

    for i, servant in data.captured do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 35)
        btn.BackgroundColor3 = servant.id == data.activeId and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(50, 50, 70)
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.TextSize = 12
        btn.Font = Enum.Font.Gotham
        btn.Text = servant.name .. " (ATK:" .. servant.atk .. ")"
        btn.Parent = listFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            selectedServantId = servant.id
            showDetails(servant, data.activeId)
        end)

        if servant.id == selectedServantId then
            showDetails(servant, data.activeId)
        end
    end

    listFrame.CanvasSize = UDim2.new(0, 0, 0, #data.captured * 38)
end

function showDetails(servant, activeId)
    nameInput.Text = servant.name
    statsLabel.Text = "Тип: " .. servant.enemyType .. "\nКровь: " .. servant.bloodQuality .. "%" ..
                          "\nАтака: " .. servant.atk .. "\nHP: " .. servant.hp .. " / " .. servant.maxHP

    local isActive = servant.id == activeId
    summonBtn.Visible = not isActive
    dismissBtn.Visible = isActive

    weaponSlot.Text = servant.weaponSlot and servant.weaponSlot.Name or "Пусто"

    currentMode = servant.mode or "Aggressive"
    updateModeButtons()
end

-- Кнопки
summonBtn.MouseButton1Click:Connect(function()
    if selectedServantId then
        Remotes.SummonServant:FireServer(selectedServantId)
        task.wait(0.3)
        refreshUI()
    end
end)

dismissBtn.MouseButton1Click:Connect(function()
    Remotes.DismissServant:FireServer()
    task.wait(0.3)
    refreshUI()
end)

nameInput.FocusLost:Connect(function(enterPressed)
    if enterPressed and selectedServantId then
        Remotes.RenameServant:FireServer(selectedServantId, nameInput.Text)
        task.wait(0.2)
        refreshUI()
    end
end)

-- Открытие/закрытие по V Esc
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.V then
        isOpen = not isOpen
        mainFrame.Visible = isOpen
        if isOpen then
            refreshUI()
        end
    end
end)
