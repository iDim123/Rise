-- Генерация лута, проверка пустоты, сериализация слотов

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local ContainerLoot = {}

-- Генерация лута по LootTable конфига
function ContainerLoot.rollLoot(cfg)
	local slots = {}
	for i = 1, cfg.Slots do
		slots[i] = false
	end

	if math.random() > cfg.SpawnChance then
		return slots, false
	end

	local slotIdx = 1
	for _, entry in cfg.LootTable do
		if slotIdx > cfg.Slots then break end
		if math.random() <= entry.Chance then
			local amount = math.random(entry.Amount.Min, entry.Amount.Max)
			slots[slotIdx] = { ItemId = entry.ItemId, Amount = amount }
			slotIdx += 1
		end
	end

	local hasItem = false
	for _, s in slots do
		if s then hasItem = true break end
	end

	return slots, hasItem
end

-- Сериализация слотов для передачи клиенту
function ContainerLoot.serialize(slots)
	local result = {}
	for i, slot in slots do
		result[i] = slot or false
	end
	return result
end

-- Проверка: все слоты пусты?
function ContainerLoot.isEmpty(slots)
	for _, slot in slots do
		if slot and slot ~= false then
			return false
		end
	end
	return true
end

-- Обновить атрибут ContainerEmpty на модели
function ContainerLoot.updateEmptyAttribute(data)
	local empty = ContainerLoot.isEmpty(data.slots)
	if data.model then
		data.model:SetAttribute("ContainerEmpty", empty)
	end
	if data.spawnPoint and data.spawnPoint ~= data.model then
		data.spawnPoint:SetAttribute("ContainerEmpty", empty)
	end
end

-- Сортировка: сдвигаем непустые слоты в начало
function ContainerLoot.sort(slots, totalSlots)
	local items = {}
	for _, slot in slots do
		if slot then table.insert(items, slot) end
	end
	for i = 1, totalSlots do
		slots[i] = items[i] or false
	end
end

return ContainerLoot