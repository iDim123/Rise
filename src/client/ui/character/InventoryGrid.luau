local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UC = require(script.Parent:WaitForChild("UIConstants"))
local SlotFactory = require(script.Parent:WaitForChild("SlotFactory"))
local DragManager = require(script.Parent:WaitForChild("DragManager"))
local CooldownManager = require(script.Parent:WaitForChild("CooldownManager"))
local ItemTooltip = require(script.Parent:WaitForChild("tooltip"))
local ActionBarHUD = require(script.Parent:WaitForChild("ActionBarHUD"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local InventoryGrid = {}

local slotFrames = {}
local savedSwapRemote = nil

function InventoryGrid.build(parent, swapRemote, equipRemote, getCurrentData, useItemRemote)
    savedSwapRemote = swapRemote
    
    local parentFrame = parent

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

            -- 1. Drop на UI targets (экипировка)
            local dropped = DragManager.tryDrop(mousePos)

            if not dropped then
                local overIndex = DragManager.dragOverIndex
                if overIndex and overIndex ~= DragManager.dragFrom then
                    -- 2. Swap
                    savedSwapRemote:FireServer(DragManager.dragFrom, overIndex)
                elseif not overIndex then
                    -- 3. Проверяем вне всех UI окон — выброс
                    local isOutside = true

                    -- Проверяем основное окно инвентаря
                    if parentFrame.Visible then
                        local absPos = parentFrame.AbsolutePosition
                        local absSize = parentFrame.AbsoluteSize
                        if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X
                            and mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
                            isOutside = false
                        end
                    end

                    -- Проверяем ActionBar
                    local abFrame = ActionBarHUD.getFrame()
                    if abFrame then
                        local absPos = abFrame.AbsolutePosition
                        local absSize = abFrame.AbsoluteSize
                        if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X
                            and mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
                            isOutside = false
                        end
                    end

                    if isOutside then
                        Remotes.DropItem:FireServer(DragManager.dragFrom)
                    end
                end
            end

            -- Reset обоих наборов слотов
            DragManager.reset(slotFrames)
            local abSlots = ActionBarHUD.getSlots()
            for _, s in abSlots do
                s.BackgroundColor3 = UC.slotBg
            end
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