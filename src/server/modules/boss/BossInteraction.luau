local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local LevelManager = require(modules:WaitForChild("LevelManager"))

local BossPlayerData = require(script.Parent:WaitForChild("BossPlayerData"))

local BossInteraction = {}

-- BossManager reference (set via init to avoid circular require)
local BossManager

function BossInteraction.init(bossManager)
    BossManager = bossManager
end

function BossInteraction.finishBoss(player, bossId)
    local data = BossManager.getBossData(bossId)
    if not data or data.state ~= BossManager.BOSS_STATE.DOWNED then
        return false, "Not downed"
    end

    local entity = data.entity
    if not entity then
        return false, "No entity"
    end

    -- Range check
    local character = player.Character
    if not character then
        return false, "No character"
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local bossRoot = entity:FindFirstChild("HumanoidRootPart")
    if not rootPart or not bossRoot then
        return false, "No root"
    end
    if (rootPart.Position - bossRoot.Position).Magnitude > (Config.Bosses.InteractRange or 8) then
        return false, "Too far"
    end

    -- Award Essence
    BossPlayerData.addEssence(player, bossId)

    -- Unlock tech on first kill
    local firstKill = BossPlayerData.unlockTech(player, bossId)

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

    print("[BossInteraction] " .. player.Name .. " FINISHED " .. bossId ..
              (firstKill and " (FIRST KILL - tech unlocked!)" or ""))

    Remotes.BossFinishResult:FireClient(player, {
        BossId = bossId,
        FirstKill = firstKill,
        Essence = BossPlayerData.getEssence(player, bossId),
        EssenceRequired = bossConfig.EssenceRequired
    })

    Remotes.Notify:FireClient(player,
        "Эссенция поглощена (" .. BossPlayerData.getEssence(player, bossId) .. "/" ..
            bossConfig.EssenceRequired .. ")", "success")
    if firstKill then
        Remotes.Notify:FireClient(player, "Технология разблокирована: " ..
            (bossConfig.Unlocks.TooltipTitle or ""), "success")
    end

    return true
end

function BossInteraction.captureBoss(player, bossId)
    local data = BossManager.getBossData(bossId)
    if not data or data.state ~= BossManager.BOSS_STATE.DOWNED then
        return false, "Not downed"
    end

    if not BossPlayerData.isEssenceFull(player, bossId) then
        local current = BossPlayerData.getEssence(player, bossId)
        local required = Config.Bosses[bossId].EssenceRequired
        Remotes.Notify:FireClient(player,
            "Эссенция не заполнена (" .. current .. "/" .. required .. ")", "warning")
        return false
    end

    local entity = data.entity
    if not entity then
        return false, "No entity"
    end

    -- Range check
    local character = player.Character
    if not character then
        return false, "No character"
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local bossRoot = entity:FindFirstChild("HumanoidRootPart")
    if not rootPart or not bossRoot then
        return false, "No root"
    end
    if (rootPart.Position - bossRoot.Position).Magnitude > (Config.Bosses.InteractRange or 8) then
        return false, "Too far"
    end

    -- Mark captured
    BossPlayerData.markCaptured(player, bossId)

    -- Create servant from boss
    local bossConfig = Config.Bosses[bossId]
    local ServantManager = require(modules:WaitForChild("servant"):WaitForChild("ServantManager"))
    local success, servantId = ServantManager.createFromEgg(player, "Warrior", 100)
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

    print("[BossInteraction] " .. player.Name .. " CAPTURED " .. bossId)

    Remotes.BossCaptureResult:FireClient(player, {
        BossId = bossId,
        Success = true,
        ServantId = servantId
    })

    return true
end

return BossInteraction
