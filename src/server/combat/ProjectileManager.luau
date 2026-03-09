local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local DamageCalc = require(script.Parent:WaitForChild("DamageCalc"))
local TargetFinder = require(script.Parent:WaitForChild("TargetFinder"))

local HealthManager
local StatsManager

local ProjectileManager = {}

-- ═══════════════════════════════════════════════════════════
-- Ленивая загрузка
-- ═══════════════════════════════════════════════════════════

local function getHealthManager()
    if not HealthManager then
        HealthManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("HealthManager"))
    end
    return HealthManager
end

local function getStatsManager()
    if not StatsManager then
        StatsManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("StatsManager"))
    end
    return StatsManager
end

-- ═══════════════════════════════════════════════════════════
-- Константы
-- ═══════════════════════════════════════════════════════════

local MAX_PROJECTILES = 50
local nextId = 0

-- ═══════════════════════════════════════════════════════════
-- Состояние
-- ═══════════════════════════════════════════════════════════

local activeProjectiles = {} -- [id] = projectileData
local heartbeatConn = nil
local initialized = false

-- ═══════════════════════════════════════════════════════════
-- Внутренние хелперы
-- ═══════════════════════════════════════════════════════════

local function generateId()
    nextId = nextId + 1
    return nextId
end

-- Получить конфиг снаряда из ProjectileConfig
local function getProjectileConfig(projectileId)
    return Config.Projectiles and Config.Projectiles[projectileId]
end

-- Подсчёт активных снарядов
local function countActive()
    local count = 0
    for _ in activeProjectiles do
        count = count + 1
    end
    return count
end

-- Удалить самый старый снаряд (при превышении лимита)
local function removeOldest()
    local oldestId = nil
    local oldestTime = math.huge

    for id, proj in activeProjectiles do
        if proj.spawnTime < oldestTime then
            oldestTime = proj.spawnTime
            oldestId = id
        end
    end

    if oldestId then
        ProjectileManager._remove(oldestId)
    end
end

-- ═══════════════════════════════════════════════════════════
-- Удаление снаряда
-- ═══════════════════════════════════════════════════════════

function ProjectileManager._remove(id)
    local proj = activeProjectiles[id]
    if not proj then
        return
    end

    activeProjectiles[id] = nil

    Remotes.ProjectileRemoved:FireAllClients(id)
end

-- ═══════════════════════════════════════════════════════════
-- Обработка попадания
-- ═══════════════════════════════════════════════════════════

function ProjectileManager._processHit(proj, target)
    -- Не бить владельца
    local ownerCharacter = proj.owner and proj.owner.Character
    if target == ownerCharacter then
        return false
    end

    -- Рассчитать урон
    local finalDamage, isCrit = DamageCalc.calculate({
        player = proj.owner,
        target = target,
        baseDamage = proj.baseDamage,
        damageType = proj.damageType
    })

    -- Нанести урон
    getHealthManager().takeDamage(target, finalDamage, ownerCharacter)
    getStatsManager().markCombat(target)

    -- Добавить в hitList
    proj.hitList[target] = true

    -- Отправить эффект попадания клиентам
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    local hitPos = targetRoot and targetRoot.Position or proj.position
    Remotes.ProjectileHit:FireAllClients(proj.id, hitPos, isCrit)

    -- Уменьшить pierce
    proj.pierceLeft = proj.pierceLeft - 1

    return true
end

-- ═══════════════════════════════════════════════════════════
-- Tick одного снаряда (вызывается из Heartbeat)
-- Возвращает true если снаряд должен быть удалён
-- ═══════════════════════════════════════════════════════════

function ProjectileManager._tickProjectile(proj, dt)
    -- Обновить время жизни
    proj.elapsed = proj.elapsed + dt

    -- Гравитация: накапливаем вертикальную скорость
    proj.velocityY = proj.velocityY - proj.gravity * dt

    -- Вычислить перемещение
    local velocity = proj.direction * proj.speed + Vector3.new(0, proj.velocityY, 0)
    local displacement = velocity * dt
    local newPos = proj.position + displacement

    -- Обновить пройденное расстояние (горизонтальное)
    local horizDisp = Vector3.new(displacement.X, 0, displacement.Z)
    proj.distanceTraveled = proj.distanceTraveled + horizDisp.Magnitude

    -- Обновить позицию
    proj.position = newPos

    -- ── Hit detection (sphere overlap) ────────────────────
    local hits = TargetFinder.sphereOverlap(newPos, proj.hitRadius, proj.hitList)

    for _, target in hits do
        local didHit = ProjectileManager._processHit(proj, target)

        if didHit and proj.pierceLeft < 0 then
            -- Pierce исчерпан — удалить
            return true
        end
    end

    -- ── Проверка земли (для снарядов с гравитацией) ───────
    if proj.gravity > 0 then
        local rayResult = workspace:Raycast(proj.position, Vector3.new(0, -1, 0), RaycastParams.new())
        if rayResult and (proj.position.Y - rayResult.Position.Y) < 0.5 then
            return true
        end
    end

    -- ── Проверка лимитов ──────────────────────────────────
    if proj.distanceTraveled > proj.maxDistance then
        return true
    end

    if proj.elapsed > proj.lifetime then
        return true
    end

    return false
end

-- ═══════════════════════════════════════════════════════════
-- Heartbeat — обновление всех снарядов
-- ═══════════════════════════════════════════════════════════

function ProjectileManager._update(dt)
    local toRemove = {}

    for id, proj in activeProjectiles do
        local shouldRemove = ProjectileManager._tickProjectile(proj, dt)
        if shouldRemove then
            table.insert(toRemove, id)
        end
    end

    for _, id in toRemove do
        ProjectileManager._remove(id)
    end
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API
-- ═══════════════════════════════════════════════════════════

--- Создать и запустить снаряд
--- @param params table
--- params.owner        : Player        — владелец снаряда
--- params.origin       : Vector3       — начальная позиция
--- params.direction    : Vector3       — направление (unit)
--- params.projectileId : string        — ключ из ProjectileConfig
--- params.baseDamage   : number        — базовый урон
--- params.damageType   : string        — "Physical"|"Magic"|"Ranged"
--- params.pierceCount  : number?       — override из эффекта (иначе из конфига)
function ProjectileManager.fire(params)
    local projConfig = getProjectileConfig(params.projectileId)
    if not projConfig then
        warn("[ProjectileManager] Unknown projectile: " .. tostring(params.projectileId))
        return nil
    end

    -- Лимит активных снарядов
    if countActive() >= MAX_PROJECTILES then
        removeOldest()
    end

    local id = generateId()

    -- Нормализуем направление
    local direction = params.direction
    if direction.Magnitude > 0.001 then
        direction = direction.Unit
    else
        direction = Vector3.new(0, 0, -1)
    end

    local pierceCount = params.pierceCount or projConfig.PierceCount or 0

    local proj = {
        id = id,
        owner = params.owner,
        position = params.origin,
        direction = direction,
        speed = projConfig.Speed,
        gravity = projConfig.Gravity or 0,
        maxDistance = projConfig.MaxDistance,
        hitRadius = projConfig.HitRadius or 2,
        lifetime = projConfig.Lifetime or 3,
        baseDamage = params.baseDamage,
        damageType = params.damageType or "Physical",
        pierceLeft = pierceCount,
        distanceTraveled = 0,
        elapsed = 0,
        velocityY = 0, -- вертикальная скорость (для гравитации)
        spawnTime = tick(),
        hitList = {} -- { [entity] = true }
    }

    activeProjectiles[id] = proj

    -- Уведомить клиентов для визуализации
    Remotes.ProjectileFired:FireAllClients({
        id = id,
        origin = params.origin,
        direction = direction,
        projectileId = params.projectileId,
        speed = projConfig.Speed,
        gravity = projConfig.Gravity or 0
    })

    return id
end

--- Инициализация — подключить Heartbeat
--- Вызывается из CombatManager.server.luau
function ProjectileManager.init()
    if initialized then
        return
    end
    initialized = true

    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        ProjectileManager._update(dt)
    end)

    print("[ProjectileManager] Initialized")
end

return ProjectileManager
