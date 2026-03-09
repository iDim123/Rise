local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- ═══════════════════════════════════════════════════════════
-- Активные визуалы
-- ═══════════════════════════════════════════════════════════

local activeVisuals = {} -- [id] = { part, direction, speed, gravity, velocityY, elapsed }

-- ═══════════════════════════════════════════════════════════
-- Создание визуала снаряда
-- ═══════════════════════════════════════════════════════════

local function createVisual(data)
    local projectileId = data.projectileId
    local projConfig = Config.Projectiles and Config.Projectiles[projectileId]

    -- Основной Part
    local part = Instance.new("Part")
    part.Name = "Projectile_" .. tostring(data.id)
    part.Size = Vector3.new(0.4, 0.4, 1.5)
    part.Shape = Enum.PartType.Block
    part.Material = Enum.Material.Neon
    part.Color = (projConfig and projConfig.TrailColor) or Color3.fromRGB(255, 220, 100)
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false

    -- Ориентация по направлению полёта
    local dir = data.direction
    if dir.Magnitude > 0.001 then
        part.CFrame = CFrame.lookAt(data.origin, data.origin + dir)
    else
        part.CFrame = CFrame.new(data.origin)
    end

    -- Trail
    if projConfig and projConfig.TrailColor then
        local attachment0 = Instance.new("Attachment")
        attachment0.Position = Vector3.new(0, 0, -0.75)
        attachment0.Parent = part

        local attachment1 = Instance.new("Attachment")
        attachment1.Position = Vector3.new(0, 0, 0.75)
        attachment1.Parent = part

        local trail = Instance.new("Trail")
        trail.Attachment0 = attachment0
        trail.Attachment1 = attachment1
        trail.Color = ColorSequence.new(projConfig.TrailColor)
        trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
        trail.Lifetime = 0.3
        trail.MinLength = 0.1
        trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
        trail.Parent = part
    end

    part.Parent = workspace

    return part
end

-- ═══════════════════════════════════════════════════════════
-- Удаление визуала
-- ═══════════════════════════════════════════════════════════

local function removeVisual(id)
    local visual = activeVisuals[id]
    if not visual then
        return
    end

    activeVisuals[id] = nil

    -- Fade out
    local part = visual.part
    if part and part.Parent then
        task.spawn(function()
            for i = 0, 1, 0.2 do
                if not part.Parent then
                    break
                end
                part.Transparency = i
                task.wait(0.02)
            end
            if part.Parent then
                part:Destroy()
            end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════
-- Эффект попадания
-- ═══════════════════════════════════════════════════════════

local function createHitEffect(position, isCrit)
    local effect = Instance.new("Part")
    effect.Name = "HitEffect"
    effect.Size = Vector3.new(1, 1, 1)
    effect.Shape = Enum.PartType.Ball
    effect.Material = Enum.Material.Neon
    effect.Color = isCrit and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 200, 100)
    effect.Anchored = true
    effect.CanCollide = false
    effect.CanQuery = false
    effect.CanTouch = false
    effect.CastShadow = false
    effect.Position = position
    effect.Parent = workspace

    -- Вспышка и исчезновение
    task.spawn(function()
        for i = 0, 1, 0.1 do
            if not effect.Parent then
                break
            end
            effect.Size = Vector3.new(1 + i * 2, 1 + i * 2, 1 + i * 2)
            effect.Transparency = i
            task.wait(0.02)
        end
        if effect.Parent then
            effect:Destroy()
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- Heartbeat — движение визуалов
-- ═══════════════════════════════════════════════════════════

RunService.Heartbeat:Connect(function(dt)
    for id, visual in activeVisuals do
        visual.elapsed = visual.elapsed + dt

        -- Гравитация
        visual.velocityY = visual.velocityY - visual.gravity * dt

        -- Перемещение
        local velocity = visual.direction * visual.speed + Vector3.new(0, visual.velocityY, 0)
        local newPos = visual.part.Position + velocity * dt

        -- Обновить позицию и ориентацию
        if velocity.Magnitude > 0.001 then
            visual.part.CFrame = CFrame.lookAt(newPos, newPos + velocity)
        else
            visual.part.Position = newPos
        end

        -- Авто-удаление по времени (safety net)
        if visual.elapsed > visual.lifetime then
            removeVisual(id)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- Remotes
-- ═══════════════════════════════════════════════════════════

-- Снаряд создан
Remotes.ProjectileFired.OnClientEvent:Connect(function(data)
    -- data = { id, origin, direction, projectileId, speed, gravity }
    local projConfig = Config.Projectiles and Config.Projectiles[data.projectileId]
    local lifetime = (projConfig and projConfig.Lifetime) or 3

    local part = createVisual(data)

    activeVisuals[data.id] = {
        part = part,
        direction = data.direction,
        speed = data.speed,
        gravity = data.gravity or 0,
        velocityY = 0,
        elapsed = 0,
        lifetime = lifetime
    }
end)

-- Снаряд попал
Remotes.ProjectileHit.OnClientEvent:Connect(function(id, hitPosition, isCrit)
    createHitEffect(hitPosition, isCrit)
end)

-- Снаряд удалён
Remotes.ProjectileRemoved.OnClientEvent:Connect(function(id)
    removeVisual(id)
end)

print("[ProjectileVisuals] Initialized")
