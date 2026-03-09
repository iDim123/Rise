return function(ctx, effect, spellConfig)
    local duration = effect.Duration or 1

    print("[ImmaterialEffect] invulnerable for", duration, "s")

    ctx.character:SetAttribute("Invulnerable", true)
    task.delay(duration, function()
        ctx.character:SetAttribute("Invulnerable", false)
        print("[ImmaterialEffect] invulnerability ended")
    end)
end
