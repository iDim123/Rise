local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local HealthManager = {}
local healthData = {}

function HealthManager.init(entity, maxHP)
    healthData[entity] = {
        CurrentHP = maxHP,
        MaxHP = maxHP,
        IsDead = false
    }
    entity:SetAttribute("MaxHP", maxHP)
    entity:SetAttribute("CurrentHP", maxHP)
    entity:SetAttribute("IsDead", false)
end

function HealthManager.takeDamage(entity, damage, attacker)
    local data = healthData[entity]
    if not data or data.IsDead then
        return
    end

    data.CurrentHP = math.floor(math.max(0, data.CurrentHP - damage))
    entity:SetAttribute("CurrentHP", data.CurrentHP)

    local attackerName = attacker and attacker.Name or "Unknown"
    Remotes.DamageEvent:FireAllClients(entity, data.CurrentHP, data.MaxHP, damage, attackerName)

    -- Mark combat for regen timer
    local StatsManager = require(modules:WaitForChild("StatsManager"))
    StatsManager.markCombat(entity)

    if data.CurrentHP <= 0 then
        HealthManager.die(entity, attacker)
    end
end

function HealthManager.die(entity, attacker)
    local data = healthData[entity]
    if not data then
        return
    end

    data.IsDead = true
    entity:SetAttribute("IsDead", true)

    local player = Players:GetPlayerFromCharacter(entity)

    if player then
        EventBus.fire("PlayerDied", player, entity, attacker)
    else
        -- Враг/NPC: сохраняем данные ДО destroy
        local enemyType = entity:GetAttribute("EnemyType")
        local spawnPos = entity:GetAttribute("SpawnPosition")
        local spawnLevel = entity:GetAttribute("SpawnLevel")

        EventBus.fire("EntityDying", entity, attacker)

        entity:Destroy()
        healthData[entity] = nil

        if enemyType and spawnPos then
            EventBus.fire("EntityRemoved", enemyType, spawnPos, spawnLevel)
        end
    end
end

function HealthManager.heal(entity, amount)
    local data = healthData[entity]
    if not data or data.IsDead then
        return
    end

    -- HealingReceived modifier
    local Players = game:GetService("Players")
    local player = Players:GetPlayerFromCharacter(entity)
    if player then
        local StatsManager = require(modules:WaitForChild("StatsManager"))
        local healMod = StatsManager.get(player, "HealingReceived")
        amount = math.floor(amount * healMod)
    end

    local oldHP = data.CurrentHP
    data.CurrentHP = math.floor(math.min(data.MaxHP, data.CurrentHP + amount))
    local actualHeal = data.CurrentHP - oldHP
    entity:SetAttribute("CurrentHP", data.CurrentHP)

    if actualHeal > 0 then
        Remotes.HealEvent:FireAllClients(entity, data.CurrentHP, data.MaxHP, actualHeal)
    end
end

function HealthManager.getData(entity)
    return healthData[entity]
end

-- Подписки
EventBus.on("PlayerDied", function(player, entity, attacker)
    Remotes.EntityDied:FireAllClients(entity)
    task.delay(Config.Player.RespawnTime, function()
        player:LoadCharacter()
    end)
end)

EventBus.on("EntityDying", function(entity, attacker)
    Remotes.EntityDied:FireAllClients(entity)
end)

-- Инициализация игроков
Players.PlayerAdded:Connect(function(player)
    local LevelManager = require(script.Parent:WaitForChild("LevelManager"))
    LevelManager.initPlayer(player)

    player.CharacterAdded:Connect(function(character)
        character:WaitForChild("Humanoid")
        local maxHP = LevelManager.getPlayerMaxHP(player)
        HealthManager.init(character, maxHP)

        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.MaxHealth = maxHP
            humanoid.Health = maxHP
        end

        -- Recalculate stats after character is ready
        local StatsManager = require(modules:WaitForChild("StatsManager"))
        StatsManager.recalculate(player)
    end)
end)

function HealthManager.setMaxHP(entity, newMaxHP)
    local data = healthData[entity]
    if not data or data.IsDead then
        return
    end

    local oldMaxHP = data.MaxHP
    data.MaxHP = newMaxHP
    entity:SetAttribute("MaxHP", newMaxHP)

    -- Пропорционально масштабируем текущее HP
    if oldMaxHP > 0 then
        local ratio = data.CurrentHP / oldMaxHP
        data.CurrentHP = math.floor(ratio * newMaxHP)
        data.CurrentHP = math.max(1, math.min(data.CurrentHP, newMaxHP))
    else
        data.CurrentHP = newMaxHP
    end

    entity:SetAttribute("CurrentHP", data.CurrentHP)

    local humanoid = entity:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.MaxHealth = newMaxHP
        humanoid.Health = data.CurrentHP
    end
end

return HealthManager
