local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local InventoryManager = {}
local inventories = {}

function InventoryManager.create(player)
    local totalSlots = Config.Inventory.Rows * Config.Inventory.Columns
    local slots = {}
    for i = 1, totalSlots do
        slots[i] = false
    end

    local equipment = {}
    for _, slotConfig in Config.Equipment.Slots do
        equipment[slotConfig.Id] = false
    end

    inventories[player.UserId] = {
        slots = slots,
        size = totalSlots,
        equipment = equipment,
        activeWeaponSlot = nil, -- номер слота ActionBar с активным оружием
    }
    print("[Inventory] Created for " .. player.Name .. " (" .. totalSlots .. " slots)")
end

function InventoryManager.getInventory(player)
    return inventories[player.UserId]
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

function InventoryManager.getEquipment(player)
    local inv = inventories[player.UserId]
    if not inv then return {} end
    return inv.equipment
end

function InventoryManager.getActiveWeaponSlot(player)
    local inv = inventories[player.UserId]
    if not inv then return nil end
    return inv.activeWeaponSlot
end

function InventoryManager.addItem(player, itemData)
    local inv = inventories[player.UserId]
    if not inv then return false, "No inventory" end

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
                EquipSlot = itemData.EquipSlot or nil,
                Stats = itemData.Stats or {},
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
    if fromIndex < 1 or fromIndex > inv.size then return false end
    if toIndex < 1 or toIndex > inv.size then return false end

    inv.slots[fromIndex], inv.slots[toIndex] = inv.slots[toIndex], inv.slots[fromIndex]

    -- Обновляем activeWeaponSlot если оружие переместилось
    if inv.activeWeaponSlot == fromIndex then
        inv.activeWeaponSlot = toIndex
    elseif inv.activeWeaponSlot == toIndex then
        inv.activeWeaponSlot = fromIndex
    end

    return true
end

function InventoryManager.equipItem(player, slotIndex)
    local inv = inventories[player.UserId]
    if not inv then return false end

    local item = inv.slots[slotIndex]
    if not item or item == false then return false end

    local equipSlot = item.EquipSlot
    if not equipSlot then return false end

    -- Проверяем что слот экипировки существует
    local validSlot = false
    for _, sc in Config.Equipment.Slots do
        if sc.Id == equipSlot then validSlot = true break end
    end
    if not validSlot then return false end

    -- Если в слоте экипировки уже что-то есть — возвращаем в инвентарь
    local currentEquip = inv.equipment[equipSlot]
    inv.equipment[equipSlot] = item
    inv.slots[slotIndex] = false

    if currentEquip and currentEquip ~= false then
        -- Пытаемся вернуть в тот же слот
        inv.slots[slotIndex] = currentEquip
    end

    return true
end

function InventoryManager.unequipItem(player, equipSlotId)
    local inv = inventories[player.UserId]
    if not inv then return false end

    local item = inv.equipment[equipSlotId]
    if not item or item == false then return false end

    -- Ищем свободный слот в инвентаре
    for i = 1, inv.size do
        if inv.slots[i] == false or inv.slots[i] == nil then
            inv.slots[i] = item
            inv.equipment[equipSlotId] = false
            return true
        end
    end

    return false, "Inventory full"
end

function InventoryManager.setActiveWeapon(player, slotIndex)
    local inv = inventories[player.UserId]
    if not inv then return false end

    -- slotIndex должен быть в пределах ActionBar (первая строка)
    local maxActionBar = Config.Inventory.Columns
    if slotIndex < 1 or slotIndex > maxActionBar then return false end

    local item = inv.slots[slotIndex]
    if item and item ~= false and item.Type == Config.ItemTypes.Weapon then
        inv.activeWeaponSlot = slotIndex
        return true
    else
        -- Если в слоте нет оружия — снимаем активное
        if inv.activeWeaponSlot == slotIndex then
            inv.activeWeaponSlot = nil
        end
        return false
    end
end

-- Подсчёт количества предмета по Id во всём инвентаре
function InventoryManager.countItem(player, itemId)
    local inv = inventories[player.UserId]
    if not inv then return 0 end
    local count = 0
    for i = 1, inv.size do
        local slot = inv.slots[i]
        if slot and slot ~= false and slot.Id == itemId then
            count = count + (slot.Amount or 1)
        end
    end
    return count
end

-- Удалить указанное количество предмета по Id (из нескольких стаков если нужно)
function InventoryManager.removeItemById(player, itemId, amount)
    local inv = inventories[player.UserId]
    if not inv then return false end
    local remaining = amount
    for i = 1, inv.size do
        if remaining <= 0 then break end
        local slot = inv.slots[i]
        if slot and slot ~= false and slot.Id == itemId then
            local take = math.min(slot.Amount or 1, remaining)
            slot.Amount = (slot.Amount or 1) - take
            remaining = remaining - take
            if slot.Amount <= 0 then
                inv.slots[i] = false
            end
        end
    end
    return remaining <= 0
end

function InventoryManager.remove(player)
    inventories[player.UserId] = nil
end

function InventoryManager.addItemFromConfig(player, itemId, amount)
    local itemDef = Config.Items[itemId]
    if not itemDef then
        warn("[Inventory] Unknown item: " .. tostring(itemId))
        return false
    end
    return InventoryManager.addItem(player, {
        Id = itemDef.Id,
        Name = itemDef.Name,
        Icon = itemDef.Icon or "rbxassetid://0",
        Amount = amount or 1,
        Stackable = itemDef.Stackable or false,
        MaxStack = itemDef.MaxStack or 1,
        Type = itemDef.Type or "Misc",
        EquipSlot = itemDef.EquipSlot,
        Stats = itemDef.Stats,
        ItemLevel = itemDef.ItemLevel or 0,
    })
end

return InventoryManager