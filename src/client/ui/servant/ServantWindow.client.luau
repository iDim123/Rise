local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local UC = require(script.Parent.Parent:WaitForChild("character"):WaitForChild("UIConstants"))

local ServantEquipPanel = require(script.Parent:WaitForChild("ServantEquipPanel"))
local ServantStatsPanel = require(script.Parent:WaitForChild("ServantStatsPanel"))
local ServantCollection = require(script.Parent:WaitForChild("ServantCollection"))
local ServantActionBar = require(script.Parent:WaitForChild("ServantActionBar"))
local WindowManager = require(script.Parent.Parent:WaitForChild("WindowManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local isOpen = false
local selectedServantId = nil
local servantData = nil

-- ===== Constants =====
local WINDOW_W = 460
local WINDOW_H = UC.windowHeight
local HEADER_H = 36
local NAME_ROW_H = 30
local EQUIP_PANEL_W = 200
local EQUIP_PANEL_H = 270
local STATS_PANEL_W = WINDOW_W - EQUIP_PANEL_W - 8 * 3
local BUTTON_H = 32
local PAD = 8
local BG_COLOR = Color3.fromRGB(25, 25, 35)
local TEXT_COLOR = Color3.fromRGB(220, 220, 220)
local GOLD_COLOR = Color3.fromRGB(220, 190, 80)

local contentY = HEADER_H + NAME_ROW_H + PAD
local buttonY = contentY + EQUIP_PANEL_H + PAD
local collectionY = buttonY + BUTTON_H + PAD
local collectionLabelH = 24
local COLLECTION_H = WINDOW_H - collectionY - collectionLabelH - PAD

-- ===== GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ServantGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "ServantFrame"
mainFrame.Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)
mainFrame.AnchorPoint = Vector2.new(1, 0)
mainFrame.Position = UDim2.new(1, -20, 0, 20)
mainFrame.BackgroundColor3 = BG_COLOR
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(60, 60, 80)
mainStroke.Thickness = 1
mainStroke.Parent = mainFrame

-- Header
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, HEADER_H)
title.BackgroundTransparency = 1
title.Text = "Слуга"
title.TextColor3 = TEXT_COLOR
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- Name row
local nameInput = Instance.new("TextBox")
nameInput.Name = "NameInput"
nameInput.Size = UDim2.new(1, -PAD * 2, 0, NAME_ROW_H)
nameInput.Position = UDim2.new(0, PAD, 0, HEADER_H)
nameInput.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
nameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
nameInput.PlaceholderText = "Servant name"
nameInput.TextSize = 14
nameInput.Font = Enum.Font.GothamBold
nameInput.Text = ""
nameInput.ClearTextOnFocus = false
nameInput.Parent = mainFrame

local nameCorner = Instance.new("UICorner")
nameCorner.CornerRadius = UDim.new(0, 4)
nameCorner.Parent = nameInput

-- Equipment panel (left)
local equipPanel = ServantEquipPanel.build(mainFrame, PAD, contentY, EQUIP_PANEL_W, EQUIP_PANEL_H)

-- Stats panel (right)
local statsPanel = ServantStatsPanel.build(mainFrame, PAD + EQUIP_PANEL_W + PAD, contentY, STATS_PANEL_W, EQUIP_PANEL_H)

-- Buttons row
local btnCount = 3
local btnGap = PAD
local btnW = math.floor((WINDOW_W - PAD * 2 - btnGap * (btnCount - 1)) / btnCount)

local summonBtn = Instance.new("TextButton")
summonBtn.Size = UDim2.new(0, btnW, 0, BUTTON_H)
summonBtn.Position = UDim2.new(0, PAD, 0, buttonY)
summonBtn.BackgroundColor3 = Color3.fromRGB(50, 130, 50)
summonBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
summonBtn.TextSize = 14
summonBtn.Font = Enum.Font.GothamBold
summonBtn.Text = "Summon"
summonBtn.Parent = mainFrame

local summonCorner = Instance.new("UICorner")
summonCorner.CornerRadius = UDim.new(0, 4)
summonCorner.Parent = summonBtn

local dismissBtn = Instance.new("TextButton")
dismissBtn.Size = UDim2.new(0, btnW, 0, BUTTON_H)
dismissBtn.Position = UDim2.new(0, PAD + btnW + btnGap, 0, buttonY)
dismissBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
dismissBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dismissBtn.TextSize = 14
dismissBtn.Font = Enum.Font.GothamBold
dismissBtn.Text = "Dismiss"
dismissBtn.Parent = mainFrame

local dismissCorner = Instance.new("UICorner")
dismissCorner.CornerRadius = UDim.new(0, 4)
dismissCorner.Parent = dismissBtn

local favBtn = Instance.new("TextButton")
favBtn.Name = "FavoriteBtn"
favBtn.Size = UDim2.new(0, btnW, 0, BUTTON_H)
favBtn.Position = UDim2.new(0, PAD + (btnW + btnGap) * 2, 0, buttonY)
favBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
favBtn.TextColor3 = TEXT_COLOR
favBtn.TextSize = 12
favBtn.Font = Enum.Font.Gotham
favBtn.Text = "Add to Favorite"
favBtn.Parent = mainFrame

local favCorner = Instance.new("UICorner")
favCorner.CornerRadius = UDim.new(0, 4)
favCorner.Parent = favBtn

-- Collection label
local collectionLabel = Instance.new("TextLabel")
collectionLabel.Size = UDim2.new(1, -PAD * 2, 0, 20)
collectionLabel.Position = UDim2.new(0, PAD, 0, collectionY)
collectionLabel.BackgroundTransparency = 1
collectionLabel.TextColor3 = TEXT_COLOR
collectionLabel.TextSize = 16
collectionLabel.Font = Enum.Font.GothamBold
collectionLabel.TextXAlignment = Enum.TextXAlignment.Left
collectionLabel.Text = "Collection"
collectionLabel.Parent = mainFrame

-- Collection panel
local collectionPanel = ServantCollection.build(mainFrame, PAD, collectionY + collectionLabelH, WINDOW_W - PAD * 2,
    COLLECTION_H)

-- Servant ActionBar
ServantActionBar.build(playerGui)

-- ===== Logic =====

local INACTIVE_COLOR = Color3.fromRGB(60, 60, 70)
local INACTIVE_TEXT = Color3.fromRGB(120, 120, 120)

local function setButtonsInactive()
    summonBtn.BackgroundColor3 = INACTIVE_COLOR
    summonBtn.TextColor3 = INACTIVE_TEXT
    summonBtn.Visible = true
    dismissBtn.BackgroundColor3 = INACTIVE_COLOR
    dismissBtn.TextColor3 = INACTIVE_TEXT
    dismissBtn.Visible = true
    favBtn.BackgroundColor3 = INACTIVE_COLOR
    favBtn.TextColor3 = INACTIVE_TEXT
    favBtn.Text = "Add to Favorite"
    nameInput.Text = ""
    selectedServantId = nil
    ServantEquipPanel.unregisterDropTargets()
    ServantEquipPanel.refresh(nil)
    ServantStatsPanel.refresh(nil)
end

local function showServant(servant, activeId)
    selectedServantId = servant.id
    nameInput.Text = servant.name or ""

    -- Favorite button
    favBtn.Text = servant.favorite and "★ Favorite" or "Add to Favorite"
    favBtn.TextColor3 = servant.favorite and GOLD_COLOR or TEXT_COLOR
    favBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)

    -- Equipment & stats panels
    ServantEquipPanel.unregisterDropTargets()
    ServantEquipPanel.refresh(servant.equipment)
    ServantEquipPanel.registerDropTargets(servant.id)

    ServantStatsPanel.refresh(servant)

    -- Summon / Dismiss visibility
    local isActive = servant.id == activeId
    summonBtn.Visible = not isActive
    dismissBtn.Visible = isActive

    summonBtn.BackgroundColor3 = Color3.fromRGB(50, 130, 50)
    summonBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dismissBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
    dismissBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
end

local function refreshUI()
    servantData = Remotes.GetServants:InvokeServer()
    if not servantData then
        return
    end

    selectedServantId = selectedServantId or servantData.activeId

    ServantCollection.refresh(servantData.captured, servantData.activeId, selectedServantId, function(servant)
        showServant(servant, servantData.activeId)
    end)

    if #servantData.captured == 0 then
        setButtonsInactive()
    else
        local shown = false
        for _, servant in servantData.captured do
            if servant.id == selectedServantId then
                showServant(servant, servantData.activeId)
                shown = true
                break
            end
        end
        if not shown then
            showServant(servantData.captured[1], servantData.activeId)
        end
    end

    ServantActionBar.setVisible(servantData.activeId ~= nil)
    if servantData.activeId then
        local activeServant = nil
        for _, s in servantData.captured do
            if s.id == servantData.activeId then
                activeServant = s
                break
            end
        end
        if activeServant then
            ServantActionBar.refresh(activeServant.mode)
        end
    end
end

-- Button handlers
summonBtn.MouseButton1Click:Connect(function()
    if not selectedServantId or not servantData or #servantData.captured == 0 then
        return
    end
    Remotes.SummonServant:FireServer(selectedServantId)
    task.wait(0.3)
    refreshUI()
end)

dismissBtn.MouseButton1Click:Connect(function()
    if not servantData or not servantData.activeId then
        return
    end
    Remotes.DismissServant:FireServer()
    task.wait(0.3)
    refreshUI()
end)

favBtn.MouseButton1Click:Connect(function()
    if not selectedServantId or not servantData or #servantData.captured == 0 then
        return
    end
    Remotes.ToggleServantFavorite:FireServer(selectedServantId)
    task.wait(0.2)
    refreshUI()
end)

nameInput.FocusLost:Connect(function(enterPressed)
    if enterPressed and selectedServantId then
        Remotes.RenameServant:FireServer(selectedServantId, nameInput.Text)
        task.wait(0.2)
        refreshUI()
    end
end)

ServantEquipPanel.onUnequip(function(slotId)
    if selectedServantId then
        Remotes.UnequipServantItem:FireServer(selectedServantId, slotId)
        task.wait(0.2)
        refreshUI()
    end
end)

-- Auto-refresh on capture
Remotes.CaptureResult.OnClientEvent:Connect(function(success, status)
    if success and status == "captured" then
        task.wait(0.3)
        if isOpen then
            refreshUI()
        end
    end
end)

-- Auto-refresh servant window when inventory changes (e.g. after equip/unequip)
Remotes.UpdateInventory.OnClientEvent:Connect(function(data)
    if isOpen then
        refreshUI()
    end
end)

local function closeServantWindow()
    if not isOpen then
        return
    end
    isOpen = false
    mainFrame.Visible = false
    ServantEquipPanel.unregisterDropTargets()
    WindowManager.remove("ServantWindow")
end

local function openServantWindow()
    if isOpen then
        return
    end
    isOpen = true
    mainFrame.Visible = true
    refreshUI()
    WindowManager.push("ServantWindow", closeServantWindow)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end
    if input.KeyCode == Enum.KeyCode.V then
        if isOpen then
            closeServantWindow()
        else
            openServantWindow()
        end
    end
end)

-- ═══ MenuBar интеграция ═══
local MenuBar = require(script.Parent.Parent:WaitForChild("MenuBar"))
MenuBar.onButtonClick("ServantWindow", function()
    if isOpen then
        closeServantWindow()
    else
        openServantWindow()
    end
end)
