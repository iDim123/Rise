local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local UC = require(script.Parent:WaitForChild("UIConstants"))
local DragManager = require(script.Parent:WaitForChild("DragManager"))
local EquipmentPanel = require(script.Parent:WaitForChild("EquipmentPanel"))
local CraftPanel = require(script.Parent:WaitForChild("CraftPanel"))
local InventoryGrid = require(script.Parent:WaitForChild("InventoryGrid"))
local ActionBarHUD = require(script.Parent:WaitForChild("ActionBarHUD"))
local CooldownManager = require(script.Parent:WaitForChild("CooldownManager"))
local ItemTooltip = require(script.Parent:WaitForChild("tooltip"))
local AttributesPanel = require(script.Parent:WaitForChild("AttributesPanel"))
local BloodPoolPanel = require(script.Parent:WaitForChild("BloodPoolPanel"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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
ItemTooltip.init(screenGui)

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
local tabs = {"Equipment", "Crafting", "Blood Pool", "Attributes"}
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
local equipPanelFrame = EquipmentPanel.build(mainFrame, UC.contentY, Remotes.UnequipItem)
local craftPanelFrame = CraftPanel.build(mainFrame, UC.contentY, Remotes.CraftItem, screenGui)
local bloodPoolFrame = BloodPoolPanel.build(mainFrame, UC.contentY)
local attributesFrame = AttributesPanel.build(mainFrame, UC.contentY, screenGui)
AttributesPanel.connectRemote()

-- Build inventory
InventoryGrid.build(mainFrame, Remotes.SwapSlots, Remotes.EquipItem, function()
    return currentData
end, Remotes.UseItem)

mainFrame.Size = UDim2.new(0, UC.windowWidth, 0, UC.windowHeight)

-- Build bottom ActionBar
ActionBarHUD.build(playerGui, Remotes.SetActiveWeapon, Remotes.UseItem, Remotes.EquipItem)

-- Register entire player equipment panel as one drop target
local equipPanel = equipPanelFrame -- это Frame возвращённый из EquipmentPanel.build
DragManager.registerDropTarget(equipPanel, function(data)
    if not data or not data.item then
        return
    end
    local item = data.item
    if not item.EquipSlot then
        return
    end
    Remotes.EquipItem:FireServer(data.slotIndex)
end)

-- Tab switching
local function switchTab(tabName)
    activeTab = tabName
    for name, btn in tabButtons do
        btn.BackgroundColor3 = (name == tabName) and UC.tabActive or UC.tabInactive
    end
    equipPanelFrame.Visible = (tabName == "Equipment")
    CraftPanel.setVisible(tabName == "Crafting")
    BloodPoolPanel.setVisible(tabName == "Blood Pool")
    AttributesPanel.setVisible(tabName == "Attributes")
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
    if not data then
        return
    end
    currentData = data
    InventoryGrid.refresh(data.slots, data.activeWeaponSlot, data.unlockedSlots)
    ActionBarHUD.refresh(data.slots, data.activeWeaponSlot)
    EquipmentPanel.refresh(data.equipment)
    if activeTab == "Crafting" then
        CraftPanel.refresh(data.slots)
    end
end

-- Hotkeys
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.C then
        isOpen = not isOpen
        mainFrame.Visible = isOpen
        if isOpen then
            local data = Remotes.GetInventory:InvokeServer()
            refreshUI(data)
        end
    end

    local keyNumber = nil
    if input.KeyCode == Enum.KeyCode.One then
        keyNumber = 1
    elseif input.KeyCode == Enum.KeyCode.Two then
        keyNumber = 2
    elseif input.KeyCode == Enum.KeyCode.Three then
        keyNumber = 3
    elseif input.KeyCode == Enum.KeyCode.Four then
        keyNumber = 4
    elseif input.KeyCode == Enum.KeyCode.Five then
        keyNumber = 5
    elseif input.KeyCode == Enum.KeyCode.Six then
        keyNumber = 6
    elseif input.KeyCode == Enum.KeyCode.Seven then
        keyNumber = 7
    elseif input.KeyCode == Enum.KeyCode.Eight then
        keyNumber = 8
    end

    if keyNumber then
        local slotData = nil
        if currentData and currentData.slots then
            slotData = currentData.slots[keyNumber]
        end

        if slotData and slotData ~= false and slotData.Type == "Consumable" then
            if not CooldownManager.isOnCooldown(slotData.Id) then
                local itemDef = Config.Items[slotData.Id]
                if itemDef and itemDef.UseEffect and itemDef.UseEffect.Cooldown then
                    CooldownManager.startCooldown(slotData.Id, itemDef.UseEffect.Cooldown)
                end
                Remotes.UseItem:FireServer(keyNumber)
            end
        else
            Remotes.SetActiveWeapon:FireServer(keyNumber)
        end
    end
end)

-- Server updates
Remotes.UpdateInventory.OnClientEvent:Connect(function(data)
    refreshUI(data)
end)

-- Load on start
task.spawn(function()
    local data = Remotes.GetInventory:InvokeServer()
    if data then
        refreshUI(data)
    end
end)
