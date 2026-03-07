local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local LevelManager = require(modules:WaitForChild("LevelManager"))
local EnemyStateManager = require(script.Parent:WaitForChild("EnemyStateManager"))
local EnemyTargeting = require(script.Parent:WaitForChild("EnemyTargeting"))

local STATE = EnemyStateManager.STATE

local EnemyBehaviors = {}

function EnemyBehaviors.update(enemy)
    if enemy:GetAttribute("IsBoss") then
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

    local enemyType = enemy:GetAttribute("EnemyType") or "Warrior"
    local config = Config.Enemies[enemyType]
    if not config then
        return
    end

    local spawnPos = enemy:GetAttribute("SpawnPosition")
    if not spawnPos then
        return
    end

    local position = rootPart.Position
    local state = EnemyStateManager.get(enemy)
    local distToSpawn = (position - spawnPos).Magnitude

    -- Проверяем получение урона
    local tookDamage = EnemyStateManager.checkTookDamage(enemy, state)

    -- Если возвращается и получил удар — реагро
    if state.State == STATE.RETURN and tookDamage then
        state.State = STATE.CHASE
        local attacker, _ = EnemyTargeting.findNearestPlayer(position, config.AggroRange * 2)
        if attacker then
            state.AggroTarget = attacker
            EnemyTargeting.alertPack(enemy, attacker, config)
        end
    end

    -- Поиск цели (пропускаем при возврате)
    local target, distToTarget

    if state.State == STATE.RETURN then
        target = nil
        distToTarget = nil
    else
        if state.AggroTarget then
            local aggroRoot = state.AggroTarget:FindFirstChild("HumanoidRootPart")
            local aggroHumanoid = state.AggroTarget:FindFirstChild("Humanoid")
            if aggroRoot and aggroHumanoid and aggroHumanoid.Health > 0 and state.AggroTarget.Parent and
                not state.AggroTarget:GetAttribute("IsDead") then
                target = state.AggroTarget
                distToTarget = (aggroRoot.Position - position).Magnitude
            else
                state.AggroTarget = nil
            end
        end

        if not target then
            target, distToTarget = EnemyTargeting.findNearestPlayer(position, config.AggroRange)
        end

        if target and state.State ~= STATE.CHASE and state.State ~= STATE.ATTACK then
            EnemyTargeting.alertPack(enemy, target, config)
        end
    end

    -- Leash
    local maxChaseRange = config.AggroRange * 2
    if distToSpawn > maxChaseRange and state.State ~= STATE.RETURN then
        state.State = STATE.RETURN
        state.AggroTarget = nil
        target = nil
    end

    -- === СОСТОЯНИЯ ===

    if state.State == STATE.RETURN then
        humanoid.WalkSpeed = config.WalkSpeed
        humanoid:MoveTo(spawnPos)
        if distToSpawn < 3 then
            state.State = STATE.IDLE
            state.IdleTimer = tick()
            state.AggroTarget = nil
        end

    elseif target then
        local targetRoot = target:FindFirstChild("HumanoidRootPart")
        if not targetRoot then
            return
        end

        if distToTarget <= config.AttackRange then
            state.State = STATE.ATTACK
            humanoid:MoveTo(rootPart.Position)
            local dir = (targetRoot.Position - rootPart.Position).Unit
            rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + Vector3.new(dir.X, 0, dir.Z))
            local now = tick()
            if now - state.LastAttack >= config.AttackCooldown then
                state.LastAttack = now

                local enemyLevel = enemy:GetAttribute("Level") or config.Level or 1
                local targetLevel = target:GetAttribute("Level") or 1
                local dmgMod = LevelManager.getDamageModifier(enemyLevel, targetLevel)
                -- Physical Resistance цели
                local targetResist = target:GetAttribute("PhysResistance") or 0
                local finalDamage = math.max(1, math.floor(config.Damage * (1 + dmgMod) * (1 - targetResist / 100)))

                HealthManager.takeDamage(target, finalDamage, enemy)
            end
        else
            state.State = STATE.CHASE
            humanoid.WalkSpeed = config.WalkSpeed * 1.2
            humanoid:MoveTo(targetRoot.Position)
        end

    elseif state.State == STATE.IDLE then
        humanoid.WalkSpeed = 0
        if tick() - state.IdleTimer > math.random(2, 5) then
            state.State = STATE.PATROL
            local patrolRadius = config.AggroRange * 0.4
            state.PatrolTarget = EnemyStateManager.getRandomPatrolPoint(spawnPos, patrolRadius)
        end

    elseif state.State == STATE.PATROL then
        humanoid.WalkSpeed = config.WalkSpeed * 0.5
        if state.PatrolTarget then
            humanoid:MoveTo(state.PatrolTarget)
            local distToPatrol = (position - state.PatrolTarget).Magnitude
            if distToPatrol < 3 then
                state.State = STATE.IDLE
                state.IdleTimer = tick()
            end
        else
            state.State = STATE.IDLE
            state.IdleTimer = tick()
        end

    else
        state.State = STATE.IDLE
        state.IdleTimer = tick()
    end
end

return EnemyBehaviors
