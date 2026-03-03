local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local modules = ReplicatedStorage:WaitForChild("modules")
local LootManager = require(modules:WaitForChild("LootManager"))

-- Remote для подбора
local pickupLoot = Instance.new("RemoteEvent")
pickupLoot.Name = "PickupLoot"
pickupLoot.Parent = ReplicatedStorage

-- Remote для обновления инвентаря
local updateInventory = ReplicatedStorage:WaitForChild("UpdateInventory")
local modules = ReplicatedStorage:WaitForChild("modules")
local InventoryManager = require(modules:WaitForChild("InventoryManager"))

-- Обработка запроса подбора
pickupLoot.OnServerEvent:Connect(function(player, lootPart)
	if not lootPart or not lootPart:IsA("Part") then return end

	local success, reason = LootManager.tryPickup(player, lootPart)
	if success then
		-- Отправляем обновлённый инвентарь
		updateInventory:FireClient(player, {
			slots = InventoryManager.getSlots(player),
			equipment = InventoryManager.getEquipment(player),
			activeWeaponSlot = InventoryManager.getActiveWeaponSlot(player),
		})
	else
		print("[LootServer] Pickup failed for " .. player.Name .. ": " .. (reason or "unknown"))
	end
end)

-- Очистка старого лута каждые 30 секунд
task.spawn(function()
	while true do
		task.wait(30)
		LootManager.cleanup()
	end
end)