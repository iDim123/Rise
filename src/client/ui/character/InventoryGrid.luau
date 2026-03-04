local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UC = require(script.Parent:WaitForChild("UIConstants"))
local SlotFactory = require(script.Parent:WaitForChild("SlotFactory"))
local DragManager = require(script.Parent:WaitForChild("DragManager"))
local CooldownManager = require(script.Parent:WaitForChild("CooldownManager"))
local ItemTooltip = require(script.Parent:WaitForChild("ItemTooltip"))

local InventoryGrid = {}

local slotFrames = {}
local savedSwapRemote = nil

function InventoryGrid.build(parent, swapRemote, equipRemote, getCurrentData, useItemRemote)
    savedSwapRemote = swapRemote

    -- ActionBar row (slots 1-8)
    for col = 0, UC.cols - 1 do
        local index = col + 1
        local posX = UC.windowPadX + UC.padding + col * (UC.slotSize + UC.padding)

        local slot = SlotFactory.createSlot(parent, "Slot_" .. index, posX, UC.actionRowY)

        local bindLabel = Instance.new("TextLabel")
        bindLabel.Size = UDim2.new(0, UC.slotSize, 0, UC.actionRowLabelH)
        bindLabel.Position = UDim2.new(0, posX, 0, UC.actionRowY + UC.slotSize + 2)
        bindLabel.BackgroundTransparency = 1
        bindLabel.TextColor3 = UC.bindColor
        bindLabel.TextSize = 11
        bindLabel.Font = Enum.Font.GothamBold
        bindLabel.Text = tostring(index)
        bindLabel.Parent = parent

        InventoryGrid._connectSlot(slot, index, equipRemote, getCurrentData, useItemRemote)
        slotFrames[index] = slot

        CooldownManager.registerSlot(slot, function()
            local data = getCurrentData()
            if data and data.slots then
                local item = data.slots[index]
                if item and item ~= false then
                    return item.Id
                end
            end
            return nil
        end)
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
            InventoryGrid._connectSlot(slot, index, equipRemote, getCurrentData, useItemRemote)
            slotFrames[index] = slot

            CooldownManager.registerSlot(slot, function()
                local data = getCurrentData()
                if data and data.slots then
                    local item = data.slots[index]
                    if item and item ~= false then
                        return item.Id
                    end
                end
                return nil
            end)
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

    -- Глобальный обработчик — единственное место где обрабатывается drop и swap
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and DragManager.isDragging() then
            local mousePos = UserInputService:GetMouseLocation()

            -- Сначала пробуем drop на внешние targets (слоты слуги и т.п.)
            local dropped = DragManager.tryDrop(mousePos)

            if not dropped then
                -- Не попали на drop target — проверяем swap внутри инвентаря
                local overIndex = DragManager.dragOverIndex
                if overIndex and overIndex ~= DragManager.dragFrom then
                    savedSwapRemote:FireServer(DragManager.dragFrom, overIndex)
                end
            end

            DragManager.reset(slotFrames)
        end
    end)
end

function InventoryGrid._connectSlot(slot, index, equipRemote, getCurrentData, useItemRemote)
    slot.MouseButton1Down:Connect(function()
        ItemTooltip.hide()
        local data = getCurrentData()
        if data then
            local item = data.slots[index]
            if item and item ~= false then
                DragManager.startDrag(index, item)
                slot.BackgroundColor3 = UC.slotBgDrag
            end
        end
    end)

    slot.MouseEnter:Connect(function()
        if DragManager.isDragging() and DragManager.dragFrom ~= index then
            DragManager.dragOverIndex = index
            slot.BackgroundColor3 = UC.slotBgTarget
        else
            -- Tooltip
            local data = getCurrentData()
            if data and data.slots then
                local item = data.slots[index]
                if item and item ~= false then
                    ItemTooltip.show(item, slot)
                end
            end
        end
    end)

    slot.MouseLeave:Connect(function()
        ItemTooltip.hide()
        if DragManager.dragOverIndex == index then
            DragManager.dragOverIndex = nil
        end
        if not DragManager.isDragging() or DragManager.dragFrom ~= index then
            slot.BackgroundColor3 = UC.slotBg
        end
    end)

    slot.MouseButton2Click:Connect(function()
        local data = getCurrentData()
        if data then
            local item = data.slots[index]
            if item and item ~= false then
                if item.EquipSlot then
                    equipRemote:FireServer(index)
                elseif item.Type == "Consumable" then
                    if not CooldownManager.isOnCooldown(item.Id) then
                        local itemDef = Config.Items[item.Id]
                        if itemDef and itemDef.UseEffect and itemDef.UseEffect.Cooldown then
                            CooldownManager.startCooldown(item.Id, itemDef.UseEffect.Cooldown)
                        end
                        useItemRemote:FireServer(index)
                    end
                end
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