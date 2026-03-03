local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UC = require(script.Parent:WaitForChild("UIConstants"))
local DragManager = require(script.Parent:WaitForChild("DragManager"))
local EquipmentPanel = require(script.Parent:WaitForChild("EquipmentPanel"))
local CraftPanel = require(script.Parent:WaitForChild("CraftPanel"))
local InventoryGrid = require(script.Parent:WaitForChild("InventoryGrid"))
local ActionBarHUD = require(script.Parent:WaitForChild("ActionBarHUD"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local getInventory = ReplicatedStorage:WaitForChild("GetInventory")
local updateInventory = ReplicatedStorage:WaitForChild("UpdateInventory")
local swapSlots = ReplicatedStorage:WaitForChild("SwapSlots")
local equipItem = ReplicatedStorage:WaitForChild("EquipItem")
local unequipItem = ReplicatedStorage:WaitForChild("UnequipItem")
local setActiveWeapon = ReplicatedStorage:WaitForChild("SetActiveWeapon")
local craftItem = ReplicatedStorage:WaitForChild("CraftItem")

local isOpen = false
local currentData = nil
local activeTab = "Equipment"

-- ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CharacterGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

DragManager.init(screenGui)

-- Main window
local mainFrame = Instance.new("Frame")
mainFrame.Name = "CharacterWindow"
mainFrame.Size = UDim2.new(0, UC.windowWidth, 0, UC.windowHeight)
mainFrame.Position = UDim2.new(0, 40, 0, 40)
mainFrame.BackgroundColor3 = UC.windowBg
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, UC.headerH)
title.BackgroundTransparency = 1
title.Text = player.Name
title.TextColor3 = UC.textColor
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- Tabs
local tabs = { "Equipment", "Crafting", "Blood Pool", "Attributes" }
local tabButtons = {}
local tabWidth = math.floor((UC.windowWidth - 10) / #tabs) - 5

for i, tab in tabs do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, tabWidth, 0, UC.tabsH)
    btn.Position = UDim2.new(0, 5 + (i - 1) * (tabWidth + 5), 0, UC.tabsY)
    btn.BackgroundColor3 = tab == activeTab and UC.tabActive or UC.tabInactive
    btn.TextColor3 = UC.textColor
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Text = tab
    btn.Parent = mainFrame

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = btn

    tabButtons[tab] = btn
end

-- Build panels
local equipPanelFrame = EquipmentPanel.build(mainFrame, UC.contentY, unequipItem)
local craftPanelFrame = CraftPanel.build(mainFrame, UC.contentY, craftItem, screenGui)

-- Build inventory (always visible)
InventoryGrid.build(mainFrame, swapSlots, equipItem, function() return currentData end)

-- Recalculate window height
mainFrame.Size = UDim2.new(0, UC.windowWidth, 0, UC.windowHeight)

-- Build bottom ActionBar
ActionBarHUD.build(playerGui, setActiveWeapon)

-- Tab switching
local function switchTab(tabName)
    activeTab = tabName
    for name, btn in tabButtons do
        btn.BackgroundColor3 = (name == tabName) and UC.tabActive or UC.tabInactive
    end
    equipPanelFrame.Visible = (tabName == "Equipment")
    CraftPanel.setVisible(tabName == "Crafting")
    if tabName == "Crafting" and currentData then
        CraftPanel.refresh(currentData.slots)
    end
end

for tabName, btn in tabButtons do
    btn.MouseButton1Click:Connect(function()
        switchTab(tabName)
    end)
end

-- Refresh all
local function refreshUI(data)
    if not data then return end
    currentData = data
    InventoryGrid.refresh(data.slots, data.activeWeaponSlot)
    ActionBarHUD.refresh(data.slots, data.activeWeaponSlot)
    EquipmentPanel.refresh(data.equipment)
    if activeTab == "Crafting" then
        CraftPanel.refresh(data.slots)
    end
end

-- Hotkeys
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.C then
        isOpen = not isOpen
        mainFrame.Visible = isOpen
        if isOpen then
            local data = getInventory:InvokeServer()
            refreshUI(data)
        end
    end

    local keyNumber = nil
    if input.KeyCode == Enum.KeyCode.One then keyNumber = 1
    elseif input.KeyCode == Enum.KeyCode.Two then keyNumber = 2
    elseif input.KeyCode == Enum.KeyCode.Three then keyNumber = 3
    elseif input.KeyCode == Enum.KeyCode.Four then keyNumber = 4
    elseif input.KeyCode == Enum.KeyCode.Five then keyNumber = 5
    elseif input.KeyCode == Enum.KeyCode.Six then keyNumber = 6
    elseif input.KeyCode == Enum.KeyCode.Seven then keyNumber = 7
    elseif input.KeyCode == Enum.KeyCode.Eight then keyNumber = 8
    end

    if keyNumber then
        setActiveWeapon:FireServer(keyNumber)
    end
end)

-- Cancel drag on mouse release outside slots
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if DragManager.isDragging() then
            DragManager.reset(InventoryGrid.getSlotFrames())
        end
    end
end)

-- Server updates
updateInventory.OnClientEvent:Connect(function(data)
    refreshUI(data)
end)

-- Load on start
task.spawn(function()
    local data = getInventory:InvokeServer()
    if data then
        refreshUI(data)
    end
end)