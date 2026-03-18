# Roadmap v1.10 — Procedural World Generation

> Дорожная карта для версии 1.10: процедурная генерация мира.
> Обновлено: 2026-03-18.

---

## Принцип: не ломать текущий рабочий процесс

Генерация мира **не уничтожает** ручную сцену в Studio. Вместо этого используется
система **трёх режимов**, которая позволяет переключаться между ручной расстановкой
и процедурной генерацией одной строкой в конфиге.

---

## Три режима мира (WorldConfig.Mode)

```lua
-- src/shared/config/WorldConfig.luau
return {
    World = {
        Mode = "Manual", -- ← переключатель режима

        -- "Manual"    — Studio сцена как есть. Ничего не генерируется.
        --               Используй для работы над моделями, UI, боевой системой.
        --
        -- "Generated" — полная генерация из seed. Terrain + враги + ресурсы.
        --               Studio сцена игнорируется. Для тестирования мира.
        --
        -- "Hybrid"    — Terrain генерируется из seed, но объекты (SpawnPoints,
        --               боссы, ресурсы) берутся из Workspace, если они есть.
        --               Для постепенного перехода от ручной к процедурной расстановке.

        ...
    }
}
```

### Что происходит в каждом режиме

| Элемент | Manual | Hybrid | Generated |
|---|---|---|---|
| **Terrain** | Из Studio (ручной) | Генерируется из seed | Генерируется из seed |
| **SpawnPoints врагов** | Из Workspace (ручные) | Из Workspace, если есть; иначе генерация | Генерация из BiomeConfig |
| **Ресурсные ноды** | Из Workspace (ручные) | Из Workspace, если есть; иначе генерация | Генерация из BiomeConfig |
| **Боссы** | Из Workspace (ручные) | Из Workspace (ручные) | Генерация из BiomeConfig |
| **Структуры (лагеря)** | Из Workspace (ручные) | Из Workspace (ручные) | Клонирование из Templates |
| **Модели врагов** | Из Workspace.Enemies | Клонирование из Templates | Клонирование из Templates |
| **Замки (Building)** | Работает как в v1.9 | Работает как в v1.9 | Работает как в v1.9 |
| **Игрок спавн** | SpawnLocation в Studio | SpawnLocation / генерация | Генерация (безопасная зона) |

### Правило: `Mode = "Manual"` — дефолт

При обычной работе в Studio **ничего не меняется**. Открыл Studio, нажал Play —
всё работает как раньше. Генерация включается только явным переключением Mode.

---

## Организация ассетов: Templates

Ключевая папка — `ServerStorage/Templates/`. Сюда переносятся **шаблоны** моделей,
которые генератор будет клонировать и расставлять по миру.

```
ServerStorage/                       ← уже создано в Studio
├── structures/
│   └── CampingArea                  -- лагерь (Model)
├── resources/
│   ├── StoneNode                    -- камень для добычи
│   └── WoodNode                     -- дерево для рубки
├── props/
│   ├── BeechwoodTree                -- декоративное дерево
│   ├── PineTree                     -- декоративное дерево
│   ├── CedarTree                    -- декоративное дерево
│   ├── Stone                        -- декоративный камень
│   └── RealisticStone               -- декоративный камень (MeshPart)
├── bosses/
│   └── BloodWarrior                 -- босс (Model)
├── containers/
│   ├── locked_chest                 -- запертый сундук
│   └── wooden_chest                 -- деревянный сундук
├── enemies/
│   ├── TrainingDummy                -- манекен
│   ├── Warrior                      -- воин
│   └── Wolf                         -- волк
└── weapons/
    ├── Axe                          -- топор
    ├── Bow                          -- лук
    └── Sword                        -- меч
```

### Рабочий процесс разработчика

```
1. Создаёшь / правишь модель в Workspace (как обычно)
2. Проверяешь в Studio (Mode = "Manual") — всё работает
3. Перемещаешь готовую модель в ServerStorage/Templates/<категория>/
4. Прописываешь в BiomeConfig, какие шаблоны где спавнятся
5. Переключаешь Mode = "Generated" → Play → смотришь результат
6. Не нравится → Mode = "Manual" → обратно к ручной сцене
```

**Важно**: оригиналы в Templates **никогда не удаляются**. Генератор только `Clone()`.

---

## Debug-команды для отладки генерации

В `DebugCommands.server.luau` добавляются команды для тестирования мира
без перезапуска Studio:

```lua
-- Чат-команды (только для разработчиков)

/worldgen              -- сгенерировать мир с случайным seed
/worldgen 12345        -- сгенерировать мир с конкретным seed (воспроизводимость)
/worldclear            -- очистить сгенерированный terrain и объекты
/worldinfo             -- показать текущий seed, режим, количество чанков
/biomemap              -- визуализировать карту биомов (цветные Part на карте)
/biomemap clear        -- убрать визуализацию биомов
/spawnmap              -- показать точки спавна врагов/ресурсов (зелёные/синие маркеры)
/spawnmap clear        -- убрать маркеры
/regenbiome DarkForest -- пересоздать объекты одного биома
/teleport DarkForest   -- телепортировать к центру биома
```

### Типичная сессия отладки

```
1. Открыть Studio, Play (Mode = "Manual" — обычная сцена)
2. В чате: /worldgen 42
   → Terrain очищается и генерируется за ~5-15 сек
   → Враги и ресурсы расставляются по биомам
3. Походить, проверить ландшафт
4. /biomemap → цветные зоны биомов на миникарте
5. /spawnmap → увидеть где спавнятся враги и ресурсы
6. Не нравится высота холмов → поменять Noise.Scale в WorldConfig
7. /worldclear → всё убрано
8. /worldgen 42 → новая генерация с новыми параметрами
9. Repeat
```

---

## Фазы реализации

```
Phase 0: Подготовка              (2-3 дня)    ← НОВАЯ
Phase 1: World Core              (2-3 недели)
Phase 2: Biomes & Spawns         (2 недели)
Phase 3: World Persistence       (1 неделя)
Phase 4: Integration & Polish    (1 неделя)
```

Общее время: **~7-8 недель**.

---

## Phase 0: Подготовка — Templates и режимы (develop_1.10_phase0)

Цель: подготовить инфраструктуру, не ломая текущий проект. После Phase 0 всё
работает как раньше (Mode = "Manual"), но готово к подключению генерации.

### Задачи

| # | Задача | Сложность | Файлы |
|---|---|---|---|
| 0.1 | **WorldConfig.luau** — конфиг с `Mode`, параметрами шума, размерами | Low | `shared/config/WorldConfig.luau` |
| 0.2 | **Templates в ServerStorage** — организовать папки, перенести копии моделей | Low | ServerStorage (в Studio) ✅ ГОТОВО |
| 0.3 | **WorldManager заглушка** — модуль-оркестратор, который в Mode="Manual" ничего не делает | Low | `server/modules/world/WorldManager.luau` |
| 0.4 | **Интеграция Main.server** — вызов WorldManager.init(), безопасный для Manual | Low | `server/Main.server.luau` |
| 0.5 | **Debug-команды** — `/worldgen`, `/worldclear`, `/worldinfo` (базовые) | Medium | `server/debug/DebugCommands.server.luau` |
| 0.6 | **Config.luau** — добавить WorldConfig в реестр | Low | `shared/Config.luau` |

### WorldConfig.luau — полный конфиг

```lua
return {
    World = {
        Mode = "Manual",       -- "Manual" | "Hybrid" | "Generated"

        MapSize = 1024,        -- studs (сторона квадрата)
        ChunkSize = 64,        -- studs (сторона чанка)
        SeaLevel = 10,         -- высота воды
        MaxHeight = 80,        -- максимальная высота
        TerrainResolution = 4, -- studs на воксель
        GenerationTimeout = 30,-- секунд макс на генерацию

        Noise = {
            Scale = 0.005,     -- масштаб основного шума
            Octaves = 4,       -- количество октав
            Persistence = 0.5, -- затухание
            Lacunarity = 2.0,  -- частотный множитель
        },

        -- Папки шаблонов в ServerStorage (уже созданы)
        TemplatePaths = {
            enemies    = "enemies",
            props      = "props",
            structures = "structures",
            resources  = "resources",
            bosses     = "bosses",
            containers = "containers",
            weapons    = "weapons",
        },

        -- Debug (только Studio)
        Debug = {
            ShowBiomeMap = false,    -- цветные зоны при генерации
            ShowSpawnPoints = false, -- маркеры точек спавна
            LogChunkTiming = false,  -- логи времени генерации чанков
        },
    }
}
```

### WorldManager заглушка

```lua
-- server/modules/world/WorldManager.luau
local Config = require(...)

local WorldManager = {}

function WorldManager.init()
    local mode = Config.World.Mode

    if mode == "Manual" then
        print("[WorldManager] Mode = Manual — skipping world generation")
        return
    end

    -- Phase 1: здесь будет вызов генерации
    print("[WorldManager] Mode =", mode, "— generation not yet implemented")
end

function WorldManager.getMode()
    return Config.World.Mode
end

return WorldManager
```

### Критерии готовности Phase 0

- [ ] WorldConfig.luau создан и подключён к Config
- [ ] `Mode = "Manual"` — проект работает как раньше, никаких изменений
- [ ] `Mode = "Generated"` — печатает лог, но ничего не ломает
- [x] Папки Templates/ созданы в ServerStorage (в Studio) ✅
- [ ] Debug-команда `/worldinfo` показывает текущий Mode и seed
- [ ] Нулевое влияние на существующий геймплей

---

## Phase 1: World Core — Базовая генерация (develop_1.10_phase1)

Цель: при `Mode = "Generated"` при старте сервера создаётся уникальный ландшафт из seed.

### Задачи

| # | Задача | Сложность | Файлы |
|---|---|---|---|
| 1.1 | **WorldSeed** — генерация / загрузка seed | Low | `server/modules/world/WorldSeed.luau` |
| 1.2 | **TerrainGenerator** — Perlin noise + Terrain API | High | `server/modules/world/TerrainGenerator.luau` |
| 1.3 | **ChunkSystem** — разбиение мира на чанки для потокового создания | Medium | `server/modules/world/ChunkSystem.luau` |
| 1.4 | **WorldManager** — реализация: seed → генерация → WorldReady | Medium | `server/modules/world/WorldManager.luau` |
| 1.5 | **Main.server** — ожидание WorldReady перед спавном | Low | `server/Main.server.luau` |
| 1.6 | **LoadingScreen** (клиент) — прогресс генерации | Low | `client/ui/LoadingScreen.client.luau` |

### TerrainGenerator — алгоритм

1. Инициализировать `Random.new(seed)` для воспроизводимости
2. Для каждого чанка (64×64):
   - Вычислить heightmap через Perlin noise (`math.noise`)
   - Определить материал по высоте: Water → Sand → Grass → Rock → Snow
   - Вызвать `Terrain:FillBlock()` или `Terrain:WriteVoxels()` для заполнения
3. Добавить базовый рельеф: равнины, холмы, утёсы
4. Генерация занимает 5–15 секунд
5. `task.wait()` между чанками для предотвращения зависания

### Безопасность для Studio

```lua
-- В TerrainGenerator, перед генерацией:
if Config.World.Mode == "Manual" then
    return  -- не трогать ничего
end

-- Очистка ТОЛЬКО сгенерированного terrain (по тегу или папке)
-- НЕ удалять объекты из Workspace напрямую
```

### Критерии готовности Phase 1

- [ ] `Mode = "Manual"` — проект работает без изменений
- [ ] `Mode = "Generated"` — мир генерируется за <15 сек из seed
- [ ] Одинаковый seed = одинаковый мир (детерминизм)
- [ ] Ландшафт выглядит естественно (холмы, долины, плоские зоны)
- [ ] Сервер ожидает завершения генерации перед спавном игроков
- [ ] `/worldgen <seed>` работает в Studio для отладки
- [ ] `/worldclear` возвращает к чистому состоянию

---

## Phase 2: Biomes & Spawns — Биомы и точки спавна (develop_1.10_phase2)

Цель: мир разбит на биомы с уникальными врагами и ресурсами.

### Задачи

| # | Задача | Сложность | Файлы |
|---|---|---|---|
| 2.1 | **BiomeMap** — карта биомов на основе noise (temperature + moisture) | Medium | `server/modules/world/BiomeMap.luau` |
| 2.2 | **BiomeConfig** — конфигурация биомов | Low | `shared/config/BiomeConfig.luau` |
| 2.3 | **StructureGenerator** — клонирование структур из Templates по биомам | High | `server/modules/world/StructureGenerator.luau` |
| 2.4 | **SpawnPointGenerator** — Poisson-disc точки спавна врагов | Medium | `server/modules/world/SpawnPointGenerator.luau` |
| 2.5 | **ResourceNodeGenerator** — клонирование ресурсных нод из Templates | Medium | `server/modules/world/ResourceNodeGenerator.luau` |
| 2.6 | **Рефакторинг EnemyManager** — спавн из сгенерированных точек | Medium | `server/enemy/EnemyManager.server.luau` |
| 2.7 | **PlayerSpawnPoint** — выбор стартовой позиции (безопасная зона) | Low | `server/modules/world/PlayerSpawnPoint.luau` |
| 2.8 | **Debug-команды** — `/biomemap`, `/spawnmap`, `/teleport` | Low | `server/debug/DebugCommands.server.luau` |

### BiomeConfig — пример

```lua
return {
    Biomes = {
        DarkForest = {
            Name = "Dark Forest",
            Temperature = { Min = 0.3, Max = 0.6 },
            Moisture = { Min = 0.5, Max = 1.0 },
            TerrainMaterial = Enum.Material.LeafyGrass,
            Enemies = { "Wolf", "Warrior" },
            EnemyDensity = 3,          -- врагов на чанк
            Resources = { "WoodNode", "StoneNode" },
            ResourceDensity = 2,       -- нод на чанк
            Props = { "PineTree", "BeechwoodTree", "Stone" },
            PropDensity = 5,           -- пропсов на чанк
            LevelRange = { 1, 6 },
            BossSpawns = { "BloodWarrior" },
            Structures = { "CampingArea" },
        },
        BloodForest = {
            Name = "Blood Forest",
            Temperature = { Min = 0.5, Max = 0.8 },
            Moisture = { Min = 0.6, Max = 1.0 },
            TerrainMaterial = Enum.Material.Grass,
            Enemies = { "Warrior" },
            EnemyDensity = 4,
            Resources = { "WoodNode" },
            LevelRange = { 5, 12 },
            Props = { "CedarTree", "RealisticStone" },
        },
        Ruins = {
            Name = "Ruins",
            Temperature = { Min = 0.1, Max = 0.4 },
            Moisture = { Min = 0.0, Max = 0.3 },
            TerrainMaterial = Enum.Material.Slate,
            Enemies = { "Warrior" },   -- TODO: добавить Skeleton, Necromancer
            EnemyDensity = 5,
            LevelRange = { 5, 18 },
            BossSpawns = {},            -- TODO: добавить LumberjackChief
            Structures = {},            -- TODO: добавить crypt, blood_altar
        },
    },

    -- Стартовая зона (центр карты) — безопасная, без врагов
    SafeZone = {
        Radius = 64,               -- studs от центра
        Biome = "DarkForest",      -- визуальный стиль
        EnemyDensity = 0,          -- без врагов
    },
}
```

### Hybrid режим — логика

```lua
-- SpawnPointGenerator / ResourceNodeGenerator
if mode == "Hybrid" then
    -- Сначала проверить: есть ли ручные SpawnPoints в Workspace?
    local manualSpawns = workspace:FindFirstChild("SpawnPoints")
    if manualSpawns and #manualSpawns:GetChildren() > 0 then
        -- Использовать ручные точки
        return collectManualSpawns(manualSpawns)
    end
    -- Нет ручных → генерировать как в Generated
end
```

### Критерии готовности Phase 2

- [ ] `Mode = "Generated"` — 2+ биомов с визуально различным ландшафтом
- [ ] `Mode = "Hybrid"` — ручные SpawnPoints работают поверх сгенерированного terrain
- [ ] Враги спавнятся в соответствующих биомах (тип + уровень)
- [ ] Ресурсные ноды клонируются из Templates и расставлены по биомам
- [ ] Боссы имеют фиксированные зоны
- [ ] Игрок спавнится в безопасной стартовой зоне
- [ ] `/biomemap` визуализирует карту биомов
- [ ] `/spawnmap` показывает точки спавна

---

## Phase 3: World Persistence — Сохранение мира (develop_1.10_phase3)

Цель: мир сохраняется в DataStore и восстанавливается при возвращении игроков.

### Задачи

| # | Задача | Сложность | Файлы |
|---|---|---|---|
| 3.1 | **WorldSaveManager** — сохранение / загрузка состояния мира | High | `server/modules/world/WorldSaveManager.luau` |
| 3.2 | **DataStore schema** — ключи и формат данных мира | Medium | (интеграция с DataService) |
| 3.3 | **Boss progress persistence** — состояние боссов по миру | Low | (интеграция с BossManager) |
| 3.4 | **Resource node persistence** — собранные ресурсы | Medium | (интеграция с ResourceManager) |
| 3.5 | **Server lifecycle** — загрузка при старте, сохранение при выходе всех | Medium | `server/Main.server.luau` |

### DataStore schema

```
world_{serverId}_meta     → { seed, version, createdAt, biomeMap_hash }
world_{serverId}_progress → { bossKills, resourceNodes, discoveredAreas }
world_{serverId}_buildings → { } -- уже реализовано в v1.9 (BuildingSerializer)
player_{userId}           → { ... existing + worldSpawnPos, homePos }
```

### Лимиты DataStore

| Ограничение | Лимит | Наше использование |
|---|---|---|
| Размер ключа | 4 MB | Meta: ~1 KB, Progress: ~50 KB, Buildings: ~500 KB |
| Запросов/мин | 60 + 10 x players | 4 players = 100 req/min (достаточно) |
| GetAsync throttle | 5 sec / key | Загрузка при старте: OK |

### Критерии готовности Phase 3

- [ ] Seed сохраняется и восстанавливается (один seed = один мир навсегда)
- [ ] Прогресс боссов привязан к миру
- [ ] Ресурсные ноды помнят состояние (собрано/не собрано)
- [ ] При выходе всех игроков → полное сохранение мира
- [ ] При возвращении → мир восстанавливается за <20 сек

---

## Phase 4: Integration & Polish (develop_1.10_phase4)

Цель: всё работает вместе, баланс, оптимизация.

### Задачи

| # | Задача | Сложность | Файлы |
|---|---|---|---|
| 4.1 | Баланс биомов (плотность врагов, уровни, ресурсы) | Medium | BiomeConfig |
| 4.2 | Chunk streaming — загрузка далёких чанков по мере движения | Medium | ChunkSystem |
| 4.3 | Minimap — отображение биомов и POI | Low | Minimap.client.luau |
| 4.4 | Loading screen — прогресс генерации | Low | LoadingScreen.client.luau |
| 4.5 | Нагрузочный тест — 100 врагов, 4 игрока, 500 блоков | Medium | — |
| 4.6 | DataStore stress test — сохранение/загрузка с большими данными | Medium | — |

---

## Техническая архитектура (v1.10)

### Новая структура файлов

```
src/
├── shared/
│   └── config/
│       ├── WorldConfig.luau       # Phase 0 — конфиг мира + режимы
│       └── BiomeConfig.luau       # Phase 2 — биомы
├── server/
│   ├── modules/
│   │   └── world/
│   │       ├── WorldManager.luau         # Phase 0/1 — оркестратор
│   │       ├── WorldSeed.luau            # Phase 1   — seed управление
│   │       ├── TerrainGenerator.luau     # Phase 1   — Perlin + Terrain API
│   │       ├── ChunkSystem.luau          # Phase 1   — чанки
│   │       ├── BiomeMap.luau             # Phase 2   — карта биомов
│   │       ├── StructureGenerator.luau   # Phase 2   — структуры из Templates
│   │       ├── SpawnPointGenerator.luau  # Phase 2   — Poisson-disc spawn points
│   │       ├── ResourceNodeGenerator.luau# Phase 2   — ресурсы из Templates
│   │       ├── PlayerSpawnPoint.luau     # Phase 2   — стартовая точка
│   │       └── WorldSaveManager.luau     # Phase 3   — персистентность
│   └── debug/
│       └── DebugCommands.server.luau     # Phase 0   — /worldgen, /worldclear, etc.
├── client/
│   └── ui/
│       └── LoadingScreen.client.luau     # Phase 1   — прогресс генерации
```

### ServerStorage (в Roblox Studio, уже создано ✅)

```
ServerStorage/
├── structures/    -- лагеря, руины           (CampingArea)
├── resources/     -- ресурсные ноды           (StoneNode, WoodNode)
├── props/         -- декоративные объекты     (BeechwoodTree, PineTree, CedarTree, Stone, RealisticStone)
├── bosses/        -- боссы                    (BloodWarrior)
├── containers/    -- сундуки                  (locked_chest, wooden_chest)
├── enemies/       -- враги                    (TrainingDummy, Warrior, Wolf)
└── weapons/       -- оружие                   (Axe, Bow, Sword)
```

**Важно**: папки уже созданы в Studio вручную. Rojo не управляет
ServerStorage — это ассеты (модели, meshes), а не код.

### Новые EventBus события

| Событие | Аргументы | Фаза |
|---|---|---|
| WorldReady | seed, mode, biomeMap | Phase 1 |
| BiomeEntered | player, biomeId | Phase 2 |
| WorldSaved | timestamp | Phase 3 |

### Новые Remotes

| Remote | Направление | Фаза |
|---|---|---|
| WorldReady | Server → Client | Phase 1 |
| WorldGenProgress | Server → Client | Phase 1 (прогресс генерации) |
| BiomeInfo | Server → Client | Phase 2 (текущий биом игрока) |

---

## Зависимости от текущего кода

| Система | Изменения в v1.10 | Режим Manual затронут? |
|---|---|---|
| **Main.server** | Вызов WorldManager.init() | Нет (skip в Manual) |
| **EnemyManager** | Спавн из сгенерированных точек | Нет (без изменений в Manual) |
| **EnemySpawner** | Без изменений (уже принимает позицию + тип) | Нет |
| **ResourceManager** | Ноды генерируются по биомам | Нет (без изменений в Manual) |
| **DataService** | Новые ключи: world_meta, world_progress | Нет (ключи не создаются в Manual) |
| **BuildingManager** | Без изменений (v1.9 работает) | Нет |
| **DebugCommands** | Новые команды /world* | Только добавление |
| **Config** | + WorldConfig | Только добавление |

**Гарантия**: `Mode = "Manual"` = нулевое влияние на существующий код.

---

## Риски и митигации

| Риск | Вероятность | Импакт | Митигация |
|---|---|---|---|
| Генерация >20 сек | Medium | High | Чанковая генерация + прогресс-бар + task.wait() |
| Сломать текущую игру | Low | Critical | Mode = "Manual" дефолт, Phase 0 = заглушки |
| DataStore 4 MB лимит | Low | High | Хранить только diff от seed (terrain не сохраняется) |
| Биомы выглядят одинаково | Medium | Medium | Разные материалы, props из Templates, ambient sounds |
| Враги спавнятся в стенах | High | Low | Raycast вниз при спавне, проверка коллизий |
| Модели не помещаются в terrain | Medium | Low | Raycast для размещения, подгонка Y-позиции |
| Studio тормозит при генерации | Medium | Medium | task.wait() между чанками, отключаемый debug |

---

## Порядок работы (TL;DR)

```
Phase 0 (3 дня):    WorldConfig + заглушка WorldManager + debug команды
                     → Проект работает как раньше. Можно переключать режимы.

Phase 1 (2-3 нед):  Terrain из seed → /worldgen → играбельный ландшафт
                     → Mode = "Generated" создаёт мир. "Manual" не трогает.

Phase 2 (2 нед):    Биомы → враги и ресурсы в правильных местах
                     → Шаблоны из Templates клонируются по BiomeConfig.

Phase 3 (1 нед):    Сохранение → мир переживает перезапуск
                     → Seed + прогресс в DataStore.

Phase 4 (1 нед):    Баланс, chunk streaming, loading screen, тесты
                     → Финальная полировка.
```
