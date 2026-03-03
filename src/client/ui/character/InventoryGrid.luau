local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UC = require(script.Parent:WaitForChild("UIConstants"))
local SlotFactory = require(script.Parent:WaitForChild("SlotFactory"))
local DragManager = require(script.Parent:WaitForChild("DragManager"))

local InventoryGrid = {}

local slotFrames = {}

function InventoryGrid.build(parent, swapRemote, equipRemote, getCurrentData)
    -- ActionBar row (slots 1-8)
    for col = 0, UC.cols - 1 do
        local index = col + 1
        local posX = UC.windowPadX + UC.padding + col * (UC.slotSize + UC.padding)

        local slot = SlotFactory.createSlot(parent, "Slot_" .. index, posX, UC.actionRowY)

        -- Bind label
        local bindLabel = Instance.new("TextLabel")
        bindLabel.Size = UDim2.new(0, UC.slotSize, 0, UC.actionRowLabelH)
        bindLabel.Position = UDim2.new(0, posX, 0, UC.actionRowY + UC.slotSize + 2)
        bindLabel.BackgroundTransparency = 1
        bindLabel.TextColor3 = UC.bindColor
        bindLabel.TextSize = 11
        bindLabel.Font = Enum.Font.GothamBold
        bindLabel.Text = tostring(index)
        bindLabel.Parent = parent

        InventoryGrid._connectSlot(slot, index, swapRemote, equipRemote, getCurrentData)
        slotFrames[index] = slot
    end

    -- Separator
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0, UC.invGridWidth, 0, UC.separatorH)
    sep.Position = UDim2.new(0, UC.windowPadX, 0, UC.separatorY)
    sep.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    sep.BorderSizePixel = 0
    sep.Parent = parent

    -- Inventory grid (slots 9-40)
    for row = 0, UC.displayRows - 1 do
        for col = 0, UC.cols - 1 do
            local index = (row + 1) * UC.cols + col + 1
            local posX = UC.windowPadX + UC.padding + col * (UC.slotSize + UC.padding)
            local posY = UC.actualInvY + row * (UC.slotSize + UC.padding)

            local slot = SlotFactory.createSlot(parent, "Slot_" .. index, posX, posY)
            InventoryGrid._connectSlot(slot, index, swapRemote, equipRemote, getCurrentData)
            slotFrames[index] = slot
        end
    end

    -- Sort button
    local sortBtn = Instance.new("TextButton")
    sortBtn.Size = UDim2.new(0, 60, 0, UC.sortH)
    sortBtn.Position = UDim2.new(0.5, -30, 0, UC.actualSortY)
    sortBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 85)
    sortBtn.TextColor3 = UC.textColor
    sortBtn.TextSize = 12
    sortBtn.Font = Enum.Font.GothamBold
    sortBtn.Text = "Sort"
    sortBtn.Parent = parent

    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(0, 4)
    sc.Parent = sortBtn
end

function InventoryGrid._connectSlot(slot, index, swapRemote, equipRemote, getCurrentData)
    slot.MouseButton1Down:Connect(function()
        DragManager.dragFrom = index
        slot.BackgroundColor3 = UC.slotBgDrag
        local data = getCurrentData()
        if data then
            local item = data.slots[index]
            if item and item ~= false then
                DragManager.createGhost(item)
            end
        end
    end)

    slot.MouseButton1Up:Connect(function()
        if DragManager.dragFrom and DragManager.dragFrom ~= index then
            swapRemote:FireServer(DragManager.dragFrom, index)
        end
        DragManager.dragFrom = nil
        DragManager.dragOverIndex = nil
        DragManager.destroyGhost()
        slot.BackgroundColor3 = UC.slotBg
    end)

    slot.MouseEnter:Connect(function()
        if DragManager.dragFrom and DragManager.dragFrom ~= index then
            DragManager.dragOverIndex = index
            slot.BackgroundColor3 = UC.slotBgTarget
        end
    end)

    slot.MouseLeave:Connect(function()
        if DragManager.dragOverIndex == index then
            DragManager.dragOverIndex = nil
        end
        if not DragManager.dragFrom or DragManager.dragFrom ~= index then
            slot.BackgroundColor3 = UC.slotBg
        end
    end)

    slot.MouseButton2Click:Connect(function()
        local data = getCurrentData()
        if data then
            local item = data.slots[index]
            if item and item ~= false and item.EquipSlot then
                equipRemote:FireServer(index)
            end
        end
    end)
end

function InventoryGrid.refresh(slotsData, activeWeaponSlot)
    for i, slotFrame in slotFrames do
        local itemData = slotsData[i]
        if itemData == false then itemData = nil end
        SlotFactory.updateSlot(slotFrame, itemData, activeWeaponSlot, i)
    end
end

function InventoryGrid.getSlotFrames()
    return slotFrames
end

return InventoryGrid