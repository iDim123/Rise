local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UC = require(script.Parent:WaitForChild("UIConstants"))
local SlotFactory = require(script.Parent:WaitForChild("SlotFactory"))
local DragManager = require(script.Parent:WaitForChild("DragManager"))
local SlotBehavior = require(script.Parent:WaitForChild("SlotBehavior"))
local ActionBarHUD = require(script.Parent:WaitForChild("ActionBarHUD"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local InventoryGrid = {}

local slotFrames = {}
local savedSwapRemote = nil
local currentUnlockedSlots = 40

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

        SlotBehavior.connect(slot, index, function()
            local data = getCurrentData()
            return data and data.slots and data.slots[index]
        end, { equipRemote = equipRemote, useItemRemote = useItemRemote })

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

            SlotBehavior.connect(slot, index, function()
                local data = getCurrentData()
                return data and data.slots and data.slots[index]
            end, { equipRemote = equipRemote, useItemRemote = useItemRemote })

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

    -- Глобальный обработчик drop и swap
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and DragManager.isDragging() then
            local mousePos = UserInputService:GetMouseLocation()
            local dragFrom = DragManager.dragFrom
            local overIndex = DragManager.dragOverIndex

            local dropped = DragManager.tryDrop(mousePos)

            if not dropped then
                if overIndex and overIndex == dragFrom then
                elseif overIndex and overIndex ~= dragFrom then
                        if overIndex > currentUnlockedSlots then
                        else
                            savedSwapRemote:FireServer(dragFrom, overIndex)
                        end
                elseif not overIndex then

                    local isOverSlot = false
                    for idx, sf in slotFrames do
                        local absPos = sf.AbsolutePosition
                        local absSize = sf.AbsoluteSize
                        if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X
                            and mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
                            isOverSlot = true
                            break
                        end
                    end

                    if not isOverSlot then
                        local abSlots = ActionBarHUD.getSlots()
                        for idx, sf in abSlots do
                            local absPos = sf.AbsolutePosition
                            local absSize = sf.AbsoluteSize
                            if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X
                                and mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
                                isOverSlot = true
                                break
                            end
                        end
                    end


                    if not isOverSlot then
                        local isOutside = true

                        if parentFrame.Visible then
                            local absPos = parentFrame.AbsolutePosition
                            local absSize = parentFrame.AbsoluteSize
                            if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X
                                and mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
                                isOutside = false
                            end
                        end

                        local abFrame = ActionBarHUD.getFrame()
                        if abFrame then
                            local absPos = abFrame.AbsolutePosition
                            local absSize = abFrame.AbsoluteSize
                            -- Добавляем 30px вниз для bind labels
                            if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X
                                and mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y + 30 then
                                isOutside = false
                            end
                        end

                        if isOutside then
                            Remotes.DropItem:FireServer(dragFrom)
                        end
                    end
                end
            end

            DragManager.reset(slotFrames)
        end
    end)
end

function InventoryGrid.refresh(slotsData, activeWeaponSlot, unlockedSlots)
    currentUnlockedSlots = unlockedSlots or 40
    local maxUnlocked = unlockedSlots or 40
    for i, slotFrame in slotFrames do
        local itemData = slotsData[i]
        if itemData == false then itemData = nil end

        if i > maxUnlocked then
            -- Заблокированный слот
            slotFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
            slotFrame.BackgroundTransparency = 0.3

            local lockIcon = slotFrame:FindFirstChild("LockIcon")
            if not lockIcon then
                lockIcon = Instance.new("TextLabel")
                lockIcon.Name = "LockIcon"
                lockIcon.Size = UDim2.new(1, 0, 1, 0)
                lockIcon.BackgroundTransparency = 1
                lockIcon.Text = "⬡"  -- или просто текст
                lockIcon.TextSize = 20
                lockIcon.Font = Enum.Font.GothamBold
                lockIcon.TextColor3 = Color3.fromRGB(60, 60, 75)
                lockIcon.TextTransparency = 0.5
                lockIcon.Parent = slotFrame
            end
            lockIcon.Visible = true

            -- Скрыть содержимое
            local icon = slotFrame:FindFirstChild("Icon")
            if icon then icon.Visible = false end
            local nameLabel = slotFrame:FindFirstChild("NameLabel")
            if nameLabel then nameLabel.Visible = false end
            local amountLabel = slotFrame:FindFirstChild("AmountLabel")
            if amountLabel then amountLabel.Visible = false end
        else
            -- Разблокированный слот
            slotFrame.BackgroundTransparency = 0
            local lockIcon = slotFrame:FindFirstChild("LockIcon")
            if lockIcon then lockIcon.Visible = false end

            SlotFactory.updateSlot(slotFrame, itemData, activeWeaponSlot, i)
        end
    end
end

function InventoryGrid.getSlotFrames()
    return slotFrames
end

return InventoryGrid