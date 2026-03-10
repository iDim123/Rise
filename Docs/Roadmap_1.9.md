# Roadmap v1.9 — Castle Building

> Дорожная карта для версии 1.9.
> Система строительства замков с Castle Heart, кооперативным режимом, разрушаемыми блоками и функциональными элементами.

## Фазы реализации

| Фаза | Срок | Описание |
|---|---|---|
| Phase 0: Refactoring | 1 неделя | Подготовка существующих систем к интеграции |
| Phase 1: Castle Foundation | 2 недели | Castle Heart, фундамент строительства, территории, кооп |
| Phase 2: Castle Interiors | 1-2 недели | Функциональные блоки (двери, сундуки, верстак, алтарь, гроб) |
| Phase 3: Integration & Polish | 1 неделя | UI, миникарта, stress test |

---

## Ключевая механика: Castle Heart

Castle Heart — центральный элемент замка, вдохновлённый V Rising.

### Правила
- **Размещение:** ставится первым на землю (PlacementRule "Ground"), определяет centerPos и ClaimRadius территории. Только один на игрока. Без Castle Heart строить нельзя.
- **Уничтожение:** Castle Heart может уничтожить **только владелец** через UI. При уничтожении весь замок мгновенно разрушается, содержимое всех сундуков выпадает на землю как лут.
- **Уничтожение через урон:** Castle Heart может быть уничтожен NPC/другим игроком через урон → каскадное разрушение всего замка.
- **Blood Essence decay:** не реализуем в v1.9 (сердце не расходует ресурсы для работы).
- **Улучшения:** 3 уровня, для улучшения требуется Blood Essence.
- **Взаимодействие (F):** открывает UI Castle Heart.

### Уровни Castle Heart

| Уровень | HP | MaxBlocks | ClaimRadius | MaxCoffins | Стоимость улучшения |
|---|---|---|---|---|---|
| 1 | 1000 | 200 | 48 studs | 1 | — (бесплатно при размещении) |
| 2 | 2000 | 350 | 56 studs | 2 | 100 blood_essence |
| 3 | 3000 | 500 | 64 studs | 3 | 250 blood_essence |

### UI Castle Heart (при нажатии F)
- Уровень сердца и HP бар
- Количество блоков: текущее / максимум
- Количество гробов: текущее / максимум
- Кнопка «Улучшить» (с отображением стоимости)
- Секция Permissions: AllowCoopBuild, AllowCoopRemove, AllowCoopInteract
- Список союзников (добавить/удалить)
- Кнопка «Уничтожить замок» (только владелец)

### Архитектурные решения
- Castle Heart **НЕ** хранится в `castle.blocks` — он отдельная сущность (`castle.heartPart`, `castle.heartBlockId`, `castle.heartLevel`).
- HP и конфигурация берутся из `Config.Building.CastleHeart.Levels[n]`, **НЕ** из `Config.Building.BlockTypes`.
- Castle Heart **НЕ** считается в `blockCount`.
- Castle Heart **НЕ** проходит через `BlockHealth` — регистрируется в HealthManager и TargetFinder напрямую из BuildingManager.
- При `StructureDestroyed` для Castle Heart — BuildingManager ловит событие и вызывает каскадное уничтожение (отдельный listener с проверкой `IsCastleHeart`).
- `MaxBlocks` и `MaxCoffins` определяются уровнем Castle Heart через `CastleBorder.getMaxBlocks(ownerId)` / `getMaxCoffins(ownerId)`.

---

## Phase 0: Refactoring (develop_1.9_phase0) ✅ ЗАВЕРШЕНА

Цель: подготовить существующие системы (HealthManager, TargetFinder, LootManager, CraftHandler) к интеграции с замками.

### Задачи

| # | Задача | Сложность | Файлы | Статус |
|---|---|---|---|---|
| 0.1 | **HealthManager** — ветвь `IsStructure`: remote `StructureDamageEvent`, `markCombat(attacker)`, `StructureDestroyed` event | Medium | `server/modules/HealthManager.luau` | ✅ |
| 0.2 | **TargetFinder** — `staticEntities` set, `addStaticEntity`/`removeStaticEntity`, `isValidTarget` (BasePart + IsStructure), `getRootPosition` (BasePart fallback), порядок `rebuildGrid`: clear → enemies → players → static | Medium | `server/combat/TargetFinder.luau` | ✅ |
| 0.3 | **LootManager** — приватные `_createLootPart`, `_calcLootOffset`, новый `dropItemAtPosition` | Medium | `server/modules/LootManager.luau` | ✅ |
| 0.4 | **CraftHandler** — параметр `context` в `onCraftItem`, поддержка `RequiresWorkbench` | Low | `server/inventory/CraftHandler.luau` | ✅ |
| 0.5 | **Remotes** — `StructureDamageEvent` | Low | `shared/Remotes.luau` | ✅ |

> **Примечание:** Задачи 0.5–0.6 (ContainerManager/ContainerServer) из первоначального плана отменены — обнаружена существующая система контейнеров в `server/modules/container/`. Она будет расширена в Phase 2.

### Критерии готовности Phase 0 ✅
- [x] HealthManager корректно обрабатывает IsStructure (init, takeDamage без DamageEvent, die с StructureDestroyed)
- [x] markCombat(attacker) вызывается при атаке структуры
- [x] TargetFinder: addStaticEntity/removeStaticEntity работают, структуры находятся через inRadius
- [x] TargetFinder: rebuildGrid не теряет статические объекты
- [x] LootManager: `_createLootPart` переиспользуется в 3 публичных методах, `dropItemAtPosition` работает
- [x] CraftHandler принимает context с hasWorkbench
- [x] Все существующие системы не сломаны

---

## Phase 1: Castle Foundation (develop_1.9_phase1)

Цель: игрок ставит Castle Heart → основывает замок → строит блоки (фундамент, стены, полы, крыши). Поддержка кооперативного строительства и территорий. Блоки разрушаемы. Castle Heart можно улучшать.

### Задачи

| # | Задача | Сложность | Файлы | Статус |
|---|---|---|---|---|
| 1.1 | **BuildingConfig** — CastleHeart (3 уровня), типы блоков, сетка, лимиты, DefaultPermissions, BlockCategories | Low | `shared/config/BuildingConfig.luau` | ✅ |
| 1.2 | **CastleBorder** — территории с heartLevel, permissions, canUpgrade, getMaxBlocks/getMaxCoffins, serializeClaim | Medium | `server/modules/building/CastleBorder.luau` | ✅ |
| 1.3 | **BuildingValidator** — коллизии (блоки + Castle Heart), PlacementRule, maxBlocks/maxCoffins из params, CanRotate | Medium | `server/modules/building/BuildingValidator.luau` | ✅ |
| 1.4 | **BuildingSerializer** — контракт: CenterPos, Claim (HeartLevel + permissions), Blocks[], Containers[] | Medium | `server/modules/building/BuildingSerializer.luau` | ✅ |
| 1.5 | **BlockHealth** — мост для обычных блоков: initBlock, StructureDestroyed → BlockDestroyedByDamage | Medium | `server/modules/building/BlockHealth.luau` | ✅ |
| 1.6 | **BuildingManager** — ядро: placeCastleHeart, upgradeHeart, destroyCastle, placeBlock, removeBlock, initPlayer (восстановление heartPart + блоков), collect, cleanup, getCastleHeartInfo | High | `server/modules/building/BuildingManager.luau` | ✅ |
| 1.7 | **BuildingServer** — remote-оркестратор: все building + Castle Heart remotes, rate-limit 0.3с | Medium | `server/building/BuildingServer.server.luau` | ✅ |
| 1.8 | **Remotes** — +11 events, +2 functions для building/Castle Heart | Low | `shared/Remotes.luau` | ✅ |
| 1.9 | **DataService** — BuildingData в getDefaultData, initPlayer в _applyData, collect в collect | Low | `server/modules/DataService.luau` | ✅ |
| 1.10 | **PlayerLifecycle** — BuildingManager.cleanup в onPlayerRemoving (после save) | Low | `server/PlayerLifecycle.server.luau` | ✅ |
| 1.11 | **Main.server** — BuildingManager.init() | Low | `server/Main.server.luau` | ✅ |
| 1.12 | **BuildingPlacer** (client) — ghost preview, snap-to-grid, поворот (R), режим удаления (X), Highlight, HP | High | `client/ui/building/BuildingPlacer.luau` | ⬜ |
| 1.13 | **BuildingMenu** (client) — UI строительства (B): блоки, стоимость, Castle Heart UI (уровень, HP, permissions, союзники) | Medium | `client/ui/building/BuildingMenu.client.luau` | ⬜ |
| 1.14 | **BuildingConstants** — цвета ghost, размеры UI, клавиши | Low | `client/ui/building/BuildingConstants.luau` | ⬜ |
| 1.15 | **BuildingDamageNumbers** — floating damage через StructureDamageEvent | Low | `client/ui/building/BuildingDamageNumbers.client.luau` | ⬜ |
| 1.16 | **CastleHeartUI** (client) — UI при взаимодействии F с Castle Heart: уровень, HP, блоки/лимит, гробы/лимит, upgrade, permissions, союзники, destroy | Medium | `client/ui/building/CastleHeartUI.client.luau` | ⬜ |

### BuildingConfig — структура

```lua
return {
    Building = {
        GridSize = 4,
        SnapTolerance = 0.1,
        MaxCastlesPerWorld = 4,
        RemoveRefundRate = 0.5,

        CastleHeart = {
            Name = "Сердце замка",
            Size = Vector3.new(4, 4, 4),
            Material = Enum.Material.Basalt,
            Color = Color3.fromRGB(60, 15, 15),
            PlacementRule = "Ground",
            CanRotate = false,
            Levels = {
                [1] = { HP = 1000, MaxBlocks = 200, ClaimRadius = 48, MaxCoffins = 1, UpgradeCost = nil },
                [2] = { HP = 2000, MaxBlocks = 350, ClaimRadius = 56, MaxCoffins = 2,
                         UpgradeCost = {{ ItemId = "blood_essence", Amount = 100 }} },
                [3] = { HP = 3000, MaxBlocks = 500, ClaimRadius = 64, MaxCoffins = 3,
                         UpgradeCost = {{ ItemId = "blood_essence", Amount = 250 }} },
            },
            MaxLevel = 3,
        },

        DefaultPermissions = { AllowCoopBuild = false, AllowCoopRemove = false, AllowCoopInteract = true },

        BlockCategories = {
            { Id = "Foundation", Name = "Фундамент", Order = 1 },
            { Id = "Wall",       Name = "Стены",     Order = 2 },
            { Id = "Floor",      Name = "Полы",      Order = 3 },
            { Id = "Roof",       Name = "Крыша",     Order = 4 },
            { Id = "Functional", Name = "Интерьер",  Order = 5 },
        },

        BlockTypes = {
            stone_foundation  = { ... PlacementRule = "Ground" },
            wooden_foundation = { ... PlacementRule = "Ground" },
            stone_wall        = { ... PlacementRule = "OnFoundation", CanRotate = true },
            wooden_wall       = { ... PlacementRule = "OnFoundation", CanRotate = true },
            stone_pillar      = { ... PlacementRule = "OnFoundation" },
            wooden_floor      = { ... PlacementRule = "OnWall" },
            stone_floor       = { ... PlacementRule = "OnWall" },
            wooden_roof       = { ... PlacementRule = "OnWall", IsShelter = true },
            stone_roof        = { ... PlacementRule = "OnWall", IsShelter = true },
            wooden_door       = { ... Functional = "Door" },
            castle_chest      = { ... Functional = "Chest", FunctionalData = { Slots = 12 } },
            workbench         = { ... Functional = "Workbench" },
            blood_altar       = { ... Functional = "BloodAltar" },
            coffin            = { ... Functional = "Coffin" },
        },
    }
}
Copy
CastleBorder — claims с heartLevel
Copy-- claims[ownerId] = {
--     ownerId, center, heartLevel,
--     permissions = { AllowCoopBuild, AllowCoopRemove, AllowCoopInteract, AllowedPlayers = {} }
-- }
-- Radius определяется из CastleHeart.Levels[heartLevel].ClaimRadius
-- API: registerClaim(ownerId, centerPos, heartLevel, savedPermissions)
--      setHeartLevel, canUpgrade, getMaxBlocks, getMaxCoffins, getHeartHP
--      serializeClaim → { HeartLevel, AllowCoopBuild, ..., AllowedPlayers }
BuildingSerializer — контракт
╔══════════════════════════════════════════════════════════════════╗
║  КОНТРАКТ СЕРИАЛИЗАЦИИ                                          ║
║                                                                  ║
║  Сохраняются:                                                    ║
║    CenterPos       — {x, y, z}                                   ║
║    Claim           — {HeartLevel, AllowCoopBuild, AllowCoopRemove,║
║                       AllowCoopInteract, AllowedPlayers: [id]}    ║
║    Blocks[]        — {T=typeId, P={x,y,z}, R=rotation}           ║
║    Containers[]    — {Id, Ref=blockIndex, Slots}                  ║
║                                                                  ║
║  НЕ сохраняются (из Config при загрузке):                        ║
║    Size, Material, Color, Cost, PlacementRule, CanRotate, HP      ║
║    Castle Heart Part (восстанавливается из CenterPos + HeartLevel)║
║                                                                  ║
║  HP блоков НЕ персистится — полное HP при загрузке.              ║
╚══════════════════════════════════════════════════════════════════╝
BuildingManager — Castle Heart логика
Размещение Castle Heart:
  1. Проверки: нет существующего замка, лимит замков, snap позиции
  2. Raycast вниз для surfaceY
  3. CastleBorder.registerClaim(ownerId, finalPos, 1)
  4. Создать Part: createHeartPart + initHeartSystems (атрибуты, HealthManager, TargetFinder)
  5. Создать castle в castles[ownerId]

Размещение блока (placeBlock):
  1. Определить castleOwnerId → требуется существующий Castle Heart
  2. Без Castle Heart → return false, "Сначала поставьте Сердце замка"
  3. validate: maxBlocks из CastleBorder.getMaxBlocks, коллизия с heartPart
  4. Остальное без изменений

Восстановление (initPlayer):
  1. BuildingSerializer.deserialize → heartLevel, permissions, blocks
  2. CastleBorder.registerClaim(ownerId, centerPos, heartLevel, permissions)
  3. createHeartPart + initHeartSystems
  4. Восстановить блоки через BlockHealth.initBlock

Castle Heart уничтожен через урон:
  EventBus "StructureDestroyed" → проверка IsCastleHeart →
  каскадное уничтожение всех блоков → cleanupHeartSystems → CastleBorder.removeClaim
BuildingManager.placeBlock — логика с Castle Heart
1. Определить castle owner:
   - position внутри claim → coop: CastleBorder.canBuild(actorId, ownerId)
   - position не в claim, у player есть Castle Heart → проверить ClaimRadius
   - position не в claim, у player нет Castle Heart → "Сначала поставьте Сердце замка"
2. Получить castle (должен существовать)
3. BuildingValidator.validate с params:
   - maxBlocks = CastleBorder.getMaxBlocks(castleOwnerId)
   - maxCoffins = CastleBorder.getMaxCoffins(castleOwnerId)
   - heartPosition, heartSize (для проверки коллизии с Castle Heart)
4. Проверить и списать ресурсы (из инвентаря СТРОИТЕЛЯ)
5. Создать Part, BlockHealth.initBlock
6. InventorySync.sendFullUpdate
7. EventBus.fire("BlockPlaced", ...)
Порядок инициализации при загрузке игрока
DataService.load → _applyData:
  1. LevelManager.initPlayer
  2. InventoryManager.create
  3. BloodManager.init
  4. BossManager.initPlayer
  5. ServantManager.init
  6. SpellProgressManager.init
  7. BuildingManager.initPlayer(player, data.BuildingData)  ← NEW
     → CastleBorder.registerClaim
     → createHeartPart + initHeartSystems
     → восстановить блоки + BlockHealth.initBlock
Порядок при выходе игрока
onPlayerRemoving:
  1. DataService.save → collect → BuildingManager.collect (сериализация)
  2. EventBus.fire("PlayerCleanup")
  3. ServantManager, BloodManager, BossManager, InventoryManager, StatsManager cleanup
  4. BuildingManager.cleanup (уничтожает Parts, folder, claim)  ← NEW
  5. HealthManager.cleanup(character)
  6. DataService.cleanup
Snap-to-grid система
Все блоки размещаются на сетке GridSize (4 studs). Клиент показывает ghost-preview. Зелёный = можно ставить, красный = нельзя. Поворот: R (шаг 90°, только CanRotate = true).

EventBus события
Событие	Аргументы	Кто fire	Кто listen
StructureDestroyed	entity, attacker	HealthManager	BlockHealth, BuildingManager (Castle Heart)
BlockDestroyedByDamage	entity, attacker, ownerId, typeId, blockId	BlockHealth	BuildingManager
BlockPlaced	player, blockTypeId, position	BuildingManager	—
BlockRemoved	player/nil, position	BuildingManager	—
CastleHeartPlaced	player, position	BuildingManager	—
CastleDestroyed	player/nil	BuildingManager	—
Критерии готовности Phase 1
 Castle Heart ставится первым, определяет территорию
 Castle Heart улучшается (3 уровня) за blood_essence
 Уничтожение Castle Heart → каскадное разрушение замка
 MaxBlocks и MaxCoffins зависят от уровня Castle Heart
 Стены, полы, крыши ставятся по PlacementRule
 Коллизия новых блоков с Castle Heart проверяется
 Сериализация включает HeartLevel в Claim
 initPlayer восстанавливает Castle Heart Part + блоки
 BuildingServer обрабатывает все remotes
 DataService интеграция (save/load BuildingData)
 PlayerLifecycle cleanup
 Ghost-preview с snap-to-grid, поворот R, отмена Esc
 UI строительства (B) с категориями блоков
 Castle Heart UI при нажатии F
 Floating damage numbers над блоками
 Расход и возврат материалов работает в UI
Phase 2: Castle Interiors (develop_1.9_phase2)
Цель: замок имеет функциональные элементы — двери, сундуки, верстак, алтарь крови, гроб.

Задачи
#	Задача	Сложность	Файлы	Статус
2.1	DoorHandler — toggle open/close (F), canInteract permissions, TweenService поворот 90°, CanCollide toggle	Medium	server/modules/building/DoorHandler.luau	⬜
2.2	ChestHandler — onCreate → ContainerManager.registerContainer, onInteract → open, onDestroy → dropItemAtPosition + removeContainer	Medium	server/modules/building/ChestHandler.luau	⬜
2.3	ContainerConfig — добавить castle_chest тип (Slots=12, Persistent=true)	Low	shared/config/ContainerConfig.luau	⬜
2.4	ContainerUI — сканирование workspace.Castles в дополнение к workspace.Containers	Low	client/ui/ContainerUI.client.luau	⬜
2.5	WorkbenchHandler — onInteract → OpenCraftStation remote с {hasWorkbench=true}	Medium	server/modules/building/WorkbenchHandler.luau	⬜
2.6	BloodAltarHandler — onInteract → OpenBloodAltar remote, blood_essence → +Quality%	Medium	server/modules/building/BloodAltarHandler.luau	⬜
2.7	CoffinHandler — onCreate → castle.coffinPos, onDestroy → nil, лимит из MaxCoffins	Low	server/modules/building/CoffinHandler.luau	⬜
2.8	HealthManager — respawnAtCoffin: CharacterAdded:Wait с защитой, WaitForChild timeout 5с	Medium	server/modules/HealthManager.luau	⬜
2.9	InteractBlock remote — маршрутизация в BuildingServer по Functional типу	Low	server/building/BuildingServer.server.luau	⬜
2.10	Укрытие от солнца — проверить DayNightManager.isInShelter() с крышей замка	Low	—	⬜
2.11	BuildingManager — destroyCastle: дроп лута из всех сундуков при уничтожении Castle Heart	Medium	server/modules/building/BuildingManager.luau	⬜
ChestHandler — уничтожение
Copyfunction ChestHandler.onDestroy(part, blockData)
    local containerId = blockData.containerId
    if not containerId then return end
    local container = ContainerManager.getContainer(containerId)
    if not container then return end
    for i = 1, container.slotCount do
        local slot = container.slots[i]
        if slot and slot ~= false then
            LootManager.dropItemAtPosition(part.Position, slot.Id, slot.Amount or 1)
        end
    end
    ContainerManager.removeContainer(containerId)
end
CoffinHandler — респавн
Copylocal function respawnAtCoffin(player)
    local coffinPos = BuildingManager.getCoffinPos(player)
    if not coffinPos then return end
    task.spawn(function()
        local newChar = player.CharacterAdded:Wait()
        if not player.Parent then return end
        local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            hrp.CFrame = CFrame.new(coffinPos + Vector3.new(0, 3, 0))
        end
    end)
end
Новые Remotes (Phase 2)
Remote	Тип	Направление	Phase
InteractBlock	Event	Client → Server	2
OpenCraftStation	Event	Server → Client	2
OpenBloodAltar	Event	Server → Client	2
Критерии готовности Phase 2
 Дверь открывается/закрывается (F), анимация, canInteract permissions
 Сундук хранит предметы, ContainerUI, данные в DataStore
 При уничтожении сундука — содержимое дропается как лут
 Уничтожение Castle Heart → содержимое всех сундуков дропается
 Верстак открывает расширенный крафт (RequiresWorkbench)
 Кровавый алтарь улучшает качество крови за blood_essence
 Гроб = точка респавна, лимит зависит от уровня Castle Heart
 Крыша замка защищает от sunlight_exposure
Phase 3: Integration & Polish (develop_1.9_phase3)
Задачи
#	Задача	Сложность	Статус
3.1	BlockCategoryTabs — категории в BuildingMenu	Medium	⬜
3.2	MenuBar — кнопка Build (B)	Low	⬜
3.3	Minimap — отображение замков (dot на центр)	Low	⬜
3.4	DataStore stress test — 500 блоков + 100 врагов + 4 игрока	High	⬜
3.5	Visual polish — эффекты размещения/удаления, звуки	Medium	⬜
3.6	Регрессионное тестирование — все системы 1.0–1.8	High	⬜
Критерии готовности Phase 3
 Категории блоков в меню строительства
 Кнопка B в MenuBar
 Замки видны на миникарте
 DataStore: save/load 500 блоков < 100мс, размер < 100КБ
 FPS: 500 блоков + 100 врагов + 4 игрока ≥ 30 FPS
 Все системы 1.0–1.8 работают без регрессий
Техническая архитектура (v1.9)
Структура файлов
src/
├── shared/
│   ├── Remotes.luau                              # MODIFY (Phase 0+1+2)
│   └── config/
│       ├── BuildingConfig.luau                   # NEW (Phase 1) ✅
│       └── ContainerConfig.luau                  # MODIFY (Phase 2)
│
├── server/
│   ├── Main.server.luau                          # MODIFY (Phase 1) ✅
│   ├── PlayerLifecycle.server.luau               # MODIFY (Phase 1) ✅
│   ├── modules/
│   │   ├── HealthManager.luau                   # MODIFY (Phase 0 ✅, Phase 2)
│   │   ├── LootManager.luau                     # REFACTOR (Phase 0) ✅
│   │   ├── DataService.luau                     # MODIFY (Phase 1) ✅
│   │   └── building/
│   │       ├── BuildingManager.luau              # NEW (Phase 1) ✅
│   │       ├── BuildingValidator.luau            # NEW (Phase 1) ✅
│   │       ├── CastleBorder.luau                 # NEW (Phase 1) ✅
│   │       ├── BuildingSerializer.luau           # NEW (Phase 1) ✅
│   │       ├── BlockHealth.luau                  # NEW (Phase 1) ✅
│   │       ├── DoorHandler.luau                  # NEW (Phase 2)
│   │       ├── ChestHandler.luau                 # NEW (Phase 2)
│   │       ├── WorkbenchHandler.luau             # NEW (Phase 2)
│   │       ├── BloodAltarHandler.luau            # NEW (Phase 2)
│   │       └── CoffinHandler.luau                # NEW (Phase 2)
│   ├── building/
│   │   └── BuildingServer.server.luau            # NEW (Phase 1) ✅
│   ├── combat/
│   │   └── TargetFinder.luau                    # MODIFY (Phase 0) ✅
│   └── inventory/
│       └── CraftHandler.luau                    # MODIFY (Phase 0) ✅
│
└── client/
    └── ui/
        ├── ContainerUI.client.luau               # MODIFY (Phase 2)
        ├── Minimap.client.luau                   # MODIFY (Phase 3)
        ├── MenuBar.luau                          # MODIFY (Phase 3)
        └── building/
            ├── BuildingMenu.client.luau          # NEW (Phase 1)
            ├── BuildingPlacer.luau                # NEW (Phase 1)
            ├── BuildingConstants.luau             # NEW (Phase 1)
            ├── BuildingDamageNumbers.client.luau  # NEW (Phase 1)
            ├── CastleHeartUI.client.luau          # NEW (Phase 1)
            └── BlockCategoryTabs.luau             # NEW (Phase 3)
Зависимости модулей
BuildingServer.server.luau
├── BuildingManager
├── CastleBorder
├── Remotes
└── EventBus

BuildingManager
├── BuildingValidator
├── BuildingSerializer
├── CastleBorder
├── BlockHealth
├── HealthManager         ← Castle Heart напрямую
├── TargetFinder (lazy)   ← Castle Heart напрямую
├── InventoryManager (lazy)
├── InventorySync (lazy)
├── EventBus
├── Config
└── Remotes

BuildingValidator
├── Config
└── CastleBorder (lazy)

CastleBorder
└── Config

BlockHealth
├── HealthManager
├── TargetFinder (lazy)
└── EventBus

BuildingSerializer
└── Config

BuildingMenu.client.luau
├── Config
├── BuildingPlacer
├── BuildingConstants
├── CastleHeartUI
└── Remotes
Полный список Remotes (v1.9)
Remote	Тип	Направление	Phase
StructureDamageEvent	Event	Server → All Clients	0
PlaceCastleHeart	Event	Client → Server	1
UpgradeCastleHeart	Event	Client → Server	1
DestroyCastle	Event	Client → Server	1
CastleHeartInfo	Event	Server → Client	1
PlaceBlock	Event	Client → Server	1
RemoveBlock	Event	Client → Server	1
BuildingSync	Event	Server → Client	1
SetBuildPermission	Event	Client → Server	1
AddBuildAlly	Event	Client → Server	1
RemoveBuildAlly	Event	Client → Server	1
GetBuildings	Function	Client → Server	1
GetCastleHeartInfo	Function	Client → Server	1
InteractBlock	Event	Client → Server	2
OpenCraftStation	Event	Server → Client	2
OpenBloodAltar	Event	Server → Client	2
Горячие клавиши
Клавиша	Действие	Контекст
B	Окно строительства / закрыть	Глобальная
R	Поворот блока 90°	Режим строительства
X	Режим удаления	Режим строительства
Escape	Отмена размещения	Режим строительства
LMB	Разместить / Удалить блок	Режим строительства
F	Взаимодействие (Castle Heart/дверь/сундук/верстак/алтарь)	Рядом с объектом
Порядок реализации
Phase 0 (5 дней) ✅
День	Задачи	Статус
1	HealthManager (IsStructure), Remotes (+StructureDamageEvent)	✅
2	TargetFinder (staticEntities, add/remove, isValidTarget, getRootPosition, порядок rebuild)	✅
3	LootManager рефакторинг (_createLootPart, _calcLootOffset, dropItemAtPosition)	✅
4	CraftHandler (context + RequiresWorkbench)	✅
5	Регрессионное тестирование	✅
Phase 1 (10 дней)
День	Задачи	Статус
1	BuildingConfig (с CastleHeart секцией)	✅
2	CastleBorder (heartLevel, canUpgrade, getMaxBlocks, serializeClaim)	✅
3	BuildingValidator (maxBlocks/maxCoffins из params, коллизия с Castle Heart)	✅
4	BuildingSerializer (Claim с HeartLevel)	✅
5	BlockHealth	✅
6-7	BuildingManager (Castle Heart: place, upgrade, destroy + блоки: place, remove, initPlayer, collect)	✅
8	BuildingServer + Remotes + DataService + PlayerLifecycle + Main интеграция	✅
9	BuildingConstants + BuildingPlacer + BuildingDamageNumbers + CastleHeartUI (клиент)	⬜
10	BuildingMenu (клиент) + интеграция + тестирование	⬜
Phase 2 (7-10 дней)
День	Задачи	Статус
1	InteractBlock remote + маршрутизация в BuildingServer	⬜
2	DoorHandler	⬜
3-4	ChestHandler + ContainerConfig(castle_chest) + ContainerUI(scanFolders)	⬜
5	WorkbenchHandler + OpenCraftStation	⬜
6	BloodAltarHandler + OpenBloodAltar + мини-UI	⬜
7	CoffinHandler + HealthManager respawnAtCoffin	⬜
8	destroyCastle дроп лута из сундуков + проверка укрытия от солнца + тестирование	⬜
Phase 3 (5 дней)
День	Задачи	Статус
1	BlockCategoryTabs	⬜
2	MenuBar (B) + Minimap (замки)	⬜
3-4	DataStore stress test + оптимизация	⬜
5	Visual polish + регрессия	⬜

---

## Что изменилось по сравнению с прежним Roadmap

Вот ключевые отличия от предыдущей версии:

**Добавлена секция "Ключевая механика: Castle Heart"** — полное описание механики, уровни, UI, архитектурные решения (отдельная сущность, не в BlockTypes, не через BlockHealth).

**Phase 0 отмечена как завершённая** — все задачи имеют статус ✅. Удалены задачи 0.5–0.6 (ContainerManager/ContainerServer) с примечанием что обнаружена существующая система.

**Phase 1 полностью переработана.** Все задачи 1.1–1.11 (серверная часть) отмечены ✅. Описания задач обновлены с учётом Castle Heart: CastleBorder теперь хранит heartLevel, BuildingValidator принимает maxBlocks/maxCoffins/heartPosition через params, BuildingSerializer сохраняет HeartLevel в Claim, BuildingManager содержит placeCastleHeart/upgradeHeart/destroyCastle. Добавлена задача 1.16 (CastleHeartUI). Таблица Remotes расширена на 11 events + 2 functions. Описаны порядки инициализации и cleanup. Добавлены новые EventBus события (CastleHeartPlaced, CastleDestroyed).

**Phase 2 добавлена задача 2.11** — дроп лута из сундуков при уничтожении Castle Heart. В критерии готовности добавлен пункт про каскадный дроп. Лимит гробов теперь привязан к уровню Castle Heart.

**Структура файлов обновлена** — добавлен `CastleHeartUI.client.luau`, все статусы файлов актуализированы. Зависимости BuildingManager расширены на HealthManager и TargetFinder (для Castle Heart напрямую). Убрана зависимость BuildingManager → ContainerManager (перенесена в Phase 2).

**Удалены устаревшие фрагменты.** Старый BuildingConfig с `MaxBlocks = 500` и `ClaimRadius = 64` как глобальными константами заменён на CastleHeart.Levels. Логика "первый foundation = centerPos" заменена на "Castle Heart = centerPos". placeBlock больше не создаёт замок автоматически.