local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local InventoryManager = {}
local inventories = {} -- [userId] = { slots = { [1..12] = itemData or nil } }

function InventoryManager.create(player)
    local totalSlots = Config.Inventory.Rows * Config.Inventory.Columns
    local slots = {}
    for i = 1, totalSlots do
        slots[i] = false  -- false вместо nil
    end
    inventories[player.UserId] = { slots = slots, size = totalSlots }
    print("[Inventory] Created for " .. player.Name .. " (" .. totalSlots .. " slots)")
end

function InventoryManager.getInventory(player)
    return inventories[player.UserId]
end

function InventoryManager.addItem(player, itemData)
    local inv = inventories[player.UserId]
    if not inv then return false, "No inventory" end

    -- Стакаемые: ищем существующий стак
    if itemData.Stackable and itemData.MaxStack then
        for i = 1, inv.size do
            local slot = inv.slots[i]
            if slot and slot ~= false and slot.Id == itemData.Id and slot.Amount < slot.MaxStack then
                local canAdd = slot.MaxStack - slot.Amount
                local toAdd = math.min(canAdd, itemData.Amount or 1)
                slot.Amount = slot.Amount + toAdd
                itemData.Amount = (itemData.Amount or 1) - toAdd
                if itemData.Amount <= 0 then
                    return true, i
                end
            end
        end
    end

    -- Ищем пустой слот
    for i = 1, inv.size do
        if inv.slots[i] == false or inv.slots[i] == nil then
            inv.slots[i] = {
                Id = itemData.Id,
                Name = itemData.Name,
                Icon = itemData.Icon or "",
                Amount = itemData.Amount or 1,
                Stackable = itemData.Stackable or false,
                MaxStack = itemData.MaxStack or 1,
                Type = itemData.Type or "Misc",
            }
            return true, i
        end
    end

    return false, "Inventory full"
end

function InventoryManager.removeItem(player, slotIndex, amount)
    local inv = inventories[player.UserId]
    if not inv then return false end

    local slot = inv.slots[slotIndex]
    if not slot or slot == false then return false end

    amount = amount or 1
    slot.Amount = slot.Amount - amount

    if slot.Amount <= 0 then
        inv.slots[slotIndex] = false
    end

    return true
end

function InventoryManager.swapSlots(player, fromIndex, toIndex)
    local inv = inventories[player.UserId]
    if not inv then return false end

    local totalSlots = #inv.slots
    if fromIndex < 1 or fromIndex > totalSlots then return false end
    if toIndex < 1 or toIndex > totalSlots then return false end

    inv.slots[fromIndex], inv.slots[toIndex] = inv.slots[toIndex], inv.slots[fromIndex]
    return true
end

function InventoryManager.getSlots(player)
    local inv = inventories[player.UserId]
    if not inv then return {} end

    local result = {}
    for i = 1, inv.size do
        result[i] = inv.slots[i] or false
    end
    return result
end

function InventoryManager.remove(player)
    inventories[player.UserId] = nil
end

return InventoryManager