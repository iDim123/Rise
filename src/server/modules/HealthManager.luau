local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local HealthManager = {}

local healthData = {}

-- === Инициализация ===

function HealthManager.init(entity, maxHP)
	healthData[entity] = {
		CurrentHP = maxHP,
		MaxHP = maxHP,
		IsDead = false,
	}

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

    -- Отправляем урон клиентам (добавлены damage и имя атакующего)
    local attackerName = attacker and attacker.Name or "Unknown"
    Remotes.DamageEvent:FireAllClients(entity, data.CurrentHP, data.MaxHP, damage, attackerName)

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

	local player = Players:GetPlayerFromCharacter(entity)

	if player then
		task.delay(Config.Player.RespawnTime, function()
			player:LoadCharacter()
		end)
	else
		local spawnPos = entity:GetAttribute("SpawnPosition")
		local enemyType = entity:GetAttribute("EnemyType")
		local LootManager = require(script.Parent:WaitForChild("LootManager"))
		LootManager.dropLoot(entity)

		entity:Destroy()
		healthData[entity] = nil

		if spawnPos and enemyType then
			local EnemySpawner = require(script.Parent:WaitForChild("EnemySpawner"))
			EnemySpawner.respawn(enemyType, spawnPos)
		end
	end      -- ← закрывает if/else
end 

-- === Лечение ===

function HealthManager.heal(entity, amount)
    local data = healthData[entity]
    if not data or data.IsDead then return end

    local oldHP = data.CurrentHP
    data.CurrentHP = math.min(data.MaxHP, data.CurrentHP + amount)
    local actualHeal = data.CurrentHP - oldHP
    entity:SetAttribute("CurrentHP", data.CurrentHP)

    if actualHeal > 0 then
        Remotes.HealEvent:FireAllClients(entity, data.CurrentHP, data.MaxHP, actualHeal)
    end
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