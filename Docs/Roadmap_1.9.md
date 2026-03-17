# Roadmap v1.9 — Castle Building

> Дорожная карта для версии 1.9.
> Система строительства замков с Castle Heart, кооперативным режимом, разрушаемыми блоками, функциональными элементами и перерабатывающими станциями.

## Фазы реализации

| Фаза | Описание | Статус |
|---|---|---|
| Phase 0: Refactoring | Подготовка существующих систем к интеграции | ✅ Завершена |
| Phase 1: Castle Foundation | Castle Heart, фундамент строительства, территории, кооп | ✅ Завершена |
| Phase 2: Castle Interiors | Функциональные блоки (двери, сундуки, станции) | 🔶 В процессе |
| Phase 3: Integration & Polish | UI, миникарта, stress test | ⬜ Не начата |

---

## Ключевая механика: Castle Heart

Castle Heart — центральный элемент замка, вдохновлённый V Rising.

### Правила
- **Размещение:** ставится первым на землю (PlacementRule "Ground"), определяет centerPos и ClaimRadius территории. Только один на игрока. Без Castle Heart строить нельзя.
- **Уничтожение:** Castle Heart может уничтожить **только владелец** через UI. При уничтожении весь замок мгновенно разрушается, содержимое всех сундуков и станций выпадает на землю как лут.
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

## Phase 0: Refactoring ✅ ЗАВЕРШЕНА

Цель: подготовить существующие системы (HealthManager, TargetFinder, LootManager, CraftHandler) к интеграции с замками.

### Задачи

| # | Задача | Файлы | Статус |
|---|---|---|---|
| 0.1 | **HealthManager** — ветвь `IsStructure`: remote `StructureDamageEvent`, `markCombat(attacker)`, `StructureDestroyed` event | `server/modules/HealthManager.luau` | ✅ |
| 0.2 | **TargetFinder** — `staticEntities` set, `addStaticEntity`/`removeStaticEntity`, `isValidTarget` (BasePart + IsStructure), `getRootPosition` (BasePart fallback), порядок `rebuildGrid`: clear → enemies → players → static | `server/combat/TargetFinder.luau` | ✅ |
| 0.3 | **LootManager** — приватные `_createLootPart`, `_calcLootOffset`, новый `dropItemAtPosition` | `server/modules/LootManager.luau` | ✅ |
| 0.4 | **CraftHandler** — параметр `context` в `onCraftItem`, поддержка `RequiresWorkbench` | `server/inventory/CraftHandler.luau` | ✅ |
| 0.5 | **Remotes** — `StructureDamageEvent` | `shared/Remotes.luau` | ✅ |

---

## Phase 1: Castle Foundation ✅ ЗАВЕРШЕНА

Цель: игрок ставит Castle Heart → основывает замок → строит блоки (фундамент, стены, крыши). Поддержка кооперативного строительства и территорий. Блоки разрушаемы. Castle Heart можно улучшать.

### Задачи

| # | Задача | Файлы | Статус |
|---|---|---|---|
| 1.1 | **BuildingConfig** — CastleHeart (3 уровня), типы блоков, сетка, лимиты, DefaultPermissions, BlockCategories | `shared/config/BuildingConfig.luau` | ✅ |
| 1.2 | **CastleBorder** — территории с heartLevel, permissions, canUpgrade, getMaxBlocks/getMaxCoffins, serializeClaim | `server/modules/building/CastleBorder.luau` | ✅ |
| 1.3 | **BuildingValidator** — коллизии, PlacementRule, maxBlocks/maxCoffins из params, CanRotate | `server/modules/building/BuildingValidator.luau` | ✅ |
| 1.4 | **BuildingSerializer** — CenterPos, Claim, Blocks[], Containers[], Stations[] | `server/modules/building/BuildingSerializer.luau` | ✅ |
| 1.5 | **BlockHealth** — мост для блоков: initBlock, StructureDestroyed → BlockDestroyedByDamage | `server/modules/building/BlockHealth.luau` | ✅ |
| 1.6 | **BuildingManager** — ядро: placeCastleHeart, upgradeHeart, destroyCastle, placeBlock, removeBlock, initPlayer, collect, cleanup, getCastleHeartInfo | `server/modules/building/BuildingManager.luau` | ✅ |
| 1.7 | **BuildingServer** — remote-оркестратор: все building + Castle Heart + Station remotes, rate-limit 0.3с | `server/building/BuildingServer.server.luau` | ✅ |
| 1.8 | **Remotes** — building/Castle Heart/Station events + functions | `shared/Remotes.luau` | ✅ |
| 1.9 | **DataService** — BuildingData в getDefaultData, initPlayer в _applyData, collect | `server/modules/DataService.luau` | ✅ |
| 1.10 | **PlayerLifecycle** — BuildingManager.cleanup в onPlayerRemoving | `server/PlayerLifecycle.server.luau` | ✅ |
| 1.11 | **Main.server** — BuildingManager.init() | `server/Main.server.luau` | ✅ |
| 1.12 | **BuildingPlacer** (client) — ghost preview, snap-to-grid, edge-snap стен, режим удаления, isActive() | `client/ui/building/BuildingPlacer.luau` | ✅ |
| 1.13 | **BuildingMenu** (client) — UI строительства (B): категории блоков, Castle Heart, безопасное закрытие | `client/ui/building/BuildingMenu.client.luau` | ✅ |
| 1.14 | **CastleHeartManager** — визуал Castle Heart: платформа, пьедестал, орб, свет | `server/modules/building/CastleHeartManager.luau` | ✅ |
| 1.15 | ~~BuildingConstants~~ | — | ❌ Отменена (константы встроены в BuildingPlacer/BuildingMenu) |
| 1.16 | ~~BuildingDamageNumbers~~ — floating damage через StructureDamageEvent | — | ⬜ Отложена на Phase 3 |
| 1.17 | ~~CastleHeartUI~~ — UI при взаимодействии F с Castle Heart | — | ⬜ Отложена на Phase 3 |

---

## Phase 2: Castle Interiors 🔶 В ПРОЦЕССЕ

Цель: замок имеет функциональные элементы — двери, сундуки, перерабатывающие станции. Маршрутизация через FunctionalDispatcher.

### Задачи

| # | Задача | Файлы | Статус |
|---|---|---|---|
| 2.1 | **FunctionalDispatcher** — маршрутизатор: по `bt.Functional` направляет в Door/Chest/Station хендлеры | `server/modules/building/FunctionalDispatcher.luau` | ✅ |
| 2.2 | **InteractBlock** remote — маршрутизация в BuildingServer через FunctionalDispatcher | `server/building/BuildingServer.server.luau` | ✅ |
| 2.3 | **DoorHandler** — toggle open/close (F), TweenService поворот 90° | `server/modules/building/DoorHandler.luau` | ✅ |
| 2.4 | **ChestHandler** — onCreate → слоты, onInteract → ContainerUI, onDestroy → dropItemAtPosition | `server/modules/building/ChestHandler.luau` | ✅ |
| 2.5 | **StationConfig** — Sawmill, Crusher: Name, InputSlots, OutputSlots, InteractRange, CraftingColor | `shared/config/StationConfig.luau` | ✅ |
| 2.6 | **StationHandler** — универсальный обработчик станций: onCreate, interact, onDestroy, Heartbeat крафт-цикл, deposit/takeFromInput/takeFromOutput/takeAll/toggle, сериализация | `server/modules/building/StationHandler.luau` | ✅ |
| 2.7 | **CraftConfig** — рецепты с полем Station (Sawmill: 3, Crusher: 1). CraftPanel фильтрует станционные | `shared/config/CraftConfig.luau` | ✅ |
| 2.8 | **ResourceItems** — Wooden Plank, Sawdust, Blood Plank, Trash, Stone Brick | `shared/config/items/ResourceItems.luau` | ✅ |
| 2.9 | **BuildingConfig** — sawmill и crusher блоки с `Functional = "Station"`, `FunctionalData.StationType` | `shared/config/BuildingConfig.luau` | ✅ |
| 2.10 | **StationUI** (client) — универсальный UI станций: рецепты с toggle, input/output с drag-and-drop, progress bar с клиентской интерполяцией, ПКМ take, WindowManager интеграция | `client/ui/building/StationUI.client.luau` | ✅ |
| 2.11 | **BlockInteract** (client) — сканирование функциональных блоков, billboard-подсказка [F], InteractBlock remote | `client/ui/building/BlockInteract.client.luau` | ✅ |
| 2.12 | **SlotBehavior** — ПКМ deposit в станцию (приоритет 1) и сундук (приоритет 2) | `client/ui/character/SlotBehavior.luau` | ✅ |
| 2.13 | **DragManager** — расширен: source/extraData в startDrag, getSource(), DragLayer ScreenGui (DisplayOrder 1000) | `client/ui/character/DragManager.luau` | ✅ |
| 2.14 | **InventoryGrid** — обработка drag из station source (stationInput/stationOutput → take remotes) | `client/ui/character/InventoryGrid.luau` | ✅ |
| 2.15 | **Station Remotes** — StationOpened, StationUpdate, StationClosed, StationDeposit, StationTakeItem, StationTakeInput, StationTakeAll, StationToggleRecipe, StationClose | `shared/Remotes.luau` | ✅ |
| 2.16 | **WorkbenchHandler** — onInteract → крафт с hasWorkbench | `server/modules/building/WorkbenchHandler.luau` | ⬜ |
| 2.17 | **BloodAltarHandler** — blood_essence → улучшение качества крови | `server/modules/building/BloodAltarHandler.luau` | ⬜ |
| 2.18 | **CoffinHandler** — точка респавна, лимит от уровня Castle Heart | `server/modules/building/CoffinHandler.luau` | ⬜ |
| 2.19 | **HealthManager** — respawnAtCoffin | `server/modules/HealthManager.luau` | ⬜ |
| 2.20 | **destroyCastle** — дроп лута из всех сундуков и станций | `server/modules/building/BuildingManager.luau` | ⬜ |
| 2.21 | Укрытие от солнца — DayNightManager.isInShelter() с крышей замка | — | ⬜ |

### Исправленные баги (Phase 2)

| Баг | Причина | Фикс |
|---|---|---|
| Castle Heart ghost не появляется | `closeBuildingMenu()` вызывал `BuildingPlacer.cleanup()` сразу после `startPlacingHeart()` | Проверка `BuildingPlacer.isActive()` перед cleanup |
| `StationHandler:501 attempt to call nil` | `removeItemBySlot` вместо `removeItem` | Замена на `InventoryManager.removeItem(player, slotIndex, amount)` |
| Drag-and-drop из инвентаря в station не работал | Input-слоты не были зарегистрированы как drop targets | `DragManager.registerDropTarget()` для input-слотов в StationUI |
| Нельзя забрать предмет из input/output станции | Слоты не имели обработчиков ЛКМ/ПКМ для забирания | ЛКМ = drag (source stationInput/stationOutput), ПКМ = take remote, новый remote StationTakeInput |
| Drag ghost скрыт за StationUI | Ghost в CharacterGui (DisplayOrder 10), StationGui DisplayOrder 815 | DragLayer — отдельный ScreenGui (DisplayOrder 1000) |
| Зелёная подсветка drop не сбрасывалась | MouseLeave условие не срабатывало при drag из инвентаря | Безусловный сброс цвета в MouseLeave |
| Progress bar не обновлялся | `currentCrafting.Elapsed` обновлялся только при StationUpdate | Клиентская интерполяция через RenderStepped + os.clock() |

### Критерии готовности Phase 2

- [x] FunctionalDispatcher маршрутизирует Door, Chest, Station
- [x] Дверь открывается/закрывается (F), анимация
- [x] Сундук хранит предметы, ContainerUI, данные в DataStore
- [x] Станции (Sawmill, Crusher) крафтят по рецептам с Heartbeat-циклом
- [x] StationUI: рецепты с toggle, input/output drag-and-drop, progress bar
- [x] ПКМ deposit из инвентаря в станцию
- [x] Drag из инвентаря в input-слоты станции
- [x] ЛКМ drag / ПКМ take из input и output слотов станции
- [x] Progress bar с клиентской интерполяцией
- [x] При уничтожении станции содержимое дропается
- [x] Сериализация станций в DataStore
- [ ] Верстак открывает расширенный крафт (RequiresWorkbench)
- [ ] Кровавый алтарь улучшает качество крови
- [ ] Гроб = точка респавна, лимит от уровня Castle Heart
- [ ] Уничтожение Castle Heart → содержимое всех сундуков и станций дропается
- [ ] Крыша замка защищает от sunlight_exposure

---

## Phase 3: Integration & Polish ⬜ НЕ НАЧАТА

### Задачи

| # | Задача | Сложность | Статус |
|---|---|---|---|
| 3.1 | **CastleHeartUI** — UI при взаимодействии F: уровень, HP, блоки/лимит, upgrade, permissions, союзники, destroy | Medium | ⬜ |
| 3.2 | **BuildingDamageNumbers** — floating damage над блоками через StructureDamageEvent | Low | ⬜ |
| 3.3 | **Minimap** — отображение замков (dot на центр) | Low | ⬜ |
| 3.4 | **MenuBar** — кнопка Build (B) | Low | ⬜ |
| 3.5 | **DataStore stress test** — 500 блоков + 100 врагов + 4 игрока | High | ⬜ |
| 3.6 | **Visual polish** — эффекты размещения/удаления, звуки | Medium | ⬜ |
| 3.7 | **Регрессионное тестирование** — все системы 1.0–1.8 | High | ⬜ |

### Критерии готовности Phase 3

- [ ] Castle Heart UI при нажатии F (уровень, HP, upgrade, permissions, союзники, destroy)
- [ ] Floating damage numbers над блоками
- [ ] Замки видны на миникарте
- [ ] Кнопка B в MenuBar
- [ ] DataStore: save/load 500 блоков < 100мс, размер < 100КБ
- [ ] FPS: 500 блоков + 100 врагов + 4 игрока ≥ 30 FPS
- [ ] Все системы 1.0–1.8 работают без регрессий

---

## Техническая архитектура (актуальная)

### Структура файлов

Copy
src/ ├── shared/ │ ├── Remotes.luau # MODIFY ✅ │ └── config/ │ ├── BuildingConfig.luau # NEW ✅ │ ├── StationConfig.luau # NEW ✅ │ ├── CraftConfig.luau # MODIFY ✅ (Station field) │ └── items/ResourceItems.luau # MODIFY ✅ (plank, sawdust, etc.) │ ├── server/ │ ├── Main.server.luau # MODIFY ✅ │ ├── PlayerLifecycle.server.luau # MODIFY ✅ │ ├── modules/ │ │ ├── HealthManager.luau # MODIFY ✅ (Phase 0) │ │ ├── LootManager.luau # REFACTOR ✅ (Phase 0) │ │ ├── DataService.luau # MODIFY ✅ │ │ └── building/ │ │ ├── BuildingManager.luau # NEW ✅ │ │ ├── BuildingValidator.luau # NEW ✅ │ │ ├── CastleBorder.luau # NEW ✅ │ │ ├── BuildingSerializer.luau # NEW ✅ │ │ ├── BlockHealth.luau # NEW ✅ │ │ ├── CastleHeartManager.luau # NEW ✅ │ │ ├── FunctionalDispatcher.luau # NEW ✅ │ │ ├── DoorHandler.luau # NEW ✅ │ │ ├── ChestHandler.luau # NEW ✅ │ │ ├── StationHandler.luau # NEW ✅ │ │ ├── WorkbenchHandler.luau # NEW ⬜ │ │ ├── BloodAltarHandler.luau # NEW ⬜ │ │ └── CoffinHandler.luau # NEW ⬜ │ ├── building/ │ │ └── BuildingServer.server.luau # NEW ✅ │ ├── combat/ │ │ └── TargetFinder.luau # MODIFY ✅ (Phase 0) │ └── inventory/ │ └── CraftHandler.luau # MODIFY ✅ (Phase 0) │ └── client/ └── ui/ ├── WindowManager.luau # NEW ✅ ├── building/ │ ├── BuildingMenu.client.luau # NEW ✅ │ ├── BuildingPlacer.luau # NEW ✅ │ ├── StationUI.client.luau # NEW ✅ │ ├── BlockInteract.client.luau # NEW ✅ │ ├── BuildingDamageNumbers.client.luau # NEW ⬜ (Phase 3) │ └── CastleHeartUI.client.luau # NEW ⬜ (Phase 3) └── character/ ├── SlotBehavior.luau # MODIFY ✅ (station deposit) ├── DragManager.luau # MODIFY ✅ (source, DragLayer) └── InventoryGrid.luau # MODIFY ✅ (station drag)


### Зависимости модулей

BuildingServer.server.luau ├── BuildingManager ├── CastleBorder ├── FunctionalDispatcher ├── Remotes └── EventBus

BuildingManager ├── BuildingValidator ├── BuildingSerializer ├── CastleBorder ├── BlockHealth ├── CastleHeartManager ├── FunctionalDispatcher ├── HealthManager (Castle Heart) ├── TargetFinder (lazy, Castle Heart) ├── InventoryManager (lazy) ├── InventorySync (lazy) ├── EventBus ├── Config └── Remotes

FunctionalDispatcher ├── Config ├── DoorHandler ├── ChestHandler └── StationHandler

StationHandler ├── Config (StationConfig, CraftConfig, Items) ├── Remotes ├── CastleBorder ├── LootManager (lazy) ├── InventoryManager (lazy) └── InventorySync (lazy)

StationUI.client.luau ├── Config ├── Remotes ├── UIConstants ├── ItemTooltip ├── WindowManager ├── DragManager └── RunService

BuildingMenu.client.luau ├── Config ├── Remotes ├── BuildingPlacer └── WindowManager

BuildingPlacer.luau ├── Config ├── Remotes └── RunService


### Полный список Station Remotes

| Remote | Тип | Направление | Описание |
|---|---|---|---|
| StationOpened | Event | Server → Client | Станция открыта, передать состояние |
| StationUpdate | Event | Server → Client | Обновление слотов/крафта |
| StationClosed | Event | Server → Client | Станция закрыта сервером |
| StationDeposit | Event | Client → Server | Положить из инвентаря в input |
| StationTakeItem | Event | Client → Server | Забрать из output |
| StationTakeInput | Event | Client → Server | Забрать из input |
| StationTakeAll | Event | Client → Server | Забрать весь output |
| StationToggleRecipe | Event | Client → Server | Вкл/выкл рецепт |
| StationClose | Event | Client → Server | Закрыть UI станции |

### Горячие клавиши

| Клавиша | Действие | Контекст |
|---|---|---|
| B | Меню строительства / закрыть | Глобальная |
| R | Поворот блока 90° | Режим строительства |
| X | Режим удаления | Режим строительства |
| Escape | Отмена размещения / закрыть окно | Режим строительства / WindowManager |
| LMB | Разместить / Удалить блок | Режим строительства |
| F | Взаимодействие (Castle Heart/дверь/станция) | Рядом с объектом |
| ПКМ на слоте инвентаря | Deposit в станцию (приоритет 1) / сундук (приоритет 2) | Станция или сундук открыт |
| ПКМ на слоте станции | Забрать в инвентарь | StationUI открыт |
| ЛКМ на слоте станции | Начать drag | StationUI открыт |

---

## Что осталось до завершения v1.9

### Phase 2 — незавершённые задачи

| Задача | Приоритет | Сложность |
|---|---|---|
| WorkbenchHandler — крафт с hasWorkbench | Medium | Medium |
| BloodAltarHandler — улучшение крови за blood_essence | Medium | Medium |
| CoffinHandler — точка респавна + лимит | Medium | Low-Medium |
| HealthManager respawnAtCoffin | Medium | Medium |
| destroyCastle — дроп лута из сундуков и станций | High | Medium |
| Укрытие от солнца (крыша) | Low | Low |

### Phase 3 — все задачи

| Задача | Приоритет | Сложность |
|---|---|---|
| CastleHeartUI (F на сердце) | High | Medium |
| BuildingDamageNumbers | Low | Low |
| Minimap — замки | Low | Low |
| MenuBar — кнопка B | Low | Low |
| DataStore stress test | High | High |
| Visual polish | Low | Medium |
| Регрессионное тестирование | High | High |