# Building System

> Строительство замков, функциональные блоки, перерабатывающие станции.

---

## Архитектура

Строительная система реализована как серверно-авторитетная: все мутации проходят через серверные remotes, клиент отображает результат. Центральный модуль — `BuildingManager`, remote-оркестратор — `BuildingServer.server.luau`.

### Серверные модули (`server/modules/building/`)

| Модуль | Назначение |
|---|---|
| BuildingManager.luau | CRUD замков и блоков: placeCastleHeart, placeBlock, removeBlock, upgradeHeart, destroyCastle, initPlayer, collect |
| BuildingValidator.luau | Валидация размещения: коллизии, PlacementRule (Ground, OnFoundation, OnWall), границы claim |
| BuildingSerializer.luau | Сериализация/десериализация замков для DataStore: блоки, контейнеры (containerId), станции (stationId) |
| CastleBorder.luau | Claim-территория: hasCastle, canPlace, canInteract, setPermission, addAlly, removeAlly |
| CastleHeartManager.luau | Визуал Castle Heart: платформа, пьедестал, орб (цвет/размер от BloodEssence), свет |
| BlockHealth.luau | HP блоков, обработка урона, разрушение → EventBus (BlockDestroyedByDamage) |
| FunctionalDispatcher.luau | Маршрутизатор: по `bt.Functional` направляет в Door/Chest/Station хендлеры |
| DoorHandler.luau | Двери: initDoor, interact (открыть/закрыть с анимацией), cleanup |
| ChestHandler.luau | Сундуки: onCreate, interact (открыть UI), onDestroy (дроп содержимого), deposit/take/sort |
| StationHandler.luau | Универсальный обработчик станций (Sawmill, Crusher, ...): onCreate, interact, onDestroy, Heartbeat крафт-цикл, deposit/take/toggle, сериализация |

### Remote-оркестратор (`server/building/BuildingServer.server.luau`)

| Секция | Remotes |
|---|---|
| Castle Heart | PlaceCastleHeart, UpgradeCastleHeart, DestroyCastle |
| Блоки | PlaceBlock, RemoveBlock |
| Permissions | SetBuildPermission, AddBuildAlly, RemoveBuildAlly |
| Interact | InteractBlock → FunctionalDispatcher.interact() |
| Станции | StationDeposit, StationTakeItem, StationTakeAll, StationToggleRecipe, StationClose |
| Запросы | GetBuildings (RemoteFunction), GetCastleHeartInfo (RemoteFunction) |

Rate-limit 0.3с на мутирующие операции. Cleanup при PlayerRemoving и PlayerCleanup EventBus.

### Клиентские модули (`client/ui/building/`)

| Модуль | Назначение |
|---|---|
| StationUI.client.luau | Универсальный UI станций: рецепты (2 колонки с toggle), input/output слоты (4×2), progress bar, Take All |
| BlockInteract.client.luau | Сканирование ближайших функциональных блоков (кроме Chest — обрабатывается ContainerUI), billboard-подсказка [F], отправка InteractBlock |

### Связанные клиентские модули

| Модуль | Связь со строительной системой |
|---|---|
| WindowManager.luau | Стек окон: StationUI использует push/remove для управления Escape-закрытием |
| SlotBehavior.luau | ПКМ на слоте инвентаря → deposit в открытую станцию (приоритет 1) или сундук (приоритет 2) |
| ContainerUI.client.luau | UI сундуков (отдельный от StationUI) |
| CharacterWindow.client.luau | Автоматически открывается/закрывается при open/close станции через BindableEvent ToggleCharacterWindow |

---

## Castle Heart

Основа замка. Определяет территорию (ClaimRadius) и лимиты (MaxBlocks, MaxCoffins).

### Уровни

| Уровень | HP | MaxBlocks | ClaimRadius | MaxCoffins | UpgradeCost |
|---|---|---|---|---|---|
| 1 | 1000 | 200 | 48 | 1 | — |
| 2 | 2000 | 350 | 56 | 2 | 100 Blood Essence |
| 3 | 3000 | 500 | 64 | 3 | 250 Blood Essence |

### Визуал

Castle Heart состоит из платформы (Slate, 8×2×8), пьедестала (Basalt цилиндр) и орба (Neon сфера). Размер и цвет орба интерполируются от BloodEssence: пустой — маленький тёмный (40,10,10), полный — большой яркий (220,30,30). PointLight с динамической яркостью и дальностью.

---

## Блоки

### Категории

| Id | Название | Порядок |
|---|---|---|
| Foundation | Фундамент | 1 |
| Wall | Стены | 2 |
| Roof | Крыша | 3 |
| Functional | Интерьер | 4 |

### PlacementRule

| Правило | Описание |
|---|---|
| Ground | Размещается на земле (фундаменты, Castle Heart) |
| OnFoundation | Требует фундамент под собой (стены, мебель) |
| OnWall | Требует стены рядом (крыши) |

### Типы блоков (BuildingConfig.BlockTypes)

| Id | Категория | Размер | Material | HP | Стоимость | Functional |
|---|---|---|---|---|---|---|
| stone_foundation | Foundation | 8×2×8 | Slate | 500 | 10 stone | — |
| wooden_foundation | Foundation | 8×2×8 | WoodPlanks | 300 | 5 plank | — |
| stone_wall | Wall | 8×8×2 | Slate | 400 | 8 stone | — |
| wooden_wall | Wall | 8×8×2 | WoodPlanks | 250 | 4 plank | — |
| stone_pillar | Wall | 2×8×2 | Slate | 600 | 6 stone | — |
| wooden_roof | Roof | 8×1×8 | WoodPlanks | 200 | 4 plank | IsShelter |
| stone_roof | Roof | 8×1×8 | Slate | 400 | 8 stone | IsShelter |
| wooden_door | Functional | 8×8×1 | Wood | 150 | 3 plank | Door |
| castle_chest | Functional | 4×4×4 | WoodPlanks | 100 | 6 plank + 2 stone | Chest |
| workbench | Functional | 6×4×4 | WoodPlanks | 150 | 8 plank + 4 stone | Workbench |
| blood_altar | Functional | 6×6×6 | Basalt | 300 | 15 stone + 50 blood_essence | BloodAltar |
| coffin | Functional | 4×2×8 | Wood | 200 | 10 plank + 20 blood_essence | Coffin |
| sawmill | Functional | 16×4×8 | WoodPlanks | 200 | 12 plank + 8 stone | Station (Sawmill) |
| crusher | Functional | 16×4×8 | Slate | 200 | 20 stone + 4 plank | Station (Crusher) |

---

## Функциональные блоки

### FunctionalDispatcher

Маршрутизатор: читает `bt.Functional` из BuildingConfig и направляет вызовы в соответствующие хендлеры.

| bt.Functional | Хендлер | Описание |
|---|---|---|
| Door | DoorHandler | Открытие/закрытие двери |
| Chest | ChestHandler | Контейнер хранения (→ ContainerUI) |
| Station | StationHandler | Перерабатывающая станция (→ StationUI) |
| Workbench | — | Зарезервировано |
| BloodAltar | — | Зарезервировано |
| Coffin | — | Точка респавна (обрабатывается BuildingManager) |

### Двери (DoorHandler)

Interact переключает состояние открыто/закрыто. Визуально дверь поворачивается на 90° (CFrame tween).

### Сундуки (ChestHandler)

12 слотов по умолчанию (`FunctionalData.Slots`). Interact открывает ContainerUI. Поддерживает deposit, take, takeAll, sort. При разрушении замка содержимое дропается на землю.

---

## Перерабатывающие станции

### Концепция

Станция — функциональный блок с `Functional = "Station"` и `FunctionalData.StationType`. Все станции обрабатываются единым `StationHandler.luau`. Тип станции определяет доступные рецепты (фильтр по `recipe.Station == stationType`).

### StationConfig

Определяется в `src/shared/config/StationConfig.luau`, загружается через Config.luau в `Config.Stations`.

| Параметр | Sawmill | Crusher |
|---|---|---|
| Name | Лесопилка | Дробилка |
| InputSlots | 8 | 8 |
| OutputSlots | 8 | 8 |
| InteractRange | 10 | 10 |
| CraftingColor | RGB(180,140,60) | RGB(140,140,180) |

### Рецепты станций (CraftConfig)

Рецепты станций определяются в `CraftConfig.luau` с полем `Station`:

| Id | Station | Название | Вход | Выход | Время |
|---|---|---|---|---|---|
| sawmill_plank | Sawmill | Доска + Опилки | 10 wood | 5 wooden_plank + 10 sawdust | 3с |
| sawmill_blood_plank | Sawmill | Кровавая доска | 10 wooden_plank + 10 blood_essence | 10 blood_plank | 4с |
| sawmill_trash | Sawmill | Переработка в мусор | 10 wood + 10 stone | 20 trash | 2с |
| crusher_stone_brick | Crusher | Каменный кирпич | 20 stone | 5 stone_brick | 3с |

Рецепты с полем `Station` не отображаются в ручном крафте (CraftPanel фильтрует их).

Станционные рецепты используют поле `Results` (массив `{ItemId, Amount}`) вместо `Result` для поддержки мульти-результатов. Однорезультатные рецепты могут использовать как `Result`, так и `Results`.

### StationHandler — серверная логика

Состояние каждой станции хранится в `stationData[blockId]`:

| Поле | Тип | Описание |
|---|---|---|
| stationId | string | Уникальный идентификатор (station_sawmill_12345_67890) |
| stationType | string | "Sawmill", "Crusher", ... |
| part | BasePart | Физический блок в мире |
| inputSlots | table | 8 слотов входа: false или {ItemId, Amount} |
| outputSlots | table | 8 слотов выхода: false или {ItemId, Amount} |
| recipeToggles | table | {[recipeId] = bool} — включение/выключение рецептов |
| crafting | table или nil | {recipeId, elapsed, duration} — текущий крафт |
| viewers | table | {[userId] = Player} — кто сейчас смотрит UI |
| originalColor | Color3 | Цвет блока до крафта |

Крафт-цикл: RunService.Heartbeat → для каждой станции проверяется наличие ингредиентов и места в output → запускается крафт → по завершении результат помещается в output. Во время крафта цвет блока меняется на CraftingColor.

API StationHandler:

| Метод | Описание |
|---|---|
| onCreate(part, typeId, blockId, castle) | Создать станцию, зарегистрировать, запустить Heartbeat |
| interact(player, part, blockData, castle) | Открыть UI для игрока (StationOpened remote) |
| onDestroy(part, blockId) | Дропнуть содержимое, уведомить viewers, очистить |
| depositToInput(player, stationId, slotIndex) | Переложить из инвентаря в input станции |
| takeFromOutput(player, stationId, slotIndex) | Забрать из output в инвентарь |
| takeAllOutput(player, stationId) | Забрать всё из output |
| toggleRecipe(player, stationId, recipeId) | Вкл/выкл рецепт. Если отключён текущий крафт — отменить и вернуть ингредиенты |
| closeStation(player, stationId) | Удалить из viewers |
| getSerializer() | Вернуть функцию сериализации для DataStore |
| restoreContainer(part, typeId, blockId, castle, savedData) | Восстановить станцию из сохранения |
| dropAllLoot(castle) | Дропнуть содержимое всех станций замка |
| getStationId(blockId) | Получить stationId по blockId |

### StationUI — клиентская логика

Файл: `client/ui/building/StationUI.client.luau`

ScreenGui "StationGui", DisplayOrder 815. Расположен справа (RIGHT_MARGIN 260, TOP_OFFSET 40). Ширина больше CharacterWindow, высота такая же.

Структура окна:

| Секция | Описание |
|---|---|
| Заголовок | Название станции из payload.StationName, кнопка закрытия |
| Рецепты | ScrollingFrame, 2 колонки. Каждый рецепт: toggle (вкл/выкл), иконка результата, название |
| Progress Bar | Текущий крафт: название, elapsed/duration |
| Input (Вход) | 4×2 слотов — сюда кладутся ингредиенты (ПКМ из инвентаря) |
| Output (Выход) | 4×2 слотов — отсюда забирается результат (клик) |
| Забрать всё | Кнопка: забирает весь output в инвентарь |

При открытии станции автоматически открывается окно персонажа (CharacterWindow) через BindableEvent. При закрытии — закрывается тоже.

WindowManager интеграция: `push("StationUI", closeFn)` при открытии, `remove("StationUI")` при закрытии. Escape закрывает верхнее окно в стеке.

Публичное состояние для SlotBehavior: BoolValue "StationOpen" и StringValue "StationOpenId" в ScreenGui "StationGui".

### BlockInteract — клиентская логика

Файл: `client/ui/building/BlockInteract.client.luau`

Сканирует ближайшие функциональные блоки (SCAN_INTERVAL 0.15с) в папке workspace.Castles. Исключает Chest (обрабатывается ContainerUI). При обнаружении показывает Billboard-подсказку с текстом по типу блока. Нажатие F → `InteractBlock:FireServer(blockId)`.

Подсказки:

| Functional | Текст |
|---|---|
| Door | [F] Открыть / Закрыть |
| Chest | (исключён — ContainerUI) |
| Station | [F] Открыть станцию |
| Workbench | [F] Верстак |
| BloodAltar | [F] Алтарь крови |
| Coffin | [F] Гроб |

---

## Сериализация (DataStore)

BuildingSerializer сохраняет данные замка:

| Поле | Описание |
|---|---|
| CenterPos | Позиция Castle Heart |
| Claim | Данные claim-территории |
| BloodEssence | Запас эссенции в сердце |
| Blocks | Массив: {typeId, position, rotation} для каждого блока |
| Containers | Массив: {Id, Ref, Slots} для сундуков |

Для станций: `block.stationId` сериализуется вместе с блоком. StationHandler.getSerializer() возвращает функцию, сохраняющую InputSlots, OutputSlots, RecipeToggles, StationType. Восстановление через StationHandler.restoreContainer().

---

## Права доступа

CastleBorder управляет правами:

| Право | По умолчанию | Описание |
|---|---|---|
| AllowCoopBuild | false | Союзники могут строить |
| AllowCoopRemove | false | Союзники могут разрушать |
| AllowCoopInteract | true | Союзники могут взаимодействовать (двери, сундуки, станции) |

Союзники добавляются/удаляются через AddBuildAlly/RemoveBuildAlly remotes.

---

## Экономика

Размещение блока расходует материалы (`Cost` в BlockTypes). Удаление возвращает `RemoveRefundRate` (50%) стоимости. Сетка: GridSize = 8 studs.

---

## WindowManager

Файл: `client/ui/WindowManager.luau`

Стек окон для управления Escape-закрытием. API:

| Метод | Описание |
|---|---|
| push(name, closeFn) | Добавить окно в стек с функцией закрытия |
| remove(name) | Убрать окно из стека |

При нажатии Escape вызывается closeFn верхнего окна в стеке. Используется StationUI, ContainerUI и другими модальными окнами.

---

## Новые ресурсы (v1.9)

| Id | Название | MaxStack | Описание |
|---|---|---|---|
| wooden_plank | Доска | 500 | Обработанная древесина, строительный материал |
| sawdust | Опилки | 500 | Побочный продукт лесопилки |
| blood_plank | Кровавая доска | 500 | Доска, пропитанная кровавой эссенцией |
| trash | Мусор | 500 | Отходы обработки |
| stone_brick | Кирпич | 500 | Обработанный камень |