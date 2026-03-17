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
- [x] 1.4 BuildingSerializer — CenterPos, Claim, Blocks[], Containers[]
- [x] 1.5 BlockHealth — initBlock, StructureDestroyed → BlockDestroyedByDamage
- [x] 1.6 BuildingManager — placeCastleHeart, upgradeHeart, destroyCastle, placeBlock, removeBlock, initPlayer, collect, cleanup
- [x] 1.7 BuildingServer — remote-оркестратор, rate-limit 0.3с
- [x] 1.8 Remotes — +11 events, +2 functions (включая InteractBlock из Phase 2)
- [x] 1.9 DataService — BuildingData в getDefaultData, initPlayer, collect
- [x] 1.10 PlayerLifecycle — BuildingManager.cleanup в onPlayerRemoving
- [x] 1.11 Main.server — BuildingManager.init()

### Клиент

- [x] 1.12 BuildingPlacer — ghost preview, snap-to-grid, поворот (R), режим удаления (X), Highlight
- [x] 1.13 BuildingMenu — UI строительства (B), категории, Castle Heart кнопка
- [x] 1.14 BuildingConstants — цвета, размеры, клавиши, Highlight параметры
- [x] 1.15 BuildingDamageNumbers — floating damage + HP bar над структурами
- [x] 1.16 CastleHeartUI — уровень, HP, эссенция, блоки/лимит, гробы/лимит, upgrade, permissions, союзники, destroy

---

## Phase 2: Castle Interiors — В РАБОТЕ

- [x] 2.1 DoorHandler — toggle open/close (F), canInteract, TweenService поворот 90°, CanCollide
- [x] 2.2 ChestHandler — onCreate, interact, onDestroy (дроп лута), сериализация, restoreContainer
- [x] 2.3 ContainerConfig — castle_chest (Persistent=true, Slots=12) реализован через ChestHandler напрямую
- [x] 2.4 ContainerUI — сканирование workspace.Castles, tooltip, ПКМ-перекладывание, кнопки disabled при пустом
- [x] 2.5 CraftStation система (Workbench) — универсальная архитектура крафтовых станций
- [ ] 2.6 BloodAltarHandler — onInteract → OpenBloodAltar, blood_essence → Quality%
- [ ] 2.7 CoffinHandler — onCreate → coffinPos, onDestroy → nil, лимит MaxCoffins
- [ ] 2.8 HealthManager — respawnAtCoffin: CharacterAdded:Wait, WaitForChild timeout 5с
- [x] 2.9 InteractBlock remote — FunctionalDispatcher маршрутизация (Door, Chest, Station, CraftStation готовы; Altar/Coffin — заглушки)
- [ ] 2.10 Укрытие от солнца — DayNightManager.isInShelter() с крышей замка (IsShelter)
- [x] 2.11 BuildingManager destroyCastle — ChestHandler.dropAllLoot + CraftStationHandler.dropAllLoot каскадный дроп

---

## Phase 3: Integration & Polish — НЕ НАЧАТА

- [x] 3.1 BlockCategoryTabs — категории уже встроены в BuildingMenu (табы)
- [ ] 3.2 MenuBar — кнопка Build (B)
- [ ] 3.3 Minimap — отображение замков (dot на центр)
- [ ] 3.4 DataStore stress test — 500 блоков + 100 врагов + 4 игрока
- [ ] 3.5 Visual polish — эффекты размещения/удаления, звуки
- [ ] 3.6 Регрессионное тестирование — все системы 1.0–1.8

---

## Внеплановые задачи (выполнены в ходе работы)

### UI-система

- [x] WindowManager — единый менеджер открытых окон, закрытие по Esc (через GuiService.MenuOpened)
- [x] Tooltip рефакторинг — перемещён из `ui/character/tooltip/` в `ui/tooltip/`, доступен всем UI
- [x] ContainerUI + CharacterWindow связка — F открывает оба окна, F закрывает оба
- [x] ContainerUI — ПКМ по слоту сундука → TakeItem, disabled кнопки при пустом сундуке
- [x] ContainerUI — tooltip при наведении на слоты (через SharedTooltip)
- [x] ContainerUI — fix: tooltip скрывается при перестройке сетки слотов
- [x] ContainerUI — fix: повторное открытие замкового сундука (ContainerEmpty + isCasting reset)
- [x] DepositItem remote — перекладывание предметов из инвентаря в сундук (ПКМ в CharacterWindow)
- [x] MenuBar — добавлены кнопки CharacterWindow (C) и ServantWindow (V)
- [x] WindowManager интеграция — CharacterWindow, ContainerUI, ServantWindow, BuildingMenu, CastleHeartUI, JournalWindow, CraftStationUI

### Processing Stations (Sawmill, Crusher)

- [x] StationHandler — универсальный обработчик (input/output, автокрафт, heartbeat, viewers, сериализация)
- [x] StationUI — drag-and-drop input/output, прогресс-бар с клиентской интерполяцией (RenderStepped)
- [x] StationConfig — Sawmill, Crusher (InputSlots=8, OutputSlots=8)
- [x] Station remotes — StationOpened, StationUpdate, StationClosed, StationDeposit, StationTakeItem, StationTakeInput, StationTakeAll, StationToggleRecipe, StationClose
- [x] SlotBehavior — ПКМ deposit приоритет: CraftStation > Station > Chest > Default

### CraftStation система (Workbench, масштабируемая)

- [x] CraftStationHandler — серверный контейнер (N слотов), очередь крафта, heartbeat, ресурсы из контейнера → инвентарь, результат в контейнер, дроп при разрушении, многопользовательский доступ, сериализация
- [x] CraftStationUI — рецепты в 2 колонки (как CraftPanel), контейнер (1 ряд), tooltip с подсчётом ресурсов (контейнер + инвентарь), прогресс-бар в рецепте, очередь (badge), авто-открытие CharacterWindow
- [x] StationConfig.CraftStations — Workbench (Slots=9)
- [x] BuildingConfig — workbench: `Functional = "CraftStation"`, `FunctionalData.StationType = "Workbench"`
- [x] CraftConfig — рецепты с `Station = "Workbench"`
- [x] FunctionalDispatcher — маршрут `CraftStation → CraftStationHandler`
- [x] CraftStation remotes — CraftStationOpened, CraftStationUpdate, CraftStationClosed, CraftStationDeposit, CraftStationTakeItem, CraftStationCraft, CraftStationClose
- [x] InventoryGrid — обработка drag source `"craftStationSlot"`

### DragManager

- [x] Расширение API — source, extraData, getSource(), DragLayer ScreenGui (DisplayOrder 1000)
- [x] Fix — GuiInset компенсация в tryDrop (mousePos смещение на ~36px)

### BuildingMenu / BuildingPlacer

- [x] Fix — closeBuildingMenu() не вызывает cleanup при активном placer
- [x] BuildingPlacer.isActive() — проверка ghostModel

### Сохранение

- [x] DataService.save — fix version conflict (UpdateAsync retry, didWrite flag)
- [x] Castle persistence — сохранение/загрузка замка с фундаментами и сундуками через DataStore

### Исправленные пути require

- [x] ServantEquipPanel — tooltip path fix (`character/tooltip` → `tooltip`)

---

## Сводка: что осталось сделать

### Phase 2 (3 задачи):

| # | Задача | Сложность | Зависимости |
|---|---|---|---|
| 2.6 | BloodAltarHandler | Medium | FunctionalDispatcher, BloodManager(?), OpenBloodAltar remote |
| 2.7 + 2.8 | CoffinHandler + respawnAtCoffin | Medium | FunctionalDispatcher, HealthManager, BuildingManager.getCoffinPos |
| 2.10 | Укрытие от солнца | Low | DayNightManager, BlockTypes.IsShelter |

### Phase 3 (4 задачи):

| # | Задача | Сложность |
|---|---|---|
| 3.2 | MenuBar — кнопка Build (B) | Low |
| 3.3 | Minimap — замки | Low |
| 3.4 | DataStore stress test | High |
| 3.5 + 3.6 | Visual polish + регрессия | High |

### Масштабирование CraftStation

Добавление новой крафтовой станции (Forge, Alchemy Lab, ...):
1. `StationConfig.CraftStations.Forge = { Name = "Кузница", Slots = 9 }`
2. `BuildingConfig: forge = { Functional = "CraftStation", FunctionalData = { StationType = "Forge" } }`
3. `CraftConfig: рецепты с Station = "Forge"`
4. Ноль изменений в коде — подхватывается автоматически.

### Итого: ~7 задач до релиза v1.9