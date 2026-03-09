local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local modules = ServerScriptService:WaitForChild("modules")
local HealthManager = require(modules:WaitForChild("HealthManager"))
local StatsManager = require(modules:WaitForChild("StatsManager"))
local SpellProgressManager = require(modules:WaitForChild("SpellProgressManager"))
local DamageCalc = require(ServerScriptService:WaitForChild("combat"):WaitForChild("DamageCalc"))
local TargetFinder = require(ServerScriptService:WaitForChild("combat"):WaitForChild("TargetFinder"))

return function(ctx, effect, spellConfig)
    -- Get channel registry from SpellCastManager
    local SpellCastManager = require(modules:WaitForChild("SpellCastManager"))
    local activeChannels = SpellCastManager.getActiveChannels()
    local userId = ctx.player.UserId

    if activeChannels[userId] then
        print("[BeamEffect] BLOCKED — already channelling")
        return
    end

    local dir = Vector3.new(ctx.mousePosition.X - ctx.rootPart.Position.X, 0,
        ctx.mousePosition.Z - ctx.rootPart.Position.Z)
    if dir.Magnitude < 0.001 then
        dir = Vector3.new(0, 0, 1)
    else
        dir = dir.Unit
    end

    local duration = effect.Duration or 3
    local tickRate = effect.TickRate or 0.25
    local range = effect.Range or 30
    local width = effect.Width or 3

    print("[BeamEffect] start: duration =", duration, "range =", range, "width =", width, "dir =", dir)

    -- Slow caster
    if effect.MovementMode == "Slowed" then
        ctx.humanoid.WalkSpeed = ctx.humanoid.WalkSpeed * (effect.SpeedMult or 0.3)
        print("[BeamEffect] slowed to", ctx.humanoid.WalkSpeed)
    end

    Remotes.BeamStart:FireAllClients(userId, ctx.rootPart.Position, dir, {
        Range = range,
        Width = width,
        Duration = duration
    })

    activeChannels[userId] = {
        spellId = spellConfig.Id,
        startTime = tick()
    }

    local channelTask = task.spawn(function()
        local elapsed = 0
        local tickCount = 0
        while elapsed < duration do
            task.wait(tickRate)
            elapsed = elapsed + tickRate
            tickCount = tickCount + 1

            local character = ctx.player.Character
            if not character or character:GetAttribute("IsDead") then
                break
            end
            local rp = character:FindFirstChild("HumanoidRootPart")
            if not rp then
                break
            end

            local targets = TargetFinder.inRadius(rp.Position, range, character)
            local baseDamage = math.floor(ctx.spellPower * (effect.DamageMult or 1.0) * 100 * tickRate / duration)
            local hitCount = 0

            for _, target in targets do
                local targetRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")
                if targetRoot then
                    local toTarget = targetRoot.Position - rp.Position
                    local projection = toTarget:Dot(dir)
                    if projection > 0 and projection < range then
                        local perpDist = (toTarget - dir * projection).Magnitude
                        if perpDist <= width then
                            local finalDamage = DamageCalc.calculate({
                                player = ctx.player,
                                target = target,
                                baseDamage = baseDamage,
                                damageType = spellConfig.DamageType or "Magic"
                            })
                            HealthManager.takeDamage(target, finalDamage, character)
                            hitCount = hitCount + 1

                            -- Apply passive
                            if effect.ApplyPassive then
                                local passive = SpellProgressManager.getEffectivePassive(ctx.player, spellConfig.School)
                                target:SetAttribute("Passive_" .. effect.ApplyPassive, true)
                                target:SetAttribute("Passive_" .. effect.ApplyPassive .. "_Owner", userId)
                                target:SetAttribute("Passive_" .. effect.ApplyPassive .. "_Expire",
                                    tick() + (passive and passive.Duration or 5))
                            end

                            -- Self heal
                            if effect.SelfHealPerHit then
                                local selfHeal = math.floor(ctx.spellPower * effect.SelfHealPerHit * 10)
                                HealthManager.heal(character, selfHeal)
                            end
                        end
                    end
                end
            end

            print("[BeamEffect] tick", tickCount, "elapsed =", string.format("%.2f", elapsed), "hits =", hitCount)
        end

        print("[BeamEffect] channel ended")
        activeChannels[userId] = nil
        Remotes.BeamEnd:FireAllClients(userId)
        StatsManager.recalculate(ctx.player)
    end)

    activeChannels[userId].task = channelTask
end
