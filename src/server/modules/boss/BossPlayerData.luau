local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local BossPlayerData = {}

local essenceData = {}   -- [userId][bossId] = { Kills, Captured }
local unlockedTechs = {} -- [userId][bossId] = true

function BossPlayerData.initPlayer(player)
    essenceData[player.UserId] = essenceData[player.UserId] or {}
    unlockedTechs[player.UserId] = unlockedTechs[player.UserId] or {}
end

-- ═══ Essence ═══

function BossPlayerData.getEssence(player, bossId)
    local pData = essenceData[player.UserId]
    if not pData then return 0 end
    local entry = pData[bossId]
    return entry and entry.Kills or 0
end

function BossPlayerData.isEssenceFull(player, bossId)
    local bossConfig = Config.Bosses[bossId]
    if not bossConfig then return false end
    return BossPlayerData.getEssence(player, bossId) >= bossConfig.EssenceRequired
end

function BossPlayerData.addEssence(player, bossId)
    local pData = essenceData[player.UserId]
    if not pData then return end
    if not pData[bossId] then
        pData[bossId] = { Kills = 0, Captured = false }
    end
    local bossConfig = Config.Bosses[bossId]
    if not bossConfig then return end
    pData[bossId].Kills = math.min(pData[bossId].Kills + 1, bossConfig.EssenceRequired)
    print("[BossPlayerData] " .. player.Name .. " essence for " .. bossId .. ": " .. pData[bossId].Kills .. "/" .. bossConfig.EssenceRequired)
end

function BossPlayerData.isCaptured(player, bossId)
    local pData = essenceData[player.UserId]
    if not pData or not pData[bossId] then return false end
    return pData[bossId].Captured == true
end

function BossPlayerData.markCaptured(player, bossId)
    local pData = essenceData[player.UserId]
    if pData and pData[bossId] then
        pData[bossId].Captured = true
    end
end

-- ═══ Tech ═══

function BossPlayerData.hasTech(player, bossId)
    local pData = unlockedTechs[player.UserId]
    return pData and pData[bossId] == true
end

function BossPlayerData.unlockTech(player, bossId)
    if not unlockedTechs[player.UserId] then
        unlockedTechs[player.UserId] = {}
    end
    if unlockedTechs[player.UserId][bossId] then return false end

    unlockedTechs[player.UserId][bossId] = true
    Remotes.UnlockTech:FireClient(player, bossId)

    local bossConfig = Config.Bosses[bossId]
    if bossConfig and bossConfig.Unlocks then
        print("[BossPlayerData] " .. player.Name .. " unlocked tech from " .. bossId .. ": " .. (bossConfig.Unlocks.TooltipTitle or ""))
    end

    return true
end

function BossPlayerData.isRecipeUnlocked(player, recipeId)
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

-- ═══ Client data ═══

function BossPlayerData.getPlayerBossData(player)
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
            Essence = BossPlayerData.getEssence(player, bossId),
            TechUnlocked = BossPlayerData.hasTech(player, bossId),
            Captured = BossPlayerData.isCaptured(player, bossId),
            Unlocks = bossConfig.Unlocks,
        }
    end
    return result
end

-- ═══ DataService helpers ═══

function BossPlayerData._setPlayerEssence(player, saved)
    essenceData[player.UserId] = saved or {}
end

function BossPlayerData._getPlayerEssence(player)
    return essenceData[player.UserId] or {}
end

function BossPlayerData._setPlayerTechs(player, saved)
    unlockedTechs[player.UserId] = saved or {}
end

function BossPlayerData._getPlayerTechs(player)
    return unlockedTechs[player.UserId] or {}
end

-- ═══ Cleanup ═══

function BossPlayerData.removePlayer(player)
    essenceData[player.UserId] = nil
    unlockedTechs[player.UserId] = nil
end

return BossPlayerData