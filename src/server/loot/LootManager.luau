local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local modules = ReplicatedStorage:WaitForChild("modules")
local InventoryManager = require(modules:WaitForChild("InventoryManager"))

local LootManager = {}

local activeLoot = {} -- { [lootPart] = { itemData, spawnTime } }

function LootManager.dropLoot(enemyEntity)
	local enemyType = enemyEntity:GetAttribute("EnemyType")
	if not enemyType then return end

	local enemyConfig = Config.Enemies[enemyType]
	if not enemyConfig or not enemyConfig.Loot then return end

	local rootPart = enemyEntity:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local basePosition = rootPart.Position
	local dropIndex = 0

	for _, lootEntry in enemyConfig.Loot do
		-- Проверяем шанс
		if math.random() > lootEntry.Chance then continue end

		local itemConfig = Config.Items[lootEntry.ItemId]
		if not itemConfig then
			warn("[LootManager] Unknown item: " .. lootEntry.ItemId)
			continue
		end

		-- Случайное количество
		local amount = math.random(lootEntry.Amount.Min, lootEntry.Amount.Max)

		-- Создаём кубик
		local lootPart = Instance.new("Part")
		lootPart.Name = "Loot_" .. lootEntry.ItemId
		lootPart.Size = Vector3.new(1.2, 1.2, 1.2)
		lootPart.Shape = Enum.PartType.Block
		lootPart.Color = Color3.fromRGB(255, 255, 255)
		lootPart.Material = Enum.Material.Neon
		lootPart.Anchored = true
		lootPart.CanCollide = false

		-- Смещаем каждый кубик чтобы не накладывались
		local offsetX = (dropIndex % 3 - 1) * 2
		local offsetZ = math.floor(dropIndex / 3) * 2
		lootPart.Position = basePosition + Vector3.new(offsetX, 0.6, offsetZ)

		-- Атрибуты для клиента
		lootPart:SetAttribute("ItemId", lootEntry.ItemId)
		lootPart:SetAttribute("ItemName", itemConfig.Name)
		lootPart:SetAttribute("Amount", amount)
		lootPart:SetAttribute("IsLoot", true)

		-- Папка для лута
		local lootFolder = workspace:FindFirstChild("Loot")
		if not lootFolder then
			lootFolder = Instance.new("Folder")
			lootFolder.Name = "Loot"
			lootFolder.Parent = workspace
		end

		lootPart.Parent = lootFolder

		activeLoot[lootPart] = {
			itemId = lootEntry.ItemId,
			itemName = itemConfig.Name,
			amount = amount,
			spawnTime = tick(),
		}

		dropIndex += 1
		print("[LootManager] Dropped " .. itemConfig.Name .. " x" .. amount .. " at " .. tostring(lootPart.Position))
	end
end

function LootManager.tryPickup(player, lootPart)
	if not lootPart or not lootPart.Parent then return false, "Invalid loot" end

	local data = activeLoot[lootPart]
	if not data then return false, "Not loot" end

	-- Проверяем дистанцию
	local character = player.Character
	if not character then return false, "No character" end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false, "No root part" end

	local distance = (rootPart.Position - lootPart.Position).Magnitude
	if distance > Config.Loot.PickupRange then return false, "Too far" end

	-- Пытаемся добавить в инвентарь
	local itemConfig = Config.Items[data.itemId]
	if not itemConfig then return false, "Unknown item" end

	local success, slotIndex = InventoryManager.addItem(player, {
		Id = itemConfig.Id,
		Name = itemConfig.Name,
		Icon = itemConfig.Icon or "",
		Amount = data.amount,
		Stackable = itemConfig.Stackable or false,
		MaxStack = itemConfig.MaxStack or 1,
		Type = itemConfig.Type or "Misc",
	})

	if not success then return false, "Inventory full" end

	-- Удаляем кубик
	activeLoot[lootPart] = nil
	lootPart:Destroy()

	print("[LootManager] " .. player.Name .. " picked up " .. data.itemName .. " x" .. data.amount)
	return true
end

-- Очистка старого лута
function LootManager.cleanup()
	local now = tick()
	for lootPart, data in activeLoot do
		if now - data.spawnTime > Config.Loot.DropLifetime then
			activeLoot[lootPart] = nil
			if lootPart and lootPart.Parent then
				lootPart:Destroy()
			end
		end
	end
end

return LootManager