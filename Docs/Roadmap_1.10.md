# Roadmap v1.10 — Procedural World Generation 

> Дорожная карта для версии 1.10. Определяет порядок реализации двух крупных систем.

---

## Фазы реализации

```
Phase 1: World Core          (2-3 недели)
Phase 2: Biomes & Spawns     (2 недели)
Phase 3: World Persistence   (1 неделя)
Phase 4: Integration & Polish (1 неделя)
```

---

## Phase 1: World Core — Базовая генерация (develop_1.10_phase1)

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

## Phase 2: Biomes & Spawns — Биомы и точки спавна (develop_1.10_phase2)

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
            BossSpawns = { "BloodWarrior" },
            Structures = { "camp_small" },
        },
        Ruins = {
            Name = "Руины",
            Temperature = { Min = 0.1, Max = 0.4 },
            Moisture = { Min = 0.0, Max = 0.3 },
            Enemies = { "Skeleton", "Necromancer" },
            EnemyDensity = 5,
            LevelRange = { 5, 18 },
            BossSpawns = { "SawmillBoss" },
            Structures = { "blood_altar", "crypt" },
        },
    }
}
```

### Критерии готовности Phase 2

- [ ] 1+ биомов с визуально различным ландшафтом
- [ ] Враги спавнятся в соответствующих биомах
- [ ] Ресурсные ноды размещены по биомам
- [ ] Боссы имеют фиксированные зоны (определяются биомом)
- [ ] Игрок спавнится в безопасной стартовой зоне

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

## Техническая архитектура (v1.10)

### Новая структура файлов

```
src/
├── shared/
│   └── config/
│       ├── WorldConfig.luau   # Phase 1
│       └── BiomeConfig.luau   # Phase 2
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

| Система | Изменения в v1.10 |
|---|---|
| EnemyManager | Спавн из сгенерированных точек вместо хардкод SpawnPoints |
| EnemySpawner | Без изменений (уже принимает позицию + тип) |
| ResourceManager | Ноды генерируются по биомам |
| DataService | Новые ключи: world_meta, world_progress, world_buildings |
| LootManager | Без изменений |
| Main.server | Ожидание WorldReady перед спавном врагов |

---

## Порядок работы (TL;DR)

1. **Phase 1** (Week 1-3): Terrain из seed → играбельный мир
2. **Phase 2** (Week 4-5): Биомы → враги и ресурсы в правильных местах
3. **Phase 3** (Week 6): Сохранение → мир переживает перезапуск
