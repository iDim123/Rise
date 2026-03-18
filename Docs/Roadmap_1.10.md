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
| **Ручные объекты** | Видимы | Скрыты (hideManualObjects) | Скрыты (hideManualObjects) |

### Правило: `Mode = "Manual"` — дефолт

При обычной работе в Studio **ничего не меняется**. Открыл Studio, нажал Play —
всё работает как раньше. Генерация включается только явным переключением Mode.

### Скрытие ручных объектов при генерации

При `/worldgen` или `Mode ≠ "Manual"` объекты из Workspace (Trees, Stones, Rigs, Baseplate и т.д.)
автоматически скрываются (`Parent = nil`) чтобы не проглядывали сквозь terrain.
Список управляется в WorldConfig:

```lua
HideOnGenerate = {
    "Baseplate", "Trees", "Stones", "Resources",
    "SpawnPoints", "SpawnLocation", "Camping Area",
    "Containers", "DungeonPack",
},
HidePatterns = { "Rig" },  -- ловит Rig, Rig (2), Rig (3)...
```

При `/worldclear` все скрытые объекты восстанавливаются обратно в Workspace.

---

## Организация ассетов: Templates

Ключевая папка — `ServerStorage/`. Сюда перенесены **шаблоны** моделей,
которые генератор будет клонировать и расставлять по миру.

```
ServerStorage/                       ← уже создано в Studio ✅
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
3. Перемещаешь готовую модель в ServerStorage/<категория>/
4. Прописываешь в BiomeConfig, какие шаблоны где спавнятся
5. Переключаешь Mode = "Generated" → Play → смотришь результат
6. Не нравится → Mode = "Manual" → обратно к ручной сцене
```

**Важно**: оригиналы в Templates **никогда не удаляются**. Генератор только `Clone()`.

---

## Debug-инструменты

### Команды (консоль `~`)

| Команда | Статус | Описание |
|---|---|---|
| `/worldgen` | ✅ Phase 1 | Генерация мира с случайным seed |
| `/worldgen 42` | ✅ Phase 1 | Генерация с конкретным seed |
| `/worldclear` | ✅ Phase 1 | Очистить terrain + восстановить ручные объекты |
| `/worldinfo` | ✅ Phase 0 | Mode, seed, chunks, время генерации |
| `/templates` | ✅ Phase 0 | Проверка папок ServerStorage |
| `/biomemap` | ⏳ Phase 2 | Визуализация карты биомов |
| `/spawnmap` | ⏳ Phase 2 | Маркеры точек спавна |
| `/teleport <biome>` | ⏳ Phase 2 | Телепорт к центру биома |
| `/regenbiome <id>` | ⏳ Phase 2 | Пересоздать объекты биома |

### Горячие клавиши (только Studio)

| Клавиша | Статус | Описание |
|---|---|---|
| **L** | ✅ Phase 1 | Toggle Fly mode + Noclip (WASD + Space/Shift, 80 studs/s) |

### Типичная сессия отладки

```
1. Открыть Studio, Play (Mode = "Manual" — обычная сцена)
2. В чате: /worldgen 42
   → Ручные объекты скрываются (Trees, Stones, Rigs, Baseplate)
   → Terrain генерируется за ~5-15 сек (чанки от центра)
3. L — включить fly + noclip → облетать ландшафт
4. Не нравится высота → поменять Noise.Scale в WorldConfig
5. /worldclear → terrain удалён, ручные объекты восстановлены
6. /worldgen 42 → повторная генерация с новыми параметрами
7. Repeat
```

---

## Фазы реализации

```
Phase 0: Подготовка              (2-3 дня)    ✅ DONE
Phase 1: World Core              (2-3 недели)  ✅ DONE
Phase 2: Biomes & Spawns         (2 недели)    ← NEXT
Phase 3: World Persistence       (1 неделя)
Phase 4: Integration & Polish    (1 неделя)
```

Общее время: **~7-8 недель**.

---

## Phase 0: Подготовка ✅ DONE

Инфраструктура, без влияния на текущий проект.

| # | Задача | Статус | Файлы |
|---|---|---|---|
| 0.1 | WorldConfig.luau — конфиг с Mode, Noise, TemplatePaths | ✅ | `shared/config/WorldConfig.luau` |
| 0.2 | Templates в ServerStorage — папки с копиями моделей | ✅ | ServerStorage (Studio) |
| 0.3 | WorldManager заглушка — skip в Manual | ✅ | `server/modules/world/WorldManager.luau` |
| 0.4 | Интеграция Main.server — WorldManager.init() | ✅ | `server/Main.server.luau` |
| 0.5 | Debug-команды — /worldinfo, /templates | ✅ | `server/debug/DebugCommands.server.luau` |
| 0.6 | Config.luau — WorldConfig авто-загрузка | ✅ | `shared/Config.luau` (итерация children) |

---

## Phase 1: World Core ✅ DONE

Terrain генерируется из seed через `/worldgen`.

| # | Задача | Статус | Файлы |
|---|---|---|---|
| 1.1 | WorldSeed — RNG из seed, offsets для noise | ✅ | `server/modules/world/WorldSeed.luau` |
| 1.2 | TerrainGenerator — 4-octave Perlin, 6 материалов, FillBlock | ✅ | `server/modules/world/TerrainGenerator.luau` |
| 1.3 | ChunkSystem — 16×16 grid, BFS spiral, task.wait() | ✅ | `server/modules/world/ChunkSystem.luau` |
| 1.4 | WorldManager — seed→hide→clear→chunks→generate→ready | ✅ | `server/modules/world/WorldManager.luau` |
| 1.5 | HideManualObjects — скрытие Workspace при генерации | ✅ | WorldManager + WorldConfig.HideOnGenerate |
| 1.6 | Debug /worldgen, /worldclear | ✅ | `server/debug/DebugCommands.server.luau` |
| 1.7 | Fly mode (L) + Noclip | ✅ | `client/debug/DebugKeys.client.luau` |

### Реализованные детали

**TerrainGenerator** — материалы по нормализованной высоте (0–1):

| Слой | MaxHeight | Материал |
|---|---|---|
| Вода | 0.00 | Water |
| Пляж | 0.05 | Sand |
| Равнины | 0.45 | LeafyGrass |
| Холмы | 0.65 | Grass |
| Горы | 0.80 | Rock |
| Вершины | 1.00 | Snow |

**Fly mode** — WASD движение относительно камеры, Space/Shift вверх/вниз.
Noclip: `CanCollide = false` каждый `Stepped` frame (Roblox сбрасывает).
Автосброс при смерти персонажа. Только в Studio.

---

## Phase 2: Biomes & Spawns — СЛЕДУЮЩАЯ ФАЗА

> Цель: мир разбит на биомы с уникальными врагами, ресурсами и декором.
> Срок: **2 недели**.

### Задачи

| # | Задача | Сложность | Файлы | Описание |
|---|---|---|---|---|
| 2.1 | **BiomeConfig** | Low | `shared/config/BiomeConfig.luau` | Конфигурация биомов: температура, влажность, враги, ресурсы, пропсы, уровни |
| 2.2 | **BiomeMap** | Medium | `server/modules/world/BiomeMap.luau` | Двойной noise (temperature + moisture) → biomeId для каждого чанка |
| 2.3 | **PropPlacer** | Medium | `server/modules/world/PropPlacer.luau` | Clone() пропсов из Templates, raycast вниз для Y, плотность из BiomeConfig |
| 2.4 | **SpawnPointGenerator** | Medium | `server/modules/world/SpawnPointGenerator.luau` | Poisson-disc точки спавна врагов с учётом биома и плотности |
| 2.5 | **ResourceNodeGenerator** | Medium | `server/modules/world/ResourceNodeGenerator.luau` | Clone() StoneNode/WoodNode из Templates, расстановка по биомам |
| 2.6 | **StructureGenerator** | High | `server/modules/world/StructureGenerator.luau` | Размещение лагерей, руин и т.д. — расчистка зоны + Clone() из Templates |
| 2.7 | **PlayerSpawnPoint** | Low | `server/modules/world/PlayerSpawnPoint.luau` | Безопасная зона (центр карты), raycast для Y-позиции |
| 2.8 | **WorldManager update** | Medium | `server/modules/world/WorldManager.luau` | Интеграция: seed → terrain → biomes → props → spawns → structures → ready |
| 2.9 | **EnemyManager refactor** | Medium | `server/enemy/EnemyManager.server.luau` | Спавн врагов из сгенерированных SpawnPoints вместо ручных |
| 2.10 | **Debug-команды** | Low | `server/debug/DebugCommands.server.luau` | /biomemap, /spawnmap, /teleport |
| 2.11 | **ObjectCleaner** | Low | `server/modules/world/WorldManager.luau` | Удаление сгенерированных объектов при /worldclear (Folder "_Generated") |

### Порядок реализации

```
Неделя 1:
  День 1-2:  BiomeConfig + BiomeMap (noise → biome assignment)
  День 3:    PropPlacer (деревья, камни по биомам)
  День 4-5:  ResourceNodeGenerator + SpawnPointGenerator

Неделя 2:
  День 1-2:  StructureGenerator + PlayerSpawnPoint
  День 3:    WorldManager интеграция (полный pipeline)
  День 4:    EnemyManager рефакторинг (спавн из точек)
  День 5:    Debug-команды, тестирование, баланс плотностей
```

### BiomeConfig — пример

```lua
return {
    Biomes = {
        DarkForest = {
            Name = "Dark Forest",
            Temperature = { Min = 0.3, Max = 0.6 },
            Moisture    = { Min = 0.5, Max = 1.0 },
            TerrainMaterial = Enum.Material.LeafyGrass,
            Enemies        = { "Wolf", "Warrior" },
            EnemyDensity   = 3,                         -- на чанк
            Resources      = { "WoodNode", "StoneNode" },
            ResourceDensity = 2,
            Props          = { "PineTree", "BeechwoodTree", "Stone" },
            PropDensity    = 5,
            LevelRange     = { 1, 6 },
            BossSpawns     = { "BloodWarrior" },
            Structures     = { "CampingArea" },
        },
        BloodForest = {
            Name = "Blood Forest",
            Temperature = { Min = 0.5, Max = 0.8 },
            Moisture    = { Min = 0.6, Max = 1.0 },
            TerrainMaterial = Enum.Material.Grass,
            Enemies        = { "Warrior" },
            EnemyDensity   = 4,
            Resources      = { "WoodNode" },
            ResourceDensity = 1,
            Props          = { "CedarTree", "RealisticStone" },
            PropDensity    = 4,
            LevelRange     = { 5, 12 },
        },
        Ruins = {
            Name = "Ruins",
            Temperature = { Min = 0.1, Max = 0.4 },
            Moisture    = { Min = 0.0, Max = 0.3 },
            TerrainMaterial = Enum.Material.Slate,
            Enemies        = { "Warrior" },   -- TODO: Skeleton, Necromancer
            EnemyDensity   = 5,
            Resources      = { "StoneNode" },
            ResourceDensity = 3,
            Props          = { "RealisticStone" },
            PropDensity    = 2,
            LevelRange     = { 5, 18 },
            BossSpawns     = {},               -- TODO: LumberjackChief
            Structures     = {},               -- TODO: crypt, blood_altar
        },
    },

    -- Центр карты — безопасная стартовая зона без врагов
    SafeZone = {
        Radius = 64,               -- studs от центра
        Biome = "DarkForest",      -- визуальный стиль
        EnemyDensity = 0,
    },
}
```

### BiomeMap — алгоритм

```
1. Два независимых noise: temperature(x,z) и moisture(x,z)
   (свои Scale и seed-offset, отличные от terrain heightmap)
2. Для каждого чанка (cx, cz):
   a. Сэмплировать temperature и moisture в центре чанка
   b. Найти ближайший BiomeConfig по (temp, moisture) диапазонам
   c. Записать biomeId в BiomeMap[cx][cz]
3. BiomeMap кэшируется — не пересчитывается
4. Граничные чанки: nearest-match (без интерполяции)
```

### PropPlacer — алгоритм

```
1. Для каждого чанка: biome = BiomeMap[cx][cz]
2. count = biome.PropDensity (± randomness)
3. Для каждого пропа:
   a. Случайная позиция (worldX, worldZ) внутри чанка
   b. height = TerrainGenerator.getHeight(worldX, worldZ)
   c. Пропустить если height < SeaLevel (вода)
   d. Случайный шаблон из biome.Props
   e. model = ServerStorage[props][name]:Clone()
   f. model:PivotTo(CFrame.new(worldX, height, worldZ) * randomRotation)
   g. model.Parent = workspace._Generated  (отдельная папка)
```

### Критерии готовности Phase 2

- [ ] 3+ биомов с визуально различным ландшафтом (разные деревья, камни, материалы)
- [ ] Props (деревья, камни) расставлены по биомам из Templates
- [ ] Враги спавнятся в соответствующих биомах (тип + уровень из BiomeConfig)
- [ ] Ресурсные ноды (WoodNode, StoneNode) работают после Clone()
- [ ] Боссы размещены в фиксированных зонах по биому
- [ ] Игрок спавнится в безопасной зоне (центр, без врагов)
- [ ] `/worldclear` убирает все сгенерированные объекты + восстанавливает ручные
- [ ] `/biomemap` визуализирует карту биомов
- [ ] `Mode = "Manual"` — без изменений

---

## Phase 3: World Persistence (1 неделя)

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

---

## Phase 4: Integration & Polish (1 неделя)

Цель: всё работает вместе, баланс, оптимизация.

| # | Задача | Сложность |
|---|---|---|
| 4.1 | Баланс биомов (плотность врагов, уровни, ресурсы) | Medium |
| 4.2 | Chunk streaming — загрузка далёких чанков по мере движения | Medium |
| 4.3 | Minimap — отображение биомов и POI | Low |
| 4.4 | Loading screen — прогресс генерации | Low |
| 4.5 | Нагрузочный тест — 100 врагов, 4 игрока, 500 блоков | Medium |

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

### Файловая структура (реализовано + план)

```
src/
├── shared/
│   └── config/
│       ├── WorldConfig.luau          # ✅ Phase 0 — режимы, noise, HideOnGenerate
│       └── BiomeConfig.luau          # ⏳ Phase 2 — биомы
├── server/
│   ├── modules/
│   │   └── world/
│   │       ├── WorldManager.luau          # ✅ Phase 0+1 — оркестратор + hideManualObjects
│   │       ├── WorldSeed.luau             # ✅ Phase 1   — seed → RNG + offsets
│   │       ├── TerrainGenerator.luau      # ✅ Phase 1   — Perlin noise + FillBlock
│   │       ├── ChunkSystem.luau           # ✅ Phase 1   — BFS spiral, progress
│   │       ├── BiomeMap.luau              # ⏳ Phase 2   — temperature+moisture → biome
│   │       ├── PropPlacer.luau            # ⏳ Phase 2   — деревья, камни из Templates
│   │       ├── SpawnPointGenerator.luau   # ⏳ Phase 2   — Poisson-disc спавн врагов
│   │       ├── ResourceNodeGenerator.luau # ⏳ Phase 2   — ресурсы из Templates
│   │       ├── StructureGenerator.luau    # ⏳ Phase 2   — лагеря, руины
│   │       ├── PlayerSpawnPoint.luau      # ⏳ Phase 2   — безопасная стартовая зона
│   │       └── WorldSaveManager.luau      # ⏳ Phase 3   — DataStore persistence
│   └── debug/
│       └── DebugCommands.server.luau      # ✅ Phase 0+1 — /worldgen, /worldclear, etc.
├── client/
│   ├── debug/
│   │   └── DebugKeys.client.luau          # ✅ Phase 1   — fly (L) + noclip
│   └── ui/
│       └── LoadingScreen.client.luau      # ⏳ Phase 4   — прогресс генерации
```

### Зависимости новых модулей

```
WorldManager
├── Config (WorldConfig)
├── WorldSeed
├── TerrainGenerator
├── ChunkSystem
└── (Phase 2: BiomeMap, PropPlacer, SpawnPointGenerator, ...)

TerrainGenerator
├── Config (WorldConfig.Noise)
└── WorldSeed (offsets)

ChunkSystem
├── Config (WorldConfig.MapSize, ChunkSize)
└── TerrainGenerator

WorldSeed (standalone — math.random + offsets)
```

### Новые EventBus события (план)

| Событие | Аргументы | Фаза |
|---|---|---|
| WorldReady | seed, mode, biomeMap | Phase 2 |
| BiomeEntered | player, biomeId | Phase 2 |
| WorldSaved | timestamp | Phase 3 |

---

## Зависимости от текущего кода

| Система | Изменения в v1.10 | Режим Manual затронут? |
|---|---|---|
| **Main.server** | + WorldManager.init() | Нет (skip в Manual) |
| **DebugCommands** | + /worldgen, /worldclear, /worldinfo, /templates | Только добавление |
| **DebugKeys** | + fly mode (L) + noclip | Только добавление |
| **Config** | + WorldConfig | Авто-загрузка через children |
| **EnemyManager** | ⏳ Phase 2: спавн из сгенерированных точек | Нет |
| **ResourceManager** | ⏳ Phase 2: ноды по биомам | Нет |
| **DataService** | ⏳ Phase 3: новые ключи world_* | Нет |
| **BuildingManager** | Без изменений | Нет |

**Гарантия**: `Mode = "Manual"` = нулевое влияние на существующий код.

---

## Риски и митигации

| Риск | Вероятность | Импакт | Митигация |
|---|---|---|---|
| Генерация >20 сек | Medium | High | Чанковая генерация + прогресс-бар + task.wait() |
| Ручные объекты сквозь terrain | ✅ Решено | — | HideOnGenerate + HidePatterns в WorldConfig |
| Застревание в terrain при fly | ✅ Решено | — | Noclip (CanCollide=false каждый Stepped) |
| DataStore 4 MB лимит | Low | High | Хранить только diff от seed |
| Биомы одинаковые | Medium | Medium | Разные props, материалы, плотности |
| Враги спавнятся в стенах | High | Low | Raycast вниз при спавне |
| Clone() моделей не работает | Medium | High | Проверка в /templates |
| Studio тормозит при генерации | Medium | Medium | task.wait() между чанками |

---

## Порядок работы (TL;DR)

```
Phase 0 (3 дня):    ✅ WorldConfig + WorldManager stub + debug команды
Phase 1 (2-3 нед):  ✅ Terrain из seed + hide objects + fly noclip
Phase 2 (2 нед):    ← Биомы → деревья, камни, враги, ресурсы по зонам
Phase 3 (1 нед):       Сохранение → seed + прогресс в DataStore
Phase 4 (1 нед):       Баланс, chunk streaming, loading screen
```
