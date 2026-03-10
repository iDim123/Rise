local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local combat = ServerScriptService:WaitForChild("combat")
local modules = ServerScriptService:WaitForChild("modules")
local TargetFinder = require(combat:WaitForChild("TargetFinder"))
local SpellProgressManager = require(modules:WaitForChild("SpellProgressManager"))

return function(ctx, effect, spellConfig)
    local radius = effect.Radius or 10
    local targets = TargetFinder.inRadius(ctx.rootPart.Position, radius, ctx.character)
    local passive = SpellProgressManager.getEffectivePassive(ctx.player, spellConfig.School)
    local duration = passive and passive.Duration or 5

    print("[AoEApplyPassiveEffect] passive =", effect.PassiveId, "radius =", radius, "targets =", #targets,
        "duration =", duration)

    for _, target in targets do
        target:SetAttribute("Passive_" .. effect.PassiveId, true)
        target:SetAttribute("Passive_" .. effect.PassiveId .. "_Owner", ctx.player.UserId)
        target:SetAttribute("Passive_" .. effect.PassiveId .. "_Expire", os.clock() + duration)
        print("[AoEApplyPassiveEffect] applied", effect.PassiveId, "to", target.Name)
    end

    Remotes.SpellEffect:FireAllClients("AoEPassive", ctx.rootPart.Position, {
        Radius = radius,
        PassiveId = effect.PassiveId,
        School = spellConfig.School
    })
end
