local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local EventBus = require(modules:WaitForChild("EventBus"))
local HealthManager = require(modules:WaitForChild("HealthManager"))

local BossPlayerData = require(script.Parent:WaitForChild("BossPlayerData"))
local BossInteraction = require(script.Parent:WaitForChild("BossInteraction"))

local BossManager = {}

local activeBosses = {} -- [bossId] = { entity, state, downedTimer, downedAttacker }

local BOSS_STATE = {
    ALIVE = "Alive",
    DOWNED = "Downed",
    DEAD = "Dead"
}

BossManager.BOSS_STATE = BOSS_STATE

-- Init BossInteraction with reference to BossManager (break circular dependency)
BossInteraction.init(BossManager)

-- ═══ Delegate player data to BossPlayerData ═══

function BossManager.initPlayer(player)
    BossPlayerData.initPlayer(player)
end

function BossManager.getEssence(player, bossId)
    return BossPlayerData.getEssence(player, bossId)
end

function BossManager.isEssenceFull(player, bossId)
    return BossPlayerData.isEssenceFull(player, bossId)
end

function BossManager.addEssence(player, bossId)
    BossPlayerData.addEssence(player, bossId)
end

function BossManager.isCaptured(player, bossId)
    return BossPlayerData.isCaptured(player, bossId)
end

function BossManager.hasTech(player, bossId)
    return BossPlayerData.hasTech(player, bossId)
end

function BossManager.unlockTech(player, bossId)
    return BossPlayerData.unlockTech(player, bossId)
end

function BossManager.isRecipeUnlocked(player, recipeId)
    return BossPlayerData.isRecipeUnlocked(player, recipeId)
end

function BossManager.getPlayerBossData(player)
    return BossPlayerData.getPlayerBossData(player)
end

function BossManager._setPlayerEssence(player, saved)
    BossPlayerData._setPlayerEssence(player, saved)
end

function BossManager._getPlayerEssence(player)
    return BossPlayerData._getPlayerEssence(player)
end

function BossManager._setPlayerTechs(player, saved)
    BossPlayerData._setPlayerTechs(player, saved)
end

function BossManager._getPlayerTechs(player)
    return BossPlayerData._getPlayerTechs(player)
end

function BossManager.removePlayer(player)
    BossPlayerData.removePlayer(player)
end

-- ═══ Delegate interactions to BossInteraction ═══

function BossManager.finishBoss(player, bossId)
    return BossInteraction.finishBoss(player, bossId)
end

function BossManager.captureBoss(player, bossId)
    return BossInteraction.captureBoss(player, bossId)
end

-- ═══ Boss state / spawn ═══

function BossManager.registerBoss(bossId, entity)
    activeBosses[bossId] = {
        entity = entity,
        state = BOSS_STATE.ALIVE,
        downedTimer = nil,
        downedAttacker = nil
    }
    entity:SetAttribute("IsBoss", true)
    entity:SetAttribute("BossId", bossId)
    entity:SetAttribute("BossState", BOSS_STATE.ALIVE)
    print("[BossManager] Registered boss: " .. bossId)
end

function BossManager.getBossData(bossId)
    return activeBosses[bossId]
end

function BossManager.getBossState(bossId)
    local data = activeBosses[bossId]
    return data and data.state or nil
end

function BossManager.onBossDowned(bossId, attacker)
    local data = activeBosses[bossId]
    if not data or data.state ~= BOSS_STATE.ALIVE then
        return
    end

    data.state = BOSS_STATE.DOWNED
    data.downedAttacker = attacker
    data.downedTimer = os.clock()

    local entity = data.entity
    if entity then
        entity:SetAttribute("BossState", BOSS_STATE.DOWNED)
        entity:SetAttribute("CurrentHP", 1)
        entity:SetAttribute("Invulnerable", true)
        local humanoid = entity:FindFirstChild("Humanoid")
        local rootPart = entity:FindFirstChild("HumanoidRootPart")
        if humanoid then
            humanoid.Health = 1
            humanoid.WalkSpeed = 0
            if rootPart then
                rootPart.Anchored = true
                local pos = rootPart.Position
                rootPart.CFrame = CFrame.new(pos.X, pos.Y - 2, pos.Z) * CFrame.Angles(-math.pi / 2, 0, 0)
            end
        end
    end

    print("[BossManager] " .. bossId .. " is DOWNED. 10s timer started.")

    task.delay(Config.Bosses.DownedTimeout or 10, function()
        if data.state == BOSS_STATE.DOWNED then
            BossManager.autoDeath(bossId)
        end
    end)
end

function BossManager.autoDeath(bossId)
    local data = activeBosses[bossId]
    if not data or data.state ~= BOSS_STATE.DOWNED then
        return
    end

    print("[BossManager] " .. bossId .. " auto-died (no one finished/captured)")
    BossManager.killBoss(bossId)
end

function BossManager.killBoss(bossId)
    local data = activeBosses[bossId]
    if not data then
        return
    end

    data.state = BOSS_STATE.DEAD

    local entity = data.entity
    local spawnPos = entity and entity:GetAttribute("SpawnPosition")

    if entity then
        entity:SetAttribute("BossState", BOSS_STATE.DEAD)
        Remotes.EntityDied:FireAllClients(entity)
        entity:Destroy()
    end

    activeBosses[bossId] = nil

    local bossConfig = Config.Bosses[bossId]
    if bossConfig and spawnPos then
        task.delay(bossConfig.RespawnTime or 60, function()
            BossManager.spawnBoss(bossId, spawnPos)
        end)
    end
end

function BossManager.spawnBoss(bossId, spawnPosition)
    local bossConfig = Config.Bosses[bossId]
    if not bossConfig then
        warn("[BossManager] No config for boss: " .. tostring(bossId))
        return nil
    end

    local ServerStorage = game:GetService("ServerStorage")
    local bossesStorage = ServerStorage:FindFirstChild("bosses")
    if not bossesStorage then
        warn("[BossManager] No bosses folder in ServerStorage")
        return nil
    end

    local template = bossesStorage:FindFirstChild(bossId)
    if not template then
        warn("[BossManager] No template for boss: " .. bossId)
        return nil
    end

    local activeEnemies = workspace:FindFirstChild("Enemies")
    if not activeEnemies then
        activeEnemies = Instance.new("Folder")
        activeEnemies.Name = "Enemies"
        activeEnemies.Parent = workspace
    end

    local entity = template:Clone()
    entity.Name = bossConfig.Name or bossId
    entity.Parent = activeEnemies

    local rootPart = entity:FindFirstChild("HumanoidRootPart")
    if rootPart then
        rootPart.Anchored = false
        rootPart.CFrame = CFrame.new(spawnPosition)
    end

    local humanoid = entity:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = bossConfig.WalkSpeed or 14
    end

    entity:SetAttribute("BossId", bossId)
    entity:SetAttribute("IsBoss", true)
    entity:SetAttribute("DisplayName", bossConfig.Name)
    entity:SetAttribute("EnemyType", bossId)
    entity:SetAttribute("SpawnPosition", spawnPosition)
    entity:SetAttribute("Level", bossConfig.Level or 1)
    entity:SetAttribute("EnemyLevel", bossConfig.Level or 1)
    entity:SetAttribute("SpawnLevel", bossConfig.Level or 1)
    entity:SetAttribute("CanCapture", false)

    HealthManager.init(entity, bossConfig.MaxHP)

    entity:SetAttribute("BloodType", "")
    entity:SetAttribute("BloodQuality", 0)

    BossManager.registerBoss(bossId, entity)

    print("[BossManager] Spawned boss: " .. bossConfig.Name .. " Lv" .. bossConfig.Level .. " at " ..
              tostring(spawnPosition))
    return entity
end

-- ═══ EventBus hook ═══

EventBus.on("EntityDying", function(entity, attacker)
    -- placeholder for future boss death interception
end)

return BossManager
