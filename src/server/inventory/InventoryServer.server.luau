local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local InventorySync = require(modules:WaitForChild("InventorySync"))

local WeaponHandler = require(script.Parent:WaitForChild("WeaponHandler"))
local CraftHandler = require(script.Parent:WaitForChild("CraftHandler"))
local UseItemHandler = require(script.Parent:WaitForChild("UseItemHandler"))

-- GetInventory
Remotes.GetInventory.OnServerInvoke = function(player)
    return InventorySync.getFullData(player)
end

-- SwapSlots
Remotes.SwapSlots.OnServerEvent:Connect(function(player, fromIndex, toIndex)
    if type(fromIndex) ~= "number" or type(toIndex) ~= "number" then return end
    if InventoryManager.swapSlots(player, math.floor(fromIndex), math.floor(toIndex)) then
        InventorySync.sendFullUpdate(player)
    end
end)

-- EquipItem
Remotes.EquipItem.OnServerEvent:Connect(function(player, slotIndex)
    if type(slotIndex) ~= "number" then return end
    if InventoryManager.equipItem(player, math.floor(slotIndex)) then
        InventorySync.sendFullUpdate(player)
    end
end)

-- UnequipItem
Remotes.UnequipItem.OnServerEvent:Connect(function(player, equipSlotId)
    if type(equipSlotId) ~= "string" then return end
    if InventoryManager.unequipItem(player, equipSlotId) then
        InventorySync.sendFullUpdate(player)
    end
end)

-- SetActiveWeapon
Remotes.SetActiveWeapon.OnServerEvent:Connect(function(player, slotIndex)
    WeaponHandler.onSetActiveWeapon(player, slotIndex)
    InventorySync.sendFullUpdate(player)
end)

-- CraftItem
Remotes.CraftItem.OnServerEvent:Connect(function(player, recipeId)
    CraftHandler.onCraftItem(player, recipeId)
end)

-- UseItem
Remotes.UseItem.OnServerEvent:Connect(function(player, slotIndex)
    UseItemHandler.onUseItem(player, slotIndex)
end)

-- PlayerAdded
Players.PlayerAdded:Connect(function(player)
    InventoryManager.create(player)

    -- Тестовые предметы
    InventoryManager.addItemFromConfig(player, "blood_essence", 150)
    InventoryManager.addItemFromConfig(player, "Sword", 1)
    InventoryManager.addItemFromConfig(player, "iron_helmet", 1)
    InventoryManager.addItemFromConfig(player, "debug_servant_egg", 10)
    InventoryManager.addItemFromConfig(player, "Axe", 1)
    InventoryManager.addItemFromConfig(player, "debug_buff_potion", 10)
end)

-- PlayerRemoving
Players.PlayerRemoving:Connect(function(player)
    CraftHandler.cleanup(player)
    UseItemHandler.cleanup(player)
    InventoryManager.remove(player)
end)