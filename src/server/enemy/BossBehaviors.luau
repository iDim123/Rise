local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local LevelManager = require(modules:WaitForChild("LevelManager"))
local BossManager = require(modules:WaitForChild("BossManager"))
local EnemyStateManager = require(script.Parent:WaitForChild("EnemyStateManager"))
local EnemyTargeting = require(script.Parent:WaitForChild("EnemyTargeting"))
local BossAbilities = require(script.Parent:WaitForChild("BossAbilities"))

local STATE = EnemyStateManager.STATE

local BossBehaviors = {}

function BossBehaviors.update(enemy)
    local bossId = enemy:GetAttribute("BossId")
    if not bossId then
        return
    end

    local bossState = enemy:GetAttribute("BossState")
    if bossState == "Downed" or bossState == "Dead" then
        return
    end

    local humanoid = enemy:FindFirstChild("Humanoid")
    local rootPart = enemy:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then
        return
    end
    if humanoid.Health <= 0 then
        return
    end

    local data = HealthManager.getData(enemy)
    if not data or data.IsDead then
        return
    end

    local bossConfig = Config.Bosses[bossId]
    if not bossConfig then
        return
    end

    local spawnPos = enemy:GetAttribute("SpawnPosition")
    if not spawnPos then
        return
    end

    local position = rootPart.Position
    local state = EnemyStateManager.get(enemy)
    local distToSpawn = (position - spawnPos).Magnitude

    -- Check took damage for reaggro
    local tookDamage = EnemyStateManager.checkTookDamage(enemy, state)

    if state.State == STATE.RETURN and tookDamage then
        state.State = STATE.CHASE
        local attacker, _ = EnemyTargeting.findNearestPlayer(position, bossConfig.AggroRange * 2)
        if attacker then
            state.AggroTarget = attacker
        end
    end

    -- Find target
    local target, distToTarget

    if state.State == STATE.RETURN then
        target = nil
    else
        if state.AggroTarget then
            local aggroChar = state.AggroTarget
            local aggroRoot = aggroChar:FindFirstChild("HumanoidRootPart")
            local aggroHum = aggroChar:FindFirstChild("Humanoid")

            if not aggroRoot or not aggroHum or aggroHum.Health <= 0 or not aggroChar.Parent or
                aggroChar:GetAttribute("IsDead") then
                state.AggroTarget = nil
            end
        end

        if not target then
            target, distToTarget = EnemyTargeting.findNearestPlayer(position, bossConfig.AggroRange)
        end
    end

    -- Leash (bosses have longer leash)
    local maxChaseRange = bossConfig.AggroRange * 3
    if distToSpawn > maxChaseRange and state.State ~= STATE.RETURN then
        state.State = STATE.RETURN
        state.AggroTarget = nil
        target = nil
        -- Heal to full when resetting
        HealthManager.heal(enemy, data.MaxHP)
    end

    -- ═══ STATES ═══

    if state.State == STATE.RETURN then
        humanoid.WalkSpeed = bossConfig.WalkSpeed * 1.5
        humanoid:MoveTo(spawnPos)
        if distToSpawn < 3 then
            state.State = STATE.IDLE
            state.IdleTimer = tick()
            state.AggroTarget = nil
            humanoid.WalkSpeed = bossConfig.WalkSpeed
            -- Full heal on reset
            HealthManager.heal(enemy, data.MaxHP)
        end

    elseif target then
        state.AggroTarget = target
        local targetRoot = target:FindFirstChild("HumanoidRootPart")
        if not targetRoot then
            return
        end

        if distToTarget <= bossConfig.AttackRange then
            state.State = STATE.ATTACK
            humanoid:MoveTo(rootPart.Position)

            -- Face target
            local dir = (targetRoot.Position - rootPart.Position).Unit
            rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + Vector3.new(dir.X, 0, dir.Z))

            -- ═══ Try ability first ═══
            local abilityId, ability = BossAbilities.pickAbility(enemy, bossConfig, target)
            if abilityId and ability then
                BossAbilities.execute(enemy, abilityId, ability, bossConfig, target)
                return
            end

            -- ═══ Normal attack ═══
            local now = tick()
            if now - state.LastAttack >= bossConfig.AttackCooldown then
                state.LastAttack = now

                local baseDamage = bossConfig.Damage
                -- Enrage multiplier
                local dmgMult = enemy:GetAttribute("BossDamageMultiplier") or 1
                baseDamage = math.floor(baseDamage * dmgMult)

                -- Level modifier
                local bossLevel = bossConfig.Level or 1
                local targetLevel = target:GetAttribute("Level") or 1
                local dmgMod = LevelManager.getDamageModifier(bossLevel, targetLevel)
                local finalDamage = math.max(1, math.floor(baseDamage * (1 + dmgMod)))

                HealthManager.takeDamage(target, finalDamage, enemy)
            end
        else
            -- Chase
            state.State = STATE.CHASE
            local enraged = enemy:GetAttribute("BossEnraged")
            local chaseSpeed = bossConfig.WalkSpeed * 1.2
            if enraged then
                chaseSpeed = bossConfig.WalkSpeed * 1.5
            end
            humanoid.WalkSpeed = chaseSpeed
            humanoid:MoveTo(targetRoot.Position)
        end

    elseif state.State == STATE.IDLE then
        humanoid.WalkSpeed = 0
        -- Bosses don't patrol, they stand at spawn
        -- Heal slowly when idle
        if data.CurrentHP < data.MaxHP then
            HealthManager.heal(enemy, math.ceil(data.MaxHP * 0.05))
        end

    else
        state.State = STATE.IDLE
        state.IdleTimer = tick()
    end
end

return BossBehaviors
