Phase 4: Ranged Weapon System — Пошаговое руководство (v2)
Обзор
Рефакторинг боевой системы для масштабирования + реализация дальнобойного оружия (Bow). Создаёт фундамент для Phase 5 (Magic System).

Ключевые архитектурные решения
Решение A — mousePosition при выстреле
Два remote'а вместо одного:

AttackRequest → начинает каст (для ranged)
RangedRelease → клиент отправляет финальную mousePosition при завершении каста
Fallback: если RangedRelease не пришёл в течение 1 с после OnComplete — используется character.HumanoidRootPart.CFrame.LookVector.

Решение B — Hit detection снарядов
Используется sphere overlap (TargetFinder.sphereOverlap), а НЕ raycast. На каждом кадре ProjectileManager перемещает снаряд и ищет цели в сфере HitRadius вокруг текущей позиции. Это исключает пролёт сквозь цели при высокой скорости.

Решение C — AoEProjectile (дождь стрел)
AbilityManager при эффекте AoEProjectile:

Клиент отправляет mousePosition → это центр области на земле
На сервере вычисляется точка удара (mousePosition)
Стрелы спавнятся на высоте mousePosition.Y + SpawnHeight (по умолчанию 40 studs)
Каждая стрела получает random XZ-offset в пределах Radius
direction = Vector3.new(0, -1, 0) (строго вниз)
Gravity в конфиге rain_arrow усиливает падение
Решение D — Cooldown при отмене каста
Cooldown применяется только в RangedHandler.onRelease после успешного ProjectileManager.fire(). Если каст отменён (OnCancel) — cooldown НЕ ставится. Игрок может сразу начать новый каст.

Решение E — getWeaponConfig → WeaponUtil.luau
Создаём общую утилиту src/server/combat/WeaponUtil.luau с функцией getConfig(player), которая заменяет дублированные getWeaponConfig в WeaponManager и AbilityManager.

Структура файлов (финальная)
src/shared/config/
├── WeaponConfig.luau          # EDIT — коллектор, подтягивает weapons/*
├── ProjectileConfig.luau      # NEW — настройки снарядов
├── weapons/                   # NEW — конфиги оружия по файлам
│   ├── SwordConfig.luau
│   ├── AxeConfig.luau
│   └── BowConfig.luau
└── items/
    └── WeaponItems.luau       # EDIT — добавить Bow

src/server/combat/
├── CombatManager.server.luau  # NEW — роутер (заменяет WeaponManager)
├── DamageCalc.luau            # NEW — единый расчёт урона
├── TargetFinder.luau          # NEW — поиск целей
├── WeaponUtil.luau            # NEW — общая утилита getConfig
├── MeleeHandler.luau          # NEW — melee логика
├── RangedHandler.luau         # NEW — ranged логика + каст
├── ResourceHit.luau           # NEW — удар по ресурсам
├── ProjectileManager.luau     # NEW — жизненный цикл снарядов
└── WeaponManager.server.luau  # DELETE после миграции

src/client/combat/
├── CombatInput.client.luau    # EDIT — роутер ввода по типу оружия
├── MeleeInput.luau            # NEW — melee LMB loop
├── RangedInput.luau           # NEW — LMB зажатие = прицел, отпускание = выстрел
└── ProjectileVisuals.client.luau # NEW — визуализация снарядов

src/shared/
└── Remotes.luau               # EDIT — добавить RangedRelease, ProjectileFired, ProjectileHit, ProjectileRemoved
Шаг 0: Remotes и default.project.json
Remotes.luau — добавить в массив events:
Copy"RangedRelease",      -- Client → Server: финальная mousePosition после каста
"ProjectileFired",    -- Server → Client: визуализация снаряда
"ProjectileHit",      -- Server → Client: эффект попадания
"ProjectileRemoved",  -- Server → Client: удалить визуал
default.project.json — без изменений
Rojo маппит src/shared → ReplicatedStorage целиком, включая все подпапки. Папка weapons/ в src/shared/config/ автоматически появится как ReplicatedStorage.config.weapons (Folder с ModuleScript'ами внутри). Дополнительного маппинга не нужно.

Шаг 1: WeaponUtil.luau (сервер)
Цель: Устранить дублирование getWeaponConfig между WeaponManager и AbilityManager.

Файл: src/server/combat/WeaponUtil.luau

Copylocal ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local InventoryManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("InventoryManager"))

local WeaponUtil = {}

-- Получить конфиг текущего оружия игрока
-- returns: weaponConfig, weaponItem | nil, nil
function WeaponUtil.getConfig(player)
    local inv = InventoryManager.getInventory(player)
    if not inv or not inv.activeWeaponSlot then return nil, nil end

    local weaponItem = inv.slots[inv.activeWeaponSlot]
    if not weaponItem or weaponItem == false then return nil, nil end

    local weaponConfig = Config.Weapons[weaponItem.Id]
    if not weaponConfig then return nil, nil end

    return weaponConfig, weaponItem
end

-- Определить тип оружия: "Melee" | "Ranged"
function WeaponUtil.getType(weaponConfig)
    return weaponConfig and weaponConfig.Type or "Melee"
end

return WeaponUtil
Применение: Заменить getWeaponConfig в WeaponManager.server.luau и AbilityManager.getWeaponConfig на WeaponUtil.getConfig. AbilityManager больше не требует собственного InventoryManager.

Шаг 2: DamageCalc.luau (сервер)
Цель: Извлечь дублированный расчёт урона из WeaponManager и AbilityManager в единый модуль.

Файл: src/server/combat/DamageCalc.luau

Извлекаемая логика из:

WeaponManager.server.luau строки 75-95 (physical power, crit, resist, level mod)
AbilityManager.luau функция calcAbilityDamage (physical + magic ветки)
API:

Copylocal DamageCalc = {}

-- params = {
--   player      : Player         — атакующий игрок (для StatsManager)
--   target      : Model          — цель (для resist, level)
--   baseDamage  : number         — базовый урон из конфига
--   damageType  : "Physical"|"Magic"|"Ranged" — тип урона
-- }
-- returns: finalDamage (number), isCrit (boolean)
function DamageCalc.calculate(params) end

return DamageCalc
Реализация:

damageType == "Ranged" использует PhysicalPower, PhysCritChance, PhysCritDamage, PhysResistance (как Physical)
damageType == "Magic" использует MagicalPower, MagicCritChance, MagicCritDamage, MagicResistance
Level modifier через LevelManager.getDamageModifier
math.max(1, math.floor(result)) — минимум 1
Зависимости: StatsManager, LevelManager

Тест: После создания — заменить расчёт урона в WeaponManager на DamageCalc.calculate(...), убедиться что урон не изменился.

Шаг 3: TargetFinder.luau (сервер)
Цель: Извлечь дублированный поиск целей из WeaponManager и AbilityManager.

Файл: src/server/combat/TargetFinder.luau

Извлекаемая логика из:

WeaponManager.server.luau функция getTargets + фильтрация по distance/dot
AbilityManager.luau функции _getEnemiesInRadius, _getPlayersInRadius
API:

Copylocal TargetFinder = {}

-- Все враги и игроки в радиусе (для AoE)
function TargetFinder.inRadius(origin, radius, excludeCharacter)
    -- returns: { entity1, entity2, ... }
end

-- Цели в конусе перед атакующим (для melee/directed)
function TargetFinder.inCone(origin, direction, range, dotThreshold, excludeCharacter)
    -- dotThreshold = 0.3 (default)
    -- returns: { {entity, distance}, ... } отсортированные по distance
end

-- Ближайшая цель в конусе (для single-target)
function TargetFinder.closestInCone(origin, direction, range, dotThreshold, excludeCharacter)
    -- returns: entity | nil
end

-- Все цели в сфере заданного радиуса (для снарядов)
-- В отличие от inRadius, работает от произвольной точки и исключает hitList
function TargetFinder.sphereOverlap(position, radius, hitList)
    -- hitList: { [entity] = true } — уже задетые цели (для pierce)
    -- returns: { entity1, entity2, ... } — новые попадания
end

-- Raycast (fallback, для лучевых способностей если потребуется)
function TargetFinder.raycast(origin, direction, maxDist, excludeList)
    -- returns: entity | nil, hitPosition
end

return TargetFinder
Copy
Реализация:

Ищет в workspace.Enemies + Players (кроме excludeCharacter)
Проверяет Humanoid.Health > 0 и not IsDead
inCone: dot product для углового фильтра
sphereOverlap: итерирует тех же врагов/игроков, сравнивает расстояние с radius, пропускает всех из hitList
Тест: Заменить поиск целей в WeaponManager на TargetFinder.inCone(...), проверить что враги получают урон как раньше.

Шаг 4: ResourceHit.luau (сервер)
Цель: Выделить логику удара по ресурсам из WeaponManager.

Файл: src/server/combat/ResourceHit.luau

Извлекаемая логика из:

WeaponManager.server.luau строки 107-145 (resource node hit)
AbilityManager.luau функция _hitResourceNodes
API:

Copylocal ResourceHit = {}

-- Ударить ресурсные ноды в конусе (для melee)
function ResourceHit.hitInCone(player, rootPart, mouseDirection, weaponConfig)
    -- Находит ноды в range+2, проверяет dot > 0.3, вызывает ResourceManager.hit
end

-- Ударить ноды в радиусе (для AoE способностей)
function ResourceHit.hitInRadius(player, rootPart, radius, weaponConfig)
end

return ResourceHit
Зависимости: ResourceManager, StatsManager (ResourceDamage stat)

Шаг 5: MeleeHandler.luau (сервер)
Цель: Melee-логика в отдельном модуле.

Файл: src/server/combat/MeleeHandler.luau

API:

Copylocal MeleeHandler = {}

local attackCooldowns = {} -- [userId] = lastAttackTime

-- Обработка melee-атаки (вызывается из CombatManager)
function MeleeHandler.attack(player, mousePosition, comboIndex, weaponConfig)
    -- 1. Валидация (character, humanoid, rootPart, IsDead, cooldown)
    -- 2. Combo index clamping
    -- 3. DamageCalc.calculate для каждой цели в конусе (TargetFinder.inCone)
    -- 4. HealthManager.takeDamage + StatsManager.markCombat
    -- 5. ResourceHit.hitInCone
end

-- Очистка данных игрока
function MeleeHandler.cleanup(player)
    attackCooldowns[player.UserId] = nil
end

return MeleeHandler
Логика: Весь код из текущего Remotes.AttackRequest.OnServerEvent переносится сюда, но с вызовами DamageCalc, TargetFinder, ResourceHit, WeaponUtil вместо inline-кода.

Шаг 6: CombatManager.server.luau (сервер)
Цель: Тонкий роутер, заменяет WeaponManager.server.luau.

Файл: src/server/combat/CombatManager.server.luau

Copylocal Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local WeaponUtil = require(script.Parent:WaitForChild("WeaponUtil"))
local MeleeHandler = require(script.Parent:WaitForChild("MeleeHandler"))
local RangedHandler = require(script.Parent:WaitForChild("RangedHandler"))
local ProjectileManager = require(script.Parent:WaitForChild("ProjectileManager"))
local AbilityManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("AbilityManager"))

-- Инициализация ProjectileManager (Heartbeat подключение)
ProjectileManager.init()

-- ═══ Основная атака ═══
Remotes.AttackRequest.OnServerEvent:Connect(function(player, mousePos, comboIndex)
    local weaponConfig, weaponItem = WeaponUtil.getConfig(player)
    if not weaponConfig then return end

    local wType = WeaponUtil.getType(weaponConfig)
    if wType == "Ranged" then
        RangedHandler.attack(player, mousePos, weaponConfig)
    else
        MeleeHandler.attack(player, mousePos, comboIndex, weaponConfig)
    end
end)

-- ═══ Ranged: клиент отправляет финальную mousePosition ═══
Remotes.RangedRelease.OnServerEvent:Connect(function(player, mousePosition)
    RangedHandler.onRelease(player, mousePosition)
end)

-- ═══ Способности Q/E ═══
Remotes.UseAbility.OnServerEvent:Connect(function(player, key, mousePosition)
    AbilityManager.useAbility(player, key, mousePosition)
end)

-- ═══ Cleanup при выходе ═══
Players.PlayerRemoving:Connect(function(player)
    MeleeHandler.cleanup(player)
    RangedHandler.cleanup(player)
end)

print("[CombatManager] Initialized")
Copy
После этого: удалить WeaponManager.server.luau.

Тест: Melee-бой должен работать точно как раньше. Проверить: комбо, урон, крит, ресурсы, способности Q/E.

Шаг 7: Рефакторинг AbilityManager.luau
Цель: Заменить inline расчёт урона и поиск целей на DamageCalc + TargetFinder + WeaponUtil.

Изменения:

Удалить getWeaponConfig (локальная) → использовать WeaponUtil.getConfig
Удалить calcAbilityDamage (локальная) → использовать DamageCalc.calculate
Удалить _getEnemiesInRadius, _getPlayersInRadius → использовать TargetFinder.inRadius
Удалить _hitResourceNodes → использовать ResourceHit.hitInRadius
_directDamage → TargetFinder.closestInCone + DamageCalc.calculate
_aoeDamage → TargetFinder.inRadius + DamageCalc.calculate
Добавить новые типы эффектов "Projectile" и "AoEProjectile" (для ranged-способностей, Шаг 12)
Тест: Способности Q/E Sword и Axe работают как раньше.

Шаг 8: Разбивка WeaponConfig.luau на файлы
Цель: Каждое оружие — отдельный файл. Коллектор остаётся на уровне config/.

Файлы:

src/shared/config/weapons/SwordConfig.luau — содержимое Weapons.Sword (return таблица)
src/shared/config/weapons/AxeConfig.luau — содержимое Weapons.Axe (return таблица)
src/shared/config/weapons/BowConfig.luau — новый (Шаг 9)
Коллектор: src/shared/config/WeaponConfig.luau (EDIT)

Copylocal ReplicatedStorage = game:GetService("ReplicatedStorage")
local configFolder = ReplicatedStorage:WaitForChild("config")
local weaponsFolder = configFolder:WaitForChild("weapons")

local Weapons = {}

-- Автоматически собираем все конфиги оружия из подпапки
for _, module in weaponsFolder:GetChildren() do
    if module:IsA("ModuleScript") then
        local data = require(module)
        -- Имя оружия = имя модуля без "Config" суффикса
        local weaponName = module.Name:gsub("Config$", "")
        Weapons[weaponName] = data
    end
end

return {
    Weapons = Weapons,
}
Почему это работает: Config.luau уже итерирует все ModuleScript'ы первого уровня в config/ и мержит их ключи. WeaponConfig.luau возвращает { Weapons = ... }, значит Config.Weapons будет доступен как раньше. Подпапка weapons/ в Rojo автоматически станет Folder-ом внутри config.

Файл SwordConfig.luau (пример):

Copyreturn {
    Type = "Melee",    -- NEW: явный тип
    Damage = 15,
    Range = 6,
    Cooldown = 0.4,
    ComboWindow = 1.2,
    ResourceDamage = 15,
    Combo = {
        [1] = { Damage = 25, AnimationId = "rbxassetid://70662356098178" },
        [2] = { Damage = 20, AnimationId = "rbxassetid://70662356098178" },
        [3] = { Damage = 30, AnimationId = "rbxassetid://110637980313006" },
    },
    -- ... ComboAbility, Abilities как раньше
}
Важно: Добавить Type = "Melee" к Sword и Axe. Ранее тип не указывался — WeaponUtil.getType возвращает "Melee" по умолчанию, но явное указание лучше.

Тест: Config.Weapons.Sword, Config.Weapons.Axe возвращают те же данные.

Шаг 9: BowConfig.luau + ProjectileConfig.luau
BowConfig.luau
Файл: src/shared/config/weapons/BowConfig.luau

Copyreturn {
    Type = "Ranged",
    Damage = 18,
    Range = 60,
    Cooldown = 0.3,
    CastTime = 0.8,
    ProjectileId = "arrow",
    ResourceDamage = 0,
    CastMovementMode = "Slowed",
    CastSpeedMult = 0.5,
    Combo = {
        [1] = { Damage = 18, AnimationId = "rbxassetid://0" },
    },
    ComboAbility = {
        Id = "bow_shot",
        Name = "Bow Shot",
        Description = "Charged arrow shot.",
        Icon = "rbxassetid://0",
    },
    Abilities = {
        Q = {
            Id = "power_shot",
            Name = "Мощный выстрел",
            Description = "Пробивающая стрела, наносит повышенный урон.",
            Icon = "rbxassetid://0",
            AnimationId = "rbxassetid://0",
            Cooldown = 10,
            DamageType = "Physical",
            Effects = {{
                Type = "Projectile",
                ProjectileId = "power_arrow",
                Damage = 50,
            }},
        },
        E = {
            Id = "arrow_rain",
            Name = "Дождь стрел",
            Description = "AoE: стрелы падают в указанную область.",
            Icon = "rbxassetid://0",
            AnimationId = "rbxassetid://0",
            Cooldown = 16,
            DamageType = "Physical",
            Effects = {{
                Type = "AoEProjectile",
                ProjectileId = "rain_arrow",
                Damage = 25,
                Radius = 12,
                Count = 8,
                SpawnHeight = 40,  -- высота спавна стрел над землёй
            }},
        },
    },
}
Copy
ProjectileConfig.luau
Файл: src/shared/config/ProjectileConfig.luau

Copyreturn {
    Projectiles = {
        arrow = {
            Speed = 120,
            MaxDistance = 60,
            Gravity = 0,
            PierceCount = 0,
            Lifetime = 3,
            ModelId = "rbxassetid://0",
            TrailColor = Color3.fromRGB(255, 220, 100),
            HitRadius = 2,
        },
        power_arrow = {
            Speed = 160,
            MaxDistance = 80,
            Gravity = 0,
            PierceCount = 2,
            Lifetime = 3,
            ModelId = "rbxassetid://0",
            TrailColor = Color3.fromRGB(255, 100, 100),
            HitRadius = 2.5,
        },
        rain_arrow = {
            Speed = 80,
            MaxDistance = 30,
            Gravity = 50,
            PierceCount = 0,
            Lifetime = 2,
            ModelId = "rbxassetid://0",
            TrailColor = Color3.fromRGB(200, 200, 255),
            HitRadius = 3,
        },
    },
}
Copy
WeaponItems.luau — добавить:
CopyBow = {
    Name = "Hunting Bow",
    Description = "A reliable ranged weapon.",
    Icon = "rbxassetid://0",
    Type = "Weapon",
    ItemLevel = 8,
    Stackable = false,
    MaxStack = 1,
},
Шаг 10: ProjectileManager.luau (сервер)
Цель: Авторитетный серверный менеджер снарядов.

Файл: src/server/combat/ProjectileManager.luau

API:

Copylocal ProjectileManager = {}

-- Создать и запустить снаряд
function ProjectileManager.fire(params)
    -- params = {
    --   owner       : Player
    --   origin      : Vector3
    --   direction   : Vector3 (unit)
    --   projectileId: string (ключ из ProjectileConfig)
    --   baseDamage  : number
    --   damageType  : "Physical"|"Magic"
    --   pierceCount : number? (override из конфига)
    -- }
end

-- Подключается к Heartbeat — вызывается из CombatManager при старте
function ProjectileManager.init() end

return ProjectileManager
Внутренняя логика:

fire() создаёт запись в activeProjectiles[]:

Copy{
    id = uniqueId,
    owner = player,
    position = origin,
    direction = direction,
    speed = projConfig.Speed,
    gravity = projConfig.Gravity,
    maxDistance = projConfig.MaxDistance,
    hitRadius = projConfig.HitRadius,
    pierceLeft = projConfig.PierceCount,
    lifetime = projConfig.Lifetime,
    baseDamage = baseDamage,
    damageType = damageType,
    distanceTraveled = 0,
    elapsed = 0,
    hitList = {},  -- { [entity] = true }
}
fire() → Remotes.ProjectileFired:FireAllClients(...) для визуализации

Heartbeat для каждого снаряда:

Вычислить velocity = direction * speed + Vector3.new(0, -gravity * elapsed, 0)
newPos = position + velocity * dt
distanceTraveled += (newPos - position).Magnitude
Hit check: TargetFinder.sphereOverlap(newPos, hitRadius, hitList) — находит новые цели
Для каждого попадания: DamageCalc.calculate(...) + HealthManager.takeDamage(...) + добавить в hitList
Remotes.ProjectileHit:FireAllClients(id, hitPosition) для визуального эффекта
Если pierceLeft <= 0 после попадания → удалить
Если distanceTraveled > maxDistance или elapsed > lifetime → удалить
При удалении → Remotes.ProjectileRemoved:FireAllClients(id)
Не создаёт физических Part'ов на сервере — чисто виртуальная симуляция

Лимит: максимум 50 активных снарядов. При превышении — самый старый удаляется.

Зависимости: DamageCalc, TargetFinder (sphereOverlap), HealthManager, StatsManager, Config.Projectiles

Шаг 11: RangedHandler.luau (сервер)
Цель: Обработка ranged-атак с кастом и двухфазным вводом.

Файл: src/server/combat/RangedHandler.luau

Copylocal RangedHandler = {}

local CastManager = require(...)
local ProjectileManager = require(...)
local WeaponUtil = require(...)

local pendingCasts = {} -- [player] = { weaponConfig, castId, timestamp }
local attackCooldowns = {} -- [userId] = lastAttackTime

-- Фаза 1: Начать каст (вызывается из CombatManager по AttackRequest)
function RangedHandler.attack(player, mousePosition, weaponConfig)
    -- 1. Валидация (character, humanoid, IsDead)
    -- 2. Проверка cooldown
    -- 3. Проверка CastManager.isActive → return если уже кастуется
    -- 4. CastManager.start({
    --      Duration = weaponConfig.CastTime,
    --      Label = "Натяжение...",
    --      MovementMode = weaponConfig.CastMovementMode or "Slowed",
    --      SpeedMult = weaponConfig.CastSpeedMult or 0.5,
    --      CancelOnDamage = true,
    --      OnComplete = function(player)
    --          -- Каст завершён, ждём RangedRelease от клиента
    --          -- Fallback: если клиент не отправит за 1 с — стреляем по LookVector
    --          pendingCasts[player].waitTask = task.delay(1.0, function()
    --              if pendingCasts[player] then
    --                  RangedHandler._fireWithLookVector(player)
    --              end
    --          end)
    --      end,
    --      OnCancel = function(player, reason)
    --          pendingCasts[player] = nil
    --          -- Cooldown НЕ применяется
    --      end,
    --   })
    -- 5. Сохраняем в pendingCasts[player] = { weaponConfig, castId, timestamp }
end

-- Фаза 2: Получить финальную mousePosition от клиента (через RangedRelease)
function RangedHandler.onRelease(player, mousePosition)
    local pending = pendingCasts[player]
    if not pending then return end

    -- Отменить fallback таймер
    if pending.waitTask then task.cancel(pending.waitTask) end
    pendingCasts[player] = nil

    -- Рассчитать направление
    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local direction = (mousePosition - rootPart.Position).Unit

    -- Применить cooldown СЕЙЧАС (выстрел успешен)
    attackCooldowns[player.UserId] = tick()

    -- Создать снаряд
    ProjectileManager.fire({
        owner = player,
        origin = rootPart.Position + direction * 2, -- чуть перед персонажем
        direction = direction,
        projectileId = pending.weaponConfig.ProjectileId,
        baseDamage = pending.weaponConfig.Damage,
        damageType = "Ranged",
    })
end

-- Fallback — стрелять по LookVector если клиент не ответил
function RangedHandler._fireWithLookVector(player)
    local pending = pendingCasts[player]
    if not pending then return end
    pendingCasts[player] = nil

    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local direction = rootPart.CFrame.LookVector
    attackCooldowns[player.UserId] = tick()

    ProjectileManager.fire({
        owner = player,
        origin = rootPart.Position + direction * 2,
        direction = direction,
        projectileId = pending.weaponConfig.ProjectileId,
        baseDamage = pending.weaponConfig.Damage,
        damageType = "Ranged",
    })
end

-- Очистка при выходе
function RangedHandler.cleanup(player)
    pendingCasts[player] = nil
    attackCooldowns[player.UserId] = nil
end

return RangedHandler
Copy
Шаг 12: Типы эффектов Projectile и AoEProjectile в AbilityManager
Цель: Добавить обработку ranged-способностей Q/E.

В AbilityManager.luau, в цикле обработки effect.Type, добавить:

Copyelseif effect.Type == "Projectile" then
    -- Одиночный снаряд (Q лука: Мощный выстрел)
    local direction = (mousePosition - rootPart.Position).Unit
    ProjectileManager.fire({
        owner = player,
        origin = rootPart.Position + direction * 2,
        direction = direction,
        projectileId = effect.ProjectileId,
        baseDamage = effect.Damage,
        damageType = ability.DamageType or "Physical",
        pierceCount = effect.PierceCount, -- override из эффекта если есть
    })

elseif effect.Type == "AoEProjectile" then
    -- Дождь снарядов (E лука: Дождь стрел)
    local count = effect.Count or 8
    local radius = effect.Radius or 12
    local spawnHeight = effect.SpawnHeight or 40
    -- mousePosition = центр области на земле
    local centerGround = Vector3.new(mousePosition.X, rootPart.Position.Y, mousePosition.Z)

    for i = 1, count do
        local offsetX = (math.random() - 0.5) * 2 * radius
        local offsetZ = (math.random() - 0.5) * 2 * radius
        local spawnPos = centerGround + Vector3.new(offsetX, spawnHeight, offsetZ)

        task.defer(function()  -- небольшой разброс по времени
            task.wait(math.random() * 0.3)
            ProjectileManager.fire({
                owner = player,
                origin = spawnPos,
                direction = Vector3.new(0, -1, 0), -- строго вниз
                projectileId = effect.ProjectileId,
                baseDamage = effect.Damage,
                damageType = ability.DamageType or "Physical",
            })
        end)
    end
Copy
Клиентская часть Q/E для лука: CastBar уже работает через CastManager. Способности Q/E лука НЕ требуют каста через CastManager (каст нужен только для базовой LMB-атаки). Q и E — мгновенные способности с обычным cooldown (как у меча). Если нужен каст для Q — добавить CastTime в конфиг способности и обработать в AbilityManager аналогично RangedHandler.

Шаг 13: Клиент — CombatInput рефакторинг
MeleeInput.luau (клиент)
Файл: src/client/combat/MeleeInput.luau

Извлечь из текущего CombatInput.client.luau:

performAttack() — комбо-логика, отправка AttackRequest, анимация
attackLoop() — цикл при зажатии LMB
Переменные: comboIndex, lastAttackTime, isAttacking, isHolding, currentTrack
API:

Copylocal MeleeInput = {}
function MeleeInput.start() end   -- начать attackLoop
function MeleeInput.stop() end    -- остановить цикл (isHolding = false)
function MeleeInput.isActive() end
return MeleeInput
RangedInput.luau (клиент)
Файл: src/client/combat/RangedInput.luau

API:

Copylocal RangedInput = {}
function RangedInput.start() end   -- отправить AttackRequest (начать каст)
function RangedInput.stop() end    -- отправить RangedRelease с финальной mousePosition
function RangedInput.isActive() end
return RangedInput
Логика:

start() — отправляет Remotes.AttackRequest:FireServer(mousePosition) (сервер начнёт каст)
Слушает Remotes.CastStart → CastBar показывает полоску натяжения
При завершении каста (CastBar заканчивается) или при stop() (отпускание LMB):
Получает текущую mousePosition в этот момент
Отправляет Remotes.RangedRelease:FireServer(mousePosition)
Если каст отменён (CastCancel от сервера) → ничего не отправляет
CombatInput.client.luau (роутер)
Файл: src/client/combat/CombatInput.client.luau

Copylocal Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local MeleeInput = require(script.Parent:WaitForChild("MeleeInput"))
local RangedInput = require(script.Parent:WaitForChild("RangedInput"))

local player = Players.LocalPlayer

local function getWeaponType()
    local character = player.Character
    if not character then return nil end
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then return nil end
    local cfg = Config.Weapons[tool.Name]
    if not cfg then return nil end
    return cfg.Type or "Melee"
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local wType = getWeaponType()
        if not wType then return end
        if wType == "Ranged" then
            RangedInput.start()
        else
            MeleeInput.start()
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        MeleeInput.stop()
        RangedInput.stop()
    end
end)
Copy
Шаг 14: ProjectileVisuals.client.luau
Файл: src/client/combat/ProjectileVisuals.client.luau

Логика:

Слушает Remotes.ProjectileFired → получает {id, origin, direction, projectileId, speed}
Создаёт Part (sphere 0.5 studs) или модель (из ProjectileConfig.ModelId)
Добавляет Trail с цветом из конфига (TrailColor)
Heartbeat: двигает визуал по direction * speed * dt
Слушает Remotes.ProjectileHit → эффект вспышки в точке попадания
Слушает Remotes.ProjectileRemoved → удаляет визуал с fade-out
Важно: Визуал чисто косметический. Авторитетная логика только на сервере.

Шаг 15: Debug команды
Добавить в DebugCommands.server.luau:

Copycommands["/bow"] = function(player, args)
    InventoryManager.addItemFromConfig(player, "Bow", 1)
    InventorySync.sendFullUpdate(player)
    return "Bow added"
end

commands["/weapon"] = function(player, args)
    local id = args[1]
    if not id then return "Usage: /weapon <id>" end
    InventoryManager.addItemFromConfig(player, id, 1)
    InventorySync.sendFullUpdate(player)
    return "Weapon " .. id .. " added"
end
Порядок реализации (чеклист)
Этап A: Рефакторинг (без нового функционала)
 0. Добавить remote'ы в Remotes.luau
 1. Создать WeaponUtil.luau
 2. Создать DamageCalc.luau
 3. Создать TargetFinder.luau (включая sphereOverlap)
 4. Создать ResourceHit.luau
 5. Создать MeleeHandler.luau (с cleanup)
 6. Создать CombatManager.server.luau (с PlayerRemoving cleanup)
 7. Тест: melee-бой работает как раньше (комбо, урон, крит, ресурсы)
 8. Удалить WeaponManager.server.luau
 9. Рефакторинг AbilityManager.luau → DamageCalc + TargetFinder + WeaponUtil
 10. Тест: способности Q/E работают как раньше
 11. Разбить WeaponConfig.luau на файлы (+ добавить Type = "Melee")
 12. Тест: Config.Weapons.Sword/Axe возвращают те же данные
Этап B: Ranged система (сервер)
 13. Создать ProjectileConfig.luau
 14. Создать BowConfig.luau
 15. Добавить Bow в WeaponItems.luau
 16. Создать ProjectileManager.luau (с sphereOverlap hit detection)
 17. Создать RangedHandler.luau (двухфазный: attack → onRelease, с cleanup)
 18. Тест: /bow, экипировать, LMB → каст → стрела летит → урон
Этап C: Клиент
 19. Создать MeleeInput.luau (извлечь из CombatInput)
 20. Создать RangedInput.luau (start → каст, stop → RangedRelease)
 21. Рефакторинг CombatInput.client.luau → роутер
 22. Создать ProjectileVisuals.client.luau
 23. Тест: визуал стрелы, каст-бар натяжения, прицеливание
Этап D: Способности и полировка
 24. Добавить тип эффекта "Projectile" в AbilityManager
 25. Добавить тип эффекта "AoEProjectile" в AbilityManager (с SpawnHeight)
 26. Тест: Q = мощный выстрел, E = дождь стрел
 27. Debug команды /bow, /weapon
 28. Обновить Architecture.md
 29. Обновить debug_commands.md
 30. Коммит
Зависимости между шагами
WeaponUtil (1) ──────┐
DamageCalc (2) ──────┤
TargetFinder (3) ────┤
ResourceHit (4) ─────┼──→ MeleeHandler (5) ──→ CombatManager (6)
                     │
                     ├──→ AbilityManager refactor (9)
                     │
ProjectileConfig (13)┤
BowConfig (14) ──────┼──→ ProjectileManager (16) ──→ RangedHandler (17)
                     │
MeleeInput (19) ─────┤
RangedInput (20) ────┼──→ CombatInput refactor (21)
                     │
                     └──→ ProjectileVisuals (22)
Решённые проблемы (итого)
#	Проблема	Решение
1	mousePosition при выстреле	Двухфазный ввод: AttackRequest → каст → RangedRelease с финальной позицией + fallback по LookVector
2	ProjectileManager.init()	Явный вызов в CombatManager.server.luau
3	Hit detection (sphere vs ray)	TargetFinder.sphereOverlap добавлен в API и используется в ProjectileManager
4	AoEProjectile спавн	Описана полная механика: mousePosition = центр, SpawnHeight, random offset, direction = вниз
5	default.project.json	Изменения не нужны — Rojo маппит подпапки автоматически. Проверено по текущему конфигу
6	Cooldown при отмене	Cooldown ставится только в onRelease после успешного fire
7	CastManager блокировка	CastManager.isActive проверяется в RangedHandler.attack
8	Новые Remote'ы	RangedRelease, ProjectileFired, ProjectileHit, ProjectileRemoved
9	WeaponConfig коллектор путь	Коллектор использует configFolder:WaitForChild("weapons") — аналогично ItemConfig.luau
10	getWeaponConfig дубликат	Вынесена в WeaponUtil.luau, используется в CombatManager, MeleeHandler, RangedHandler, AbilityManager
11	Q/E для ranged на клиенте	Q/E лука — мгновенные способности (без каста), CastBar только для LMB. Если нужен каст Q — добавить CastTime в конфиг
12	attackCooldowns cleanup	MeleeHandler.cleanup и RangedHandler.cleanup вызываются из CombatManager при PlayerRemoving
Риски и заметки
Tool система Roblox: Лук должен быть Tool с Handle, как и мечи. CombatInput определяет тип по Tool.Name → Config.Weapons[name].Type.
CastManager + Ranged: Во время каста нельзя атаковать повторно (CastManager.isActive → return).
PierceCount: Снаряд ведёт hitList чтобы не бить одну цель дважды.
Gravity: Для rain_arrow стрелы спавнятся сверху, Gravity ускоряет падение.
Performance: ProjectileManager лимитирует ≤50 активных снарядов. При превышении — самый старый удаляется.
Серверная авторитетность: Клиент НЕ решает попадания. ProjectileVisuals — чисто косметический.


Сценарии:

Сценарий	LMB up	Каст	Результат
A. Нормальный	После каста	Завершён	RangedRelease приходит → выстрел ✅
B. Раннее отпускание	До конца каста	Ещё идёт	RangedRelease приходит → pendingCasts пуст → пакет теряется → каст завершится → fallback по LookVector ❌
C. Быстрый клик	Сразу	Начался	То же что B, но хуже — игрок ожидал отмену
Проблема B — игрок целится и отпускает LMB, ожидая что стрела полетит в нужном направлении, но mousePosition теряется и срабатывает fallback по LookVector.

Решение: клиент отправляет RangedRelease только после получения CastComplete
Вместо привязки к InputEnded (LMB up), клиент ждёт сигнал завершения каста от сервера:

LMB down → AttackRequest → сервер начинает каст
          → клиент запоминает isAiming = true

Сервер каст завершён → CastStart remote уже отработал, CastBar закончился
          → клиент получает событие завершения каста

Клиент после завершения каста:
  - Если LMB всё ещё зажат → отправить RangedRelease сразу
  - Если LMB уже отпущен → ТОЖЕ отправить RangedRelease 
    (mousePosition запоминается в момент отпускания)

LMB up до конца каста → запомнить earlyReleasePosition, 
                        НЕ отправлять RangedRelease
Давай посмотрю как CastBar/CastManager сигнализирует клиенту о завершении:

Использование инструмента
|
Чтение
https://raw.githubusercontent.com/iDim123/Rise/develop_1.7/src/client/ui/CastBar.client.luau
Посмотреть
Отлично — вижу ключевой момент: CastBar.client.luau создаёт BindableEvent под названием CastComplete, который файрится при успешном завершении каста. Это именно тот сигнал, который нужен RangedInput.

Также вижу что CastCancel от сервера тоже обрабатывается.

Теперь у меня полная картина для исправления проблемы. Вот финальная схема:

Исправление: RangedInput.stop() и CastComplete
Проблема: Если игрок отпустит LMB до завершения каста, stop() отправит RangedRelease преждевременно. На сервере pendingCasts[player] ещё пуст (OnComplete не вызван) → пакет теряется → fallback по LookVector.

Решение: RangedInput работает через 3 состояния:

IDLE → CASTING → READY → IDLE
Состояние	LMB down	LMB up	CastComplete	CastCancel
IDLE	→ CASTING (send AttackRequest)	—	—	—
CASTING	—	запомнить earlyRelease + mousePos	→ отправить RangedRelease (earlyRelease mousePos) → IDLE	→ IDLE
READY	—	отправить RangedRelease (текущая mousePos) → IDLE	—	→ IDLE
Сценарии:

A. Нормальный (зажал → каст → отпустил):

LMB down → state = CASTING, send AttackRequest
CastComplete → state = READY (LMB ещё зажат)
LMB up → send RangedRelease с текущей mousePosition → IDLE
B. Раннее отпускание (нажал → отпустил → каст завершился):

LMB down → state = CASTING, send AttackRequest
LMB up → earlyReleasePos = текущая mousePosition, state остаётся CASTING
CastComplete → send RangedRelease с earlyReleasePos → IDLE
C. Каст отменён:

LMB down → state = CASTING
CastCancel → state = IDLE (ничего не отправляем)
Код RangedInput.luau:

Copylocal ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local RangedInput = {}

-- Состояния
local STATE_IDLE = "Idle"
local STATE_CASTING = "Casting"
local STATE_READY = "Ready"

local state = STATE_IDLE
local earlyReleasePos = nil -- mousePosition запомненная при раннем отпускании
local castCompleteConn = nil
local castCancelConn = nil

local function getMouseWorldPosition()
    local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local origin = mouseRay.Origin
    local dir = mouseRay.Direction

    local character = player.Character
    if not character then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local groundY = rootPart.Position.Y - 3
    if math.abs(dir.Y) < 0.001 then return nil end
    local t = (groundY - origin.Y) / dir.Y
    if t < 0 then return nil end

    return origin + dir * t
end

local function cleanup()
    if castCompleteConn then
        castCompleteConn:Disconnect()
        castCompleteConn = nil
    end
    if castCancelConn then
        castCancelConn:Disconnect()
        castCancelConn = nil
    end
    state = STATE_IDLE
    earlyReleasePos = nil
end

local function sendRelease(mousePos)
    if mousePos then
        Remotes.RangedRelease:FireServer(mousePos)
    end
    cleanup()
end

-- LMB down → начать каст
function RangedInput.start()
    if state ~= STATE_IDLE then return end

    local mousePos = getMouseWorldPosition()
    if not mousePos then return end

    state = STATE_CASTING
    earlyReleasePos = nil

    -- Отправляем AttackRequest → сервер начнёт каст
    Remotes.AttackRequest:FireServer(mousePos)

    -- Слушаем CastComplete (BindableEvent в CastBarUI)
    local castBarUI = player:WaitForChild("PlayerGui"):FindFirstChild("CastBarUI")
    if castBarUI then
        local completeEvent = castBarUI:FindFirstChild("CastComplete")
        if completeEvent then
            castCompleteConn = completeEvent.Event:Connect(function()
                if castCompleteConn then
                    castCompleteConn:Disconnect()
                    castCompleteConn = nil
                end

                if state == STATE_CASTING then
                    -- Каст завершился
                    if earlyReleasePos then
                        -- Игрок уже отпустил LMB → отправляем запомненную позицию
                        sendRelease(earlyReleasePos)
                    else
                        -- LMB ещё зажат → переходим в READY, ждём отпускания
                        state = STATE_READY
                    end
                end
            end)
        end
    end

    -- Слушаем CastCancel от сервера
    castCancelConn = Remotes.CastCancel.OnClientEvent:Connect(function()
        cleanup()
    end)
end

-- LMB up
function RangedInput.stop()
    if state == STATE_CASTING then
        -- Каст ещё идёт → запоминаем позицию, ждём CastComplete
        earlyReleasePos = getMouseWorldPosition()
        -- НЕ отправляем RangedRelease!
    elseif state == STATE_READY then
        -- Каст завершён, ожидали отпускания → отправляем текущую позицию
        local mousePos = getMouseWorldPosition()
        sendRelease(mousePos)
    end
    -- STATE_IDLE → ничего не делаем
end

function RangedInput.isActive()
    return state ~= STATE_IDLE
end

return RangedInput