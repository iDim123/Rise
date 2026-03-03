local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local modules = ReplicatedStorage:WaitForChild("modules")
local InventoryManager = require(modules:WaitForChild("InventoryManager"))

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
