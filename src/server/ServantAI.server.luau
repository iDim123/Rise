local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local HealthManager = require(script.Parent:WaitForChild("HealthManager"))

local TICK_RATE = 0.2
local lastAttackTimes = {} -- [servantEntity] = tick

local function findNearestEnemy(position, range)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end

    local nearest = nil
    local nearestDist = range + 1

    for _, enemy in enemiesFolder:GetChildren() do
        local root = enemy:FindFirstChild("HumanoidRootPart")
        local hum = enemy:FindFirstChild("Humanoid")
        if not root or not hum or hum.Health <= 0 then continue end

        local dist = (root.Position - position).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearest = enemy
        end
    end

    return nearest, nearestDist
end

local function getOwner(servant)
    local ownerId = servant:GetAttribute("OwnerUserId")
    if not ownerId then return nil end
    return Players:GetPlayerByUserId(ownerId)
end

local function getOwnerCharacter(servant)
    local owner = getOwner(servant)
    if not owner then return nil end
    return owner.Character
end

local function updateServant(servant)
    local humanoid = servant:FindFirstChild("Humanoid")
    local rootPart = servant:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart or humanoid.Health <= 0 then return end

    local mode = servant:GetAttribute("ServantMode") or "Aggressive"
    local command = servant:GetAttribute("ServantCommand") or "Follow"
    local atk = servant:GetAttribute("ServantATK") or 10

    local ownerChar = getOwnerCharacter(servant)
    if not ownerChar then return end
    local ownerRoot = ownerChar:FindFirstChild("HumanoidRootPart")
    if not ownerRoot then return end

    -- Команда "Стой"
    if command == Config.Servants.Commands.Stay then
        humanoid:MoveTo(rootPart.Position)
        return
    end

    local target = nil

    -- Команда "Атакуй цель"
    if command == Config.Servants.Commands.AttackTarget then
        local targetName = servant:GetAttribute("ServantTargetName")
        if targetName then
            local enemiesFolder = workspace:FindFirstChild("Enemies")
            if enemiesFolder then
                target = enemiesFolder:FindFirstChild(targetName)
            end
        end
    end

    -- Поиск цели по режиму
    if not target then
        if mode == Config.Servants.Modes.Aggressive then
            target = findNearestEnemy(rootPart.Position, Config.Servants.AggroRange)
        elseif mode == Config.Servants.Modes.Defensive then
            -- Атакуем только если владелец получает урон (ищем врагов рядом с владельцем)
            target = findNearestEnemy(ownerRoot.Position, Config.Servants.AttackRange * 2)
        end
        -- Passive: target остаётся nil
    end

    if target then
        local targetRoot = target:FindFirstChild("HumanoidRootPart")
        local targetHum = target:FindFirstChild("Humanoid")
        if targetRoot and targetHum and targetHum.Health > 0 then
            local dist = (targetRoot.Position - rootPart.Position).Magnitude

            if dist <= Config.Servants.AttackRange then
                -- Атакуем
                humanoid:MoveTo(rootPart.Position)

                -- Поворачиваемся к цели
                local dir = (targetRoot.Position - rootPart.Position).Unit
                rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + Vector3.new(dir.X, 0, dir.Z))

                -- Кулдаун
                local now = tick()
                local lastAttack = lastAttackTimes[servant] or 0
                if now - lastAttack >= Config.Servants.AttackCooldown then
                    lastAttackTimes[servant] = now
                    HealthManager.takeDamage(target, atk, servant)
                end
                return
            else
                -- Идём к цели
                humanoid:MoveTo(targetRoot.Position)
                return
            end
        end
    end

    -- Нет цели — следуем за игроком
    local distToOwner = (ownerRoot.Position - rootPart.Position).Magnitude
    if distToOwner > Config.Servants.FollowDistance then
        humanoid:MoveTo(ownerRoot.Position)
    else
        humanoid:MoveTo(rootPart.Position) -- стоим
    end
end

-- Очистка при удалении
local function onServantDestroyed(servant)
    lastAttackTimes[servant] = nil
end

-- Основной цикл
local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
    accumulated = accumulated + dt
    if accumulated < TICK_RATE then return end
    accumulated = 0

    local servantsFolder = workspace:FindFirstChild("Servants")
    if not servantsFolder then return end

    for _, servant in servantsFolder:GetChildren() do
        if not servant:GetAttribute("IsServant") then continue end

        if not servant:FindFirstChild("_AIConnected") then
            local tag = Instance.new("BoolValue")
            tag.Name = "_AIConnected"
            tag.Parent = servant
            servant.Destroying:Connect(function()
                onServantDestroyed(servant)
            end)
        end

        task.spawn(updateServant, servant)
    end
end)