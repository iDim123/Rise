local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local UC = require(script.Parent:WaitForChild("UIConstants"))
local SlotFactory = require(script.Parent:WaitForChild("SlotFactory"))
local DragManager = require(script.Parent:WaitForChild("DragManager"))
local CooldownManager = require(script.Parent:WaitForChild("CooldownManager"))
local ItemTooltip = require(script.Parent:WaitForChild("tooltip"))

local ActionBarHUD = {}

local actionBarSlots = {}
local cachedSlotsData = nil
local actionBarFrame = nil

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
    frame.AnchorPoint = Vector2.new(0.5, 1)
    frame.Position = UDim2.new(0.5, 0, 1, -10)
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

        -- Drag start
        slot.MouseButton1Down:Connect(function()
            ItemTooltip.hide()
            if cachedSlotsData then
                local item = cachedSlotsData[index]
                if item and item ~= false then
                    DragManager.startDrag(index, item)
                    slot.BackgroundColor3 = UC.slotBgDrag
                end
            end
        end)

        -- Hover для drag и tooltip
        slot.MouseEnter:Connect(function()
            if DragManager.isDragging() and DragManager.dragFrom ~= index then
                DragManager.dragOverIndex = index
                slot.BackgroundColor3 = UC.slotBgTarget
            elseif not DragManager.isDragging() then
                if cachedSlotsData then
                    local item = cachedSlotsData[index]
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

        -- ПКМ
        slot.MouseButton2Click:Connect(function()
            ItemTooltip.hide()
            local slotData = nil
            if cachedSlotsData then
                slotData = cachedSlotsData[index]
            end

            if not slotData or slotData == false then return end

            if slotData.EquipSlot then
                if equipRemote then
                    equipRemote:FireServer(index)
                end
            elseif slotData.Type == "Consumable" then
                if not CooldownManager.isOnCooldown(slotData.Id) then
                    local itemDef = Config.Items[slotData.Id]
                    if itemDef and itemDef.UseEffect and itemDef.UseEffect.Cooldown then
                        CooldownManager.startCooldown(slotData.Id, itemDef.UseEffect.Cooldown)
                    end
                    useItemRemote:FireServer(index)
                end
            elseif slotData.Type == "Weapon" then
                setActiveWeaponRemote:FireServer(index)
            end
        end)

        actionBarSlots[index] = slot

        CooldownManager.registerSlot(slot, function()
            if cachedSlotsData then
                local item = cachedSlotsData[index]
                if item and item ~= false then
                    return item.Id
                end
            end
            return nil
        end)
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