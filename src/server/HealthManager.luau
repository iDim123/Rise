
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local HealthManager = {}

-- Хранилище HP для всех сущностей (игроки + враги)
local healthData = {}

-- === Инициализация ===

function HealthManager.init(entity, maxHP)
	healthData[entity] = {
		CurrentHP = maxHP,
		MaxHP = maxHP,
		IsDead = false,
	}

	-- Создаём атрибуты для чтения клиентом
	entity:SetAttribute("MaxHP", maxHP)
	entity:SetAttribute("CurrentHP", maxHP)
	entity:SetAttribute("IsDead", false)
end

-- === Нанесение урона ===

function HealthManager.takeDamage(entity, damage, attacker)
	local data = healthData[entity]
	if not data or data.IsDead then return end

	data.CurrentHP = math.max(0, data.CurrentHP - damage)
	entity:SetAttribute("CurrentHP", data.CurrentHP)

	-- Оповещаем клиентов
	Remotes.DamageEvent:FireAllClients(entity, data.CurrentHP, data.MaxHP)

	print(entity.Name .. " took " .. damage .. " damage. HP: " .. data.CurrentHP .. "/" .. data.MaxHP)

	if data.CurrentHP <= 0 then
		HealthManager.die(entity, attacker)
	end
end

-- === Смерть ===

function HealthManager.die(entity, attacker)
	local data = healthData[entity]
	if not data then return end

	data.IsDead = true
	entity:SetAttribute("IsDead", true)

	Remotes.EntityDied:FireAllClients(entity)

	print(entity.Name .. " died!")

	-- Определяем: игрок или враг
	local player = Players:GetPlayerFromCharacter(entity)

	if player then
		-- Игрок: респавн через N секунд
		task.delay(Config.Player.RespawnTime, function()
			player:LoadCharacter()
		end)
	else
		-- Враг: убираем модель, респавн позже
		local spawnPos = entity:GetAttribute("SpawnPosition")
		local enemyType = entity:GetAttribute("EnemyType")

		entity:Destroy()
		healthData[entity] = nil

		-- Респавн врага (будет реализован в EnemyManager)
	end
end

-- === Лечение ===

function HealthManager.heal(entity, amount)
	local data = healthData[entity]
	if not data or data.IsDead then return end

	data.CurrentHP = math.min(data.MaxHP, data.CurrentHP + amount)
	entity:SetAttribute("CurrentHP", data.CurrentHP)
end

-- === Получение данных ===

function HealthManager.getData(entity)
	return healthData[entity]
end

-- === Инициализация игроков ===

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		HealthManager.init(character, Config.Player.MaxHP)
		print("Initialized HP for player: " .. player.Name)
	end)
end)

return HealthManager