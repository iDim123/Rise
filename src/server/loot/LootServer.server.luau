local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local LootManager = require(modules:WaitForChild("LootManager"))
local InventorySync = require(modules:WaitForChild("InventorySync"))
local InventoryManager = require(modules:WaitForChild("InventoryManager"))

Remotes.PickupLoot.OnServerEvent:Connect(function(player, lootPart)
    if not lootPart or not lootPart:IsA("Part") then
        return
    end

    local success, reason = LootManager.tryPickup(player, lootPart)
    if success then
        InventorySync.sendFullUpdate(player)
    else
        print("[LootServer] Pickup failed for " .. player.Name .. ": " .. (reason or "unknown"))
    end
end)

Remotes.DropItem.OnServerEvent:Connect(function(player, slotIndex)
    if type(slotIndex) ~= "number" then return end
    slotIndex = math.floor(slotIndex)

    local inv = InventoryManager.getInventory(player)
    if not inv then return end

    local item = inv.slots[slotIndex]
    if not item or item == false then return end

    local amount = item.Amount or 1

    local success = LootManager.dropItemFromPlayer(player, slotIndex, item, amount)
    if success then
        InventoryManager.removeItem(player, slotIndex, amount)
        InventorySync.sendFullUpdate(player)
        print("[LootServer] " .. player.Name .. " dropped " .. item.Name .. " x" .. amount)
    end
end)

task.spawn(function()
    while true do
        task.wait(30)
        LootManager.cleanup()
    end
end)
