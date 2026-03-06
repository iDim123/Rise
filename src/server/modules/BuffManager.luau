local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local BuffManager = {}

local activeBuffs = {} -- [entity] = { [buffId] = { config, startTime, duration, source } }

function BuffManager.applyBuff(entity, buffId, duration, source)
    local buffConfig = Config.Buffs[buffId]
    if not buffConfig then
        warn("[BuffManager] Unknown buff: " .. tostring(buffId))
        return false
    end

    if not activeBuffs[entity] then
        activeBuffs[entity] = {}
    end

    local existing = activeBuffs[entity][buffId]

    if existing and not buffConfig.Stackable then
        -- Обновляем длительность (refresh)
        existing.startTime = tick()
        existing.duration = duration
        existing.source = source
    else
        activeBuffs[entity][buffId] = {
            config = buffConfig,
            startTime = tick(),
            duration = duration,
            source = source,
        }
    end

    BuffManager._applyStatEffects(entity)
    BuffManager._sendUpdate(entity)

    -- Recalc player stats
    local player = Players:GetPlayerFromCharacter(entity)
    if player then
        local StatsManager = require(script.Parent:WaitForChild("StatsManager"))
        StatsManager.recalculate(player)
    end

    local displayName = buffConfig.Name or buffId
    print("[BuffManager] Applied " .. displayName .. " (" .. duration .. "s) to " .. entity.Name)

    return true
end

function BuffManager.removeBuff(entity, buffId)
    if not activeBuffs[entity] then return false end
    if not activeBuffs[entity][buffId] then return false end

    activeBuffs[entity][buffId] = nil

    -- Если пусто — удалить запись
    local hasBuffs = false
    for _ in activeBuffs[entity] do
        hasBuffs = true
        break
    end
    if not hasBuffs then
        activeBuffs[entity] = nil
    end

    BuffManager._applyStatEffects(entity)
    BuffManager._sendUpdate(entity)

    -- Recalc player stats
    local player = Players:GetPlayerFromCharacter(entity)
    if player then
        local StatsManager = require(script.Parent:WaitForChild("StatsManager"))
        StatsManager.recalculate(player)
    end

    return true
end

function BuffManager.getActiveBuffs(entity)
    local result = {}
    local buffs = activeBuffs[entity]
    if not buffs then return result end

    local now = tick()
    for buffId, data in buffs do
        local remaining = data.duration - (now - data.startTime)
        if remaining > 0 then
            table.insert(result, {
                Id = buffId,
                Name = data.config.Name,
                Description = data.config.Description,
                Icon = data.config.Icon,
                Type = data.config.Type,
                Remaining = remaining,
                Duration = data.duration,
            })
        end
    end

    return result
end

function BuffManager.getStatModifier(entity, statName)
    local buffs = activeBuffs[entity]
    if not buffs then return 0 end

    local total = 0
    local now = tick()

    for buffId, data in buffs do
        local remaining = data.duration - (now - data.startTime)
        if remaining > 0 and data.config.Stat == statName then
            total = total + data.config.Value
        end
    end

    return total
end

function BuffManager.getAllStatModifiers(entity)
	local result = {}
	local buffs = activeBuffs[entity]
	if not buffs then return result end

	local now = tick()
	for buffId, data in buffs do
		local remaining = data.duration - (now - data.startTime)
		if remaining > 0 and data.config.Stat then
			local statId = data.config.Stat
			result[statId] = (result[statId] or 0) + data.config.Value
		end
	end

	return result
end

function BuffManager.clearBuffs(entity)
    if not activeBuffs[entity] then return end
    activeBuffs[entity] = nil
    BuffManager._applyStatEffects(entity)
    BuffManager._sendUpdate(entity)
end

-- Применяет эффекты скорости на Humanoid
function BuffManager._applyStatEffects(entity)
	-- For players, StatsManager handles side effects
	local player = Players:GetPlayerFromCharacter(entity)
	if player then return end

	-- For enemies: apply speed effects directly
	local humanoid = entity:FindFirstChild("Humanoid")
	if not humanoid then return end

	local enemyType = entity:GetAttribute("EnemyType")
	local baseSpeed = 16
	if enemyType then
		local enemyConfig = Config.Enemies[enemyType]
		if enemyConfig then baseSpeed = enemyConfig.WalkSpeed end
	end

	local speedMod = BuffManager.getStatModifier(entity, "MoveSpeed")
	humanoid.WalkSpeed = math.max(0, baseSpeed * (1 + speedMod))
end
    -- Отправляет обновление баффов клиенту
    function BuffManager._sendUpdate(entity)
        local buffs = BuffManager.getActiveBuffs(entity)
        
        -- If entity is a player character, send to that player
        local player = Players:GetPlayerFromCharacter(entity)
        if player then
            Remotes.UpdateBuffs:FireClient(player, buffs)
            return
        end
        
        -- Otherwise send to all clients (for enemies/servants)
        Remotes.UpdateBuffs:FireAllClients(buffs)
    end

-- Тик — проверка истёкших баффов
function BuffManager.tick()
    local now = tick()

    for entity, buffs in activeBuffs do
        -- Проверяем что entity ещё существует
        if not entity or not entity.Parent then
            activeBuffs[entity] = nil
            continue
        end

        local expired = {}
        for buffId, data in buffs do
            local remaining = data.duration - (now - data.startTime)
            if remaining <= 0 then
                table.insert(expired, buffId)
            end
        end

        if #expired > 0 then
            for _, buffId in expired do
                buffs[buffId] = nil
                print("[BuffManager] Expired: " .. buffId .. " on " .. entity.Name)
            end

            -- Проверяем пусто ли
            local hasBuffs = false
            for _ in buffs do
                hasBuffs = true
                break
            end
            if not hasBuffs then
                activeBuffs[entity] = nil
            end

            BuffManager._applyStatEffects(entity)
            BuffManager._sendUpdate(entity)
        end
    end
end

-- EventBus подписки — очистка при смерти
EventBus.on("EntityDying", function(entity, attacker)
    BuffManager.clearBuffs(entity)
end)

EventBus.on("PlayerDied", function(player, entity, attacker)
    if entity then
        BuffManager.clearBuffs(entity)
    end
end)

return BuffManager