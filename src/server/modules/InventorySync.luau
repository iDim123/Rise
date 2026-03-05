local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local InventoryManager = require(script.Parent:WaitForChild("InventoryManager"))

local InventorySync = {}

function InventorySync.sendFullUpdate(player)
    local inv = InventoryManager.getInventory(player)
    Remotes.UpdateInventory:FireClient(player, {
        slots = InventoryManager.getSlots(player),
        equipment = InventoryManager.getEquipment(player),
        activeWeaponSlot = InventoryManager.getActiveWeaponSlot(player),
        unlockedSlots = inv and inv.unlockedSlots or 40,
    })
end

function InventorySync.getFullData(player)
    local inv = InventoryManager.getInventory(player)
    if not inv then return nil end
    return {
        slots = InventoryManager.getSlots(player),
        equipment = inv.equipment,
        activeWeaponSlot = inv.activeWeaponSlot,
        unlockedSlots = inv.unlockedSlots,  -- <<< ДОБАВИТЬ
    }
end

return InventorySync
