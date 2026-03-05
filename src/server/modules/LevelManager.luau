local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local EventBus = require(modules:WaitForChild("EventBus"))

local LevelManager = {}

-- Storage: playerData[userId] = { Level, XP, MaxHP }
local playerData = {}

-- Storage: servantData[servantId] = { Level, XP, MaxHP, BaseHP, OwnerId }
local servantLevels = {}

-- Constants
local BASE_HP = Config.Player.BaseHP or 100
local HP_PER_LEVEL = Config.Player.HPPerLevel or 20
local MAX_LEVEL = Config.Player.MaxLevel or 20
local BASE_XP = Config.Player.BaseXP or 100

-- ══════════════════════════════════
--  Формулы
-- ══════════════════════════════════

function LevelManager.getXPToNext(level)
    if level >= MAX_LEVEL then return 0 end
    return BASE_XP * level
end

function LevelManager.getMaxHP(level, baseHP)
    baseHP = baseHP or BASE_HP
    return baseHP + HP_PER_LEVEL * (level - 1)
end

function LevelManager.getDamageModifier(attackerLevel, defenderLevel)
    local diff = attackerLevel - defenderLevel
    local modifier
    if diff >= 0 then
        -- Overleveled: +1% per level
        modifier = math.clamp(diff * 0.01, 0, 1.0)
    else
        -- Underleveled: -4% per level
        modifier = math.clamp(diff * 0.04, -1.0, 0)
    end
    return modifier
end

-- ══════════════════════════════════
--  Игрок
-- ══════════════════════════════════

function LevelManager.initPlayer(player)
    local userId = player.UserId
    playerData[userId] = {
        Level = 1,
        XP = 0,
        MaxHP = LevelManager.getMaxHP(1),
    }
    LevelManager._sendUpdate(player)
    print("[LevelManager] Initialized player " .. player.Name .. " at Level 1")
end

function LevelManager.getPlayerLevel(player)
    local data = playerData[player.UserId]
    return data and data.Level or 1
end

function LevelManager.getPlayerXP(player)
    local data = playerData[player.UserId]
    return data and data.XP or 0
end

function LevelManager.getPlayerMaxHP(player)
    local data = playerData[player.UserId]
    return data and data.MaxHP or LevelManager.getMaxHP(1)
end

function LevelManager.addPlayerXP(player, amount)
    local data = playerData[player.UserId]
    if not data then return end
    if data.Level >= MAX_LEVEL then return end

    data.XP = data.XP + amount

    -- Level up loop
    local leveled = false
    while data.Level < MAX_LEVEL do
        local needed = LevelManager.getXPToNext(data.Level)
        if data.XP >= needed then
            data.XP = data.XP - needed
            data.Level = data.Level + 1
            data.MaxHP = LevelManager.getMaxHP(data.Level)
            leveled = true
            print("[LevelManager] " .. player.Name .. " leveled up to " .. data.Level)
        else
            break
        end
    end

    -- Cap XP at max level
    if data.Level >= MAX_LEVEL then
        data.XP = 0
    end

    if leveled then
        -- Update humanoid MaxHealth
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.MaxHealth = data.MaxHP
                humanoid.Health = data.MaxHP -- Full heal on level up
            end
        end
    end

    LevelManager._sendUpdate(player)
end

-- ══════════════════════════════════
--  Слуги
-- ══════════════════════════════════

function LevelManager.initServant(servantId, ownerId, baseHP)
    servantLevels[servantId] = {
        Level = 1,
        XP = 0,
        BaseHP = baseHP,
        MaxHP = LevelManager.getMaxHP(1, baseHP),
        OwnerId = ownerId,
    }
    print("[LevelManager] Initialized servant " .. servantId .. " at Level 1, BaseHP=" .. baseHP)
end

function LevelManager.getServantLevel(servantId)
    local data = servantLevels[servantId]
    return data and data.Level or 1
end

function LevelManager.getServantXP(servantId)
    local data = servantLevels[servantId]
    return data and data.XP or 0
end

function LevelManager.getServantMaxHP(servantId)
    local data = servantLevels[servantId]
    return data and data.MaxHP or 100
end

function LevelManager.getServantData(servantId)
    return servantLevels[servantId]
end

function LevelManager.addServantXP(servantId, amount)
    local data = servantLevels[servantId]
    if not data then return end
    if data.Level >= MAX_LEVEL then return end

    data.XP = data.XP + amount

    local leveled = false
    while data.Level < MAX_LEVEL do
        local needed = LevelManager.getXPToNext(data.Level)
        if data.XP >= needed then
            data.XP = data.XP - needed
            data.Level = data.Level + 1
            data.MaxHP = LevelManager.getMaxHP(data.Level, data.BaseHP)
            leveled = true
            print("[LevelManager] Servant " .. servantId .. " leveled up to " .. data.Level)
        else
            break
        end
    end

    if data.Level >= MAX_LEVEL then
        data.XP = 0
    end

    -- Notify owner
    local owner = Players:GetPlayerByUserId(data.OwnerId)
    if owner then
        LevelManager._sendServantUpdate(owner, servantId)
    end
end

function LevelManager.removeServant(servantId)
    servantLevels[servantId] = nil
end

-- ══════════════════════════════════
--  Обновление клиента
-- ══════════════════════════════════

function LevelManager._sendUpdate(player)
    local data = playerData[player.UserId]
    if not data then return end
    Remotes.UpdateLevel:FireClient(player, {
        Level = data.Level,
        XP = data.XP,
        MaxHP = data.MaxHP,
        XPToNext = LevelManager.getXPToNext(data.Level),
    })
end

function LevelManager._sendServantUpdate(player, servantId)
    local data = servantLevels[servantId]
    if not data then return end
    Remotes.UpdateServantLevel:FireClient(player, servantId, {
        Level = data.Level,
        XP = data.XP,
        MaxHP = data.MaxHP,
        XPToNext = LevelManager.getXPToNext(data.Level),
    })
end

-- ══════════════════════════════════
--  EventBus: XP при убийстве
-- ══════════════════════════════════

EventBus.on("EntityDying", function(entity, attacker)
    if not attacker then return end

    -- Определяем игрока-атакующего
    local player = Players:GetPlayerFromCharacter(attacker)
    if not player then return end

    -- Определяем тип врага
    local enemyType = entity:GetAttribute("EnemyType")
    if not enemyType then return end

    local enemyConfig = Config.Enemies[enemyType]
    if not enemyConfig then return end

    local xpReward = enemyConfig.XPReward or 0
    if xpReward <= 0 then return end

    -- XP игроку
    LevelManager.addPlayerXP(player, xpReward)
    print("[LevelManager] " .. player.Name .. " gained " .. xpReward .. " XP from " .. enemyType)

    -- XP активному слуге (если призван)
    local ServantManager = require(modules:WaitForChild("ServantManager"))
    local servantData = ServantManager.getData(player)
    if servantData and servantData.activeId then
        LevelManager.addServantXP(servantData.activeId, xpReward)
    end
end)

-- ══════════════════════════════════
--  Cleanup
-- ══════════════════════════════════

Players.PlayerRemoving:Connect(function(player)
    playerData[player.UserId] = nil
end)

return LevelManager