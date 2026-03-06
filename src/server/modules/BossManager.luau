local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local EventBus = require(modules:WaitForChild("EventBus"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local LevelManager = require(modules:WaitForChild("LevelManager"))

local BossManager = {}

-- ═══ Per-player Essence tracking ═══
-- essenceData[userId][bossId] = { Kills = number, Captured = bool }
local essenceData = {}

-- ═══ Per-player unlocked techs ═══
-- unlockedTechs[userId][bossId] = true
local unlockedTechs = {}

-- ═══ Active boss entities ═══
-- activeBosses[bossId] = { entity, state, downedTimer, downedAttacker }
local activeBosses = {}

local BOSS_STATE = {
    ALIVE = "Alive",
    DOWNED = "Downed",
    DEAD = "Dead",
}

BossManager.BOSS_STATE = BOSS_STATE

-- ═══ Init player data ═══
function BossManager.initPlayer(player)
    essenceData[player.UserId] = essenceData[player.UserId] or {}
    unlockedTechs[player.UserId] = unlockedTechs[player.UserId] or {}
end

-- ═══ Essence ═══
function BossManager.getEssence(player, bossId)
    local pData = essenceData[player.UserId]
    if not pData then return 0 end
    local entry = pData[bossId]
    return entry and entry.Kills or 0
end

function BossManager.isEssenceFull(player, bossId)
    local bossConfig = Config.Bosses[bossId]
    if not bossConfig then return false end
    return BossManager.getEssence(player, bossId) >= bossConfig.EssenceRequired
end

function BossManager.addEssence(player, bossId)
    local pData = essenceData[player.UserId]
    if not pData then return end
    if not pData[bossId] then
        pData[bossId] = { Kills = 0, Captured = false }
    end
    local bossConfig = Config.Bosses[bossId]
    if not bossConfig then return end
    -- Cap at EssenceRequired
    pData[bossId].Kills = math.min(pData[bossId].Kills + 1, bossConfig.EssenceRequired)
    print("[BossManager] " .. player.Name .. " essence for " .. bossId .. ": " .. pData[bossId].Kills .. "/" .. bossConfig.EssenceRequired)
end

function BossManager.isCaptured(player, bossId)
    local pData = essenceData[player.UserId]
    if not pData or not pData[bossId] then return false end
    return pData[bossId].Captured == true
end

-- ═══ Tech unlocks ═══
function BossManager.hasTech(player, bossId)
    local pData = unlockedTechs[player.UserId]
    return pData and pData[bossId] == true
end

function BossManager.unlockTech(player, bossId)
    if not unlockedTechs[player.UserId] then
        unlockedTechs[player.UserId] = {}
    end
    if unlockedTechs[player.UserId][bossId] then return false end -- already unlocked

    unlockedTechs[player.UserId][bossId] = true
    Remotes.UnlockTech:FireClient(player, bossId)

    local bossConfig = Config.Bosses[bossId]
    if bossConfig and bossConfig.Unlocks then
        print("[BossManager] " .. player.Name .. " unlocked tech from " .. bossId .. ": " .. (bossConfig.Unlocks.TooltipTitle or ""))
    end

    return true
end

-- Check if a recipe is unlocked for a player (used by CraftHandler)
function BossManager.isRecipeUnlocked(player, recipeId)
    local pTechs = unlockedTechs[player.UserId]
    if not pTechs then return false end

    for bossId, unlocked in pTechs do
        if not unlocked then continue end
        local bossConfig = Config.Bosses[bossId]
        if not bossConfig or not bossConfig.Unlocks then continue end
        if bossConfig.Unlocks.Type == "Recipes" and bossConfig.Unlocks.Recipes then
            for _, rid in bossConfig.Unlocks.Recipes do
                if rid == recipeId then return true end
            end
        end
    end

    return false
end

-- ═══ Boss spawn / state ═══
function BossManager.registerBoss(bossId, entity)
    activeBosses[bossId] = {
        entity = entity,
        state = BOSS_STATE.ALIVE,
        downedTimer = nil,
        downedAttacker = nil,
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

-- Called when boss HP reaches 1 (or 0)
function BossManager.onBossDowned(bossId, attacker)
    local data = activeBosses[bossId]
    if not data or data.state ~= BOSS_STATE.ALIVE then return end

    data.state = BOSS_STATE.DOWNED
    data.downedAttacker = attacker
    data.downedTimer = tick()

    local entity = data.entity
    if entity then
        entity:SetAttribute("BossState", BOSS_STATE.DOWNED)
        -- Set HP to 1, make invulnerable
        entity:SetAttribute("CurrentHP", 1)
        entity:SetAttribute("Invulnerable", true)
        local humanoid = entity:FindFirstChild("Humanoid")
        local rootPart = entity:FindFirstChild("HumanoidRootPart")
        if humanoid then
            humanoid.Health = 1
            humanoid.WalkSpeed = 0
            if rootPart then
                -- Disable physics so model stays in place
                rootPart.Anchored = true
                -- Tilt forward to lie on the ground
                local pos = rootPart.Position
                rootPart.CFrame = CFrame.new(pos.X, pos.Y - 2, pos.Z) * CFrame.Angles(-math.pi / 2, 0, 0)
            end
        end
    end

    print("[BossManager] " .. bossId .. " is DOWNED. 10s timer started.")

    -- Auto-death timer
    task.delay(Config.Bosses.DownedTimeout or 10, function()
        if data.state == BOSS_STATE.DOWNED then
            BossManager.autoDeath(bossId)
        end
    end)
end

-- Player finishes boss with F
function BossManager.finishBoss(player, bossId)
    local data = activeBosses[bossId]
    if not data or data.state ~= BOSS_STATE.DOWNED then return false, "Not downed" end

    local entity = data.entity
    if not entity then return false, "No entity" end

    -- Range check
    local character = player.Character
    if not character then return false, "No character" end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local bossRoot = entity:FindFirstChild("HumanoidRootPart")
    if not rootPart or not bossRoot then return false, "No root" end
    if (rootPart.Position - bossRoot.Position).Magnitude > (Config.Bosses.InteractRange or 8) then
        return false, "Too far"
    end

    -- Award Essence
    BossManager.addEssence(player, bossId)

    -- Unlock tech on first kill
    local firstKill = BossManager.unlockTech(player, bossId)

    -- Award XP
    local bossConfig = Config.Bosses[bossId]
    if bossConfig and bossConfig.XPReward and bossConfig.XPReward > 0 then
        LevelManager.addPlayerXP(player, bossConfig.XPReward)
    end

    -- Loot
    if bossConfig and bossConfig.Loot then
        local LootManager = require(modules:WaitForChild("LootManager"))
        LootManager.dropLoot(entity, bossConfig.Loot)
    end

    -- Kill boss
    BossManager.killBoss(bossId)

    print("[BossManager] " .. player.Name .. " FINISHED " .. bossId .. (firstKill and " (FIRST KILL - tech unlocked!)" or ""))

    -- Notify client
    Remotes.BossFinishResult:FireClient(player, {
        BossId = bossId,
        FirstKill = firstKill,
        Essence = BossManager.getEssence(player, bossId),
        EssenceRequired = bossConfig.EssenceRequired,
    })

    Remotes.Notify:FireClient(player, "Эссенция поглощена (" .. BossManager.getEssence(player, bossId) .. "/" .. bossConfig.EssenceRequired .. ")", "success")
    if firstKill then
        Remotes.Notify:FireClient(player, "Технология разблокирована: " .. (bossConfig.Unlocks.TooltipTitle or ""), "success")
    end

    return true
end

-- Player captures boss with T
function BossManager.captureBoss(player, bossId)
    local data = activeBosses[bossId]
    if not data or data.state ~= BOSS_STATE.DOWNED then return false, "Not downed" end

    if not BossManager.isEssenceFull(player, bossId) then
        local current = BossManager.getEssence(player, bossId)
        local required = Config.Bosses[bossId].EssenceRequired
        Remotes.Notify:FireClient(player, "Эссенция не заполнена (" .. current .. "/" .. required .. ")", "warning")
        return false
    end

    local entity = data.entity
    if not entity then return false, "No entity" end

    -- Range check
    local character = player.Character
    if not character then return false, "No character" end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local bossRoot = entity:FindFirstChild("HumanoidRootPart")
    if not rootPart or not bossRoot then return false, "No root" end
    if (rootPart.Position - bossRoot.Position).Magnitude > (Config.Bosses.InteractRange or 8) then
        return false, "Too far"
    end

    -- Mark captured (essence stays full forever)
    local pData = essenceData[player.UserId]
    if pData and pData[bossId] then
        pData[bossId].Captured = true
    end

    -- Create servant from boss
    local bossConfig = Config.Bosses[bossId]
    local ServantManager = require(modules:WaitForChild("ServantManager"))
    local success, servantId = ServantManager.createFromEgg(player, "Warrior", 100) -- boss servant
    if success then
        local servant = ServantManager.getServantById(player, servantId)
        if servant then
            servant.name = bossConfig.Name .. " (Слуга)"
        end
    end

    -- Award XP
    if bossConfig and bossConfig.XPReward and bossConfig.XPReward > 0 then
        LevelManager.addPlayerXP(player, bossConfig.XPReward)
    end

    -- Kill boss
    BossManager.killBoss(bossId)

    print("[BossManager] " .. player.Name .. " CAPTURED " .. bossId)

    Remotes.BossCaptureResult:FireClient(player, {
        BossId = bossId,
        Success = true,
        ServantId = servantId,
    })

    return true
end

-- Auto-death: no rewards
function BossManager.autoDeath(bossId)
    local data = activeBosses[bossId]
    if not data or data.state ~= BOSS_STATE.DOWNED then return end

    print("[BossManager] " .. bossId .. " auto-died (no one finished/captured)")
    BossManager.killBoss(bossId)
end

-- Destroy entity and schedule respawn
function BossManager.killBoss(bossId)
    local data = activeBosses[bossId]
    if not data then return end

    data.state = BOSS_STATE.DEAD

    local entity = data.entity
    local spawnPos = entity and entity:GetAttribute("SpawnPosition")

    if entity then
        entity:SetAttribute("BossState", BOSS_STATE.DEAD)
        Remotes.EntityDied:FireAllClients(entity)
        entity:Destroy()
    end

    activeBosses[bossId] = nil

    -- Respawn
    local bossConfig = Config.Bosses[bossId]
    if bossConfig and spawnPos then
        task.delay(bossConfig.RespawnTime or 60, function()
            BossManager.spawnBoss(bossId, spawnPos)
        end)
    end
end

-- ═══ Spawn boss ═══
function BossManager.spawnBoss(bossId, spawnPosition)
    local bossConfig = Config.Bosses[bossId]
    if not bossConfig then
        warn("[BossManager] No config for boss: " .. tostring(bossId))
        return nil
    end

    local EnemySpawner = require(modules:WaitForChild("EnemySpawner"))

    -- Use EnemySpawner-like logic but with boss config
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

    entity:SetAttribute("DisplayName", bossConfig.Name)
    entity:SetAttribute("EnemyType", bossId)
    entity:SetAttribute("SpawnPosition", spawnPosition)
    entity:SetAttribute("Level", bossConfig.Level or 1)
    entity:SetAttribute("EnemyLevel", bossConfig.Level or 1)
    entity:SetAttribute("SpawnLevel", bossConfig.Level or 1)
    entity:SetAttribute("CanCapture", false)

    -- HP
    HealthManager.init(entity, bossConfig.MaxHP)

    -- No blood for bosses
    entity:SetAttribute("BloodType", "")
    entity:SetAttribute("BloodQuality", 0)

    -- Register with BossManager
    BossManager.registerBoss(bossId, entity)

    print("[BossManager] Spawned boss: " .. bossConfig.Name .. " Lv" .. bossConfig.Level .. " at " .. tostring(spawnPosition))
    return entity
end

-- ═══ Get all boss data for client ═══
function BossManager.getPlayerBossData(player)
    local result = {}
    for bossId, bossConfig in Config.Bosses do
        if type(bossConfig) ~= "table" or not bossConfig.Name then continue end
        result[bossId] = {
            Name = bossConfig.Name,
            Level = bossConfig.Level,
            Act = bossConfig.Act,
            Location = bossConfig.Location,
            Description = bossConfig.Description,
            Image = bossConfig.Image,
            EssenceRequired = bossConfig.EssenceRequired,
            Essence = BossManager.getEssence(player, bossId),
            TechUnlocked = BossManager.hasTech(player, bossId),
            Captured = BossManager.isCaptured(player, bossId),
            Unlocks = bossConfig.Unlocks,
        }
    end
    return result
end

-- ═══ Override HealthManager.die for bosses ═══
-- Hook into EntityDying to intercept boss death
EventBus.on("EntityDying", function(entity, attacker)
    -- This fires BEFORE entity:Destroy() in normal HealthManager flow
    -- But for bosses, we need to intercept BEFORE die() calls Destroy
end)

-- ═══ Cleanup ═══
function BossManager.removePlayer(player)
    -- essenceData persists (will be saved to DataStore later)
    -- For now, clean up on leave
    essenceData[player.UserId] = nil
    unlockedTechs[player.UserId] = nil
end

return BossManager