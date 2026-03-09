# Phase 4: Ranged Weapon System — Пошаговое руководство

## Обзор

Рефакторинг боевой системы для масштабирования + реализация дальнобойного оружия (Bow).
Создаёт фундамент для Phase 5 (Magic System).

---

## Структура файлов (финальная)

src/shared/config/ ├── weapons/ # NEW — конфиги оружия по файлам │ ├── SwordConfig.luau │ ├── AxeConfig.luau │ └── BowConfig.luau ├── ProjectileConfig.luau # NEW — настройки снарядов └── items/ └── WeaponItems.luau # EDIT — добавить Bow

src/server/combat/ ├── CombatManager.server.luau # NEW — роутер (заменяет WeaponManager.server.luau) ├── DamageCalc.luau # NEW — единый расчёт урона ├── TargetFinder.luau # NEW — поиск целей ├── MeleeHandler.luau # NEW — melee логика ├── RangedHandler.luau # NEW — ranged логика + каст ├── ResourceHit.luau # NEW — удар по ресурсам ├── ProjectileManager.luau # NEW — жизненный цикл снарядов └── WeaponManager.server.luau # DELETE после миграции

src/client/combat/ ├── CombatInput.client.luau # EDIT — роутер ввода по типу оружия ├── MeleeInput.luau # NEW — melee LMB loop ├── RangedInput.luau # NEW — LMB зажатие = прицел, отпускание = выстрел └── ProjectileVisuals.client.luau # NEW — визуализация снарядов

src/shared/ └── Remotes.luau # EDIT — добавить ProjectileFired, RangedAttack


---

## Шаг 1: DamageCalc.luau (сервер)

**Цель:** Извлечь дублированный расчёт урона из WeaponManager и AbilityManager в единый модуль.

**Файл:** `src/server/combat/DamageCalc.luau`

**Извлекаемая логика из:**
- `WeaponManager.server.luau` строки 75-95 (physical power, crit, resist, level mod)
- `AbilityManager.luau` функция `calcAbilityDamage` (physical + magic ветки)

**API:**
```lua
local DamageCalc = {}

-- params = {
--   player      : Player          — атакующий игрок (для StatsManager)
--   target      : Model           — цель (для resist, level)
--   baseDamage  : number          — базовый урон из конфига
--   damageType  : "Physical"|"Magic"|"Ranged"  — тип урона
--   attacker    : Model?          — character атакующего (для level mod)
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

Шаг 2: TargetFinder.luau (сервер)
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

-- Raycast для снарядов (первое попадание)
function TargetFinder.raycast(origin, direction, maxDist, excludeList)
    -- returns: entity | nil, hitPosition
end

return TargetFinder
Реализация:

Ищет в workspace.Enemies + Players (кроме excludeCharacter)
Проверяет Humanoid.Health > 0 и not IsDead
inCone: dot product для углового фильтра
Тест: Заменить поиск целей в WeaponManager на TargetFinder.inCone(...), проверить что враги получают урон как раньше.

Шаг 3: ResourceHit.luau (сервер)
Цель: Выделить логику удара по ресурсам из WeaponManager.

Файл: src/server/combat/ResourceHit.luau

Извлекаемая логика из:

WeaponManager.server.luau строки 107-145 (resource node hit)
AbilityManager.luau функция _hitResourceNodes
API:

Copylocal ResourceHit = {}

-- Ударить ресурсные ноды в радиусе/конусе
function ResourceHit.hit(player, rootPart, mouseDirection, weaponConfig)
    -- Находит ноды в range+2, проверяет dot > 0.3, вызывает ResourceManager.hit
end

-- Ударить ноды в радиусе (для AoE способностей)
function ResourceHit.hitInRadius(player, rootPart, radius, weaponConfig)
end

return ResourceHit
Зависимости: ResourceManager, StatsManager (ResourceDamage stat)

Шаг 4: MeleeHandler.luau (сервер)
Цель: Melee-логика в отдельном модуле.

Файл: src/server/combat/MeleeHandler.luau

API:

Copylocal MeleeHandler = {}

-- Обработка melee-атаки (вызывается из CombatManager)
function MeleeHandler.attack(player, mousePosition, comboIndex, weaponConfig)
    -- 1. Валидация (character, humanoid, rootPart, IsDead, cooldown)
    -- 2. Combo index clamping
    -- 3. DamageCalc.calculate для каждой цели в конусе (TargetFinder.inCone)
    -- 4. HealthManager.takeDamage + StatsManager.markCombat
    -- 5. ResourceHit.hit
end

return MeleeHandler
Логика: Весь код из текущего Remotes.AttackRequest.OnServerEvent переносится сюда, но с вызовами DamageCalc, TargetFinder, ResourceHit вместо inline-кода.

Шаг 5: CombatManager.server.luau (сервер)
Цель: Тонкий роутер, заменяет WeaponManager.server.luau.

Файл: src/server/combat/CombatManager.server.luau

Реализация:

Copy-- Общая функция получения конфига оружия
local function getWeaponConfig(player) end
local function getWeaponType(weaponConfig) end  -- "Melee" | "Ranged"

Remotes.AttackRequest.OnServerEvent:Connect(function(player, mousePos, comboIndex)
    local weaponConfig, weaponItem = getWeaponConfig(player)
    if not weaponConfig then return end

    local wType = getWeaponType(weaponConfig)
    if wType == "Ranged" then
        RangedHandler.attack(player, mousePos, weaponConfig)
    else
        MeleeHandler.attack(player, mousePos, comboIndex, weaponConfig)
    end
end)

Remotes.UseAbility.OnServerEvent:Connect(function(player, key, mousePosition)
    AbilityManager.useAbility(player, key, mousePosition)
end)
После этого: удалить WeaponManager.server.luau (или переименовать в _old).

Тест: Melee-бой должен работать точно как раньше. Проверить: комбо, урон, крит, ресурсы, способности Q/E.

Шаг 6: Конфиги оружия — разбивка на файлы
Цель: Каждое оружие — отдельный файл.

Файлы:

src/shared/config/weapons/SwordConfig.luau — содержимое Weapons.Sword
src/shared/config/weapons/AxeConfig.luau — содержимое Weapons.Axe
src/shared/config/weapons/BowConfig.luau — новый (см. Шаг 8)
Коллектор: src/shared/config/WeaponConfig.luau становится коллектором:

Copylocal SwordConfig = require(script:WaitForChild("weapons"):WaitForChild("SwordConfig"))
local AxeConfig   = require(script:WaitForChild("weapons"):WaitForChild("AxeConfig"))
local BowConfig   = require(script:WaitForChild("weapons"):WaitForChild("BowConfig"))

return {
    Weapons = {
        Sword = SwordConfig,
        Axe   = AxeConfig,
        Bow   = BowConfig,
    }
}
Важно: Структура Rojo — weapons/ должна быть подпапкой config/. Проверить default.project.json.

Шаг 7: Рефакторинг AbilityManager.luau
Цель: Заменить inline расчёт урона и поиск целей на DamageCalc + TargetFinder.

Изменения:

Удалить calcAbilityDamage (локальная функция) → использовать DamageCalc.calculate
Удалить _getEnemiesInRadius, _getPlayersInRadius → использовать TargetFinder.inRadius
Удалить _hitResourceNodes → использовать ResourceHit.hitInRadius
_directDamage → TargetFinder.closestInCone + DamageCalc.calculate
_aoeDamage → TargetFinder.inRadius + DamageCalc.calculate
Добавить новый тип эффекта "Projectile" (для ranged-способностей, Шаг 10)
Тест: Способности Q/E Sword и Axe работают как раньше.

Шаг 8: BowConfig.luau + ProjectileConfig.luau
Цель: Конфиг лука и снарядов.

Файл: src/shared/config/weapons/BowConfig.luau

Copyreturn {
    Type = "Ranged",
    Damage = 18,
    Range = 60,              -- максимальная дистанция снаряда
    Cooldown = 0.3,          -- между выстрелами
    CastTime = 0.8,          -- натяжение тетивы
    ProjectileId = "arrow",
    ResourceDamage = 0,      -- лук не бьёт ресурсы
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
            }},
        },
    },
}
Copy
Файл: src/shared/config/ProjectileConfig.luau

Copyreturn {
    Projectiles = {
        arrow = {
            Speed = 120,        -- studs/sec
            MaxDistance = 60,
            Gravity = 0,        -- 0 = прямой полёт
            PierceCount = 0,    -- 0 = останавливается при первом попадании
            Lifetime = 3,       -- секунд
            ModelId = "rbxassetid://0",  -- или workspace.Projectiles.Arrow
            TrailColor = Color3.fromRGB(255, 220, 100),
            HitRadius = 2,      -- радиус hitbox
        },
        power_arrow = {
            Speed = 160,
            MaxDistance = 80,
            Gravity = 0,
            PierceCount = 2,    -- пробивает 2 врагов
            Lifetime = 3,
            ModelId = "rbxassetid://0",
            TrailColor = Color3.fromRGB(255, 100, 100),
            HitRadius = 2.5,
        },
        rain_arrow = {
            Speed = 80,
            MaxDistance = 30,
            Gravity = 50,       -- падает вниз
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
Remotes.luau — добавить:

Copy"ProjectileFired",   -- Server → Client: визуализация снаряда
"RangedAttack",      -- Client → Server: запрос ranged-атаки (после каста)
Шаг 9: ProjectileManager.luau (сервер)
Цель: Авторитетный серверный менеджер снарядов.

Файл: src/server/modules/ProjectileManager.luau

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
    --   pierceCount : number? (override)
    -- }
end

-- Вызывается в init() — подключается к Heartbeat
function ProjectileManager.init() end

return ProjectileManager
Внутренняя логика:

fire() создаёт запись в activeProjectiles[] с position, direction, distanceTraveled, hitList
Heartbeat: для каждого снаряда:
Рассчитать newPos = pos + direction * speed * dt + Vector3.new(0, -gravity * dt, 0)
Raycast от pos к newPos (short raycast каждый кадр)
Если hit → DamageCalc.calculate + HealthManager.takeDamage
Если pierceCount > 0 → добавить в hitList, продолжить
Если distanceTraveled > maxDistance или lifetime истёк → удалить
При fire() и remove() → Remotes.ProjectileFired:FireAllClients(...) для визуализации
Не создаёт физических Part'ов на сервере — чисто виртуальная симуляция
Зависимости: DamageCalc, TargetFinder (raycast), HealthManager, StatsManager, Config.Projectiles

Шаг 10: RangedHandler.luau (сервер)
Цель: Обработка ranged-атак с кастом.

Файл: src/server/combat/RangedHandler.luau

API:

Copylocal RangedHandler = {}

function RangedHandler.attack(player, mousePosition, weaponConfig)
    -- 1. Валидация (character, humanoid, IsDead, cooldown)
    -- 2. Запуск каста через CastManager.start({
    --      Duration = weaponConfig.CastTime,
    --      Label = "Натяжение...",
    --      MovementMode = weaponConfig.CastMovementMode or "Slowed",
    --      SpeedMult = weaponConfig.CastSpeedMult or 0.5,
    --      CancelOnDamage = true,
    --      OnComplete = function(player)
    --          -- Получить текущее направление мыши (сохранённое)
    --          -- ProjectileManager.fire(...)
    --      end,
    --      OnCancel = function(player, reason)
    --          -- cooldown не тратится
    --      end,
    --   })
end

return RangedHandler
Важно: mousePosition сохраняется в замыкании OnComplete, но пересчитывается:

Клиент при завершении каста отправляет финальное направление через RangedAttack remote
Или: OnComplete использует character.HumanoidRootPart.CFrame.LookVector как fallback
Cooldown: Применяется только при успешном выстреле (в OnComplete), не при начале каста.

Шаг 11: Клиент — CombatInput рефакторинг
Цель: Разделить melee/ranged ввод.

src/client/combat/MeleeInput.luau — модуль:

Экспортирует start(), stop(), isActive()
Содержит текущий attackLoop, performAttack, playAttackAnimation
Вызывается из CombatInput когда оружие melee
src/client/combat/RangedInput.luau — модуль:

start() — начать прицеливание (визуал crosshair)
stop() — отпустить LMB → отправить AttackRequest с mousePosition
Показывает индикатор дальности
CastBar интеграция: клиент видит полоску натяжения
src/client/combat/CombatInput.client.luau — роутер:

Copylocal function getWeaponType()
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then return nil end
    local cfg = Config.Weapons[tool.Name]
    return cfg and cfg.Type or "Melee"
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local wType = getWeaponType()
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
Шаг 12: ProjectileVisuals.client.luau
Цель: Визуализация полёта снарядов на клиенте.

Файл: src/client/combat/ProjectileVisuals.client.luau

Логика:

Слушает Remotes.ProjectileFired → получает {id, origin, direction, projectileId, speed}
Создаёт Part или модель (из ProjectileConfig.ModelId или fallback sphere)
Добавляет Trail (цвет из конфига)
Heartbeat: двигает визуал по direction * speed * dt
При получении ProjectileHit или ProjectileRemoved → удаляет визуал с эффектом (вспышка)
Важно: Визуал чисто косметический. Авторитетная логика только на сервере.

Шаг 13: Debug команды
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
 1. Создать DamageCalc.luau
 2. Создать TargetFinder.luau
 3. Создать ResourceHit.luau
 4. Создать MeleeHandler.luau
 5. Создать CombatManager.server.luau
 6. Тест: melee-бой работает как раньше (комбо, урон, крит, ресурсы)
 7. Удалить WeaponManager.server.luau
 8. Рефакторинг AbilityManager.luau → DamageCalc + TargetFinder
 9. Тест: способности Q/E работают как раньше
 10. Разбить WeaponConfig.luau на файлы в weapons/
 11. Тест: всё по-прежнему работает
Этап B: Ranged система
 12. Добавить Remotes (ProjectileFired, RangedAttack)
 13. Создать ProjectileConfig.luau
 14. Создать BowConfig.luau
 15. Добавить Bow в WeaponItems.luau
 16. Создать ProjectileManager.luau
 17. Создать RangedHandler.luau
 18. Тест: /bow, экипировать, LMB → каст → стрела летит → урон
Этап C: Клиент
 19. Создать MeleeInput.luau (извлечь из CombatInput)
 20. Создать RangedInput.luau
 21. Рефакторинг CombatInput.client.luau → роутер
 22. Создать ProjectileVisuals.client.luau
 23. Тест: визуал стрелы, каст-бар натяжения
Этап D: Способности и полировка
 24. Добавить тип эффекта "Projectile" в AbilityManager
 25. Добавить тип эффекта "AoEProjectile" в AbilityManager
 26. Тест: Q = мощный выстрел, E = дождь стрел
 27. Debug команды /bow, /weapon
 28. Обновить Architecture.md
 29. Обновить debug_commands.md
 30. Коммит
Зависимости между шагами
DamageCalc (1) ──────┐
TargetFinder (2) ────┤
ResourceHit (3) ─────┼──→ MeleeHandler (4) ──→ CombatManager (5)
                     │
                     ├──→ AbilityManager refactor (8)
                     │
ProjectileConfig (13)┤
BowConfig (14) ──────┼──→ ProjectileManager (16) ──→ RangedHandler (17)
                     │
MeleeInput (19) ─────┤
RangedInput (20) ────┼──→ CombatInput refactor (21)
                     │
                     └──→ ProjectileVisuals (22)
Риски и заметки
Tool система Roblox: Лук должен быть Tool с Handle, как и мечи. Проверить что CombatInput корректно определяет Tool.Name.
CastManager + Ranged: CastTime лука = каст через CastManager. Во время каста нельзя атаковать повторно (CastManager.isActive → return).
Серверный mousePosition: При ranged атаке клиент отправляет mousePosition при завершении каста (не при начале). Нужен отдельный remote или callback.
Cooldown при отмене: Если каст отменён → cooldown НЕ тратится. Cooldown ставится только в OnComplete.
PierceCount: Снаряд ведёт hitList чтобы не бить одну цель дважды.
Gravity: Для rain_arrow (E способность) — стрелы спавнятся сверху и падают в область.
Performance: ProjectileManager.Heartbeat должен обрабатывать ≤50 активных снарядов. Pool при необходимости.