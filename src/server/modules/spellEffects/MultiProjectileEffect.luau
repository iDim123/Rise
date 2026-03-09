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

    local count = effect.Count or 3
    local interval = effect.Interval
    local spreadAngle = effect.SpreadAngle or 0
    local baseDamage = math.floor(ctx.spellPower * (effect.DamageMult or 1.0) * 100)

    -- Support DirectHit + Splash (chaos_barrage)
    local directDamage = effect.DirectHitDamageMult and math.floor(ctx.spellPower * effect.DirectHitDamageMult * 100) or
                             baseDamage

    print("[MultiProjectileEffect] count =", count, "interval =", interval, "baseDmg =", baseDamage)

    local function fireOne(index)
        local character = ctx.player.Character
        if not character or character:GetAttribute("IsDead") then
            return
        end
        local rp = character:FindFirstChild("HumanoidRootPart")
        if not rp then
            return
        end

        local baseDir = flatDirection(rp.Position, ctx.mousePosition)

        local rotatedDir = baseDir
        if spreadAngle > 0 and count > 1 then
            local startAngle = -spreadAngle / 2
            local step = spreadAngle / (count - 1)
            local angle = math.rad(startAngle + step * index)
            rotatedDir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(baseDir)
            rotatedDir = Vector3.new(rotatedDir.X, 0, rotatedDir.Z).Unit
        elseif spreadAngle > 0 and count == 1 then
            rotatedDir = baseDir
        else
            -- Small random spread for sequential shots
            if interval and interval > 0 then
                local jitter = math.rad((math.random() - 0.5) * 5)
                rotatedDir = CFrame.Angles(0, jitter, 0):VectorToWorldSpace(baseDir)
                rotatedDir = Vector3.new(rotatedDir.X, 0, rotatedDir.Z).Unit
            end
        end

        print("[MultiProjectileEffect] proj", index + 1, "/", count, "dir =", rotatedDir)

        pm.fire({
            owner = ctx.player,
            origin = rp.Position + rotatedDir * 2,
            direction = rotatedDir,
            projectileId = effect.ProjectileId,
            baseDamage = directDamage,
            damageType = spellConfig.DamageType or "Magic",
            onHitEffects = effect.OnHitEffects,
            spellSchool = spellConfig.School,
            splashDamage = effect.SplashDamageMult and math.floor(ctx.spellPower * effect.SplashDamageMult * 100) or nil,
            splashRadius = effect.SplashRadius
        })
    end

    if interval and interval > 0 then
        -- Sequential fire with interval (chaos_volley, chaos_barrage)
        task.spawn(function()
            for i = 0, count - 1 do
                fireOne(i)
                if i < count - 1 then
                    task.wait(interval)
                end
            end
        end)
    else
        -- Instant fan fire (all at once)
        for i = 0, count - 1 do
            fireOne(i)
        end
    end
end
