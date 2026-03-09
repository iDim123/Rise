local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local InventoryManager

local WeaponUtil = {}

-- Ленивая загрузка InventoryManager (избегаем циклических зависимостей)
local function getInventoryManager()
    if not InventoryManager then
        InventoryManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("InventoryManager"))
    end
    return InventoryManager
end

-- Получить конфиг текущего оружия игрока
-- returns: weaponConfig, weaponItem | nil, nil
function WeaponUtil.getConfig(player)
    local inv = getInventoryManager().getInventory(player)
    if not inv or not inv.activeWeaponSlot then
        return nil, nil
    end

    local weaponItem = inv.slots[inv.activeWeaponSlot]
    if not weaponItem or weaponItem == false then
        return nil, nil
    end

    local weaponConfig = Config.Weapons[weaponItem.Id]
    if not weaponConfig then
        return nil, nil
    end

    return weaponConfig, weaponItem
end

-- Определить тип оружия: "Melee" | "Ranged"
function WeaponUtil.getType(weaponConfig)
    if not weaponConfig then
        return "Melee"
    end
    return weaponConfig.Type or "Melee"
end

-- Проверить что оружие ranged
function WeaponUtil.isRanged(weaponConfig)
    return WeaponUtil.getType(weaponConfig) == "Ranged"
end

return WeaponUtil
