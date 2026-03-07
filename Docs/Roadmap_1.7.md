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


Система дистанционного оружия для игрока и врагов с дальним оружием, новое оружие лук (нужно сразу заложить дальние заклинания для магии)
Интересная система. Уточнения:

Прицеливание — как выглядит? У нас изометрическая камера. Варианты: стреляем в направлении курсора мыши (как в Diablo), или нужен отдельный режим прицеливания? Рекомендую в направлении курсора — консистентно с текущей боевой системой.

Снаряды — физические (летят по траектории, можно увернуться) или hitscan (мгновенное попадание, проверка луча)? Для лука логично физические снаряды, для некоторых заклинаний можно hitscan.

Боеприпасы — лук требует стрелы (расходуемый предмет из инвентаря) или бесконечные стрелы? Если расходуемые — нужен слот для стрел в экипировке (Ammo slot).

Дальность — фиксированная максимальная дальность (снаряд исчезает), или летит пока не столкнётся?

Враги с дальним оружием — стреляют по той же логике (спавнят снаряд), или упрощённо (raycast + задержка)?

Анимация выстрела — нужен ли каст (натяжение тетивы) перед выстрелом? Если да — это ложится на общий CastBar из фазы 2.

Магия — ты упомянул дальние заклинания. Это отдельные от оружия способности (Q/E/Space слоты), или будет магический посох как оружие с LMB-атакой в виде снаряда?

Прицеливание стреляем  направлении курсора мыши (как в Diablo).
Снаряды Для лука физические снаряды / некоторые заклинания  (можно уклонится) , для некоторых заклинаний можно hitscan.
Боеприпасов нету (бесконечные стрелы)
Дальность — фиксированная максимальная дальность / ищезает при столкновении. / некоторые снаряды имеют свойство пробивания 
Враги с дальним оружием — стреляют по той же логике (спавнят снаряд) от которого можно уклонится. Враги тоже могут исполозовать заклинания.
Анимация выстрела  - нужен наст (натяжение тетивы) перед выстрелом
Магия -это отдельная система не завязанная на оружии. Она будет следящей целью я опишу там подробнее
Н ходу стрелаять из лука нельзя (когда происходит каст прицеливания игрок стоит на месте ) Прервать люой каст (анимацию) можно нажав колёсико мышки
Ещё вопросы?