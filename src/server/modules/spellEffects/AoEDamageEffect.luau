local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local HealthManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("HealthManager"))
local DamageCalc = require(ServerScriptService:WaitForChild("combat"):WaitForChild("DamageCalc"))
local TargetFinder = require(ServerScriptService:WaitForChild("combat"):WaitForChild("TargetFinder"))

return function(ctx, effect, spellConfig)
    local radius = effect.Radius or 8
    local targets = TargetFinder.inRadius(ctx.rootPart.Position, radius, ctx.character)
    local baseDamage = math.floor(ctx.spellPower * (effect.DamageMult or 1.0) * 100)

    print("[AoEDamageEffect] radius =", radius, "baseDmg =", baseDamage, "targets =", #targets)

    for _, target in targets do
        local finalDamage = DamageCalc.calculate({
            player = ctx.player,
            target = target,
            baseDamage = baseDamage,
            damageType = spellConfig.DamageType or "Magic"
        })
        HealthManager.takeDamage(target, finalDamage, ctx.character)
        print("[AoEDamageEffect] dealt", finalDamage, "to", target.Name)
    end

    Remotes.SpellEffect:FireAllClients("AoEDamage", ctx.rootPart.Position, {
        Radius = radius,
        School = spellConfig.School
    })
end
