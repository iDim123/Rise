local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local modules = ServerScriptService:WaitForChild("modules")
local combat = ServerScriptService:WaitForChild("combat")
local HealthManager = require(modules:WaitForChild("HealthManager"))
local EventBus = require(modules:WaitForChild("EventBus"))
local TargetFinder = require(combat:WaitForChild("TargetFinder"))

local SpellProgressManager
local function getSPM()
    if not SpellProgressManager then
        SpellProgressManager = require(modules:WaitForChild("SpellProgressManager"))
    end
    return SpellProgressManager
end

local IgniteHandler = {}

-- Active ignites: [target] = { ownerId, totalDamage, remaining, tickInterval, lastTick }
local activeIgnites = {}
local TICK_INTERVAL = 1.0 -- damage every 1 second

-- ═══════════════════════════════════════════════════════════
-- Apply Ignite to a target
-- ═══════════════════════════════════════════════════════════

function IgniteHandler.apply(target, ownerId, spellPower)
    local owner = Players:GetPlayerByUserId(ownerId)
    if not owner then return end

    local spm = getSPM()
    local passive = spm.getEffectivePassive(owner, "Chaos")
    if not passive then return end

    local dotDuration = passive.DotDuration or 5
    local dotPercent = passive.DotPercent or 0.50
    local totalDamage = math.floor(spellPower * dotPercent * 100)
    local ticks = math.floor(dotDuration / TICK_INTERVAL)
    if ticks <= 0 then return end

    activeIgnites[target] = {
        ownerId = ownerId,
        totalDamage = totalDamage,
        damagePerTick = math.floor(totalDamage / ticks),
        remaining = dotDuration,
        lastTick = tick(),
    }

    target:SetAttribute("Passive_Ignite", true)
    target:SetAttribute("Passive_Ignite_Owner", ownerId)
    target:SetAttribute("Passive_Ignite_Expire", tick() + dotDuration)

    print("[IgniteHandler] applied to", target.Name, "totalDmg =", totalDamage, "duration =", dotDuration, "dmg/tick =", math.floor(totalDamage / ticks))
end

-- ═══════════════════════════════════════════════════════════
-- Tick loop: apply DoT damage
-- ═══════════════════════════════════════════════════════════

RunService.Heartbeat:Connect(function()
    local now = tick()
    local toRemove = {}

    for target, data in activeIgnites do
        -- Target destroyed?
        if not target.Parent then
            table.insert(toRemove, target)
            continue
        end

        -- Expired?
        if data.remaining <= 0 then
            table.insert(toRemove, target)
            continue
        end

        -- Tick?
        if (now - data.lastTick) >= TICK_INTERVAL then
            data.lastTick = now
            data.remaining = data.remaining - TICK_INTERVAL

            local owner = Players:GetPlayerByUserId(data.ownerId)
            local attackerChar = owner and owner.Character or nil

            HealthManager.takeDamage(target, data.damagePerTick, attackerChar)
            print("[IgniteHandler] tick on", target.Name, "dmg =", data.damagePerTick, "remaining =", string.format("%.1f", data.remaining))
        end
    end

    for _, target in toRemove do
        activeIgnites[target] = nil
        if target.Parent then
            target:SetAttribute("Passive_Ignite", false)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- On kill: explosion
-- ═══════════════════════════════════════════════════════════

EventBus.on("EntityDying", function(target, attacker)
    local data = activeIgnites[target]
    if not data then return end

    local owner = Players:GetPlayerByUserId(data.ownerId)
    if not owner then return end

    local spm = getSPM()
    local passive = spm.getEffectivePassive(owner, "Chaos")
    if not passive then return end

    local explosionPercent = passive.ExplosionDamagePercent or 0.50
    local explosionRadius = passive.ExplosionRadius or 1
    local spellPower = require(modules:WaitForChild("StatsManager")).get(owner, "MagicalPower") or 1.0
    local explosionDamage = math.floor(spellPower * explosionPercent * 100)

    local targetRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")
    if not targetRoot then return end

    local ownerChar = owner.Character
    print("[IgniteHandler] explosion on death of", target.Name, "dmg =", explosionDamage, "radius =", explosionRadius)

    -- AoE damage
    local nearbyTargets = TargetFinder.inRadius(targetRoot.Position, explosionRadius, target)
    for _, nearby in nearbyTargets do
        if nearby == target then continue end
        HealthManager.takeDamage(nearby, explosionDamage, ownerChar)
        print("[IgniteHandler] explosion hit", nearby.Name, "for", explosionDamage)

        -- Chain ignite
        if passive.ChainIgnite then
            local shouldChain = passive.ChainIgniteGuaranteed or (math.random() < 0.5)
            if shouldChain then
                IgniteHandler.apply(nearby, data.ownerId, spellPower)
                print("[IgniteHandler] chain ignite on", nearby.Name)
            end
        end
    end

    -- Cleanup this target
    activeIgnites[target] = nil
end)

print("[IgniteHandler] Initialized")

return IgniteHandler