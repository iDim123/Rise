local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local modules = ServerScriptService:WaitForChild("modules")
local HealthManager = require(modules:WaitForChild("HealthManager"))
local StatsManager = require(modules:WaitForChild("StatsManager"))
local SpellProgressManager = require(modules:WaitForChild("SpellProgressManager"))
local DamageCalc = require(ServerScriptService:WaitForChild("combat"):WaitForChild("DamageCalc"))
local TargetFinder = require(ServerScriptService:WaitForChild("combat"):WaitForChild("TargetFinder"))

return function(ctx, effect, spellConfig)
    local SpellCastManager = require(modules:WaitForChild("SpellCastManager"))
    local activeChannels = SpellCastManager.getActiveChannels()
    local userId = ctx.player.UserId

    if activeChannels[userId] then
        print("[BeamEffect] BLOCKED — already channelling")
        return
    end

    -- Initial direction
    local dir = Vector3.new(ctx.mousePosition.X - ctx.rootPart.Position.X, 0,
        ctx.mousePosition.Z - ctx.rootPart.Position.Z)
    if dir.Magnitude < 0.001 then
        dir = Vector3.new(0, 0, 1)
    else
        dir = dir.Unit
    end

    local duration = effect.Duration or 3
    local tickRate = effect.TickRate or 0.25
    local range = effect.Range or effect.Length or 30
    local width = effect.Width or 3
    local followCursor = effect.FollowCursor ~= false -- default true

    print("[BeamEffect] start: duration=", duration, "range=", range, "width=", width)

    -- Slow caster
    local originalSpeed = ctx.humanoid.WalkSpeed
    if effect.MovementMode == "Slowed" then
        ctx.humanoid.WalkSpeed = originalSpeed * (effect.SpeedMult or 0.3)
    end

    -- Register channel with mutable direction
    activeChannels[userId] = {
        spellId = spellConfig.Id,
        startTime = tick(),
        direction = dir,  -- mutable: updated by BeamUpdate
    }

    -- Notify clients to start beam visual
    Remotes.BeamStart:FireAllClients(userId, ctx.rootPart.Position, dir, {
        Range = range,
        Width = width,
        Duration = duration,
        School = spellConfig.School,
    })

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

            -- Check channel still active
            if not activeChannels[userId] then
                break
            end

            -- Use latest direction (updated by BeamUpdate remote)
            local currentDir = activeChannels[userId].direction or dir

            -- Broadcast updated beam position to all clients
            Remotes.SpellEffect:FireAllClients("BeamTick", {
                CasterId = userId,
                Origin = rp.Position,
                Direction = currentDir,
                Range = range,
                Width = width,
            })

            -- Find all entities in range
            local allTargets = TargetFinder.inRadius(rp.Position, range, character)

            -- Per-tick damage = total damage * (tickRate / duration)
            local baseDamage = math.floor(ctx.spellPower * (effect.DamageMult or 1.0) * 100 * tickRate / duration)
            local hitEnemies = 0
            local hitAllies = 0

            for _, target in allTargets do
                local targetRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")
                if not targetRoot then
                    continue
                end

                -- Check if target is in beam cone
                local toTarget = targetRoot.Position - rp.Position
                local projection = toTarget:Dot(currentDir)
                if projection <= 0 or projection > range then
                    continue
                end
                local perpDist = (toTarget - currentDir * projection).Magnitude
                if perpDist > width then
                    continue
                end

                -- Determine if enemy or ally
                local isPlayer = Players:GetPlayerFromCharacter(target)
                local isAlly = isPlayer ~= nil

                if isAlly then
                    -- Heal ally
                    if effect.HealAllyMult then
                        local healAmount = math.floor(ctx.spellPower * effect.HealAllyMult * 100 * tickRate / duration)
                        HealthManager.heal(target, healAmount)
                        hitAllies = hitAllies + 1
                    end
                else
                    -- Damage enemy
                    local finalDamage = DamageCalc.calculate({
                        player = ctx.player,
                        target = target,
                        baseDamage = baseDamage,
                        damageType = spellConfig.DamageType or "Magic"
                    })
                    HealthManager.takeDamage(target, finalDamage, character)
                    hitEnemies = hitEnemies + 1

                    -- Apply passive (Leech)
                    if effect.ApplyPassive then
                        local passive = SpellProgressManager.getEffectivePassive(ctx.player, spellConfig.School)
                        target:SetAttribute("Passive_" .. effect.ApplyPassive, true)
                        target:SetAttribute("Passive_" .. effect.ApplyPassive .. "_Owner", userId)
                        target:SetAttribute("Passive_" .. effect.ApplyPassive .. "_Expire",
                            tick() + (passive and passive.Duration or 5))
                    end

                    -- Self heal per enemy hit
                    if effect.SelfHealPerHit then
                        local selfHeal = math.floor(ctx.spellPower * effect.SelfHealPerHit * 10)
                        HealthManager.heal(character, selfHeal)
                    end
                end
            end

            if tickCount % 4 == 0 then
                print("[BeamEffect] tick", tickCount, "enemies=", hitEnemies, "allies=", hitAllies)
            end
        end

        -- Channel ended
        print("[BeamEffect] channel ended after", tickCount, "ticks")
        activeChannels[userId] = nil
        Remotes.BeamEnd:FireAllClients(userId)
        StatsManager.recalculate(ctx.player)
    end)

    activeChannels[userId].task = channelTask
end