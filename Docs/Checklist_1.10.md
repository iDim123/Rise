# Checklist v1.10 — Procedural World Generation

> Чеклист прогресса. Обновлён: 2026-03-18.
> Справочник: `Docs/Roadmap_1.10.md`

---

## Phase 0: Подготовка ✅ ЗАВЕРШЕНА

- [x] 0.1 WorldConfig.luau — Mode, MapSize, ChunkSize, Noise, TemplatePaths, HideOnGenerate, HidePatterns, Debug
- [x] 0.2 Templates в ServerStorage — 7 папок (enemies, props, structures, resources, bosses, containers, weapons)
- [x] 0.3 WorldManager заглушка — init() skip в Manual mode
- [x] 0.4 Main.server — WorldManager.init() вызов
- [x] 0.5 Debug /worldinfo — Mode, Seed, Ready, Map, Chunks, GenTime
- [x] 0.6 Debug /templates — проверка папок ServerStorage (found/missing)
- [x] 0.7 Config.luau — WorldConfig подхватывается через итерацию children

---

## Phase 1: World Core ✅ ЗАВЕРШЕНА

### Terrain generation

- [x] 1.1 WorldSeed.luau — generateRandom(), setSeed(), getOffsets(), getState()
- [x] 1.2 TerrainGenerator.luau — getHeight() (4-octave Perlin), generateChunk() (FillBlock), clearTerrain()
- [x] 1.3 ChunkSystem.luau — init(), generateAll(), _buildSpiralOrder() (BFS от центра), reset()
- [x] 1.4 WorldManager.luau — generate(seed): seed → hide → clear → chunks → ready
- [x] 1.5 Материалы по высоте: Water → Sand → LeafyGrass → Grass → Rock → Snow

### Скрытие ручных объектов

- [x] 1.6 WorldConfig.HideOnGenerate — Baseplate, Trees, Stones, Resources, SpawnPoints, SpawnLocation, Camping Area, Containers, DungeonPack
- [x] 1.7 WorldConfig.HidePatterns — "Rig" (ловит Rig, Rig (2), Rig (3)...)
- [x] 1.8 WorldManager.hideManualObjects() — Parent = nil, сохранение в hiddenObjects
- [x] 1.9 WorldManager.restoreManualObjects() — восстановление при /worldclear

### Debug & Fly

- [x] 1.10 /worldgen [seed] — генерация terrain в отдельном потоке (task.spawn)
- [x] 1.11 /worldclear — очистка terrain + restore objects
- [x] 1.12 Fly mode (L) — BodyVelocity + BodyGyro, WASD + Space/Shift, 80 studs/s
- [x] 1.13 Noclip при fly — CanCollide=false каждый Stepped, восстановление при stopFly

---

## Phase 2: Biomes & Spawns ⏳ СЛЕДУЮЩАЯ

### Конфигурация биомов

- [ ] 2.1 BiomeConfig.luau — DarkForest, BloodForest, Ruins (температура, влажность, враги, ресурсы, пропсы, уровни)
- [ ] 2.2 BiomeConfig.SafeZone — центр карты, radius 64, без врагов

### Карта биомов

- [ ] 2.3 BiomeMap.luau — два noise (temperature + moisture), назначение biome per chunk
- [ ] 2.4 BiomeMap.getBiome(cx, cz) → biomeId
- [ ] 2.5 BiomeMap.getBiomeAtWorld(x, z) → biomeId

### Расстановка объектов

- [ ] 2.6 PropPlacer.luau — Clone() деревьев/камней из Templates, raycast Y, random rotation
- [ ] 2.7 ResourceNodeGenerator.luau — Clone() WoodNode/StoneNode, расстановка по биомам
- [ ] 2.8 SpawnPointGenerator.luau — Poisson-disc точки спавна, density per biome
- [ ] 2.9 StructureGenerator.luau — лагеря/руины из Templates, расчистка зоны
- [ ] 2.10 PlayerSpawnPoint.luau — безопасная стартовая позиция (центр, raycast Y)

### Интеграция

- [ ] 2.11 WorldManager — pipeline: seed → terrain → biomes → props → spawns → structures → ready
- [ ] 2.12 Папка workspace._Generated для сгенерированных объектов
- [ ] 2.13 /worldclear — удаление _Generated + restore manual objects
- [ ] 2.14 EnemyManager рефакторинг — спавн из сгенерированных SpawnPoints

### Debug

- [ ] 2.15 /biomemap — цветные Part визуализация биомов
- [ ] 2.16 /spawnmap — маркеры точек спавна
- [ ] 2.17 /teleport <biomeId> — телепорт к центру биома

### Критерии

- [ ] 3+ визуально различных биомов (разные деревья, камни, материалы)
- [ ] Props расставлены по биомам, не в воде
- [ ] Враги спавнятся по типу и уровню биома
- [ ] Ресурсные ноды работают после Clone()
- [ ] Игрок спавнится в безопасной зоне
- [ ] Mode = "Manual" — без изменений

---

## Phase 3: World Persistence ⏳

- [ ] 3.1 WorldSaveManager.luau — save/load seed + world state
- [ ] 3.2 DataStore schema — world_{serverId}_meta, world_{serverId}_progress
- [ ] 3.3 Boss progress persistence
- [ ] 3.4 Resource node persistence (собрано/не собрано)
- [ ] 3.5 Server lifecycle — load on start, save on BindToClose

---

## Phase 4: Integration & Polish ⏳

- [ ] 4.1 Баланс биомов (плотности, уровни)
- [ ] 4.2 Chunk streaming (загрузка далёких чанков)
- [ ] 4.3 Minimap — биомы и POI
- [ ] 4.4 Loading screen — прогресс генерации
- [ ] 4.5 Нагрузочный тест

---

## Созданные файлы (Phase 0+1)

| Файл | Фаза | Строк |
|---|---|---|
| `src/shared/config/WorldConfig.luau` | Phase 0 | ~80 |
| `src/server/modules/world/WorldManager.luau` | Phase 0+1 | ~280 |
| `src/server/modules/world/WorldSeed.luau` | Phase 1 | ~60 |
| `src/server/modules/world/TerrainGenerator.luau` | Phase 1 | ~150 |
| `src/server/modules/world/ChunkSystem.luau` | Phase 1 | ~170 |

## Изменённые файлы

| Файл | Изменения |
|---|---|
| `src/server/Main.server.luau` | + require WorldManager, + WorldManager.init() |
| `src/server/debug/DebugCommands.server.luau` | + /worldgen, /worldclear, /worldinfo, /templates |
| `src/client/debug/DebugKeys.client.luau` | + fly mode (L), + noclip (CanCollide=false per Stepped) |
| `Docs/Roadmap_1.10.md` | Полное обновление: Phase 0+1 ✅, Phase 2 план |
| `Docs/Game_Overview.md` | v1.9 castle building, hotkey B, ресурсы |
