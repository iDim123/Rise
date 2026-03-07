local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local ServantEquipment = {}

function ServantEquipment.calcItemLevelSum(equipment)
    local sum = 0
    for _, item in equipment do
        if item and item ~= false then
            local itemDef = Config.Items[item.Id]
            sum = sum + (itemDef and itemDef.ItemLevel or item.ItemLevel or 0)
        end
    end
    return sum
end

function ServantEquipment.calcPower(expertise, equipment)
    local base = Config.Servants.PowerBase
    local sum = ServantEquipment.calcItemLevelSum(equipment)
    return math.floor(base + base * expertise / 100 + sum)
end

function ServantEquipment.recalcStats(servant)
    local power = ServantEquipment.calcPower(servant.expertise, servant.equipment)
    servant.power = power
    servant.atk = math.floor(servant.baseATK + power / 10)
    servant.maxHP = math.floor(servant.baseHP + power)
    if servant.hp > servant.maxHP then
        servant.hp = servant.maxHP
    end
end

function ServantEquipment.initSlots()
    local equipment = {}
    for _, slotConfig in Config.Servants.EquipmentSlots do
        equipment[slotConfig.Id] = false
    end
    return equipment
end

function ServantEquipment.isValidSlot(slotId)
    for _, slotConfig in Config.Servants.EquipmentSlots do
        if slotConfig.Id == slotId then
            return true
        end
    end
    return false
end

function ServantEquipment.equip(servant, slotId, itemData)
    if not ServantEquipment.isValidSlot(slotId) then
        return false, nil
    end

    local previousItem = servant.equipment[slotId]
    if previousItem == false then
        previousItem = nil
    end

    servant.equipment[slotId] = itemData
    ServantEquipment.recalcStats(servant)

    return true, previousItem
end

function ServantEquipment.unequip(servant, slotId)
    local item = servant.equipment[slotId]
    if not item or item == false then
        return false, nil
    end

    servant.equipment[slotId] = false
    ServantEquipment.recalcStats(servant)

    return true, item
end

function ServantEquipment.syncEntity(servant, entity)
    if not entity then
        return
    end
    entity:SetAttribute("ServantATK", servant.atk)
    entity:SetAttribute("MaxHP", servant.maxHP)
    entity:SetAttribute("CurrentHP", servant.hp)
    local humanoid = entity:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.MaxHealth = servant.maxHP
        humanoid.Health = servant.hp
    end
end

return ServantEquipment
