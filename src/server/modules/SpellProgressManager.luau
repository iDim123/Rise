local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local SpellProgressManager = {}

-- [userId] = { SpellPoints, LearnedSpells, EquippedSlots, SchoolProgress }
local playerData = {}

-- ═══════════════════════════════════════════════════════════
-- Init / Cleanup
-- ═══════════════════════════════════════════════════════════

function SpellProgressManager.init(player)
    local userId = player.UserId
    if playerData[userId] then
        return
    end
    playerData[userId] = {
        SpellPoints = {},
        LearnedSpells = {},
        EquippedSlots = {
            R = nil,
            G = nil,
            Z = nil
        },
        SchoolProgress = {}
    }
end

function SpellProgressManager.cleanup(player)
    playerData[player.UserId] = nil
end

-- ═══════════════════════════════════════════════════════════
-- DataService integration
-- ═══════════════════════════════════════════════════════════

function SpellProgressManager._setPlayerData(player, saved)
    local userId = player.UserId
    if not playerData[userId] then
        SpellProgressManager.init(player)
    end
    local d = playerData[userId]
    d.SpellPoints = saved.SpellPoints or {}
    d.LearnedSpells = saved.LearnedSpells or {}
    d.EquippedSlots = saved.EquippedSlots or {
        R = nil,
        G = nil,
        Z = nil
    }
    d.SchoolProgress = saved.SchoolProgress or {}
end

function SpellProgressManager._getPlayerData(player)
    local d = playerData[player.UserId]
    if not d then
        return nil
    end
    return {
        SpellPoints = d.SpellPoints,
        LearnedSpells = d.LearnedSpells,
        EquippedSlots = d.EquippedSlots,
        SchoolProgress = d.SchoolProgress
    }
end

-- ═══════════════════════════════════════════════════════════
-- Spell Points
-- ═══════════════════════════════════════════════════════════

function SpellProgressManager.addSpellPoints(player, school, tier, amount)
    local d = playerData[player.UserId]
    if not d then
        return
    end
    if not d.SpellPoints[school] then
        d.SpellPoints[school] = {}
    end
    local current = d.SpellPoints[school][tier] or 0
    d.SpellPoints[school][tier] = current + amount
    SpellProgressManager._sync(player)
end

function SpellProgressManager.getSpellPoints(player, school, tier)
    local d = playerData[player.UserId]
    if not d or not d.SpellPoints[school] then
        return 0
    end
    return d.SpellPoints[school][tier] or 0
end

-- ═══════════════════════════════════════════════════════════
-- Learn Spell
-- ═══════════════════════════════════════════════════════════

function SpellProgressManager.canLearn(player, spellId)
    local d = playerData[player.UserId]
    if not d then
        return false, "no_data"
    end
    if d.LearnedSpells[spellId] then
        return false, "already_learned"
    end

    local spellConfig = Config.Spells[spellId]
    if not spellConfig then
        return false, "invalid_spell"
    end

    local school = spellConfig.School
    local tier = spellConfig.Tier
    local cost = spellConfig.UnlockCost or 1

    -- Check previous tier spells are learned (except tier 1)
    if spellConfig.Class == "Basic" and tier > 1 then
        local prevTierComplete = SpellProgressManager._isTierComplete(player, school, tier - 1)
        if not prevTierComplete then
            return false, "prev_tier_incomplete"
        end
    end

    -- Check spell points
    local pointsKey = spellConfig.Class == "Ultimate" and "ULT" or tostring(tier)
    local available = SpellProgressManager.getSpellPoints(player, school, pointsKey)
    if available < cost then
        return false, "not_enough_points"
    end

    return true
end

function SpellProgressManager.learnSpell(player, spellId)
    local canLearn, reason = SpellProgressManager.canLearn(player, spellId)
    if not canLearn then
        return false, reason
    end

    local d = playerData[player.UserId]
    local spellConfig = Config.Spells[spellId]
    local school = spellConfig.School
    local tier = spellConfig.Tier
    local cost = spellConfig.UnlockCost or 1
    local pointsKey = spellConfig.Class == "Ultimate" and "ULT" or tostring(tier)

    -- Spend points
    d.SpellPoints[school][pointsKey] = d.SpellPoints[school][pointsKey] - cost
    d.LearnedSpells[spellId] = true

    -- Check tier completion
    SpellProgressManager._checkTierCompletion(player, school, tier)

    SpellProgressManager._sync(player)
    return true
end

function SpellProgressManager.isLearned(player, spellId)
    local d = playerData[player.UserId]
    if not d then
        return false
    end
    return d.LearnedSpells[spellId] == true
end

-- ═══════════════════════════════════════════════════════════
-- Equip / Unequip Spells to R/G/Z slots
-- ═══════════════════════════════════════════════════════════

function SpellProgressManager.equipSpell(player, spellId, slotKey)
    local d = playerData[player.UserId]
    if not d then
        return false, "no_data"
    end
    if not d.LearnedSpells[spellId] then
        return false, "not_learned"
    end

    local spellConfig = Config.Spells[spellId]
    if not spellConfig then
        return false, "invalid_spell"
    end

    -- Validate slot
    local slotConfig = nil
    for _, slot in Config.SpellSlots do
        if slot.Key == slotKey then
            slotConfig = slot
            break
        end
    end
    if not slotConfig then
        return false, "invalid_slot"
    end

    -- Check class restriction (Z = Ultimate only, R/G = Basic only)
    if slotConfig.AllowedClass ~= spellConfig.Class then
        return false, "class_mismatch"
    end

    -- Check if spell already equipped in another slot
    for key, equipped in d.EquippedSlots do
        if equipped == spellId and key ~= slotKey then
            d.EquippedSlots[key] = nil
        end
    end

    d.EquippedSlots[slotKey] = spellId
    SpellProgressManager._sync(player)
    return true
end

function SpellProgressManager.unequipSpell(player, slotKey)
    local d = playerData[player.UserId]
    if not d then
        return false
    end
    d.EquippedSlots[slotKey] = nil
    SpellProgressManager._sync(player)
    return true
end

function SpellProgressManager.getEquippedSpell(player, slotKey)
    local d = playerData[player.UserId]
    if not d then
        return nil
    end
    return d.EquippedSlots[slotKey]
end

function SpellProgressManager.getEquippedSlots(player)
    local d = playerData[player.UserId]
    if not d then
        return {}
    end
    return d.EquippedSlots
end

-- ═══════════════════════════════════════════════════════════
-- Tier progress helpers
-- ═══════════════════════════════════════════════════════════

function SpellProgressManager._isTierComplete(player, school, tier)
    local d = playerData[player.UserId]
    if not d then
        return false
    end
    -- Check all Basic spells of this school+tier are learned
    for spellId, spellConfig in Config.Spells do
        if spellConfig.School == school and spellConfig.Class == "Basic" and spellConfig.Tier == tier and
            not d.LearnedSpells[spellId] then
            return false
        end
    end
    return true
end

function SpellProgressManager._checkTierCompletion(player, school, tier)
    local d = playerData[player.UserId]
    if not d then
        return
    end
    if not SpellProgressManager._isTierComplete(player, school, tier) then
        return
    end

    if not d.SchoolProgress[school] then
        d.SchoolProgress[school] = {
            CompletedTiers = {}
        }
    end
    d.SchoolProgress[school].CompletedTiers[tostring(tier)] = true
end

function SpellProgressManager.getCompletedTiers(player, school)
    local d = playerData[player.UserId]
    if not d or not d.SchoolProgress[school] then
        return {}
    end
    return d.SchoolProgress[school].CompletedTiers or {}
end

-- ═══════════════════════════════════════════════════════════
-- Get effective passive (with tier bonuses)
-- ═══════════════════════════════════════════════════════════

function SpellProgressManager.getEffectivePassive(player, school)
    local schoolConfig = Config.MagicSchools[school]
    if not schoolConfig then
        return nil
    end

    -- Start with base passive
    local passive = {}
    for k, v in schoolConfig.Passive do
        passive[k] = v
    end

    -- Apply tier bonuses
    local completed = SpellProgressManager.getCompletedTiers(player, school)
    for tier = 1, 3 do
        if completed[tostring(tier)] and schoolConfig.TierBonuses[tier] then
            local bonus = schoolConfig.TierBonuses[tier]
            if bonus.Override then
                for k, v in bonus.Override do
                    passive[k] = v
                end
            end
            if bonus.Extra then
                for k, v in bonus.Extra do
                    passive[k] = v
                end
            end
        end
    end

    -- ULT tier bonus
    local hasUlt = SpellProgressManager._isUltTierComplete(player, school)
    if hasUlt and schoolConfig.UltTierBonus then
        if schoolConfig.UltTierBonus.Override then
            for k, v in schoolConfig.UltTierBonus.Override do
                passive[k] = v
            end
        end
        if schoolConfig.UltTierBonus.Extra then
            for k, v in schoolConfig.UltTierBonus.Extra do
                passive[k] = v
            end
        end
    end

    return passive
end

function SpellProgressManager._isUltTierComplete(player, school)
    local d = playerData[player.UserId]
    if not d then
        return false
    end
    for spellId, spellConfig in Config.Spells do
        if spellConfig.School == school and spellConfig.Class == "Ultimate" and not d.LearnedSpells[spellId] then
            return false
        end
    end
    return true
end

-- ═══════════════════════════════════════════════════════════
-- Sync to client
-- ═══════════════════════════════════════════════════════════

function SpellProgressManager._sync(player)
    local d = playerData[player.UserId]
    if not d then
        return
    end
    Remotes.UpdateSpellData:FireClient(player, {
        SpellPoints = d.SpellPoints,
        LearnedSpells = d.LearnedSpells,
        EquippedSlots = d.EquippedSlots,
        SchoolProgress = d.SchoolProgress
    })
end

-- ═══════════════════════════════════════════════════════════
-- Remotes
-- ═══════════════════════════════════════════════════════════

Remotes.LearnSpell.OnServerEvent:Connect(function(player, spellId)
    if type(spellId) ~= "string" then
        return
    end
    local ok, reason = SpellProgressManager.learnSpell(player, spellId)
    if not ok then
        Remotes.Notify:FireClient(player, "Не удалось изучить: " .. (reason or "unknown"), "error")
    end
end)

Remotes.EquipSpell.OnServerEvent:Connect(function(player, spellId, slotKey)
    if type(spellId) ~= "string" or type(slotKey) ~= "string" then
        return
    end
    local ok, reason = SpellProgressManager.equipSpell(player, spellId, slotKey)
    if not ok then
        Remotes.Notify:FireClient(player, "Не удалось экипировать: " .. (reason or "unknown"),
            "error")
    end
end)

Remotes.UnequipSpell.OnServerEvent:Connect(function(player, slotKey)
    if type(slotKey) ~= "string" then
        return
    end
    SpellProgressManager.unequipSpell(player, slotKey)
end)

Remotes.GetSpellData.OnServerInvoke = function(player)
    return SpellProgressManager._getPlayerData(player)
end

-- ═══════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════

Players.PlayerRemoving:Connect(function(player)
    SpellProgressManager.cleanup(player)
end)

return SpellProgressManager
