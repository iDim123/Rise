local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UC = require(script.Parent:WaitForChild("UIConstants"))
local DragManager = require(script.Parent:WaitForChild("DragManager"))
local CooldownManager = require(script.Parent:WaitForChild("CooldownManager"))
local ItemTooltip = require(script.Parent:WaitForChild("tooltip"))

local SlotBehavior = {}

local function isLocked(slot)
    local lockIcon = slot:FindFirstChild("LockIcon")
    return lockIcon and lockIcon.Visible
end

function SlotBehavior.connect(slot, index, getItemFn, options)
    -- options: { equipRemote, useItemRemote, setActiveWeaponRemote (optional) }

    slot.MouseButton1Down:Connect(function()
        if isLocked(slot) then return end
        ItemTooltip.hide()
        local item = getItemFn()
        if item and item ~= false then
            DragManager.startDrag(index, item)
            slot.BackgroundColor3 = UC.slotBgDrag
        end
    end)

    slot.MouseEnter:Connect(function()
        if isLocked(slot) then return end
        if DragManager.isDragging() and DragManager.dragFrom ~= index then
            DragManager.dragOverIndex = index
            slot.BackgroundColor3 = UC.slotBgTarget
        elseif not DragManager.isDragging() then
            local item = getItemFn()
            if item and item ~= false then
                ItemTooltip.show(item, slot)
            end
        end
    end)

    slot.MouseLeave:Connect(function()
        if isLocked(slot) then return end
        ItemTooltip.hide()
        if DragManager.dragOverIndex == index then
            DragManager.dragOverIndex = nil
        end
        if not DragManager.isDragging() or DragManager.dragFrom ~= index then
            slot.BackgroundColor3 = UC.slotBg
        end
    end)

    slot.MouseButton2Click:Connect(function()
        if isLocked(slot) then return end
        ItemTooltip.hide()
        local item = getItemFn()
        if not item or item == false then return end

        if item.EquipSlot and options.equipRemote then
            options.equipRemote:FireServer(index)
        elseif item.Type == "Consumable" and options.useItemRemote then
            if not CooldownManager.isOnCooldown(item.Id) then
                local itemDef = Config.Items[item.Id]
                if itemDef and itemDef.UseEffect and itemDef.UseEffect.Cooldown then
                    CooldownManager.startCooldown(item.Id, itemDef.UseEffect.Cooldown)
                end
                options.useItemRemote:FireServer(index)
            end
        elseif item.Type == "Weapon" and options.setActiveWeaponRemote then
            options.setActiveWeaponRemote:FireServer(index)
        end
    end)

    CooldownManager.registerSlot(slot, function()
        local item = getItemFn()
        if item and item ~= false then
            return item.Id
        end
        return nil
    end)
end

return SlotBehavior