local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

return function(ctx, effect, spellConfig)
    local duration = effect.Duration or 1

    print("[ImmaterialEffect] invulnerable for", duration, "s")

    ctx.character:SetAttribute("Invulnerable", true)

    Remotes.SpellEffect:FireAllClients("Immaterial", ctx.rootPart.Position, {
        CasterId = ctx.player.UserId,
        Duration = duration,
        School = spellConfig.School
    })

    task.delay(duration, function()
        ctx.character:SetAttribute("Invulnerable", false)
        print("[ImmaterialEffect] invulnerability ended")
    end)
end
