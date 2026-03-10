# Roadmap v1.9 — Procedural World Generation + Castle Building

> Дорожная карта для версии 1.9. Определяет порядок реализации двух крупных систем.

---

## Что реализовывать сначала?

### Вердикт: **Генерация мира — первая. Строительство замка — второе.**

### Обоснование

| Фактор | Генерация мира | Строительство замка |
|---|---|---|
| **Зависимости** | Ни от чего не зависит | Зависит от мира (нужна карта, куда ставить замок) |
| **Влияние на всё** | Меняет спавн врагов, ресурсы, боссов, навигацию | Локальная система, не ломает существующее |
| **Тестирование** | Все остальные системы нужно проверить в новом мире | Можно тестировать на любой карте |
| **Персистентность** | Seed-based, минимальные данные | Большой объём данных (каждый блок) |
| **Блокирует** | Весь контент: новых врагов, биомы, боссов | Только замок-функционал |
| **Сложность** | Высокая (Terrain API, биомы, spawn points) | Средняя (placement, DataStore) |
| **Риск** | Высокий (может потребовать переделку спавна) | Низкий (изолированная система) |

**Вывод**: Генерация мира — это фундамент. Без неё замок некуда ставить, враги спавнятся в пустоте, а биомы не существуют. Замок можно добавить поверх уже готового мира.

---

## Фазы реализации

```
Phase 1: World Core          (2-3 недели)
Phase 2: Biomes & Spawns     (2 недели)
Phase 3: World Persistence   (1 неделя)
Phase 4: Castle Foundation   (2 недели)
Phase 5: Castle Interiors    (1-2 недели)
Phase 6: Integration & Polish (1 неделя)
```

Итого: ~10-12 недель

---

## Phase 1: World Core — Базовая генерация (develop_1.9_phase1)

Цель: при старте сервера создаётся уникальный ландшафт из seed.

### Задачи

| # | Задача | Сложность | Файлы |
|---|---|---|---|
| 1.1 | **WorldConfig.luau** — конфигурация мира | Low | `shared/config/WorldConfig.luau` |
| 1.2 | **WorldSeed** — генерация / загрузка seed | Low | `server/modules/world/WorldSeed.luau` |
| 1.3 | **TerrainGenerator** — Perlin noise + Terrain API | High | `server/modules/world/TerrainGenerator.luau` |
| 1.4 | **ChunkSystem** — разбиение мира на чанки для потокового создания | Medium | `server/modules/world/ChunkSystem.luau` |
| 1.5 | **WorldManager** — оркестратор: seed → генерация → готовность | Medium | `server/modules/world/WorldManager.luau` |
| 1.6 | **Интеграция с Main.server** — ожидание завершения генерации перед спавном | Low | `server/Main.server.luau` |

### WorldConfig — параметры

```lua
return {
    World = {
        MapSize = 1024,        -- studs (сторона квадрата)
        ChunkSize = 64,        -- studs (сторона чанка)
        SeaLevel = 10,         -- высота воды
        MaxHeight = 80,        -- максимальная высота
        TerrainResolution = 4, -- studs на вексель
        GenerationTimeout = 30,-- секунд макс на генерацию

        Noise = {
            Scale = 0.005,     -- масштаб основного шума
            Octaves = 4,       -- количество октав
            Persistence = 0.5, -- затухание
            Lacunarity = 2.0,  -- частотный множитель
        },
    }
}
```

### TerrainGenerator — алгоритм

1. Инициализировать `Random.new(seed)` для воспроизводимости
2. Для каждого чанка (64×64):
   - Вычислить heightmap через Perlin noise (math.noise)
   - Определить материал по высоте: Water → Sand → Grass → Rock → Snow
   - Вызвать `Terrain:FillBlock()` или `Terrain:WriteVoxels()` для заполнения
3. Добавить базовый рельеф: равнины, холмы, утёсы
4. Генерация занимает 5–15 секунд

### Критерии готовности Phase 1

- [ ] Мир генерируется за <15 сек из seed
- [ ] Одинаковый seed = одинаковый мир
- [ ] Ландшафт выглядит естественно (холмы, долины, плоские зоны)
- [ ] Сервер ожидает завершения генерации перед спавном игроков

---

## Phase 2: Biomes & Spawns — Биомы и точки спавна (develop_1.9_phase2)

Цель: мир разбит на биомы с уникальными врагами и ресурсами.

### Задачи

| # | Задача | Сложность | Файлы |
|---|---|---|---|
| 2.1 | **BiomeMap** — карта биомов на основе noise | Medium | `server/modules/world/BiomeMap.luau` |
| 2.2 | **BiomeConfig** — конфигурация биомов | Low | `shared/config/BiomeConfig.luau` |
| 2.3 | **StructureGenerator** — размещение структур (лагеря, руины) | High | `server/modules/world/StructureGenerator.luau` |
| 2.4 | **SpawnPointGenerator** — автоматическое создание spawn points | Medium | `server/modules/world/SpawnPointGenerator.luau` |
| 2.5 | **ResourceNodeGenerator** — размещение ресурсных нод | Medium | `server/modules/world/ResourceNodeGenerator.luau` |
| 2.6 | **Рефакторинг EnemyManager** — спавн из сгенерированных точек | Medium | `server/enemy/EnemyManager.server.luau` |
| 2.7 | **PlayerSpawnPoint** — выбор стартовой позиции | Low | `server/modules/world/PlayerSpawnPoint.luau` |

### BiomeConfig — пример

```lua
return {
    Biomes = {
        DarkForest = {
            Name = "Тёмный лес",
            Temperature = { Min = 0.3, Max = 0.6 },
            Moisture = { Min = 0.5, Max = 1.0 },
            Enemies = { "Wolf", "Warrior" },
            EnemyDensity = 3, -- врагов на чанк
            Resources = { "Tree", "Rock" },
            LevelRange = { 1, 6 },
            Structures = { "camp_small" },
        },
        BloodForest = {
            Name = "Кровавый лес",
            Temperature = { Min = 0.4, Max = 0.7 },
            Moisture = { Min = 0.3, Max = 0.6 },
            Enemies = { "Warrior", "BloodKnight" },
            EnemyDensity = 4,
            Resources = { "BloodTree", "Rock" },
            LevelRange = { 5, 12 },
            BossSpawns = { "BloodWarrior" },
            Structures = { "blood_altar", "camp_medium" },
        },
        Ruins = {
            Name = "Руины",
            Temperature = { Min = 0.1, Max = 0.4 },
            Moisture = { Min = 0.0, Max = 0.3 },
            Enemies = { "Skeleton", "Necromancer" },
            EnemyDensity = 5,
            LevelRange = { 10, 18 },
            BossSpawns = { "SawmillBoss" },
            Structures = { "ruin_tower", "crypt" },
        },
        Swamp = {
            Name = "Болото",
            Temperature = { Min = 0.5, Max = 0.8 },
            Moisture = { Min = 0.8, Max = 1.0 },
            Enemies = { "Toad", "SwampKnight" },
            EnemyDensity = 3,
            LevelRange = { 14, 20 },
            Structures = { "swamp_hut" },
        },
    }
}
```

### Критерии готовности Phase 2

- [ ] 4+ биомов с визуально различным ландшафтом
- [ ] Враги спавнятся в соответствующих биомах
- [ ] Ресурсные ноды размещены по биомам
- [ ] Боссы имеют фиксированные зоны (определяются биомом)
- [ ] Игрок спавнится в безопасной стартовой зоне

---

## Phase 3: World Persistence — Сохранение мира (develop_1.9_phase3)

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
world_{serverId}_buildings → { } -- Phase 4-5
player_{userId}           → { ... existing + worldSpawnPos, homePos }
```

### Лимиты DataStore

| Ограничение | Лимит | Наше использование |
|---|---|---|
| Размер ключа | 4 MB | Meta: ~1 KB, Progress: ~50 KB, Buildings: ~500 KB |
| Запросов/мин | 60 + 10 × players | 4 players = 100 req/min (достаточно) |
| GetAsync throttle | 5 sec / key | Загрузка при старте: OK |

### Критерии готовности Phase 3

- [ ] Seed сохраняется и восстанавливается
- [ ] Прогресс боссов привязан к миру
- [ ] Ресурсные ноды помнят состояние
- [ ] При выходе всех игроков → полное сохранение мира
- [ ] При возвращении → мир восстанавливается за <20 сек

---

## Phase 4: Castle Foundation — Фундамент строительства (develop_1.9_phase4)

Цель: игрок может разместить фундамент замка и строить базовые стены.

### Задачи

| # | Задача | Сложность | Файлы |
|---|---|---|---|
| 4.1 | **BuildingConfig** — типы строительных блоков | Low | `shared/config/BuildingConfig.luau` |
| 4.2 | **BuildingManager** — серверная логика размещения / удаления | High | `server/modules/building/BuildingManager.luau` |
| 4.3 | **BuildingValidator** — проверки: коллизии, грунт, лимиты | Medium | `server/modules/building/BuildingValidator.luau` |
| 4.4 | **BuildingPlacer (client)** — ghost preview, snap-to-grid | High | `client/ui/building/BuildingPlacer.luau` |
| 4.5 | **BuildingUI (client)** — меню строительства | Medium | `client/ui/building/BuildingMenu.client.luau` |
| 4.6 | **CastleBorder** — границы замка (claim area) | Medium | `server/modules/building/CastleBorder.luau` |
| 4.7 | **Remotes** — PlaceBlock, RemoveBlock, GetBuildings | Low | (интеграция с Remotes.luau) |
| 4.8 | **Интеграция с крафтом** — стройматериалы из ресурсов | Low | (интеграция с CraftConfig) |

### BuildingConfig — пример

```lua
return {
    Building = {
        GridSize = 4,          -- studs (snap)
        MaxBlocks = 500,       -- макс блоков на замок
        ClaimRadius = 64,      -- studs (территория замка)
        MaxCastlesPerWorld = 4, -- по одному на игрока

        BlockTypes = {
            stone_foundation = {
                Name = "Каменный фундамент",
                Size = Vector3.new(4, 1, 4),
                Material = Enum.Material.Slate,
                Color = Color3.fromRGB(120, 120, 120),
                HP = 500,
                Cost = { { Id = "stone", Amount = 10 } },
                PlacementRule = "Ground", -- только на землю
            },
            stone_wall = {
                Name = "Каменная стена",
                Size = Vector3.new(4, 4, 1),
                Material = Enum.Material.Slate,
                Color = Color3.fromRGB(140, 140, 140),
                HP = 300,
                Cost = { { Id = "stone", Amount = 8 } },
                PlacementRule = "OnFoundation",
            },
            wooden_floor = {
                Name = "Деревянный пол",
                Size = Vector3.new(4, 0.5, 4),
                Material = Enum.Material.Wood,
                Color = Color3.fromRGB(139, 90, 43),
                HP = 200,
                Cost = { { Id = "wooden_plank", Amount = 4 } },
                PlacementRule = "OnFoundation",
            },
            wooden_roof = {
                Name = "Деревянная крыша",
                Size = Vector3.new(4, 0.5, 4),
                Material = Enum.Material.Wood,
                Color = Color3.fromRGB(100, 60, 30),
                HP = 150,
                Cost = { { Id = "wooden_plank", Amount = 6 } },
                PlacementRule = "OnWall",
            },
        }
    }
}
```

### Snap-to-grid система

Все блоки размещаются на сетке GridSize (4 studs). Клиент показывает ghost-preview с привязкой к сетке. Зелёный = можно ставить, красный = нельзя (коллизия / нет фундамента / вне зоны).

### Критерии готовности Phase 4

- [ ] Игрок может разместить фундамент на ровной поверхности
- [ ] Стены ставятся на фундамент
- [ ] Ghost-preview с snap-to-grid
- [ ] Расход материалов при строительстве
- [ ] Удаление блоков (возврат части материалов)
- [ ] Лимит блоков на замок (500)
- [ ] Сохранение построек в DataStore

---

## Phase 5: Castle Interiors — Интерьер и функционал (develop_1.9_phase5)

Цель: замок имеет функциональные элементы.

### Задачи

| # | Задача | Сложность | Файлы |
|---|---|---|---|
| 5.1 | **Дверь** — открытие/закрытие, доступ для команды | Medium | building/DoorBlock.luau |
| 5.2 | **Сундук** — хранилище предметов (общий для команды) | Medium | building/ChestBlock.luau |
| 5.3 | **Верстак** — крафт-станция (расширенные рецепты) | Medium | building/WorkbenchBlock.luau |
| 5.4 | **Кровавый алтарь** — обработка крови, ритуалы | Medium | building/BloodAltarBlock.luau |
| 5.5 | **Гроб** — точка возрождения (замена стандартного респавна) | Low | building/CoffinBlock.luau |
| 5.6 | **Укрытие от солнца** — крыша защищает от sunlight_exposure | Low | (интеграция с DayNightManager) |

### Критерии готовности Phase 5

- [ ] 5+ функциональных блоков
- [ ] Замок защищает от солнца (крыша → нет дебаффа)
- [ ] Сундук хранит предметы между сессиями
- [ ] Гроб = точка респавна
- [ ] Верстак = расширенный крафт

---

## Phase 6: Integration & Polish (develop_1.9_phase6)

### Задачи

| # | Задача | Сложность |
|---|---|---|
| 6.1 | Баланс биомов, врагов, ресурсов | Medium |
| 6.2 | Оптимизация: streaming чанков, LOD | Medium |
| 6.3 | Миникарта: отображение биомов и замка | Low |
| 6.4 | UI: кнопка строительства (B), категории блоков | Medium |
| 6.5 | Тестирование 4 игрока: production load test | High |
| 6.6 | DataStore stress test: 500 блоков + 100 врагов + 4 игрока | High |

---

## Техническая архитектура (v1.9)

### Новая структура файлов

```
src/
├── shared/
│   └── config/
│       ├── WorldConfig.luau      # Phase 1
│       ├── BiomeConfig.luau      # Phase 2
│       └── BuildingConfig.luau   # Phase 4
├── server/
│   └── modules/
│       ├── world/
│       │   ├── WorldManager.luau         # Phase 1 — оркестратор
│       │   ├── WorldSeed.luau            # Phase 1 — seed управление
│       │   ├── TerrainGenerator.luau     # Phase 1 — Perlin + Terrain API
│       │   ├── ChunkSystem.luau          # Phase 1 — чанки
│       │   ├── BiomeMap.luau             # Phase 2 — карта биомов
│       │   ├── StructureGenerator.luau   # Phase 2 — структуры
│       │   ├── SpawnPointGenerator.luau  # Phase 2 — spawn points
│       │   ├── ResourceNodeGenerator.luau# Phase 2 — ресурсы
│       │   ├── PlayerSpawnPoint.luau     # Phase 2 — стартовая точка
│       │   └── WorldSaveManager.luau     # Phase 3 — персистентность
│       └── building/
│           ├── BuildingManager.luau      # Phase 4 — размещение
│           ├── BuildingValidator.luau    # Phase 4 — валидация
│           └── CastleBorder.luau        # Phase 4 — территория
├── client/
│   └── ui/
│       └── building/
│           ├── BuildingMenu.client.luau  # Phase 4 — UI
│           └── BuildingPlacer.luau       # Phase 4 — ghost preview
```

### Новые EventBus события

| Событие | Аргументы | Фаза |
|---|---|---|
| WorldReady | seed, biomeMap | Phase 1 |
| BiomeEntered | player, biomeId | Phase 2 |
| BlockPlaced | player, blockType, position | Phase 4 |
| BlockRemoved | player, position | Phase 4 |

### Новые Remotes

| Remote | Направление | Фаза |
|---|---|---|
| WorldReady | Server → Client | Phase 1 |
| PlaceBlock | Client → Server | Phase 4 |
| RemoveBlock | Client → Server | Phase 4 |
| GetBuildings | Client → Server (Function) | Phase 4 |

---

## Риски и митигации

| Риск | Вероятность | Импакт | Митигация |
|---|---|---|---|
| Генерация >20 сек | Medium | High | Чанковая генерация, прогресс-бар для игрока |
| DataStore 4 MB лимит | Low | High | Компрессия, хранить только diff от seed |
| 500 блоков = лаг | Medium | Medium | Part count мониторинг, LOD для далёких блоков |
| Биомы выглядят одинаково | Medium | Medium | Разные материалы, props, ambient sounds |
| Враги спавнятся в стенах | High | Low | Raycast проверка при спавне |

---

## Зависимости от текущего кода

| Система | Изменения в v1.9 |
|---|---|
| EnemyManager | Спавн из сгенерированных точек вместо хардкод SpawnPoints |
| EnemySpawner | Без изменений (уже принимает позицию + тип) |
| ResourceManager | Ноды генерируются по биомам |
| DayNightManager | Проверка крыши для sunlight_exposure |
| DataService | Новые ключи: world_meta, world_progress, world_buildings |
| LootManager | Без изменений |
| Main.server | Ожидание WorldReady перед спавном врагов |

---

## Порядок работы (TL;DR)

1. **Phase 1** (Week 1-3): Terrain из seed → играбельный мир
2. **Phase 2** (Week 4-5): Биомы → враги и ресурсы в правильных местах
3. **Phase 3** (Week 6): Сохранение → мир переживает перезапуск
4. **Phase 4** (Week 7-8): Замок → стены и фундамент
5. **Phase 5** (Week 9-10): Интерьер → сундуки, верстак, гроб
6. **Phase 6** (Week 11-12): Полировка → баланс, оптимизация, тесты
