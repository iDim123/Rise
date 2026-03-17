# Checklist v1.9 — Castle Building

> Актуальный чеклист прогресса. Обновлён: 2026-03-17.
> Справочник: `Docs/Roadmap_1.9.md`

---

## Phase 0: Refactoring ✅ ЗАВЕРШЕНА

- [x] 0.1 HealthManager — ветвь IsStructure, StructureDamageEvent, markCombat, StructureDestroyed
- [x] 0.2 TargetFinder — staticEntities, addStaticEntity/removeStaticEntity, isValidTarget, getRootPosition
- [x] 0.3 LootManager — _createLootPart, _calcLootOffset, dropItemAtPosition
- [x] 0.4 CraftHandler — параметр context, поддержка RequiresWorkbench
- [x] 0.5 Remotes — StructureDamageEvent

---

## Phase 1: Castle Foundation ✅ ЗАВЕРШЕНА

### Сервер

- [x] 1.1 BuildingConfig — CastleHeart (3 уровня), BlockTypes, BlockCategories, DefaultPermissions
- [x] 1.2 CastleBorder — claims, heartLevel, permissions, canUpgrade, getMaxBlocks/getMaxCoffins
- [x] 1.3 BuildingValidator — коллизии, PlacementRule, maxBlocks/maxCoffins, CanRotate
- [x] 1.4 BuildingSerializer — CenterPos, Claim, Blocks[], Containers[], Stations[]
- [x] 1.5 BlockHealth — initBlock, StructureDestroyed → BlockDestroyedByDamage
- [x] 1.6 BuildingManager — placeCastleHeart, upgradeHeart, destroyCastle, placeBlock, removeBlock, initPlayer, collect, cleanup
- [x] 1.7 BuildingServer — remote-оркестратор, rate-limit 0.3с
- [x] 1.8 Remotes — +11 events, +2 functions (включая InteractBlock из Phase 2)
- [x] 1.9 DataService — BuildingData в getDefaultData, initPlayer, collect
- [x] 1.10 PlayerLifecycle — BuildingManager.cleanup в onPlayerRemoving
- [x] 1.11 Main.server — BuildingManager.init()
- [x] 1.14 CastleHeartManager — визуал Castle Heart: платформа, пьедестал, орб, свет

### Клиент

- [x] 1.12 BuildingPlacer — ghost preview, snap-to-grid, поворот (R), Highlight
- [x] 1.13 BuildingMenu — UI строительства (B), категории, Castle Heart кнопка

---

## Phase 2: Castle Interiors ✅ ЗАВЕРШЕНА

### Функциональные блоки

- [x] 2.1 FunctionalDispatcher — маршрутизатор: Door, Chest, Station, CraftStation, Coffin, Doorway
- [x] 2.2 InteractBlock remote — маршрутизация в BuildingServer через FunctionalDispatcher
- [x] 2.3 DoorHandler — toggle open/close (F), TweenService поворот 90°, CanCollide
- [x] 2.4 ChestHandler — onCreate, interact, onDestroy (дроп лута), сериализация, restoreContainer
- [x] 2.5 StationHandler — универсальный обработчик (Sawmill, Crusher): input/output, автокрафт, heartbeat, viewers, сериализация
- [x] 2.6 StationConfig — Sawmill, Crusher (InputSlots=8, OutputSlots=8)
- [x] 2.7 CraftConfig — рецепты с полем Station (Sawmill, Crusher, Workbench)
- [x] 2.8 ResourceItems — Wooden Plank, Sawdust, Blood Plank, Trash, Stone Brick
- [x] 2.9 BuildingConfig — sawmill, crusher, workbench с Functional + FunctionalData

### CraftStation система (Workbench, масштабируемая)

- [x] 2.10 CraftStationHandler — серверный контейнер (N слотов), очередь крафта, heartbeat, многопользовательский доступ, сериализация, дроп при разрушении
- [x] 2.11 CraftStationUI — рецепты в 2 колонки, контейнер, tooltip, прогресс-бар, очередь (badge), авто-открытие CharacterWindow
- [x] 2.12 StationConfig.CraftStations — Workbench (Slots=9)
- [x] 2.13 FunctionalDispatcher — маршрут CraftStation → CraftStationHandler
- [x] 2.14 CraftStation remotes — CraftStationOpened/Update/Closed, Deposit, TakeItem, Craft, Close

### Гроб (Coffin)

- [x] 2.15 CoffinHandler — onCreate, interact (привязка), onDestroy (уведомление), getRespawnPosition, cleanupPlayer
- [x] 2.16 HealthManager — respawnAtCoffin: PlayerRespawn → CoffinHandler.getRespawnPosition → телепорт
- [x] 2.17 PlayerLifecycle — CoffinHandler.cleanupPlayer при выходе игрока

### Разрушение замка

- [x] 2.18 BuildingManager destroyCastle — ChestHandler.dropAllLoot + CraftStationHandler.dropAllLoot + StationHandler.dropAllLoot каскадный дроп

### Укрытие от солнца

- [x] 2.19 DayNightManager.isInShelter() — raycast вниз (фундамент / Castle Heart) + raycast к солнцу (тень от деревьев и объектов)

### Стены с дверным проёмом

- [x] 2.20 BuildingConfig — stone_wall_doorway, wooden_wall_doorway (проём 4×5)
- [x] 2.21 BuildingManager.createBlockPart — генерация Model (колонны + перемычка) для Doorway

### Разбор блоков (Dismantle)

- [x] 2.22 Remotes — DismantleBlock (Event), CanDismantleBlock (Function)
- [x] 2.23 BuildingManager — dismantleBlock (100% возврат), dismantleHeart (только если blockCount == 0)
- [x] 2.24 BuildingServer — обработчик DismantleBlock + CanDismantleBlock.OnServerInvoke (проверка прав, предметов, блоков)
- [x] 2.25 BlockInteract (client) — ПКМ зажатие 1с: красная подсветка, прогресс-бар, предварительная проверка через CanDismantleBlock
- [x] 2.26 ChestHandler.hasItems, CraftStationHandler.hasItems, StationHandler.hasItems — проверка наличия предметов
- [x] 2.27 Убран старый режим удаления (X) из BuildingMenu и BuildingPlacer

### Отложено на v2.0

- ~~2.X BloodAltarHandler — blood_essence → улучшение качества крови~~ (отложен на v2.0)
- ~~2.X Блоки крыши (wooden_roof, stone_roof)~~ (убраны из конфига, фундамент = укрытие)

### Исправленные баги (Phase 2)

| Баг | Причина | Фикс |
|---|---|---|
| Castle Heart ghost не появляется | closeBuildingMenu() вызывал cleanup() сразу после startPlacingHeart() | Проверка BuildingPlacer.isActive() перед cleanup |
| StationHandler:501 attempt to call nil | removeItemBySlot вместо removeItem | Замена на InventoryManager.removeItem(player, slotIndex, amount) |
| Drag-and-drop из инвентаря в station не работал | Input-слоты не были зарегистрированы как drop targets | DragManager.registerDropTarget() для input-слотов |
| Нельзя забрать предмет из input/output станции | Слоты не имели обработчиков ЛКМ/ПКМ | ЛКМ = drag, ПКМ = take remote, новый remote StationTakeInput |
| Drag ghost скрыт за StationUI | Ghost в CharacterGui (DisplayOrder 10) | DragLayer — отдельный ScreenGui (DisplayOrder 1000) |
| Зелёная подсветка drop не сбрасывалась | MouseLeave условие не срабатывало | Безусловный сброс цвета в MouseLeave |
| Progress bar не обновлялся | Elapsed обновлялся только при StationUpdate | Клиентская интерполяция через RenderStepped + os.clock() |
| NotifyModule nil в BlockInteract | Модуль не был require'd | Добавлен require(NotifyModule) |
| CanDismantleBlock — InvokeServer на RemoteEvent | Был в events вместо functions | Перемещён в functions массив Remotes |

---

## Phase 3: Integration & Polish ✅ ЗАВЕРШЕНА

- [x] 3.1 BlockCategoryTabs — категории уже встроены в BuildingMenu (табы)
- [x] 3.2 MenuBar — кнопка Build (B)
- [x] 3.3 Minimap — отображение замков (золото = свой, фиолетовый = чужой)
- [x] 3.5 Регрессионное тестирование — все системы 1.0–1.8 работают без регрессий

### Отложено

- ~~3.X CastleHeartUI~~ — отложен (реализован базовый UI в Phase 1)
- ~~3.X BuildingDamageNumbers~~ — отложен
- ~~3.X DataStore stress test~~ — отложен, ручное тестирование по необходимости
- ~~3.X Visual polish~~ — отложен

---

## Внеплановые задачи (выполнены в ходе работы)

### UI-система

- [x] WindowManager — единый менеджер открытых окон, закрытие по Esc
- [x] Tooltip рефакторинг — перемещён из character/tooltip/ в ui/tooltip/, доступен всем UI
- [x] ContainerUI + CharacterWindow связка — F открывает оба окна
- [x] ContainerUI — ПКМ по слоту сундука → TakeItem, disabled кнопки при пустом сундуке
- [x] ContainerUI — tooltip при наведении на слоты (SharedTooltip)
- [x] ContainerUI — fix: tooltip скрывается при перестройке сетки слотов
- [x] ContainerUI — fix: повторное открытие замкового сундука (ContainerEmpty + isCasting reset)
- [x] DepositItem remote — перекладывание предметов из инвентаря в сундук (ПКМ)
- [x] MenuBar — кнопки CharacterWindow (C), ServantWindow (V), BuildingMenu (B)
- [x] WindowManager интеграция — CharacterWindow, ContainerUI, ServantWindow, BuildingMenu, CastleHeartUI, JournalWindow, CraftStationUI

### StationUI

- [x] StationUI — drag-and-drop input/output, прогресс-бар с клиентской интерполяцией (RenderStepped)
- [x] Station remotes — StationOpened, StationUpdate, StationClosed, StationDeposit, StationTakeItem, StationTakeInput, StationTakeAll, StationToggleRecipe, StationClose
- [x] SlotBehavior — ПКМ deposit приоритет: CraftStation > Station > Chest > Default

### DragManager

- [x] Расширение API — source, extraData, getSource(), DragLayer ScreenGui (DisplayOrder 1000)
- [x] Fix — GuiInset компенсация в tryDrop (mousePos смещение на ~36px)

### BuildingMenu / BuildingPlacer

- [x] Fix — closeBuildingMenu() не вызывает cleanup при активном placer
- [x] BuildingPlacer.isActive() — проверка ghostModel
- [x] Убран режим удаления (X) — заменён на ПКМ-разбор

### Сохранение

- [x] DataService.save — fix version conflict (UpdateAsync retry, didWrite flag)
- [x] Castle persistence — сохранение/загрузка замка с фундаментами, сундуками, станциями через DataStore

### Исправленные пути require

- [x] ServantEquipPanel — tooltip path fix (character/tooltip → tooltip)

---

## Масштабирование CraftStation

Добавление новой крафтовой станции (Forge, Alchemy Lab, ...):
1. `StationConfig.CraftStations.Forge = { Name = "Кузница", Slots = 9 }`
2. `BuildingConfig: forge = { Functional = "CraftStation", FunctionalData = { StationType = "Forge" } }`
3. `CraftConfig: рецепты с Station = "Forge"`
4. Ноль изменений в коде — подхватывается автоматически.

---

## Итого: v1.9 READY TO RELEASE ✅

Все критические задачи завершены. Отложены на v2.0: BloodAltarHandler, CastleHeartUI (расширенный), BuildingDamageNumbers, DataStore stress test, Visual polish.