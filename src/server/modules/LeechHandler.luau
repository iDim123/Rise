local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local modules = ServerScriptService:WaitForChild("modules")
local HealthManager = require(modules:WaitForChild("HealthManager"))
local EventBus = require(modules:WaitForChild("EventBus"))

local SpellProgressManager
local function getSPM()
    if not SpellProgressManager then
        SpellProgressManager = require(modules:WaitForChild("SpellProgressManager"))
    end
    return SpellProgressManager
end

local LeechHandler = {}

-- ═══════════════════════════════════════════════════════════
-- Check if target has Leech passive
-- ═══════════════════════════════════════════════════════════

local function hasLeech(target)
    if not target:GetAttribute("Passive_Leech") then
        return false
    end
    local expire = target:GetAttribute("Passive_Leech_Expire") or 0
    if os.clock() > expire then
        target:SetAttribute("Passive_Leech", false)
        return false
    end
    return true
end

local function getLeechOwner(target)
    return target:GetAttribute("Passive_Leech_Owner")
end

-- ═══════════════════════════════════════════════════════════
-- On hit: heal attacker for % of damage dealt
-- ═══════════════════════════════════════════════════════════

function LeechHandler.onDamageDealt(attacker, target, damage)
    if not hasLeech(target) then
        return
    end

    local ownerId = getLeechOwner(target)
    if not ownerId then
        return
    end

    local owner = Players:GetPlayerByUserId(ownerId)
    if not owner then
        return
    end

    local spm = getSPM()
    local passive = spm.getEffectivePassive(owner, "Blood")
    if not passive then
        return
    end

    local healPercent = passive.HealOnHitPercent or 0.10
    local healAmount = math.floor(damage * healPercent)
    if healAmount <= 0 then
        return
    end

    local ownerChar = owner.Character
    if not ownerChar or ownerChar:GetAttribute("IsDead") then
        return
    end

    HealthManager.heal(ownerChar, healAmount)
    print("[LeechHandler] onHit: healed", owner.Name, "for", healAmount, "(", damage, "*", healPercent, ")")
end

-- ═══════════════════════════════════════════════════════════
-- On kill: heal attacker for % of max HP
-- ═══════════════════════════════════════════════════════════

function LeechHandler.onTargetKilled(attacker, target)
    if not target:GetAttribute("Passive_Leech") then
        return
    end

    local ownerId = getLeechOwner(target)
    if not ownerId then
        return
    end

    local owner = Players:GetPlayerByUserId(ownerId)
    if not owner then
        return
    end

    local spm = getSPM()
    local passive = spm.getEffectivePassive(owner, "Blood")
    if not passive then
        return
    end

    local killHealPercent = passive.HealOnKillPercent or 0.03
    local ownerChar = owner.Character
    if not ownerChar or ownerChar:GetAttribute("IsDead") then
        return
    end

    local maxHP = ownerChar:GetAttribute("MaxHP") or 100
    local healAmount = math.floor(maxHP * killHealPercent)
    if healAmount <= 0 then
        return
    end

    HealthManager.heal(ownerChar, healAmount)
    print("[LeechHandler] onKill: healed", owner.Name, "for", healAmount, "(", maxHP, "*", killHealPercent, ")")

    -- Slow enemy if tier 3 bonus
    if passive.SlowPercent and passive.SlowPercent > 0 then
        print("[LeechHandler] slow bonus active but target died — no slow applied")
    end
end

function LeechHandler.init()
    EventBus.on("EntityTookDamage", function(target, damage, attacker)
        if not attacker then
            return
        end
        LeechHandler.onDamageDealt(attacker, target, damage)
    end)

    EventBus.on("EntityDying", function(target, attacker)
        if not attacker then
            return
        end
        LeechHandler.onTargetKilled(attacker, target)
    end)

    print("[LeechHandler] Initialized")
end

return LeechHandler
