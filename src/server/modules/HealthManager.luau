local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local HealthManager = {}
local healthData = {}

-- Periodic GC: remove entries for destroyed entities
local GC_INTERVAL = 30
task.spawn(function()
    while true do
        task.wait(GC_INTERVAL)
        for entity, _ in healthData do
            if not entity or not entity.Parent then
                healthData[entity] = nil
            end
        end
    end
end)

function HealthManager.init(entity, maxHP)
    healthData[entity] = {
        CurrentHP = maxHP,
        MaxHP = maxHP,
        IsDead = false
    }
    entity:SetAttribute("MaxHP", maxHP)
    entity:SetAttribute("CurrentHP", maxHP)
    entity:SetAttribute("IsDead", false)
    -- print("[HealthManager] init:", entity.Name, "HP:", maxHP, "IsStructure:", entity:GetAttribute("IsStructure") or false) -- DEBUG
end

function HealthManager.takeDamage(entity, damage, attacker)
    local data = healthData[entity]
    if not data or data.IsDead then
        return
    end
    if entity:GetAttribute("Invulnerable") then
        return
    end

    data.CurrentHP = math.floor(math.max(0, data.CurrentHP - damage))
    entity:SetAttribute("CurrentHP", data.CurrentHP)

    EventBus.fire("EntityTookDamage", entity, damage, attacker)

    -- ═══ v1.9: Разделение структур и живых сущностей ═══
    local isStructure = entity:GetAttribute("IsStructure")

    if isStructure then
        -- Структуры: отдельный remote (клиент не ищет Humanoid)
        Remotes.StructureDamageEvent:FireAllClients(entity, data.CurrentHP, data.MaxHP, damage)
        print("[HealthManager] Structure took damage:", entity.Name, "HP:", data.CurrentHP, "/", data.MaxHP, "dmg:",
            damage) -- DEBUG

        -- Структура не входит в combat, но АТАКУЮЩИЙ входит (останавливаем реген)
        if attacker then
            local StatsManager = require(modules:WaitForChild("StatsManager"))
            StatsManager.markCombat(attacker)
        end
    else
        -- Живые сущности: стандартный DamageEvent
        local attackerName = attacker and attacker.Name or "Unknown"
        Remotes.DamageEvent:FireAllClients(entity, data.CurrentHP, data.MaxHP, damage, attackerName)

        -- Mark combat for regen timer (both attacker and target)
        local StatsManager = require(modules:WaitForChild("StatsManager"))
        StatsManager.markCombat(entity)
        if attacker then
            StatsManager.markCombat(attacker)
        end
    end

    if data.CurrentHP <= 0 then
        -- Структуры не могут быть боссами — пропускаем boss check
        if not isStructure then
            local bossId = entity:GetAttribute("BossId")
            if bossId then
                local BossManager = require(modules:WaitForChild("boss"):WaitForChild("BossManager"))
                if BossManager.getBossState(bossId) == BossManager.BOSS_STATE.ALIVE then
                    data.CurrentHP = 1
                    entity:SetAttribute("CurrentHP", 1)
                    local humanoid = entity:FindFirstChild("Humanoid")
                    if humanoid then
                        humanoid.Health = 1
                    end
                    BossManager.onBossDowned(bossId, attacker)
                    return
                end
            end
        end

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

    -- ═══ v1.9: Структуры — отдельная ветвь смерти ═══
    if entity:GetAttribute("IsStructure") then
        print("[HealthManager] Structure destroyed:", entity.Name, "attacker:", attacker and attacker.Name or "nil") -- DEBUG
        EventBus.fire("StructureDestroyed", entity, attacker)
        -- Part уничтожается BuildingManager через StructureDestroyed listener,
        -- здесь только очищаем healthData
        healthData[entity] = nil
        return
    end

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

    -- HealingReceived modifier — только для персонажей игроков
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

EventBus.on("PlayerDied", function(player, entity, attacker)
    local humanoid = entity:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.JumpHeight = 0
        humanoid.Health = 1
        humanoid.MaxHealth = math.huge
    end

    Remotes.EntityDied:FireAllClients(entity)

    local respawnTime = Config.Player.RespawnTime or 10
    Remotes.PlayerDied:FireClient(player, respawnTime)

    -- Страховка
    task.delay(respawnTime + 2, function()
        if player.Parent and entity and entity.Parent and entity:GetAttribute("IsDead") then
            player:LoadCharacter()
        end
    end)
end)

EventBus.on("EntityDying", function(entity, attacker)
    Remotes.EntityDied:FireAllClients(entity)
end)

-- Explicit cleanup for an entity (call when entity is removed/player leaves)
function HealthManager.cleanup(entity)
    healthData[entity] = nil
end

function HealthManager.setMaxHP(entity, newMaxHP)
    local data = healthData[entity]
    if not data or data.IsDead then
        return
    end

    local oldMaxHP = data.MaxHP
    data.MaxHP = newMaxHP
    entity:SetAttribute("MaxHP", newMaxHP)

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

Remotes.PlayerRespawn.OnServerEvent:Connect(function(player)
    local character = player.Character
    if not character then
        return
    end
    if not character:GetAttribute("IsDead") then
        return
    end

    player:LoadCharacter()
end)

return HealthManager
