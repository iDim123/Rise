local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UC = require(script.Parent:WaitForChild("UIConstants"))
local SlotFactory = require(script.Parent:WaitForChild("SlotFactory"))
local SlotBehavior = require(script.Parent:WaitForChild("SlotBehavior"))

local ActionBarHUD = {}

local actionBarSlots = {}
local cachedSlotsData = nil
local actionBarFrame = nil

local FLASK_WIDTH = 50
local GAP = 8

function ActionBarHUD.build(playerGui, setActiveWeaponRemote, useItemRemote, equipRemote)
    local gui = Instance.new("ScreenGui")
    gui.Name = "ActionBarGui"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local frameW = UC.padding + UC.cols * (UC.slotSize + UC.padding)
    local frameH = UC.slotSize + 20

    local frame = Instance.new("Frame")
    frame.Name = "ActionBar"
    frame.Size = UDim2.new(0, frameW, 0, frameH)
    frame.AnchorPoint = Vector2.new(1, 1)
    frame.Position = UDim2.new(0.5, -(FLASK_WIDTH / 2) - GAP, 1, -10)
    frame.BackgroundColor3 = UC.windowBg
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    actionBarFrame = frame

    for col = 0, UC.cols - 1 do
        local index = col + 1
        local posX = UC.padding + col * (UC.slotSize + UC.padding)

        local slot = SlotFactory.createSlot(frame, "AB_" .. index, posX, 2)

        local numLabel = Instance.new("TextLabel")
        numLabel.Name = "NumLabel"
        numLabel.Size = UDim2.new(1, 0, 0, 14)
        numLabel.Position = UDim2.new(0, 0, 1, 2)
        numLabel.BackgroundTransparency = 1
        numLabel.TextColor3 = UC.bindColor
        numLabel.TextSize = 11
        numLabel.Font = Enum.Font.GothamBold
        numLabel.Text = tostring(index)
        numLabel.TextXAlignment = Enum.TextXAlignment.Center
        numLabel.Parent = slot

        SlotBehavior.connect(slot, index, function()
            return cachedSlotsData and cachedSlotsData[index]
        end, {
            equipRemote = equipRemote,
            useItemRemote = useItemRemote,
            setActiveWeaponRemote = setActiveWeaponRemote,
        })

        actionBarSlots[index] = slot
    end
end

function ActionBarHUD.getFrame()
    return actionBarFrame
end

function ActionBarHUD.getSlots()
    return actionBarSlots
end

function ActionBarHUD.refresh(slotsData, activeWeaponSlot)
    cachedSlotsData = slotsData
    for i, slot in actionBarSlots do
        local itemData = slotsData[i]
        if itemData == false then itemData = nil end
        SlotFactory.updateSlot(slot, itemData, activeWeaponSlot, i)
    end
end

return ActionBarHUD