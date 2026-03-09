local ServerScriptService = game:GetService("ServerScriptService")

local modules = ServerScriptService:WaitForChild("modules")
local combat = ServerScriptService:WaitForChild("combat")
local StatsManager = require(modules:WaitForChild("StatsManager"))

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
    local SpellCastManager = require(modules:WaitForChild("SpellCastManager"))
    local activeChannels = SpellCastManager.getActiveChannels()
    local userId = ctx.player.UserId

    if activeChannels[userId] then
        print("[ChannelledProjectileEffect] BLOCKED — already channelling")
        return
    end

    local pm = getPM()
    if not pm then
        warn("[ChannelledProjectileEffect] ProjectileManager not available")
        return
    end

    local duration = effect.Duration or 2
    local count = effect.Count or 8
    local interval = duration / count
    local baseDamage = math.floor(ctx.spellPower * (effect.DamageMult or 1.0) * 100)

    print("[ChannelledProjectileEffect] start: count =", count, "interval =", string.format("%.2f", interval),
        "baseDmg =", baseDamage)

    if effect.MovementMode == "Slowed" then
        ctx.humanoid.WalkSpeed = ctx.humanoid.WalkSpeed * (effect.SpeedMult or 0.3)
        print("[ChannelledProjectileEffect] slowed to", ctx.humanoid.WalkSpeed)
    end

    activeChannels[userId] = {
        spellId = spellConfig.Id,
        startTime = tick()
    }

    local channelTask = task.spawn(function()
        for i = 1, count do
            local character = ctx.player.Character
            if not character or character:GetAttribute("IsDead") then
                break
            end
            if not activeChannels[userId] then
                break
            end
            local rp = character:FindFirstChild("HumanoidRootPart")
            if not rp then
                break
            end

            local dir = flatDirection(rp.Position, ctx.mousePosition)

            -- Slight random spread
            local spreadAngle = effect.SpreadAngle or 5
            local angle = math.rad((math.random() - 0.5) * spreadAngle)
            local rotatedDir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(dir)
            rotatedDir = Vector3.new(rotatedDir.X, 0, rotatedDir.Z).Unit

            print("[ChannelledProjectileEffect] proj", i, "/", count, "dir =", rotatedDir)

            pm.fire({
                owner = ctx.player,
                origin = rp.Position + rotatedDir * 2,
                direction = rotatedDir,
                projectileId = effect.ProjectileId,
                baseDamage = baseDamage,
                damageType = spellConfig.DamageType or "Magic",
                onHitEffects = effect.OnHitEffects,
                spellSchool = spellConfig.School
            })

            if i < count then
                task.wait(interval)
            end
        end

        print("[ChannelledProjectileEffect] channel ended")
        activeChannels[userId] = nil
        StatsManager.recalculate(ctx.player)
    end)

    activeChannels[userId].task = channelTask
end
