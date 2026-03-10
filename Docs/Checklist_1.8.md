# Checklist v1.8 — Архитектурный аудит и фиксы

> Полный список выполненных работ в версии 1.8.
> Ветка: `develop_1.8` | PRs: [#1](https://github.com/iDim123/Rise/pull/1), [#2](https://github.com/iDim123/Rise/pull/2)
> Статистика: **42 файла изменено**, +1967 / -285 строк, 2 новых документа, 1 новый модуль

---

## P0 Critical — Защита данных

### ✅ #1 DataService: SetAsync → UpdateAsync + version guard
- **Файл:** `src/server/modules/DataService.luau`
- **Проблема:** `SetAsync` слепо перезаписывал данные. При быстром rejoin один save мог перетереть другой.
- **Решение:** Заменён на `UpdateAsync` с проверкой `data.Version`. Если в DataStore лежит более новая версия — перезапись блокируется (`return nil`).
- **PR:** #1

### ✅ #2 DataService: SAVE_ENABLED по RunService:IsStudio()
- **Файл:** `src/server/modules/DataService.luau`
- **Проблема:** `SAVE_ENABLED = false` по умолчанию. Забыв включить при деплое — все данные терялись.
- **Решение:** `SAVE_ENABLED = not RunService:IsStudio()` — автоматически включается в production, выключается в Studio.
- **PR:** #1

### ✅ #3 BindToClose: race condition → thread tracking + 25s timeout
- **Файл:** `src/server/PlayerLifecycle.server.luau`
- **Проблема:** `task.wait(4)` не гарантировал завершение всех сохранений. С ростом данных (мир, постройки) 4 секунд недостаточно.
- **Решение:** Полная переработка BindToClose:
  - Каждый save запускается через `task.spawn`
  - `BindableEvent` для ожидания завершения всех потоков
  - Таймаут 25 секунд (Roblox даёт макс. 30, оставлено 5 сек запаса)
  - Логирование при таймауте: `warn("[BindToClose] Timeout! N player(s) not saved")`
- **PR:** #1

---

## P1 Serious — Производительность и память

### ✅ #4 HealthManager: instance-key memory leak → GC + cleanup()
- **Файл:** `src/server/modules/HealthManager.luau`
- **Проблема:** `healthData` хранил данные по Instance-ключу. Удалённые entity оставались в таблице навсегда. За 4-часовую сессию — сотни «мёртвых» записей.
- **Решение:**
  - Периодический GC каждые 30 секунд: проверяет `entity.Parent`, удаляет записи разрушенных entity
  - Публичный API `HealthManager.cleanup(entity)` для явного удаления
  - Combat tracking: пометка `lastCombatTime` на атакующем (для HealthRegen)
- **PR:** #1

### ✅ #5 EnemyAI: O(N) tick → activation distance + batch processing
- **Файл:** `src/server/enemy/EnemyAI.server.luau`
- **Проблема:** Все 100 врагов тикали AI каждые 0.2с, даже если игроки на другом конце карты.
- **Решение:**
  - `ACTIVATION_DISTANCE = 100` studs — AI тикает только для врагов в радиусе от игроков
  - `BATCH_SIZE = 20` — за один тик обрабатывается максимум 20 врагов, затем `task.wait()` перед следующей пачкой
  - При 4 игроках и 100 врагах — реально активных ~20-40, остальные спят
- **PR:** #1

### ✅ #6 TargetFinder: O(N) full scan → spatial hash grid
- **Файл:** `src/server/combat/TargetFinder.luau`
- **Проблема:** `inRadius`, `inCone`, `sphereOverlap` перебирали всех врагов и игроков при каждом запросе. При 100 врагах и активных beam/projectile — значительная нагрузка.
- **Решение:** Пространственный хэш-грид:
  - `CELL_SIZE = 50` studs — мир разбит на ячейки 50×50
  - Грид перестраивается каждые `0.2` секунд
  - Запросы читают только ячейки, пересекающие AABB (bounding box) запроса → **O(K)** вместо O(N)
  - `inRadius(30)` при 100 врагах проверяет ~4 ячейки вместо 100+ entity
  - Добавлены `refreshGrid()` и `getGridStats()` для диагностики
  - `raycast()` не затронут (использует engine-level Raycast, грид не нужен)
  - API полностью обратно совместим — те же сигнатуры функций
- **PR:** #2

### ✅ #7 LootManager: cleanup не вызывался → периодический тик
- **Файл:** `src/server/modules/LootManager.luau`
- **Проблема:** Функция `cleanup()` была определена, но нигде не вызывалась. Лут оставался на земле навсегда.
- **Решение:** Добавлен автоматический тик каждые 30 секунд: `task.spawn(function() while true do task.wait(30) LootManager.cleanup() end end)`
- **PR:** #1

### ✅ #8 PlayerRemoving: централизация через EventBus
- **Файл:** `src/server/PlayerLifecycle.server.luau`
- **Проблема:** `Players.PlayerRemoving:Connect()` был разбросан по 8+ файлам без гарантии порядка.
- **Решение:**
  - `PlayerLifecycle` — единственная точка для `PlayerRemoving`
  - Порядок: save → `EventBus.fire("PlayerCleanup", player)` → core cleanup → DataService cleanup
  - Модули подписываются на `PlayerCleanup` вместо `PlayerRemoving` (рекомендуемый паттерн для новых модулей)
  - Вызов `HealthManager.cleanup(character)` при выходе игрока — предотвращает утечку
- **PR:** #1

---

## P2 Medium — Качество кода

### ✅ #9 EventBus: добавлен off() для отписки
- **Файл:** `src/server/modules/EventBus.luau`
- **Проблема:** Невозможно отписаться от события. При cleanup модулей — утечка подписок.
- **Решение:** `EventBus.off(eventName, callback)` — удаляет конкретный callback из массива слушателей.
- **PR:** #1

### ✅ #10 SpellAim: rate-limit remote
- **Файл:** `src/server/modules/SpellCastManager.luau`
- **Проблема:** `SpellAim` remote обрабатывался без ограничения частоты. Клиент мог спамить обновлениями позиции.
- **Решение:** Per-player throttle 50ms (20 обновлений/сек). `lastSpellAimTime[player]` отслеживает последнее время.
- **PR:** #1

### ✅ #11 Main.server: удалена дубль-переменная
- **Файл:** `src/server/Main.server.luau`
- **Проблема:** `local ServerScriptService` был объявлен дважды (строки 1 и 5).
- **Решение:** Удалён дубликат. Скрипт очищен и обновлён.
- **PR:** #1

### ✅ #12 tick() → os.clock(): глобальная замена в 30 файлах
- **Файлы:** 30 серверных файлов (полный список ниже)
- **Проблема:** `tick()` deprecated в Roblox, возвращает wall-clock время с непредсказуемой точностью.
- **Решение:** Массовая замена на `os.clock()` (monotonic, высокая точность). `BuffManager.tick()` — имя метода сохранено.
- **PR:** #2

<details>
<summary>Полный список затронутых файлов (30 шт.)</summary>

| # | Файл |
|---|------|
| 1 | `src/server/Main.server.luau` |
| 2 | `src/server/blood/BloodServer.server.luau` |
| 3 | `src/server/combat/MeleeHandler.luau` |
| 4 | `src/server/combat/ProjectileManager.luau` |
| 5 | `src/server/combat/RangedHandler.luau` |
| 6 | `src/server/enemy/BossAbilities.luau` |
| 7 | `src/server/enemy/BossBehaviors.luau` |
| 8 | `src/server/enemy/EnemyBehaviors.luau` |
| 9 | `src/server/inventory/UseItemHandler.luau` |
| 10 | `src/server/loot/LootServer.server.luau` |
| 11 | `src/server/modules/AbilityManager.luau` |
| 12 | `src/server/modules/BuffManager.luau` |
| 13 | `src/server/modules/CastManager.luau` |
| 14 | `src/server/modules/ContainerManager.luau` |
| 15 | `src/server/modules/DayNightManager.luau` |
| 16 | `src/server/modules/IgniteHandler.luau` |
| 17 | `src/server/modules/LeechHandler.luau` |
| 18 | `src/server/modules/SpellCastManager.luau` |
| 19 | `src/server/modules/StatsManager.luau` |
| 20 | `src/server/modules/boss/BossManager.luau` |
| 21 | `src/server/modules/container/ContainerSpawner.luau` |
| 22 | `src/server/modules/servant/ServantManager.luau` |
| 23 | `src/server/modules/spellEffects/AoEApplyPassiveEffect.luau` |
| 24 | `src/server/modules/spellEffects/BeamEffect.luau` |
| 25 | `src/server/modules/spellEffects/ChannelledProjectileEffect.luau` |
| 26 | `src/server/modules/spellEffects/TargetAreaProjectileEffect.luau` |
| 27 | `src/server/servant/ServantAI.server.luau` |
| 28 | `src/server/servant/ServantServer.server.luau` |
| 29 | `src/server/enemy/EnemyAI.server.luau` |
| 30 | `src/server/PlayerLifecycle.server.luau` |

</details>

### ✅ #13 CharacterUtil: выделен shared модуль валидации
- **Файл:** `src/shared/CharacterUtil.luau` (НОВЫЙ)
- **Проблема:** Одинаковый код валидации (IsDead, Humanoid, HumanoidRootPart) дублировался в 8+ модулях.
- **Решение:** Shared utility модуль `CharacterUtil`:
  - `validate(player)` → `{ character, humanoid, rootPart }` или `nil`
  - `isAlive(entity)` → `boolean` (проверяет IsDead, Humanoid.Health)
  - Используется в TargetFinder, доступен для всех серверных и клиентских модулей
- **PR:** #1

---

## Документация

### ✅ Game_Overview.md — Дизайн-документ игры (НОВЫЙ)
- **Файл:** `Docs/Game_Overview.md`
- **Содержание:**
  - Концепция и формат (Co-op Action RPG, вампирская тематика, Roblox)
  - Сеттинг, цикл дня/ночи, лунные фазы
  - Основной игровой цикл и прогрессия
  - Боевая система (оружие, магия, снаряды, формулы урона)
  - Система крови, слуги, прогрессия персонажа (20 статов)
  - Инвентарь и крафт
  - Враги и боссы (текущие + планируемые)
  - Планы: процедурная генерация, строительство замка
  - Персистентность (DataStore), управление, технические параметры
  - Текущий статус (v1.7 / develop_1.8)
- **PR:** #2

### ✅ Roadmap_1.9.md — Дорожная карта v1.9 (НОВЫЙ)
- **Файл:** `Docs/Roadmap_1.9.md`
- **Содержание:**
  - Анализ: генерация мира **первая**, строительство замка **второе** (с обоснованием)
  - 6 фаз реализации (10-12 недель)
  - Phase 1: World Core — Terrain из seed (Perlin noise, чанки, WorldConfig)
  - Phase 2: Biomes & Spawns — 4+ биомов, SpawnPointGenerator, ResourceNodeGenerator
  - Phase 3: World Persistence — WorldSaveManager, DataStore schema, лимиты
  - Phase 4: Castle Foundation — BuildingManager, snap-to-grid, BuildingValidator
  - Phase 5: Castle Interiors — дверь, сундук, верстак, алтарь, гроб
  - Phase 6: Integration & Polish — баланс, оптимизация, stress-тесты
  - Техническая архитектура: новая структура файлов, EventBus события, Remotes
  - Риски и митигации
  - Зависимости от текущего кода
- **PR:** #2

### ✅ Architecture.md — обновлено
- **Файл:** `Docs/Architecture/Architecture.md`
- **Изменения:**
  - Добавлена запись версии 1.8 с полным перечнем изменений
  - Включены: spatial hash grid, Roadmap 1.9
- **PR:** #2

### ✅ Dependencies.md — обновлено
- **Файл:** `Docs/Architecture/Dependencies.md`
- **Изменения:**
  - TargetFinder: `(standalone)` → `CharacterUtil (+ spatial hash grid, RunService)`
  - PlayerLifecycle: добавлен `EventBus`
  - Main.server: исправлен список зависимостей (полный: StatsManager, DayNightManager, HealthManager, LootManager, EnemySpawner, LevelManager, BuffManager)
- **PR:** #2

### ✅ Systems_Combat.md — обновлено
- **Файл:** `Docs/Architecture/Systems_Combat.md`
- **Изменения:**
  - Таблица модулей: TargetFinder обновлён с пометкой spatial hash
  - Секция TargetFinder переписана: описание грида, CELL_SIZE, O(K), новые методы (refreshGrid, getGridStats)
- **PR:** #2

### ✅ Audit_Architecture.md — обновлено
- **Файл:** `Docs/Architecture/Audit_Architecture.md`
- **Изменения:**
  - Проблема #6 (TargetFinder full scan): статус изменён с **P3 Deferred** на **CLOSED (v1.8)**
  - Таблица P3: обновлена с пометкой закрытия
- **PR:** #2

---

## Сводка по приоритетам

| Приоритет | Всего | Закрыто | Открыто |
|-----------|-------|---------|---------|
| **P0 Critical** | 3 | 3 ✅ | 0 |
| **P1 Serious** | 5 | 5 ✅ | 0 |
| **P2 Medium** | 5 | 5 ✅ | 0 |
| **P3 Deferred** | 4 | 1 ✅ | 3 (не актуально при 1-4 игроках) |
| **Документация** | 6 | 6 ✅ | 0 |
| **Итого** | **23** | **20 ✅** | **3** (deferred) |

---

## Сводка по файлам

### Новые файлы (2)
| Файл | Описание |
|------|----------|
| `src/shared/CharacterUtil.luau` | Shared утилита валидации персонажей |
| `Docs/Game_Overview.md` | Дизайн-документ игры |
| `Docs/Roadmap_1.9.md` | Дорожная карта v1.9 |

### Изменённые серверные модули (33)
| Файл | Что изменено |
|------|-------------|
| `src/server/Main.server.luau` | Удалён дубль переменной, tick()→os.clock() |
| `src/server/PlayerLifecycle.server.luau` | BindToClose переписан (thread tracking + 25s timeout), PlayerCleanup EventBus, HealthManager.cleanup |
| `src/server/modules/DataService.luau` | SetAsync→UpdateAsync + version guard, SAVE_ENABLED auto |
| `src/server/modules/EventBus.luau` | Добавлен off() |
| `src/server/modules/HealthManager.luau` | GC каждые 30с, cleanup() API, combat tracking |
| `src/server/modules/LootManager.luau` | Периодический cleanup каждые 30с, tick()→os.clock() |
| `src/server/modules/SpellCastManager.luau` | SpellAim rate-limit 50ms, tick()→os.clock() |
| `src/server/enemy/EnemyAI.server.luau` | Activation distance 100 studs, batch processing 20/tick |
| `src/server/enemy/EnemyBehaviors.luau` | tick()→os.clock() |
| `src/server/combat/TargetFinder.luau` | Spatial hash grid (полная переработка) |
| + 23 файла | tick()→os.clock() (см. список выше) |

### Изменённая документация (4)
| Файл | Что изменено |
|------|-------------|
| `Docs/Architecture/Architecture.md` | Версия 1.8 добавлена |
| `Docs/Architecture/Dependencies.md` | TargetFinder, PlayerLifecycle, Main обновлены |
| `Docs/Architecture/Systems_Combat.md` | TargetFinder секция переписана |
| `Docs/Architecture/Audit_Architecture.md` | TargetFinder #6 → CLOSED |

---

## Оставшиеся задачи (P2-P3, не входят в v1.8)

| # | Задача | Приоритет | Статус |
|---|--------|-----------|--------|
| 15 | DamageCalc: универсальный для Player и NPC | P2 | Открыто |
| 16 | StatsManager: Player Instance → UserId key | P2 | Открыто |
| 17 | WaitForChild в runtime → lazy require | P2 | Открыто |
| 19 | HP врагов: скалирование по уровню | P2 | Открыто |
| 5 | EnemyAI: O(N) spawn storm | P3 Deferred | Не актуально |
| 7 | Projectile hit каждый кадр | P3 Deferred | Не актуально |
| 10 | FireAllClients overhead | P3 Deferred | Не актуально |

---

## Рекомендации для v1.9

Архитектурные рекомендации из аудита, актуальные для v1.9:

1. **R1. Entity Component System** — централизация данных NPC (HP, состояния, баффы) упростит WorldSave и AI sleep
2. **R2. Typed Config с валидацией** — критично для WorldConfig, BuildingConfig, BiomeConfig
3. **R3. Network Throttler** — единый модуль rate-limit вместо ad-hoc на отдельных remotes
4. **R4. InventoryManager → Data + Logic** — разделение для чистоты при добавлении сундуков (Building система)
5. **R5. Command Pattern** — единый router вместо 50+ OnServerEvent подписок

---

*Документ создан: 2026-03-10 | Ветка: develop_1.8*
