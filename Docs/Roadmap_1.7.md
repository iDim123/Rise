# Roadmap v1.7

## Фаза 1 — Рефакторинг архитектуры ✅

**Цель:** уменьшить связность и размер крупных файлов, улучшить масштабируемость конфигов.

- ItemConfig → `config/ItemConfig.luau` коллектор + `config/items/` (WeaponItems, ArmorItems, AccessoryItems, ConsumableItems, ResourceItems)
- BossManager → `modules/boss/` (BossManager фасад + BossPlayerData + BossInteraction)
- ServantManager → `modules/servant/` (ServantManager + ServantEquipment)
- Обновлены все require-пути (8 файлов)
- Architecture.md обновлён

---

## Фаза 2 — Система контейнеров

**Цель:** интерактивные сундуки/шкафы/контейнеры с лутом, расставленные по миру через SpawnPoints.

### Жизненный цикл контейнера
1. **Спавн:** SpawnPoint с атрибутом `ContainerType` → ContainerManager читает конфиг
2. **Рандомный спавн:** базовый `RespawnTime` ± `RespawnJitter` (±%). `SpawnChance` (0-1) — при неудаче повтор через `RetryInterval`. `Persistent = true` — спавн мгновенно при старте сервера, без рандома
3. **Ожидание:** контейнер стоит на карте, при приближении игрока появляется подсказка "Open [F]"
4. **Каст:** если `CastTime > 0` — показывается CastBar, игрок заморожен (нельзя двигаться, атаковать, использовать способности). Прерывание: движение, Stun, Knockdown. Урон НЕ прерывает
5. **Открытие:** окно контейнера (shared между игроками — содержимое одно, забирают наперегонки). Слоты аналогичны инвентарю. Кнопки "Take All", "Sort"
6. **Auto-close:** если игрок отошёл дальше `InteractRange` — окно закрывается
7. **Despawn:** после первого открытия запускается `DespawnTime` таймер → контейнер исчезает (независимо от содержимого)
8. **Респавн:** возврат к шагу 1-2

### Конфиг
```lua
-- src/shared/config/ContainerConfig.luau
Config.Containers = {
    wooden_chest = {
        Name = "Деревянный сундук",
        Slots = 6,
        CastTime = 0,               -- 0 = мгновенно
        DespawnTime = 60,            -- секунд после первого открытия
        RespawnTime = 300,           -- базовое время респавна
        RespawnJitter = 0.5,         -- ±50% рандом к RespawnTime
        SpawnChance = 0.8,           -- шанс появиться при попытке спавна
        RetryInterval = 60,          -- повтор попытки если SpawnChance не сработал
        InteractRange = 5,
        Persistent = false,          -- рандомный спавн
        LootTable = {
            { ItemId = "health_potion", Chance = 0.7, Amount = { Min = 1, Max = 3 } },
            { ItemId = "rugged_hide",   Chance = 0.5, Amount = { Min = 5, Max = 20 } },
        },
    },
    locked_chest = {
        Name = "Запертый сундук",
        Slots = 8,
        CastTime = 5,               -- 5 секунд каста
        DespawnTime = 90,
        RespawnTime = 600,
        RespawnJitter = 0.3,
        SpawnChance = 0.5,
        RetryInterval = 120,
        InteractRange = 5,
        Persistent = true,           -- стоит с начала сервера, после лута → обычный респавн
        LootTable = {
            { ItemId = "blood_ring",    Chance = 0.1, Amount = { Min = 1, Max = 1 } },
            { ItemId = "health_potion", Chance = 0.9, Amount = { Min = 2, Max = 5 } },
        },
    },
}


Файлы
Действие	Путь	Описание
NEW	src/shared/config/ContainerConfig.luau	Конфиг типов контейнеров
NEW	src/server/modules/ContainerManager.luau	Спавн, лут-генерация, таймеры, состояния (Inactive→Active→Opened→Despawned)
NEW	src/server/container/ContainerServer.server.luau	Remotes: Open, TakeItem, TakeAll, Sort, Close; проверки дистанции/каста
NEW	src/client/ui/ContainerUI.client.luau	Подсказка "Open [F]", окно контейнера, auto-close
NEW	src/client/ui/CastBar.client.luau	Общий модуль каст-бара (переиспользуемый: контейнеры, будущие заклинания)
UPDATE	src/shared/Remotes.luau	+ContainerOpen, ContainerClose, ContainerTakeItem, ContainerTakeAll, ContainerSort, ContainerOpened, ContainerUpdate, ContainerClosed, CastStart, CastCancel
Модели
Шаблоны в ServerStorage/containers/ (wooden_chest, locked_chest и т.д.)
Клонируются в workspace/Containers/ при спавне
Remotes
Имя	Направление	Назначение
ContainerOpen	Client → Server	Запрос открытия (containerId)
ContainerClose	Client → Server	Закрытие окна (containerId)
ContainerTakeItem	Client → Server	Забрать предмет (containerId, slotIndex)
ContainerTakeAll	Client → Server	Забрать всё (containerId)
ContainerSort	Client → Server	Сортировка (containerId)
ContainerOpened	Server → Client	Данные контейнера (containerId, slots, name)
ContainerUpdate	Server → Client	Обновление слотов (containerId, slots) — для всех кто смотрит
ContainerClosed	Server → Client	Контейнер закрыт/исчез
CastStart	Server → Client	Начало каста (castTime, label)
CastCancel	Server → Client	Отмена каста

## Фаза 3 — День/Ночь и лунные циклы

**Цель:** динамическая смена дня и ночи с геймплейным влиянием, лунные фазы с уникальными эффектами.

### Цикл дня/ночи
- Полный цикл: **20 минут** (15 мин ночь + 5 мин день)
- Переходы (рассвет/закат): **30 секунд** каждый — плавная интерполяция Lighting
- Серверное время, синхронизировано для всех игроков
- Управление через Roblox Lighting (ClockTime, Brightness, Ambient, OutdoorAmbient, ColorShift)

### Солнечный дебафф
- Днём все игроки-вампиры получают дебафф "Sunlight Exposure":
  - Наносимый урон ×0.5
  - Получаемый урон ×2.0
- **Укрытие (тень):** вертикальный raycast вверх от персонажа — если есть Part над головой, игрок в тени
  - При входе в тень: дебафф исчезает через **3 секунды**
  - При выходе на солнце: проверка каждую **1 секунду**, дебафф применяется на **3 секунды** (обновляется при каждой проверке)
- Реализация через BuffManager — бафф "sunlight_exposure" с модификаторами DamageDealt и DamageTaken

### Лунные циклы
- Полный лунный цикл: **5 реальных часов** (15 игровых день/ночь циклов)
- Фазы: Новолуние → Растущая → Полнолуние → Убывающая → Новолуние → **Кровавая луна** → повтор
- Кровавая луна наступает **между каждым полным циклом** (после каждого новолуния)

#### Лунные баффы
| Фаза | Эффект |
|---|---|
| Полнолуние | Все вампиры: MoveSpeed +15% |
| Кровавая луна | Все вампиры: PhysicalPower +20%, MagicalPower +20% |
| Новолуние | (без эффектов, или будущие) |
| Растущая/Убывающая | (без эффектов, или будущие) |

- Баффы применяются через BuffManager ко всем игрокам на сервере
- Враги: опционально могут получать свои лунные модификаторы (настраивается в конфиге)

### Конфиг
```lua
-- src/shared/config/DayNightConfig.luau
Config.DayNight = {
    DayDuration = 300,          -- 5 минут (секунды)
    NightDuration = 900,        -- 15 минут
    TransitionTime = 30,        -- рассвет/закат
    SunlightDebuff = {
        BuffId = "sunlight_exposure",
        DamageDealtMult = 0.5,
        DamageTakenMult = 2.0,
        ShelterGracePeriod = 3, -- секунд до снятия в тени
        CheckInterval = 1,      -- частота проверки на солнце
        Duration = 3,           -- длительность дебаффа (обновляется)
    },
    RaycastHeight = 100,        -- высота луча для проверки тени
}

Config.LunarCycle = {
    FullCycleDuration = 18000,
    Phases = {
        { Id = "new_moon",   Duration = 0.15,
          PlayerBuffs = {},
          EnemyBuffs = {},
        },
        { Id = "waxing",     Duration = 0.25,
          PlayerBuffs = {},
          EnemyBuffs = {},
        },
        { Id = "full_moon",  Duration = 0.15,
          PlayerBuffs = {
              { BuffId = "full_moon_speed", Stat = "MoveSpeed", Value = 0.15 },
          },
          EnemyBuffs = {
              { BuffId = "full_moon_enemy_hp", Stat = "MaxHP", Value = 0.10 },
          },
        },
        { Id = "waning",     Duration = 0.25,
          PlayerBuffs = {},
          EnemyBuffs = {},
        },
        { Id = "blood_moon", Duration = 0.20,
          PlayerBuffs = {
              { BuffId = "blood_moon_power", Stat = "PhysicalPower", Value = 0.20 },
              { BuffId = "blood_moon_magic", Stat = "MagicalPower", Value = 0.20 },
          },
          EnemyBuffs = {
              { BuffId = "blood_moon_enemy_dmg", Stat = "Damage", Value = 0.30 },
              { BuffId = "blood_moon_enemy_aggro", Stat = "AggroRange", Value = 0.50 },
          },
        },
    },
}
Copy
Файлы
Действие	Путь	Описание
NEW	src/shared/config/DayNightConfig.luau	Конфиг дня/ночи и лунных циклов
NEW	src/server/modules/DayNightManager.luau	Серверный тик: время суток, Lighting, солнечный дебафф (raycast + BuffManager), лунные фазы
NEW	src/client/ui/DayNightCycle.client.luau	UI полоска цикла с иконкой солнца/луны, индикатор лунной фазы
UPDATE	src/shared/config/BuffConfig.luau	+sunlight_exposure, +full_moon_speed, +blood_moon_power, +blood_moon_magic
UPDATE	src/shared/Remotes.luau	+DayNightSync (Server→Client: timeOfDay, phase, lunarPhase)
UPDATE	src/server/modules/BuffManager.luau	Поддержка серверных баффов без источника-entity (глобальные баффы)
Remotes
Имя	Направление	Назначение
DayNightSync	Server → Client	Синхронизация: timeOfDay (0-1), isDay, lunarPhase, при входе + периодически
Lighting параметры (примерные)
Параметр	День	Ночь	Кровавая луна
ClockTime	14	0	0
Brightness	2	0.2	0.3
Ambient	(180,180,180)	(30,30,50)	(50,20,20)
OutdoorAmbient	(150,150,150)	(20,20,40)	(40,15,15)
FogColor	—	(10,10,20)	(30,10,10)


Фаза 4 — Система дистанционного оружия (Ranged Weapon System)
Концепция
Единая система снарядов (Projectile System) для игроков и врагов. Игрок стреляет в направлении курсора мыши (Diablo-style). Враги с дальним оружием используют ту же логику — спавнят снаряд, от которого можно уклониться. Система закладывает фундамент для магических заклинаний с дальними снарядами.

4.1 — ProjectileConfig (конфигурация снарядов)
Copy-- src/shared/config/ProjectileConfig.luau
Config.Projectiles = {
    arrow = {
        Name = "Стрела",
        Speed = 120,                -- studs/sec
        MaxRange = 60,              -- studs, после чего исчезает
        Gravity = 0,                -- 0 = прямой полёт (без дуги)
        HitboxRadius = 1.5,         -- радиус коллизии
        Pierce = 0,                 -- 0 = уничтожается при первом попадании, 1+ = пробивает N целей
        Model = "arrow_projectile", -- шаблон из ServerStorage/projectiles/
        TrailEnabled = true,
        TrailColor = Color3.fromRGB(255, 255, 200),
    },
    fire_arrow = {
        Name = "Огненная стрела",
        Speed = 100,
        MaxRange = 50,
        Gravity = 0,
        HitboxRadius = 2,
        Pierce = 0,
        Model = "fire_arrow_projectile",
        TrailEnabled = true,
        TrailColor = Color3.fromRGB(255, 100, 20),
        OnHitEffects = {
            { Type = "ApplyDebuff", BuffId = "burning", Duration = 4 },
        },
    },
    enemy_arrow = {
        Name = "Вражеская стрела",
        Speed = 80,
        MaxRange = 40,
        Gravity = 0,
        HitboxRadius = 1.5,
        Pierce = 0,
        Model = "enemy_arrow_projectile",
    },
}
Copy
4.2 — WeaponConfig: новый тип оружия Ranged
Copy-- Дополнение к src/shared/config/WeaponConfig.luau
Bow = {
    WeaponType = "Ranged",          -- NEW: "Melee" (по умолчанию) или "Ranged"
    Damage = 18,
    Range = 60,                     -- максимальная дальность стрельбы
    Cooldown = 1.2,                 -- время между выстрелами
    CastTime = 0.6,                -- натяжение тетивы (каст перед выстрелом)
    ProjectileId = "arrow",         -- ссылка на ProjectileConfig
    ResourceDamage = 0,             -- лук не рубит ресурсы
    Combo = {                       -- у лука одна "комбо"-фаза
        [1] = {
            Damage = 18,
            AnimationId = "rbxassetid://0", -- анимация выстрела
        },
    },
    ComboAbility = {
        Id = "bow_shot",
        Name = "Bow Shot",
        Description = "Single arrow shot.",
        Icon = "rbxassetid://0",
    },
    Abilities = {
        Q = {
            Id = "bow_multishot",
            Name = "Веерный залп",
            Description = "Выпускает 3 стрелы веером.",
            Icon = "rbxassetid://0",
            AnimationId = "rbxassetid://0",
            Cooldown = 10,
            CastTime = 0.8,
            DamageType = "Physical",
            Effects = {{
                Type = "MultiProjectile",
                ProjectileId = "arrow",
                Count = 3,
                SpreadAngle = 30,       -- градусов между крайними стрелами
                DamageMult = 0.7,       -- каждая стрела = 70% урона
            }},
        },
        E = {
            Id = "bow_fire_arrow",
            Name = "Огненная стрела",
            Description = "Мощный выстрел поджигающей стрелой.",
            Icon = "rbxassetid://0",
            AnimationId = "rbxassetid://0",
            Cooldown = 14,
            CastTime = 1.0,
            DamageType = "Physical",
            Effects = {{
                Type = "Projectile",
                ProjectileId = "fire_arrow",
                DamageMult = 1.5,
            }},
        },
    },
},
Copy
4.3 — ProjectileManager (серверный модуль)
Путь: src/server/modules/ProjectileManager.luau

Функционал:

Лук: при нажатии LMB начинается каст (Locked, WalkSpeed=0, 0.6 сек). Игрок стоит на месте и не может двигаться. WASD не прерывает каст и не двигает персонажа. Для отмены натяжения — MMB. После завершения каста: выстрел → снаряд летит к курсору → Cooldown → при зажатом LMB повторный каст автоматически.

ProjectileManager.fire(owner, projectileId, origin, direction, baseDamage, damageType, overrides) — основная функция стрельбы. Работает одинаково для игроков и врагов.
Создаёт серверный Part-снаряд (клонирует из ServerStorage/projectiles/) или создаёт простой Part.
Двигает снаряд каждый Heartbeat (Speed * dt studs).
Проверяет коллизии через workspace:GetPartBoundsInRadius() или Raycast на каждом шаге.
При попадании: вычисляет урон (через общий calcDamage с учётом PhysicalPower/MagicalPower, крита, резистов, LevelModifier), применяет OnHitEffects, вызывает HealthManager.takeDamage().
Pierce > 0: снаряд продолжает лететь после попадания, уменьшая счётчик Pierce; запоминает уже поражённые цели.
Уничтожает снаряд при: достижении MaxRange, столкновении с terrain/static parts, исчерпании Pierce.
Отправляет Remotes.ProjectileSpawned клиентам для визуализации (ID, позиция, направление, скорость) — клиент видит визуал и trail, сервер — авторитетно решает попадание.
4.4 — CastBar интеграция (натяжение тетивы)
Лук имеет CastTime — время натяжения перед выстрелом.
При нажатии LMB: клиент отправляет RangedCastStart, сервер запускает каст (CastBar модуль из фазы 2).
Во время каста: нельзя использовать способности, нельзя атаковать мечом, нельзя использовать предметы.
Каст прерывается: Stun, Knockdown (но НЕ уроном).
По завершении каста: сервер вызывает ProjectileManager.fire(), клиент проигрывает анимацию выстрела.
Зажатый LMB = повторное натяжение после выстрела (автоматическая стрельба с задержкой CastTime + Cooldown).
4.5 — Клиентская часть
Путь: src/client/combat/CombatInput.client.luau (обновление)

Изменения:

Определяет тип оружия (WeaponType): если "Ranged" — другая логика LMB.
Ranged LMB: отправляет RangedCastStart + mousePosition серверу; показывает CastBar на клиенте; по завершении каста — анимация выстрела.
Отображение прицела: при экипированном луке показывает маркер дальности (круг или линию).
Путь: src/client/combat/ProjectileVisuals.client.luau (NEW)

Слушает Remotes.ProjectileSpawned — создаёт визуальную копию снаряда на клиенте (Part + Trail).
Слушает Remotes.ProjectileHit — VFX попадания (частицы).
Слушает Remotes.ProjectileDestroyed — убирает визуал.
Клиент НЕ решает попадания — только визуализация.
4.6 — Враги с дальним оружием
Дополнение к EnemyConfig:

CopyArcher = {
    HP = 60,
    Damage = 12,
    WalkSpeed = 14,
    AggroRange = 35,
    AttackRange = 30,            -- дальность стрельбы
    AttackCooldown = 2.5,
    AttackType = "Ranged",       -- NEW: "Melee" (по умолчанию) или "Ranged"
    ProjectileId = "enemy_arrow",-- снаряд из ProjectileConfig
    CastTime = 0.8,              -- время подготовки к выстрелу
    Level = { Min = 4, Max = 6 },
    BloodType = "Warrior",
    BloodQuality = { Min = 10, Max = 40 },
    CanCapture = true,
    Loot = {
        { ItemId = "wood", Chance = 0.3, Amount = { Min = 1, Max = 5 } },
    },
},
Обновление EnemyBehaviors.luau:

В состоянии ATTACK: если config.AttackType == "Ranged", вместо мгновенного урона — вызывает ProjectileManager.fire(enemy, projectileId, ...) с задержкой CastTime.
Враг стоит во время каста (MoveTo текущую позицию), поворачивается к цели.
После выстрела — обычная логика Cooldown.
Враг с Ranged пытается держать дистанцию: если цель ближе AttackRange * 0.3, отступает назад (kite-AI).
4.7 — Расчёт урона (общий)
Создать общий модуль src/server/modules/DamageCalc.luau:

Извлечь логику расчёта из WeaponManager и AbilityManager в единый модуль.
DamageCalc.calc(attacker, target, baseDamage, damageType) → finalDamage.
Учитывает: PhysicalPower/MagicalPower, Crit, Resistance, LevelModifier, DamageDealt/DamageTaken баффы.
WeaponManager, AbilityManager, ProjectileManager — все используют DamageCalc.calc().
4.8 — Новые Remotes
Remote	Направление	Назначение
RangedCastStart	Client → Server	Начать натяжение лука (mousePosition)
RangedCastCancel	Client → Server	Отмена каста
ProjectileSpawned	Server → Client	Визуализация снаряда (id, pos, dir, speed, model)
ProjectileHit	Server → Client	VFX попадания (pos, targetId)
ProjectileDestroyed	Server → Client	Убрать визуал снаряда (id)
4.9 — Файловая структура
Действие	Путь	Описание
NEW	src/shared/config/ProjectileConfig.luau	Конфигурация всех типов снарядов
NEW	src/server/modules/ProjectileManager.luau	Серверная логика: создание, полёт, коллизии, урон
NEW	src/server/modules/DamageCalc.luau	Общий расчёт урона (извлечён из WeaponManager/AbilityManager)
NEW	src/client/combat/ProjectileVisuals.client.luau	Клиентская визуализация снарядов
UPDATE	src/shared/config/WeaponConfig.luau	+ Bow (WeaponType="Ranged", CastTime, ProjectileId)
UPDATE	src/shared/config/EnemyConfig.luau	+ Archer (AttackType="Ranged", ProjectileId)
UPDATE	src/server/combat/WeaponManager.server.luau	Ветвление Melee/Ranged по WeaponType
UPDATE	src/server/modules/AbilityManager.luau	+ обработка Effect.Type "Projectile" и "MultiProjectile"
UPDATE	src/server/enemy/EnemyBehaviors.luau	+ Ranged AI: стрельба снарядами, кайтинг
UPDATE	src/client/combat/CombatInput.client.luau	+ Ranged LMB логика с CastBar
UPDATE	src/shared/Remotes.luau	+ RangedCastStart, RangedCastCancel, ProjectileSpawned, ProjectileHit, ProjectileDestroyed
ASSETS	ServerStorage/projectiles/	Модели снарядов (arrow, fire_arrow, enemy_arrow)
Ключевые принципы
Server-authoritative: сервер решает все попадания. Клиент отвечает только за визуализацию и ввод.
Единая система: ProjectileManager.fire() используется и игроками, и врагами, и будущими заклинаниями.
DamageCalc: единая точка расчёта урона для всей игры — ближний бой, дальний бой, способности, снаряды врагов.
CastBar: интеграция с общим CastBar из фазы 2 — натяжение тетивы, каст заклинаний, открытие сундуков — всё через один модуль.
Масштабируемость: добавление нового типа снаряда = одна запись в ProjectileConfig. Добавление нового дальнего врага = AttackType="Ranged" + ProjectileId в EnemyConfig.
Фундамент для магии: Effect.Type = "Projectile" / "MultiProjectile" уже позволяет создавать дальние заклинания в AbilityManager. В будущем магическая система будет использовать ProjectileManager.fire() с DamageType = "Magic".

Обновлённая система CastBar — режимы передвижения
Copy-- Режимы каста (CastMovementMode)
CastMovementMode = {
    Locked = "Locked",         -- игрок заморожен, движение невозможно, каст НЕ прерывается движением
    Slowed = "Slowed",         -- игрок замедлен (множитель скорости), каст НЕ прерывается
    Free = "Free",             -- свободное передвижение, каст НЕ прерывается
    CancelOnMove = "CancelOnMove", -- любое движение отменяет каст (текущее поведение сундуков)
}
Примеры применения:

Действие	MovementMode	Отмена	Замедление
Натяжение лука (LMB)	Locked	Средняя кнопка мыши (MMB)	WalkSpeed = 0
Открытие сундука	CancelOnMove	Движение / MMB	—
Будущее заклинание (каст на ходу)	Slowed	MMB / Stun	SpeedMult = 0.4
Мгновенный каст	Free	MMB / Stun	—
Параметры каста в конфиге:

Copy-- WeaponConfig.luau — Bow
Bow = {
    WeaponType = "Ranged",
    CastTime = 0.6,
    CastMovementMode = "Locked",      -- заморозка при натяжении
    CastCancelKey = "MMB",            -- отмена средней кнопкой
    -- ...
}

-- ContainerConfig.luau — сундук
locked_chest = {
    CastTime = 5,
    CastMovementMode = "CancelOnMove", -- движение отменяет каст
    CastCancelKey = "MMB",
    -- ...
}

-- Будущее заклинание
fireball_ability = {
    CastTime = 1.5,
    CastMovementMode = "Slowed",
    CastSpeedMult = 0.4,              -- 40% скорости во время каста
    CastCancelKey = "MMB",
    -- ...
}
Общая структура вызова CastBar:

Copy-- Серверный API
CastBar.startCast(player, {
    Duration = 0.6,
    Label = "Натяжение тетивы",
    MovementMode = "Locked",         -- Locked / Slowed / Free / CancelOnMove
    SpeedMult = 0,                   -- для Slowed режима (0 = полная остановка)
    CancelKey = "MMB",               -- клавиша отмены
    CancelOnStun = true,             -- Stun/Knockdown прерывает
    CancelOnDamage = false,          -- урон НЕ прерывает
    OnComplete = function() ... end,
    OnCancel = function() ... end,
})
Логика режимов на сервере:

Locked — устанавливает WalkSpeed = 0 на время каста, игнорирует попытки движения, каст не прерывается WASD. Отмена только через CancelKey (MMB), Stun, Knockdown.
Slowed — устанавливает WalkSpeed = BaseSpeed × SpeedMult, игрок может двигаться замедленно, каст не прерывается. Отмена через CancelKey, Stun, Knockdown.
Free — скорость не меняется, каст идёт в фоне. Отмена через CancelKey, Stun, Knockdown.
CancelOnMove — если сервер фиксирует перемещение (HumanoidRootPart сдвинулся > порога), каст автоматически отменяется. Также отмена через CancelKey, Stun, Knockdown.
На клиенте:

CombatInput при Locked — не отправляет движение серверу (или сервер игнорирует).
MMB (средняя кнопка мыши) — отправляет CastCancel серверу.
CastBar UI показывает полосу заполнения + название действия.

Фаза 5 — Система магии (Magic / Spellbook System)
Концепция
Магия — отдельная система, не привязанная к оружию. Заклинания открываются через Spell Points, получаемые с боссов (только первое убийство). Каждая школа магии имеет пассивную механику (Leech для Blood, Ignite для Chaos), тировую прогрессию (I → II → III → ULT) и пассивные бонусы за закрытие полного тира. Заклинания экипируются в слоты R, G (обычные) и Z (только ультимативные) через окно Spellbook. Нельзя использовать два одинаковых заклинания одновременно.

5.1 — SpellConfig (конфигурация заклинаний)
Copy-- src/shared/config/SpellConfig.luau

Config.MagicSchools = {
    Blood = {
        Name = "Blood Magic",
        Description = "Магия крови. Контроль жизненной силы врагов...",
        Icon = "rbxassetid://0",
        PassiveName = "Leech",
        PassiveDescription = "Физические атаки восстанавливают 10% урона по целям с Leech. При смерти цели с Leech — лечение 3% от максимального HP.",
        Passive = {
            HealOnHitPercent = 0.10,
            HealOnKillPercent = 0.03,
            Duration = 5,               -- длительность дебаффа Leech
        },
        -- Бонусы за закрытие полных тиров
        TierBonuses = {
            [1] = { Description = "Leech heal on hit: 10% → 12%",   Override = { HealOnHitPercent = 0.12 } },
            [2] = { Description = "Leech heal on kill: 3% → 5%",    Override = { HealOnKillPercent = 0.05 } },
            [3] = { Description = "Leech замедляет врагов на 10%",  Extra = { SlowPercent = 0.10, SlowDuration = 2 } },
        },
        UltTierBonus = { Description = "Leech также снижает урон врага на 5%", Extra = { DamageReduction = 0.05 } },
    },
    Chaos = {
        Name = "Chaos Magic",
        Description = "Магия хаоса. Разрушительная сила огня и пустоты...",
        Icon = "rbxassetid://0",
        PassiveName = "Ignite",
        PassiveDescription = "Поджигает врагов хаос-пламенем: 50% магического урона за 5с. При смерти цели с Ignite — взрыв 50% магического урона.",
        Passive = {
            DotPercent = 0.50,           -- % от spell power за полную длительность
            DotDuration = 5,
            ExplosionDamagePercent = 0.50,
            ExplosionRadius = 1,         -- studs
            ChainIgnite = true,          -- взрыв может наложить Ignite на других
        },
        TierBonuses = {
            [1] = { Description = "Ignite урон +25%",              Override = { DotPercent = 0.625 } },
            [2] = { Description = "Ignite радиус взрыва +50%",     Override = { ExplosionRadius = 1.5 } },
            [3] = { Description = "Ignite взрыв гарантированно накладывает Ignite", Override = { ChainIgnite = true, ChainIgniteGuaranteed = true } },
        },
        UltTierBonus = { Description = "Ignite DoT тикает на 30% быстрее", Override = { DotDuration = 3.5 } },
    },
}

Config.Spells = {
    -- ═══════════ BLOOD SCHOOL ═══════════
    blood_rage = {
        Id = "blood_rage",
        Name = "Blood Rage",
        Description = "Лечит ближайших союзников на 65% spell power и накладывает ускорение: +10% скорости, +25% скорости атаки на 3с. Накладывает Leech на ближайших врагов.",
        Icon = "rbxassetid://0",
        School = "Blood",
        Class = "Basic",                -- "Basic" или "Ultimate"
        Tier = 1,
        UnlockCost = 1,                 -- 1 Spell Point Tier 1
        Tags = { "Area", "Buff" },
        CastTime = 0.1,
        CastMovementMode = "Free",
        Cooldown = 10,
        DamageType = "Magic",
        CanCrit = false,
        Effects = {
            {
                Type = "AoEHeal",
                Radius = 10,
                HealPercent = 0.65,      -- % от spell power
                TargetFilter = "Allies", -- игроки + серванты
            },
            {
                Type = "AoEBuff",
                Radius = 10,
                TargetFilter = "Allies",
                Buffs = {
                    { BuffId = "blood_rage_speed", Stat = "MoveSpeed", Value = 0.10, Duration = 3, Fading = true },
                    { BuffId = "blood_rage_atkspd", Stat = "AttackSpeed", Value = 0.25, Duration = 3, Fading = true },
                },
            },
            {
                Type = "AoEApplyPassive",
                Radius = 10,
                TargetFilter = "Enemies",
                PassiveId = "Leech",
            },
        },
    },

    shadowbolt = {
        Id = "shadowbolt",
        Name = "Shadowbolt",
        Description = "Выпускает снаряд, наносящий 200% магического урона и накладывающий Leech.",
        Icon = "rbxassetid://0",
        School = "Blood",
        Class = "Basic",
        Tier = 2,
        UnlockCost = 1,
        Tags = { "Projectile", "CanCrit" },
        CastTime = 1.0,
        CastMovementMode = "Locked",
        Cooldown = 8,
        DamageType = "Magic",
        CanCrit = true,
        Effects = {
            {
                Type = "Projectile",
                ProjectileId = "shadowbolt",
                DamageMult = 2.0,
                OnHitEffects = {
                    { Type = "ApplyPassive", PassiveId = "Leech" },
                },
            },
        },
    },

    blood_rite = {
        Id = "blood_rite",
        Name = "Blood Rite",
        Description = "Блокирует ближние и дальние атаки 1.5с. При блоке — кровавая нова: отталкивает врагов, 60% маг. урона, Leech. Неуязвимость 1.2с при срабатывании.",
        Icon = "rbxassetid://0",
        School = "Blood",
        Class = "Basic",
        Tier = 3,
        UnlockCost = 1,
        Tags = { "Counter", "Area", "CannotCrit" },
        CastTime = 0.1,
        CastMovementMode = "Slowed",
        CastSpeedMult = 0.5,
        Cooldown = 10,
        DamageType = "Magic",
        CanCrit = false,
        Effects = {
            {
                Type = "Block",
                Duration = 1.5,
                BlockMelee = true,
                BlockProjectile = true,
                MovementMode = "Slowed",
                SpeedMult = 0.5,
                OnBlockTriggered = {
                    {
                        Type = "AoEDamage",
                        DamageMult = 0.60,
                        Radius = 8,
                        Knockback = true,
                        KnockbackForce = 30,
                    },
                    {
                        Type = "AoEApplyPassive",
                        Radius = 8,
                        TargetFilter = "Enemies",
                        PassiveId = "Leech",
                    },
                    {
                        Type = "Immaterial",
                        Duration = 1.2,    -- неуязвимость, нельзя таргетировать
                        CanPassThroughEnemies = false,
                    },
                },
            },
        },
    },

    crimson_beam = {
        Id = "crimson_beam",
        Name = "Crimson Beam",
        Description = "Канал луча энергии: 275% маг. урона + Leech на врагах, лечение союзников 200% spell power/сек, до 3с. Каждая задетая цель лечит кастера на 75% spell power.",
        Icon = "rbxassetid://0",
        School = "Blood",
        Class = "Ultimate",
        Tier = 1,                        -- ULT Tier 1 (отдельная шкала)
        UnlockCost = 1,                  -- 1 Ultimate Point
        Tags = { "Channelling", "Beam", "CannotCrit" },
        CastTime = 0.4,
        CastMovementMode = "Slowed",
        CastSpeedMult = 0.3,
        Cooldown = 120,
        DamageType = "Magic",
        CanCrit = false,
        Effects = {
            {
                Type = "Beam",
                Duration = 3,
                TickRate = 0.2,          -- проверка попаданий каждые 0.2с
                Width = 3,               -- studs ширина луча
                Length = 25,             -- studs длина луча
                FollowCursor = true,     -- луч следует за курсором
                DamageMult = 2.75,       -- за полную длительность
                ChannelMovementMode = "Slowed",
                ChannelSpeedMult = 0.3,
                OnHitEnemy = {
                    { Type = "ApplyPassive", PassiveId = "Leech" },
                    { Type = "HealCaster", HealPercent = 0.75 }, -- % spell power
                },
                OnHitAlly = {
                    { Type = "Heal", HealPercent = 2.00 }, -- % spell power / сек
                },
            },
        },
    },

    -- ═══════════ CHAOS SCHOOL ═══════════
    chaos_volley = {
        Id = "chaos_volley",
        Name = "Chaos Volley",
        Description = "Выпускает 2 хаос-болта последовательно, каждый наносит 125% маг. урона и накладывает Ignite.",
        Icon = "rbxassetid://0",
        School = "Chaos",
        Class = "Basic",
        Tier = 1,
        UnlockCost = 1,
        Tags = { "Channelling", "Projectile", "CanCrit" },
        CastTime = 0.6,
        CastMovementMode = "Slowed",
        CastSpeedMult = 0.6,
        Cooldown = 8,
        DamageType = "Magic",
        CanCrit = true,
        Effects = {
            {
                Type = "MultiProjectile",
                ProjectileId = "chaos_bolt",
                Count = 2,
                Interval = 0.3,           -- секунд между болтами
                DamageMult = 1.25,
                FollowCursor = true,       -- каждый болт летит к текущей позиции курсора
                OnHitEffects = {
                    { Type = "ApplyPassive", PassiveId = "Ignite" },
                },
            },
        },
    },

    void = {
        Id = "void",
        Name = "Void",
        Description = "Призывает сферу, взрывающуюся в указанной точке: 80% маг. урона, Ignite, притягивает врагов к центру.",
        Icon = "rbxassetid://0",
        School = "Chaos",
        Class = "Basic",
        Tier = 2,
        UnlockCost = 1,
        Tags = { "TargetArea", "CanCrit" },
        CastTime = 0.4,
        CastMovementMode = "Free",
        Cooldown = 9,
        Charges = 2,                      -- 2 заряда
        ChargeRechargeTime = 9,           -- каждый заряд восстанавливается независимо
        DamageType = "Magic",
        CanCrit = true,
        Effects = {
            {
                Type = "TargetAreaProjectile",
                ProjectileId = "void_orb",
                Speed = 60,
                DamageMult = 0.80,
                ExplosionRadius = 6,
                OnHitEffects = {
                    { Type = "ApplyPassive", PassiveId = "Ignite" },
                    { Type = "Pull", Duration = 0.5, Force = 40 }, -- притягивание к центру
                },
            },
        },
    },

    chaos_barrier = {
        Id = "chaos_barrier",
        Name = "Chaos Barrier",
        Description = "Блокирует ближние и дальние атаки спереди 2с. Отражает атаки обратно в атакующего. Каждый следующий отражённый снаряд наносит на 30% меньше урона.",
        Icon = "rbxassetid://0",
        School = "Chaos",
        Class = "Basic",
        Tier = 3,
        UnlockCost = 1,
        Tags = { "Defensive", "Channelling", "Projectile", "CannotCrit" },
        CastTime = 0.1,
        CastMovementMode = "Slowed",
        CastSpeedMult = 0.5,
        Cooldown = 11,
        DamageType = "Magic",
        CanCrit = false,
        Effects = {
            {
                Type = "FrontBlock",
                Duration = 2,
                BlockAngle = 120,          -- градусов перед персонажем
                BlockMelee = true,
                BlockProjectile = true,
                MovementMode = "Slowed",
                SpeedMult = 0.5,
                ReflectProjectiles = true,
                ReflectDamageDecay = 0.30, -- -30% за каждое отражение
            },
        },
    },

    chaos_barrage = {
        Id = "chaos_barrage",
        Name = "Chaos Barrage",
        Description = "Выпускает 4 хаос-снаряда: 200% маг. урона при прямом попадании, 100% по области. Ignite.",
        Icon = "rbxassetid://0",
        School = "Chaos",
        Class = "Ultimate",
        Tier = 1,
        UnlockCost = 1,
        Tags = { "Channelling", "CannotCrit" },
        CastTime = 1.0,
        CastMovementMode = "Slowed",
        CastSpeedMult = 0.4,
        Cooldown = 120,
        DamageType = "Magic",
        CanCrit = false,
        Effects = {
            {
                Type = "MultiProjectile",
                ProjectileId = "chaos_barrage_bolt",
                Count = 4,
                Interval = 0.4,
                FollowCursor = true,
                DirectHitDamageMult = 2.0,
                SplashDamageMult = 1.0,
                SplashRadius = 5,
                OnHitEffects = {
                    { Type = "ApplyPassive", PassiveId = "Ignite" },
                },
            },
        },
    },
}
Copy
5.2 — SpellPointConfig (награды с боссов)
Copy-- Дополнение к src/shared/config/BossConfig.luau
BloodWarrior = {
    -- ... существующие поля ...
    SpellPointRewards = {
        { School = "Blood", Tier = 1, Amount = 1 },
    },
},
SawmillBoss = {
    -- ... существующие поля ...
    SpellPointRewards = {
        { School = "Chaos", Tier = 1, Amount = 1 },
        { School = "Blood", Tier = 2, Amount = 1 },
    },
},
-- Будущие боссы могут давать несколько разных поинтов
-- включая Ultimate Points:
-- { School = "Blood", Tier = "Ultimate", Amount = 1 },
5.3 — Spell Points и прогрессия (SpellProgressManager)
Путь: src/server/modules/SpellProgressManager.luau

Хранит и управляет:

Доступные (неиспользованные) Spell Points по школам и тирам: { Blood = { [1] = 2, [2] = 0, [3] = 0, Ultimate = 0 }, Chaos = { ... } }
Список изученных заклинаний: { "blood_rage", "chaos_volley", ... }
Экипированные заклинания: { R = "blood_rage", G = "chaos_volley", Z = nil }
Закрытые тиры (все заклинания тира изучены): автоматически рассчитывается
API:

addSpellPoints(player, school, tier, amount) — добавить поинты (вызывается при убийстве босса)
getSpellPoints(player, school, tier) → number
canLearnSpell(player, spellId) → boolean (есть ли поинт нужного тира)
learnSpell(player, spellId) → boolean (тратит поинт, добавляет в список)
isSpellLearned(player, spellId) → boolean
equipSpell(player, spellId, slot) → boolean (R/G/Z, проверка дубликатов и класса)
unequipSpell(player, slot) → boolean
getEquippedSpells(player) → { R, G, Z }
getLearnedSpells(player) → list
isTierComplete(player, school, tier) → boolean
getTierBonuses(player, school) → active bonuses list
getPassiveStats(player, school) → passive values with tier bonus overrides
getProgressData(player) → full data for UI
save(player) / load(player, data) — сериализация для DataService
5.4 — SpellCastManager (серверный модуль — исполнение заклинаний)
Путь: src/server/modules/SpellCastManager.luau

Обрабатывает кастование и эффекты заклинаний. Вызывается когда игрок нажимает R/G/Z.

API:

castSpell(player, slot, mousePosition) — основная функция
Проверяет: заклинание экипировано, кулдаун, заряды, персонаж жив, не в другом касте
Запускает CastBar с параметрами заклинания (CastTime, CastMovementMode, CastSpeedMult)
По завершении каста — исполняет Effects по типам
Обработчики типов эффектов:

Projectile / MultiProjectile → вызывает ProjectileManager.fire() (из фазы 4)
Beam → создаёт серверный луч, обновляет направление по данным клиента (BeamUpdate remote, ~10 раз/сек), тикает урон/хил по TickRate
AoEDamage → урон в радиусе
AoEHeal → лечение союзников (игроки + серванты) в радиусе
AoEBuff → баффы союзникам через BuffManager
AoEApplyPassive → наложение Leech/Ignite на врагов в радиусе
Block / FrontBlock → состояние блока с таймером, при атаке → триггер OnBlockTriggered
TargetAreaProjectile → снаряд летит к точке курсора, взрывается при достижении
Immaterial → неуязвимость, не таргетируемый
Pull → LinearVelocity к центру на Duration
HealCaster → лечение кастера
Channelling-логика:

Для Beam, MultiProjectile с Interval — заклинание продолжает действовать после каста
Серверный таймер управляет длительностью канала
CastMovementMode применяется на весь канал (не только каст)
5.5 — Пассивные механики (LeechHandler, IgniteHandler)
Путь: src/server/modules/spell/LeechHandler.luau

Слушает HealthManager.takeDamage — если на цели есть Leech и атакующий — игрок с физ. атакой → лечение
Слушает EventBus.EntityDying — если на умершей цели Leech → лечение 3% maxHP кастеру
Учитывает TierBonuses текущего игрока (повышенные % если тиры закрыты)
Путь: src/server/modules/spell/IgniteHandler.luau

Управляет DoT: тик урона каждую секунду в течение DotDuration
При смерти цели с Ignite → взрыв (ExplosionRadius, ExplosionDamagePercent)
ChainIgnite: взрыв накладывает Ignite на задетых врагов
Учитывает TierBonuses
5.6 — Charges-система (для Void и будущих заклинаний)
В SpellCastManager:

Заклинания с Charges > 1 хранят массив таймеров зарядов
При использовании — тратится 1 заряд, запускается отдельный таймер ChargeRechargeTime
Каждый заряд восстанавливается независимо
Если все заряды на КД — заклинание недоступно
UI показывает количество доступных зарядов; если 0 — время до ближайшего восстановления
5.7 — DataService интеграция
Дополнение к шаблону данных в DataService:

Copy-- В defaultData:
Magic = {
    SpellPoints = {
        Blood = { [1] = 0, [2] = 0, [3] = 0, Ultimate = 0 },
        Chaos = { [1] = 0, [2] = 0, [3] = 0, Ultimate = 0 },
    },
    LearnedSpells = {},              -- { "blood_rage", "chaos_volley" }
    EquippedSpells = {               -- слоты R, G, Z
        R = nil,
        G = nil,
        Z = nil,
    },
    ClaimedBossRewards = {},         -- { "BloodWarrior" = true } — защита от повторного получения
},
5.8 — UI: Spellbook Window
Модульная структура (по аналогии с BossJournal):

src/client/ui/spellbook/
├── SpellbookInit.client.luau        -- точка входа, создаёт окно
├── SpellbookWindow.luau             -- основной контейнер (полная высота экрана)
├── SpellbookConstants.luau          -- цвета, размеры, отступы
├── SchoolTabs.luau                  -- табы Blood / Chaos вверху
├── SchoolInfoPanel.luau             -- левая панель: название, описание, пассивка школы
├── TierProgressBar.luau             -- шкала тиров I → II → III → ULT с заполнением
├── SpellGrid.luau                   -- центральная сетка: ряды по тирам, иконки заклинаний
├── SpellSlot.luau                   -- одна ячейка заклинания (иконка, замок, доступность)
├── SpellDetailPanel.luau            -- правая панель: детали выбранного заклинания
├── CurrentSpellsBar.luau            -- нижняя зона: слоты R, G, Z (зеркало AbilitiesBar)
├── SpellDragManager.luau            -- drag & drop из SpellGrid в CurrentSpellsBar
└── SpellLearnOverlay.luau           -- оверлей зажатия ЛКМ 2с для изучения (прогресс-бар)
Окно открывается через MenuBar (иконка "Spellbook") или горячей клавишей. Заголовок окна содержит табы: Map, Bosses, Spellbook (подчёркнут когда активен).

SchoolTabs: Blood | Chaos — переключают содержимое. Добавление новой школы = новый таб.

SchoolInfoPanel (левая часть): описание школы, пассивная механика (Leech / Ignite) с текстом, пассивные бонусы за закрытые тиры (с галочкой если закрыт).

TierProgressBar: горизонтальная шкала с секциями I, II, III, ULT. Каждая секция заполняется пропорционально количеству изученных заклинаний в тире. Полностью заполненная секция подсвечивается.

SpellGrid: ряды тиров. Каждый ряд содержит иконки заклинаний. Неизученные — затемнены с замком (но кликабельны для просмотра описания). Доступные для изучения (есть поинт) — подсвечены рамкой. Изученные — полная яркость.

SpellDetailPanel (правая часть): появляется при клике на заклинание. Показывает: иконку, название, тип (Projectile, Area и т.д.), Cast Time, Cooldown, Charges (если есть), полное описание. Для неизученных — показывает "Требуется: Blood Spell Point Tier 2". Для доступных к изучению — подсказка "Зажмите ЛКМ для изучения".

SpellLearnOverlay: при зажатии ЛКМ на доступном заклинании — круговой прогресс 2 секунды. По завершении — анимация изучения, заклинание разблокируется, тратится Spell Point.

CurrentSpellsBar (низ окна): три слота R, G, Z. Не меняются при переключении школ. Зеркало AbilitiesBar. Drag & drop из SpellGrid сюда. Правый клик — убрать заклинание из слота. Z принимает только Ultimate.

SpellDragManager: перетаскивание изученных заклинаний из сетки в слоты R/G/Z. Валидация: не дублировать, Ultimate только в Z, Basic только в R/G. При успешном drop — отправляет EquipSpell remote серверу.

5.9 — Обновление AbilitiesBar
Текущие слоты: LMB, Q, E, Space. Новые слоты: LMB, Q, E, Space, R, G, Z, X.

LMB — атака оружием (как сейчас)
Q, E — способности оружия (как сейчас)
Space — Dash (будущее: заклинания-дэши)
R — заклинание магии (Basic)
G — заклинание магии (Basic)
Z — заклинание магии (Ultimate only)
X — зарезервировано для классового спелла
Обновить src/client/ui/abilities/AbilitiesBar.luau — добавить 4 новых слота. Для R/G/Z — иконка из экипированного заклинания, кулдаун-оверлей, отображение зарядов.

5.10 — Remotes
Remote	Направление	Назначение
CastSpell	Client → Server	Использовать заклинание (slot: R/G/Z, mousePosition)
LearnSpell	Client → Server	Изучить заклинание (spellId)
EquipSpell	Client → Server	Экипировать заклинание (spellId, slot)
UnequipSpell	Client → Server	Снять заклинание (slot)
SpellCooldown	Server → Client	Кулдаун заклинания (slot, cooldownTime)
SpellChargeUpdate	Server → Client	Обновление зарядов (slot, charges, rechargeTimes)
BeamUpdate	Client → Server	Позиция курсора для Beam (mousePosition, ~10/сек)
BeamVisual	Server → Client	Визуализация луча (casterId, origin, direction, width, length)
SpellEffect	Server → Client	VFX заклинания (spellId, position, targets)
GetSpellProgress	RemoteFunction	Запрос полных данных прогресса магии
SpellProgressUpdate	Server → Client	Обновление прогресса (после изучения/получения поинтов)
5.11 — ProjectileConfig дополнения (для заклинаний)
Copy-- Дополнение к ProjectileConfig.luau
shadowbolt = {
    Name = "Shadowbolt",
    Speed = 90,
    MaxRange = 50,
    HitboxRadius = 2,
    Pierce = 0,
    Model = "shadowbolt_projectile",
    TrailEnabled = true,
    TrailColor = Color3.fromRGB(139, 0, 0),
},
chaos_bolt = {
    Name = "Chaos Bolt",
    Speed = 100,
    MaxRange = 45,
    HitboxRadius = 1.5,
    Pierce = 0,
    Model = "chaos_bolt_projectile",
    TrailEnabled = true,
    TrailColor = Color3.fromRGB(180, 50, 255),
},
void_orb = {
    Name = "Void Orb",
    Speed = 60,
    MaxRange = 40,
    HitboxRadius = 2,
    Pierce = 0,
    Model = "void_orb_projectile",
    DestinationBased = true,     -- летит к точке, не бесконечно
},
chaos_barrage_bolt = {
    Name = "Chaos Barrage Bolt",
    Speed = 80,
    MaxRange = 50,
    HitboxRadius = 2.5,
    Pierce = 0,
    Model = "chaos_barrage_projectile",
    SplashRadius = 5,
    TrailEnabled = true,
    TrailColor = Color3.fromRGB(200, 30, 200),
},
Copy
5.12 — Файловая структура
Действие	Путь	Описание
NEW	src/shared/config/SpellConfig.luau	Школы магии, пассивки, тир-бонусы, все заклинания
NEW	src/server/modules/SpellProgressManager.luau	Spell Points, изучение, экипировка, прогресс
NEW	src/server/modules/SpellCastManager.luau	Кастование, исполнение эффектов, channelling, charges
NEW	src/server/modules/spell/LeechHandler.luau	Пассивка Blood: heal on hit, heal on kill
NEW	src/server/modules/spell/IgniteHandler.luau	Пассивка Chaos: DoT, explosion, chain
NEW	src/client/ui/spellbook/SpellbookInit.client.luau	Точка входа UI
NEW	src/client/ui/spellbook/SpellbookWindow.luau	Основной контейнер
NEW	src/client/ui/spellbook/SpellbookConstants.luau	UI константы
NEW	src/client/ui/spellbook/SchoolTabs.luau	Табы школ
NEW	src/client/ui/spellbook/SchoolInfoPanel.luau	Левая панель — описание школы
NEW	src/client/ui/spellbook/TierProgressBar.luau	Шкала прогресса тиров
NEW	src/client/ui/spellbook/SpellGrid.luau	Сетка заклинаний по тирам
NEW	src/client/ui/spellbook/SpellSlot.luau	Ячейка одного заклинания
NEW	src/client/ui/spellbook/SpellDetailPanel.luau	Правая панель — детали
NEW	src/client/ui/spellbook/CurrentSpellsBar.luau	Нижние слоты R, G, Z
NEW	src/client/ui/spellbook/SpellDragManager.luau	Drag & drop
NEW	src/client/ui/spellbook/SpellLearnOverlay.luau	Оверлей изучения (2с зажатие)
UPDATE	src/shared/config/BossConfig.luau	+ SpellPointRewards для каждого босса
UPDATE	src/shared/config/ProjectileConfig.luau	+ shadowbolt, chaos_bolt, void_orb и т.д.
UPDATE	src/server/modules/boss/BossInteraction.luau	+ начисление Spell Points при первом убийстве
UPDATE	src/server/modules/DataService.luau	+ Magic в defaultData и сериализация
UPDATE	src/server/modules/HealthManager.luau	+ хуки для Leech/Ignite проверок
UPDATE	src/client/ui/abilities/AbilitiesBar.luau	+ слоты R, G, Z, X
UPDATE	src/client/ui/MenuBar.luau	+ иконка Spellbook
UPDATE	src/shared/Remotes.luau	+ все новые remotes
ASSETS	ServerStorage/projectiles/	+ модели shadowbolt, chaos_bolt, void_orb и т.д.
Ключевые принципы
Server-authoritative: все расчёты урона, хила, эффектов — на сервере. Клиент только визуализация и ввод.
Единая система снарядов: заклинания-проджектайлы используют ProjectileManager.fire() из фазы 4.
CastBar интеграция: каждое заклинание настраивает CastMovementMode индивидуально.
Модульный UI: 12 файлов Spellbook — каждый компонент отдельно, легко расширять.
Масштабируемость: добавление новой школы = записи в SpellConfig + новый таб в UI. Добавление заклинания = запись в Config.Spells.
Пассивки как отдельные handler-модули: LeechHandler и IgniteHandler подключаются к EventBus и HealthManager, не загрязняя основной код.
