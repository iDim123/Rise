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
        warn("[MultiProjectileEffect] ProjectileManager not available")
        return
    end

    local baseDir = flatDirection(ctx.rootPart.Position, ctx.mousePosition)
    local count = effect.Count or 3
    local spreadAngle = effect.SpreadAngle or 25
    local baseDamage = math.floor(ctx.spellPower * (effect.DamageMult or 1.0) * 100)

    local startAngle = -spreadAngle / 2
    local step = count > 1 and (spreadAngle / (count - 1)) or 0

    print("[MultiProjectileEffect] count =", count, "spread =", spreadAngle, "baseDmg =", baseDamage)

    for i = 0, count - 1 do
        local angle = math.rad(startAngle + step * i)
        local rotatedDir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(baseDir)
        rotatedDir = Vector3.new(rotatedDir.X, 0, rotatedDir.Z).Unit

        print("[MultiProjectileEffect] proj", i + 1, "angle =", math.deg(angle), "dir =", rotatedDir)

        pm.fire({
            owner = ctx.player,
            origin = ctx.rootPart.Position + rotatedDir * 2,
            direction = rotatedDir,
            projectileId = effect.ProjectileId,
            baseDamage = baseDamage,
            damageType = spellConfig.DamageType or "Magic",
            onHitEffects = effect.OnHitEffects,
            spellSchool = spellConfig.School
        })
    end
end
