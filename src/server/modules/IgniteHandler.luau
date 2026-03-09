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
    if not owner then
        return
    end

    local spm = getSPM()
    local passive = spm.getEffectivePassive(owner, "Chaos")
    if not passive then
        return
    end

    local dotDuration = passive.DotDuration or 5
    local dotPercent = passive.DotPercent or 0.50
    local totalDamage = math.floor(spellPower * dotPercent * 100)
    local ticks = math.floor(dotDuration / TICK_INTERVAL)
    if ticks <= 0 then
        return
    end

    activeIgnites[target] = {
        ownerId = ownerId,
        totalDamage = totalDamage,
        damagePerTick = math.floor(totalDamage / ticks),
        remaining = dotDuration,
        lastTick = tick()
    }

    target:SetAttribute("Passive_Ignite", true)
    target:SetAttribute("Passive_Ignite_Owner", ownerId)
    target:SetAttribute("Passive_Ignite_Expire", tick() + dotDuration)

    print("[IgniteHandler] applied to", target.Name, "totalDmg =", totalDamage, "duration =", dotDuration, "dmg/tick =",
        math.floor(totalDamage / ticks))
end

function IgniteHandler.init()
    RunService.Heartbeat:Connect(function()
        -- ...существующая tick логика...
    end)

    EventBus.on("EntityDying", function(target, attacker)
        -- ...существующая explosion логика...
    end)

    print("[IgniteHandler] Initialized")
end

print("[IgniteHandler] Initialized")

return IgniteHandler
