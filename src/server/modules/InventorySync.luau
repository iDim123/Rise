local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local InventoryManager = require(script.Parent:WaitForChild("InventoryManager"))

local InventorySync = {}

function InventorySync.sendFullUpdate(player)
    Remotes.UpdateInventory:FireClient(player, {
        slots = InventoryManager.getSlots(player),
        equipment = InventoryManager.getEquipment(player),
        activeWeaponSlot = InventoryManager.getActiveWeaponSlot(player)
    })
end

function InventorySync.getFullData(player)
    return {
        slots = InventoryManager.getSlots(player),
        equipment = InventoryManager.getEquipment(player),
        activeWeaponSlot = InventoryManager.getActiveWeaponSlot(player)
    }
end

return InventorySync
