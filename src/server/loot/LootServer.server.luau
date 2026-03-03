local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local modules = ReplicatedStorage:WaitForChild("modules")
local LootManager = require(modules:WaitForChild("LootManager"))
local InventorySync = require(modules:WaitForChild("InventorySync"))

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

task.spawn(function()
    while true do
        task.wait(30)
        LootManager.cleanup()
    end
end)
