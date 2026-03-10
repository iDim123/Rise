# Rise — Architectural Audit Report

> Полный аудит архитектуры проекта. Выявленные слабые места, рекомендации по исправлению.
> Дата: 2026-03-10 | Ветка: `develop_1.8`

---

## Контекст проекта

| Параметр | Значение |
|----------|---------|
| Жанр | Action RPG, вампирская тематика (аналог V Rising) |
| Режим | Кооп 1-4 игрока, без PVP |
| Сервер | Roblox Cloud (Private Server), self-hosted не требуется |
| Врагов на карте | До 100 одновременно |
| Типы врагов | До 100 типов, 20+ боссов |
| Мир | Процедурная генерация по seed (аналог Valheim) |
| Ландшафт | Не изменяемый игроками |
| Строительство | База/замок (аналог V Rising) — ближайший план |
| Упор | Взаимодействие со слугами |
| Persistence | Полное сохранение мира между сессиями |

### Влияние на архитектуру

Кооп 1-4 игрока **радикально снижает** требования к сетевой производительности:
- `FireAllClients` на 4 клиента — не проблема
- TargetFinder перебор 100 врагов + 4 игрока — мгновенно
- EnemyAI на 100 врагов с тиком 0.2с = 500 task.spawn/сек — нормально

**Критичными становятся** другие вещи:
- Сохранение/загрузка мира (World Persistence) — core архитектурная задача
- Процедурная генерация — новая система с нуля
- Строительство — сериализация построек в DataStore
- Долгие игровые сессии — утечки памяти, лут на земле, etc.

---

## Сводная таблица (приоритеты с учётом контекста)

| # | Проблема | Приоритет | Сложность | Файлы |
|---|---------|-----------|-----------|-------|
| 1 | SetAsync вместо UpdateAsync | **P0 Critical** | Низкая | DataService |
| 2 | SAVE_ENABLED = false | **P0 Critical** | Низкая | DataService |
| 3 | BindToClose race condition | **P0 Critical** | Средняя | PlayerLifecycle |
| NEW | World Persistence система | **P0 Critical** | Высокая | Новая система |
| NEW | Процедурная генерация мира | **P0 Critical** | Высокая | Новая система |
| 8 | PlayerRemoving разброс | **P1 Serious** | Средняя | 8 файлов |
| 13 | LootManager.cleanup не вызывается | **P1 Serious** | Низкая | LootManager, Main |
| NEW | Building система | **P1 Serious** | Высокая | Новая система |
| NEW | AI activation distance (sleep) | **P1 Serious** | Средняя | EnemyAI |
| 4 | Instance-key memory leak | **P2 Medium** | Средняя | HealthManager, BuffManager, EnemyStateManager |
| 9 | Дублирование валидации | **P2 Medium** | Низкая | 8+ файлов |
| 11 | EventBus без off() | **P2 Medium** | Низкая | EventBus |
| 12 | tick() deprecated | **P2 Medium** | Низкая | 20+ файлов |
| 14 | Дубль переменной | **P2 Low** | Низкая | Main |
| 15 | DamageCalc только для Player | **P2 Medium** | Средняя | DamageCalc, EnemyBehaviors |
| 16 | Instance-key в StatsManager | **P2 Medium** | Низкая | StatsManager |
| 17 | WaitForChild в runtime | **P2 Medium** | Низкая | HealthManager, CastManager |
| 18 | Нет rate-limit SpellAim | **P2 Low** | Низкая | SpellCastManager |
| 19 | HP врагов не скалируется | **P2 Medium** | Низкая | EnemySpawner |
| 5 | EnemyAI O(N) spawn storm | **P3 Deferred** | Средняя | EnemyAI |
| 6 | TargetFinder full scan | **CLOSED (v1.8)** | Высокая | TargetFinder — spatial hash grid |
| 7 | Projectile hit каждый кадр | **P3 Deferred** | Средняя | ProjectileManager |
| 10 | FireAllClients overhead | **P3 Deferred** | Средняя | HealthManager, ProjectileManager |

> **P3 Deferred** = при 1-4 игроках и до 100 врагах проблемы нет. Пересмотреть если масштаб изменится.

---

## P0 CRITICAL — Существующий код

### 1. DataService: `SetAsync` без `UpdateAsync` — риск потери данных

**Файл:** `src/server/modules/DataService.luau:330`

```lua
dataStore:SetAsync(key, data)
```

**Проблема:** `SetAsync` слепо перезаписывает данные. При быстром rejoin (выход + мгновенный вход) или teleport — один сейв может перетереть другой. Также нет проверки версии данных при миграции формата.

**Решение:**
```lua
dataStore:UpdateAsync(key, function(oldData)
    if oldData and (oldData.Version or 0) > (data.Version or 0) then
        return nil -- не перезаписывать более новые данные
    end
    return data
end)
```

---

### 2. DataService: SAVE_ENABLED = false по умолчанию

**Файл:** `src/server/modules/DataService.luau:21`

```lua
local SAVE_ENABLED = false
```

**Проблема:** Сохранение выключено. Если забыть включить при деплое — все данные игроков и мира теряются.

**Решение:**
```lua
local RunService = game:GetService("RunService")
local SAVE_ENABLED = not RunService:IsStudio()
```

---

### 3. BindToClose: race condition при сохранении

**Файл:** `src/server/PlayerLifecycle.server.luau:114-125`

```lua
game:BindToClose(function()
    for _, player in Players:GetPlayers() do
        task.spawn(function()
            DataService.save(player)
        end)
    end
    task.wait(4) -- жёсткий таймаут
end)
```

**Проблема:** `task.wait(4)` не гарантирует завершение всех сейвов. С добавлением World Persistence здесь нужно сохранять и мир — это ещё больше времени.

**Решение:**
```lua
game:BindToClose(function()
    local saveComplete = false

    task.spawn(function()
        -- 1. Сохранить мир
        WorldSave.save()

        -- 2. Сохранить игроков параллельно
        local threads = {}
        for _, player in Players:GetPlayers() do
            table.insert(threads, task.spawn(DataService.save, player))
        end

        -- 3. Ждать завершения
        for _, t in threads do
            while coroutine.status(t) ~= "dead" do
                task.wait(0.1)
            end
        end

        saveComplete = true
    end)

    -- Ждём не более 25 секунд
    local start = os.clock()
    while not saveComplete and (os.clock() - start) < 25 do
        task.wait(0.1)
    end
end)
```

---

## P0 CRITICAL — Новые системы

### World Persistence — сохранение состояния мира

**Статус:** Не реализовано, необходимо для core gameplay.

**Задача:** При выходе всех игроков — сохранить полное состояние мира. При возврате — восстановить с того же места.

#### Архитектура хранения

```
DataStore Keys (привязаны к PrivateServerId):
  "world_{serverId}_meta"       → { Seed, CreatedAt, Version, OwnerUserId, PlayTime }
  "world_{serverId}_buildings"  → { [id] = { Type, Position, Rotation, Health, Data } }
  "world_{serverId}_bosses"     → { [bossId] = { Killed, KillCount, RespawnAt, Loot } }
  "world_{serverId}_resources"  → { [nodeId] = { Depleted, RespawnAt } }
  "world_{serverId}_containers" → { [containerId] = { Items, Position } }

DataStore Keys (привязаны к UserId, уже есть):
  "player_{userId}"             → { Level, XP, Inventory, Blood, Spells, ... }
```

#### Лимиты DataStore

| Ключ | Ожидаемый размер | Лимит | Запас |
|------|-----------------|-------|-------|
| meta | ~200 B | 4 MB | Огромный |
| buildings (500 построек) | ~100 KB | 4 MB | 40x |
| bosses (20 боссов) | ~2 KB | 4 MB | 2000x |
| resources (500 нод) | ~50 KB | 4 MB | 80x |
| player data | ~10 KB | 4 MB | 400x |

#### Жизненный цикл сервера

```
SERVER START
  ├─ 1. Определить PrivateServerId (game.PrivateServerId)
  ├─ 2. Загрузить world_meta (seed, version)
  │     └─ Если нет — первый запуск, сгенерировать seed
  ├─ 3. Сгенерировать terrain по seed (детерминированно)
  ├─ 4. Загрузить buildings → Instance-ировать Part-ы
  ├─ 5. Загрузить boss progress → пометить убитых
  ├─ 6. Загрузить resources → убрать добытые, проверить respawn
  ├─ 7. Спавнить врагов по SpawnPoints (враги не сохраняются)
  └─ 8. Loading screen → разрешить вход

GAMEPLAY
  ├─ Autosave мира каждые 120 сек
  ├─ Autosave игроков каждые 120 сек (уже есть)
  └─ Instant save при критических событиях:
       ├─ Босс убит
       ├─ Постройка размещена/удалена
       └─ Крупное изменение (рецепт разблокирован)

ALL PLAYERS LEAVE → BindToClose
  ├─ WorldSave.save() — мир
  ├─ DataService.save() — каждый игрок
  └─ Сервер закрывается (Roblox автоматически)
```

#### Модульная структура (предложение)

```
src/server/
  world/
    WorldManager.server.luau    -- Точка входа, координирует load/save
    WorldSave.luau              -- Сериализация/десериализация мира
    WorldGeneration.luau        -- Процедурная генерация по seed
    BuildingManager.luau        -- Размещение/удаление построек
    ResourceNodeManager.luau    -- Ресурсные ноды с respawn таймерами

src/shared/
  config/
    WorldConfig.luau            -- Seed параметры, biome настройки
    BuildingConfig.luau         -- Типы построек, стоимость, HP
```

---

### Процедурная генерация мира

**Статус:** Не реализовано, необходимо для core gameplay.

**Подход:** Seed-based, детерминированная генерация. Один seed = всегда один и тот же мир.

#### Ключевые принципы

1. **Детерминированность** — `math.random` заменяется на seed-based RNG (PRNG)
2. **Terrain API** — `Terrain:FillBlock()`, `Terrain:FillBall()` для voxel рельефа
3. **Perlin noise** — `math.noise(x, z)` для высот, biome зон
4. **SpawnPoints** — генерируются процедурно, привязаны к biome
5. **Без изменения ландшафта** — terrain создаётся один раз, игроки не копают

#### Что генерируется

| Элемент | Метод | Сохраняется? |
|---------|-------|-------------|
| Рельеф | math.noise + Terrain API | Нет (воспроизводится по seed) |
| Biome зоны | Voronoi / noise thresholds | Нет (воспроизводится по seed) |
| SpawnPoints врагов | Poisson disc на biome | Нет (воспроизводится по seed) |
| Ресурсные ноды | Poisson disc на biome | Да (добытые/respawn) |
| Точки интереса (боссы) | Фиксированные по seed | Да (прогресс) |
| Постройки игроков | Ручное размещение | Да (полное сохранение) |

#### Время генерации (оценка)

| Размер карты | Terrain | SpawnPoints | Ресурсы | Итого |
|-------------|---------|-------------|---------|-------|
| 512x512 studs | ~2 сек | ~0.5 сек | ~0.5 сек | **~3 сек** |
| 1024x1024 studs | ~5 сек | ~1 сек | ~1 сек | **~7 сек** |
| 2048x2048 studs | ~15 сек | ~2 сек | ~2 сек | **~19 сек** |

Рекомендация: начать с 1024x1024, это ~7 секунд загрузки с loading screen.

---

## P1 SERIOUS

### 8. Множественные `PlayerRemoving` подписки разбросаны по модулям

**Проблема:** `Players.PlayerRemoving:Connect()` зарегистрирован в 8 разных файлах. Нет гарантии порядка выполнения. При добавлении WorldSave — порядок cleanup станет ещё критичнее.

**Решение:** Единая точка cleanup через EventBus:
```lua
-- В PlayerLifecycle (единственный PlayerRemoving):
Players.PlayerRemoving:Connect(function(player)
    DataService.save(player)
    EventBus.fire("PlayerCleanup", player)
end)

-- Все модули подписываются на PlayerCleanup вместо PlayerRemoving
```

---

### 13. LootManager.cleanup() вызывается нигде

**Файл:** `src/server/modules/LootManager.luau:127-137`

**Проблема:** Функция `cleanup` определена, но нигде не вызывается. Лут остаётся на земле навсегда. При длительных кооп-сессиях (2-4 часа) — сотни Part-ов лута накапливаются.

**Решение:** Добавить автоматический тик:
```lua
-- Внутри LootManager.luau, в конце файла:
task.spawn(function()
    while true do
        task.wait(30)
        LootManager.cleanup()
    end
end)
```

---

### AI Activation Distance (sleep для далёких врагов)

**Статус:** Не реализовано.

**Проблема:** При 100 врагах на карте все 100 тикают AI каждые 0.2с, даже если игроки на другом конце карты. Бессмысленная нагрузка.

**Решение:**
```lua
local ACTIVATION_RANGE = 120 -- studs

local function isNearAnyPlayer(enemy, range)
    local rootPart = enemy:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    local pos = rootPart.Position
    for _, player in Players:GetPlayers() do
        local char = player.Character
        local pRoot = char and char:FindFirstChild("HumanoidRootPart")
        if pRoot and (pRoot.Position - pos).Magnitude <= range then
            return true
        end
    end
    return false
end

-- В AI loop:
for _, enemy in enemiesFolder:GetChildren() do
    if isNearAnyPlayer(enemy, ACTIVATION_RANGE) then
        task.spawn(EnemyBehaviors.update, enemy)
    end
end
```

При 4 игроках и 100 врагах на большой карте — реально активных будет 20-40, остальные спят.

---

### Building система (предварительная архитектура)

**Статус:** Ближайший план разработки.

#### Серверная сторона

```lua
-- BuildingManager API:
BuildingManager.place(player, buildingType, position, rotation)
  → Проверка: ресурсы, коллизия, зона
  → Создание Instance (Part/Model)
  → Запись в buildings table
  → Trigger autosave

BuildingManager.remove(player, buildingId)
  → Проверка: владелец, доступ
  → Удаление Instance
  → Возврат части ресурсов
  → Удаление из buildings table

BuildingManager.serialize() → table  -- для WorldSave
BuildingManager.deserialize(data)    -- при загрузке мира
```

#### Сериализация постройки

```lua
{
    Id = "bld_001",           -- уникальный ID
    Type = "stone_wall",      -- ключ из BuildingConfig
    Position = {X, Y, Z},     -- Vector3 → table
    Rotation = {X, Y, Z},     -- EulerAngles → table
    Health = 500,              -- текущее HP
    Owner = 12345678,          -- UserId строителя
    PlacedAt = 1710000000,     -- timestamp
}
-- ~150-200 bytes на постройку
-- 500 построек ≈ 75-100 KB (лимит DataStore: 4 MB)
```

---

## P2 MEDIUM

### 4. Instance-key memory leak (HealthManager, BuffManager, EnemyStateManager)

**Проблема:** Данные хранятся по Instance-ключу. Если entity удаляется не через `die()` — утечка.

**Масштаб при 1-4 игроках:** При 100 врагах и длительных сессиях (4 часа, враги респавнятся) — потенциально сотни «мёртвых» записей. Каждая ~100-200 bytes. Итого ~20-50 KB за сессию. Не критично, но грязно.

**Решение:** Периодический GC:
```lua
task.spawn(function()
    while true do
        task.wait(60)
        for entity, _ in healthData do
            if not entity or not entity.Parent then
                healthData[entity] = nil
            end
        end
    end
end)
```

---

### 9. Дублирование валидации персонажа — одинаковый код в 8+ модулях

**Решение:** Shared utility `CharacterUtil`:
```lua
-- shared/CharacterUtil.luau
function CharacterUtil.validate(player)
    local character = player.Character
    if not character or character:GetAttribute("IsDead") then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    return { character = character, humanoid = humanoid, rootPart = rootPart }
end
```

---

### 11. EventBus без отписки

**Решение:** Добавить `off()`:
```lua
function EventBus.on(eventName, callback)
    if not listeners[eventName] then
        listeners[eventName] = {}
    end
    table.insert(listeners[eventName], callback)
    return function() -- disconnect handle
        local cbs = listeners[eventName]
        if cbs then
            table.remove(cbs, table.find(cbs, callback))
        end
    end
end
```

---

### 12. `tick()` deprecated

Используется в 20+ местах. Заменить на `os.clock()` по всему проекту.

---

### 14. Двойная переменная в Main.server.luau

Строки 1 и 5: дублирование `local ServerScriptService = game:GetService("ServerScriptService")`.

---

### 15. DamageCalc только для Player

`DamageCalc.calculate()` принимает только Player. Враги считают урон отдельно в `EnemyBehaviors`. Нет единого pipeline.

**Решение:** Универсальный calculate с `params.attackerType`.

---

### 16. StatsManager: Player object-key

Использовать `player.UserId` вместо Player Instance.

---

### 17. WaitForChild внутри функций

В `HealthManager.luau:42`, `StatsManager.luau:178`, `CastManager.luau:47-49` — `require(modules:WaitForChild(...))` вызывается внутри функций. Заменить на lazy require на уровне модуля.

---

### 18. Нет rate-limit на SpellAim remote

Per-player throttle 40мс минимум между обработкой. При 4 игроках некритично, но хорошая практика.

---

### 19. HP врагов не масштабируется по уровню

`EnemySpawner` использует `config.MaxHP` фиксированно. Нужна формула: `baseHP + hpPerLevel * (level - 1)`.

---

## P3 DEFERRED (не актуально при 1-4 игроках)

Следующие проблемы **снимаются** при текущем масштабе (1-4 игрока, до 100 врагов). Пересмотреть при увеличении масштаба:

| # | Проблема | Почему снято |
|---|---------|-------------|
| 5 | EnemyAI O(N) spawn storm | 100 врагов x 5/сек = 500 spawn/сек, нормально |
| 6 | TargetFinder full scan | **CLOSED**: spatial hash grid (v1.8) — O(K) вместо O(N) |
| 7 | Projectile hit каждый кадр | При 4 игроках макс ~10 снарядов одновременно |
| 10 | FireAllClients overhead | 4 клиента = копейки |

---

## АРХИТЕКТУРНЫЕ РЕКОМЕНДАЦИИ (Долгосрочные)

### R1. Entity Component System (ECS) для NPC

Данные NPC размазаны: HP в HealthManager, состояния в EnemyStateManager, баффы в BuffManager, атрибуты на Instance. Централизация через EntityRegistry упростит WorldSave и AI sleep.

### R2. Typed Config с валидацией при загрузке

Конфиги не валидируются. При добавлении WorldConfig, BuildingConfig, BiomeConfig — важно ловить ошибки при загрузке, а не в runtime.

### R3. Network Throttler — централизованный rate limiter

Единый модуль вместо ad-hoc throttle на отдельных remotes.

### R4. Разделение InventoryManager на Data + Logic

`InventoryManager` хранит данные и содержит бизнес-логику. Разделить на `InventoryStore` (pure data) + `InventoryService` (логика).

### R5. Command Pattern для remote actions

Единый Command router вместо 50+ отдельных OnServerEvent подписок.

---

## Рекомендуемый порядок работы

```
Фаза 1: Защита данных (P0 существующий код)
  ├─ #1 SetAsync → UpdateAsync
  ├─ #2 SAVE_ENABLED = auto
  └─ #3 BindToClose → надёжное сохранение

Фаза 2: World Persistence (P0 новое)
  ├─ WorldSave модуль (serialize/deserialize мира)
  ├─ Private Server интеграция (game.PrivateServerId)
  └─ Autosave мира + BindToClose

Фаза 3: Процедурная генерация (P0 новое)
  ├─ Seed-based terrain generation
  ├─ Biome система
  ├─ Процедурные SpawnPoints
  └─ Loading screen

Фаза 4: Cleanup и подготовка (P1)
  ├─ #8 Единый PlayerRemoving → EventBus
  ├─ #13 LootManager.cleanup тик
  └─ AI activation distance

Фаза 5: Building система (P1)
  ├─ BuildingConfig + BuildingManager
  ├─ Placement / removal
  ├─ Сериализация в WorldSave
  └─ Стоимость и ресурсы

Фаза 6: Polish (P2) — по мере работы над фичами
  ├─ #4 GC для Instance-key таблиц
  ├─ #9 CharacterUtil
  ├─ #12 tick() → os.clock()
  └─ Остальное из P2
```
