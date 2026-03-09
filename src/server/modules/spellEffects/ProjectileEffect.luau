local ServerScriptService = game:GetService("ServerScriptService")

local combat = ServerScriptService:WaitForChild("combat")

local ProjectileManager
local function getPM()
    if not ProjectileManager then
        local ok, mod = pcall(function()
            return require(combat:WaitForChild("ProjectileManager", 2))
        end)
        if ok then
            ProjectileManager = mod
        end
    end
    return ProjectileManager
end

local function flatDirection(from, to)
    local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
    if dir.Magnitude < 0.001 then
        return Vector3.new(0, 0, 1)
    end
    return dir.Unit
end

return function(ctx, effect, spellConfig)
    local pm = getPM()
    if not pm then
        warn("[ProjectileEffect] ProjectileManager not available")
        return
    end

    local dir = flatDirection(ctx.rootPart.Position, ctx.mousePosition)
    local baseDamage = math.floor(ctx.spellPower * (effect.DamageMult or 1.0) * 100)

    print("[ProjectileEffect] projId =", effect.ProjectileId, "baseDmg =", baseDamage, "dir =", dir)

    pm.fire({
        owner = ctx.player,
        origin = ctx.rootPart.Position + dir * 2,
        direction = dir,
        projectileId = effect.ProjectileId,
        baseDamage = baseDamage,
        damageType = spellConfig.DamageType or "Magic",
        pierceCount = effect.PierceCount,
        onHitEffects = effect.OnHitEffects,
        spellSchool = spellConfig.School
    })
end
