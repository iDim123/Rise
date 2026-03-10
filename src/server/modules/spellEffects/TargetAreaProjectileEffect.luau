local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local combat = ServerScriptService:WaitForChild("combat")
local modules = ServerScriptService:WaitForChild("modules")
local HealthManager = require(modules:WaitForChild("HealthManager"))
local DamageCalc = require(combat:WaitForChild("DamageCalc"))
local TargetFinder = require(combat:WaitForChild("TargetFinder"))

return function(ctx, effect, spellConfig)
    local targetPos = ctx.mousePosition
    local origin = ctx.rootPart.Position + Vector3.new(0, 2, 0)
    local speed = effect.Speed or 60
    local explosionRadius = effect.ExplosionRadius or 6
    local baseDamage = math.floor(ctx.spellPower * (effect.DamageMult or 1.0) * 100)

    print("[TargetAreaProjectileEffect] target =", targetPos, "speed =", speed, "radius =", explosionRadius)

    -- Calculate travel time
    local flatOrigin = Vector3.new(origin.X, 0, origin.Z)
    local flatTarget = Vector3.new(targetPos.X, 0, targetPos.Z)
    local distance = (flatTarget - flatOrigin).Magnitude
    local travelTime = math.max(distance / speed, 0.1)

    -- Fire visual projectile to all clients
    local direction = (targetPos - origin)
    if direction.Magnitude > 0.001 then
        direction = direction.Unit
    else
        direction = ctx.rootPart.CFrame.LookVector
    end

    Remotes.ProjectileFired:FireAllClients({
        id = os.clock(),
        origin = origin,
        direction = direction,
        projectileId = effect.ProjectileId,
        speed = speed,
        gravity = 0,
        destinationBased = true,
        destination = targetPos
    })

    -- Wait for projectile to arrive, then explode
    task.delay(travelTime, function()
        local character = ctx.player.Character
        if not character then
            return
        end

        local targets = TargetFinder.inRadius(targetPos, explosionRadius, character)

        print("[TargetAreaProjectileEffect] explosion at", targetPos, "targets =", #targets)

        for _, target in targets do
            local finalDamage = DamageCalc.calculate({
                player = ctx.player,
                target = target,
                baseDamage = baseDamage,
                damageType = spellConfig.DamageType or "Magic"
            })
            HealthManager.takeDamage(target, finalDamage, character)

            -- Process OnHitEffects
            if effect.OnHitEffects then
                for _, onHit in effect.OnHitEffects do
                    if onHit.Type == "ApplyPassive" then
                        target:SetAttribute("Passive_" .. onHit.PassiveId, true)
                        target:SetAttribute("Passive_" .. onHit.PassiveId .. "_Owner", ctx.player.UserId)
                        target:SetAttribute("Passive_" .. onHit.PassiveId .. "_Expire", os.clock() + (onHit.Duration or 5))
                        print("[TargetAreaProjectileEffect] applied", onHit.PassiveId, "to", target.Name)
                    end
                end
            end
        end

        -- Process Pull effect separately (applies to all targets)
        if effect.OnHitEffects then
            for _, onHit in effect.OnHitEffects do
                if onHit.Type == "Pull" then
                    for _, target in targets do
                        local targetRoot = target:FindFirstChild("HumanoidRootPart")
                        if targetRoot then
                            local pullDir = (targetPos - targetRoot.Position)
                            if pullDir.Magnitude > 1 then
                                pullDir = pullDir.Unit
                            end
                            local bv = Instance.new("BodyVelocity")
                            bv.MaxForce = Vector3.new(onHit.Force or 40, 0, onHit.Force or 40) * 1000
                            bv.Velocity = pullDir * (onHit.Force or 40)
                            bv.Parent = targetRoot
                            task.delay(onHit.Duration or 0.5, function()
                                bv:Destroy()
                            end)
                            print("[TargetAreaProjectileEffect] pulling", target.Name)
                        end
                    end
                end
            end
        end

        Remotes.SpellEffect:FireAllClients("AreaExplosion", targetPos, {
            Radius = explosionRadius,
            School = spellConfig.School
        })
    end)
end
