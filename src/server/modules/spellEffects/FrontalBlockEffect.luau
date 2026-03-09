local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local modules = ServerScriptService:WaitForChild("modules")
local StatsManager = require(modules:WaitForChild("StatsManager"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local TargetFinder = require(ServerScriptService:WaitForChild("combat"):WaitForChild("TargetFinder"))

return function(ctx, effect, spellConfig)
    local character = ctx.character

    print("[FrontalBlockEffect] angle =", effect.BlockAngle, "reflect =", effect.ReflectPercent, "duration =",
        effect.Duration)

    character:SetAttribute("FrontalBlock", true)
    character:SetAttribute("FrontalBlockAngle", effect.BlockAngle or 120)
    character:SetAttribute("FrontalBlockReflect", effect.ReflectPercent or 0)
    character:SetAttribute("FrontalBlockDamageAbsorbed", 0)

    if effect.MovementMode == "Slowed" then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = humanoid.WalkSpeed * (effect.SpeedMult or 0.4)
            print("[FrontalBlockEffect] slowed to", humanoid.WalkSpeed)
        end
    end

    task.delay(effect.Duration or 2, function()
        local absorbed = character:GetAttribute("FrontalBlockDamageAbsorbed") or 0
        print("[FrontalBlockEffect] expired, absorbed =", absorbed)

        character:SetAttribute("FrontalBlock", false)
        character:SetAttribute("FrontalBlockAngle", nil)
        character:SetAttribute("FrontalBlockReflect", nil)
        character:SetAttribute("FrontalBlockDamageAbsorbed", nil)

        StatsManager.recalculate(ctx.player)

        -- Reflect on expire
        if absorbed > 0 and (effect.ReflectPercent or 0) > 0 then
            local reflectDmg = math.floor(absorbed * effect.ReflectPercent)
            local targets = TargetFinder.inRadius(ctx.rootPart.Position, 8, character)
            print("[FrontalBlockEffect] reflecting", reflectDmg, "to", #targets, "targets")
            for _, target in targets do
                HealthManager.takeDamage(target, reflectDmg, character)
            end
            Remotes.SpellEffect:FireAllClients("Reflect", ctx.rootPart.Position, {
                Damage = reflectDmg
            })
        end
    end)
end
