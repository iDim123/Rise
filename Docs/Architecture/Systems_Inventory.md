# Inventory System

> Инвентарь, предметы, экипировка, крафт, ActionBar, сумки.

---

## Архитектура

Инвентарь управляется серверным `InventoryManager` с авторитетной валидацией. Клиент получает полные снапшоты через `UpdateInventory` remote. Все мутации проходят через серверные remotes.

### Серверные модули

| Модуль | Назначение |
|---|---|
| InventoryManager.luau | CRUD: addItem, removeItem, swapSlots, equip, unequip, activeWeapon, bag slots |
| InventorySync.luau | sendFullUpdate(player), getFullData(player) — единая точка синхронизации |
| InventoryServer.server.luau | Оркестратор: подключает remotes к обработчикам |
| WeaponHandler.luau | Обработка SetActiveWeapon: экипировка Tool на персонажа |
| CraftHandler.luau | Очередь крафта: валидация рецепта, расход материалов, создание предмета |
| UseItemHandler.luau | Использование Consumable: Heal, AddServant, ApplyBuffs, DrinkBloodVial |

### Клиентские модули (`client/ui/character/`)

| Модуль | Назначение |
|---|---|
| CharacterWindow.client.luau | Оркестратор окна персонажа (клавиша C) |
| InventoryGrid.luau | Сетка инвентаря: слоты, drag-and-drop, обработка drag из station source |
| EquipmentPanel.luau | Левая и правая панели экипировки |
| ActionBarHUD.luau | Нижняя панель 1-8 (слоты из инвентаря) |
| CraftPanel.luau | Панель крафта: список рецептов, прогресс (фильтрует станционные рецепты) |
| SlotFactory.luau | Создание UI-слотов |
| SlotBehavior.luau | Поведение слотов: клик, ПКМ, drag, deposit в станцию/сундук |
| DragManager.luau | Drag-and-drop: ghost-элемент, drop targets, source routing, DragLayer ScreenGui |
| CooldownManager.luau | Визуальный cooldown (шторка + таймер) |
| UIConstants.luau | Layout, размеры, цвета |
| tooltip/ | Модульный ItemTooltip (DisplayOrder 999) |

---

## Структура инвентаря

### Слоты

По умолчанию 24 слота (3 ряда × 8 колонок), максимум 40 (5 рядов × 8 колонок). Дополнительные ряды разблокируются сумками (Bag). Слоты 1–8 — ActionBar (отображаются внизу экрана).

Пустой слот = `false`. Занятый слот — таблица:

```lua
{
    Id = "iron_axe",
    Name = "Iron Axe",
    Icon = "rbxassetid://...",
    Amount = 1,
    Type = "Weapon",
    ItemLevel = 8,
    Stackable = false,
    MaxStack = 1,
    -- опционально:
    EquipSlot = "Chest",
    Stats = { HP = 20, PhysResistance = 5 },
    UseEffect = { Type = "Heal", Amount = 50 },
    BagData = { ExtraRows = 1 }
}
Copy
Экипировка
Два столбца слотов экипировки:

Левая панель	Правая панель
Head	Cloak
Chest	Amulet
Legs	Ring1
Feet	Ring2
Hands	Bag
Экипировка предмета: EquipItem:FireServer(slotIndex) → сервер проверяет тип, EquipSlot, перемещает предмет из инвентаря в экипировку. Снятие: UnequipItem:FireServer(equipSlotId) → возвращает в первый свободный слот.

Активное оружие
activeWeaponSlot — номер слота ActionBar (1–8) с выбранным оружием. Переключение: клавиши 1–8 или SetActiveWeapon:FireServer(slotIndex). При смене: InventoryManager обновляет activeWeaponSlot, WeaponHandler удаляет текущий Tool с персонажа, WeaponHandler клонирует шаблон из ServerStorage.weapons и ставит на персонажа. Если шаблон не найден — создаётся fallback Tool (невидимый, с Handle). InventorySync.sendFullUpdate обновляет клиент. При swapSlots activeWeaponSlot перемещается вместе с оружием.

Предметы
Определение
Все предметы определяются в src/shared/config/items/ через подмодули. ItemConfig.luau — коллектор, собирающий все подмодули в Config.Items.

Подмодули
Файл	Содержание
WeaponItems.luau	Sword of Light, Iron Axe, Hunting Bow
ArmorItems.luau	Hide Helmet, Hide Chest, Hide Legs, Hide Boots, Hide Gloves
AccessoryItems.luau	Cloak, Amulet, Ring
ConsumableItems.luau	Health Potion, Blood Vial, Servant Egg
ResourceItems.luau	Blood Essence, Wood, Stone, Rugged Hide, Wooden Plank, Sawdust, Blood Plank, Trash, Stone Brick
Типы предметов (Config.ItemTypes)
Type	Stackable	Действия
Weapon	Нет	Экипировка в ActionBar, SetActiveWeapon
Armor	Нет	Экипировка в слот (Head/Chest/Legs/Feet/Hands)
Accessory	Нет	Экипировка в слот (Cloak/Amulet/Ring1/Ring2)
Consumable	Да	Использование (ПКМ или UseItem remote)
Resource	Да	Материал для крафта и строительства
Bag	Нет	Экипировка в слот Bag, разблокирует ряды
Поля предмета
Поле	Тип	Обязательное	Описание
Id	string	Да	Уникальный идентификатор
Name	string	Да	Отображаемое имя
Description	string	Да	Описание
Icon	string	Да	rbxassetid://
Type	string	Да	Weapon/Armor/Accessory/Consumable/Resource/Bag
ItemLevel	number	Да	Уровень предмета
Stackable	bool	Да	Можно ли складывать в стак
MaxStack	number	Да	Максимальный размер стака
EquipSlot	string	Нет	Слот экипировки (Head, Chest, и т.д.)
Stats	table	Нет	Бонусы статов: { HP, PhysResistance, ... }
UseEffect	table	Нет	Эффект при использовании (Consumable)
BagData	table	Нет	{ ExtraRows = number }
UseEffect типы
Type	Поля	Описание
Heal	Amount	Восстановить HP
AddServant	ServantType	Создать слугу
ApplyBuffs	Buffs: { {BuffId, Duration} }	Наложить баффы
DrinkBloodVial	BloodType, Quality	Установить кровь
Крафт
Обзор
Клиент отправляет CraftItem:FireServer(recipeId). Сервер (CraftHandler) валидирует рецепт, проверяет материалы и разблокированные технологии, расходует материалы, создаёт предмет и обновляет инвентарь.

Рецепты (CraftConfig)
Рецепты определяются в CraftConfig.luau. Каждый рецепт содержит:

Поле	Описание
Id	Уникальный идентификатор рецепта
Name	Отображаемое имя
Description	Описание рецепта
Icon	rbxassetid://
Result	{ ItemId, Amount } — результат крафта (одиночный)
Results	{ {ItemId, Amount}, ... } — мульти-результат (для станций; если задан, Result игнорируется)
Ingredients	{ {ItemId, Amount}, ... } — требуемые материалы
CraftTime	Время крафта в секундах
RequiresTech	Требуемая технология босса (опционально)
Station	Тип станции: "Sawmill", "Crusher" и т.д. Если nil — ручной крафт
Станционные рецепты
Рецепты с полем Station доступны только в соответствующей станции и не отображаются в ручном крафте (CraftPanel). CraftPanel фильтрует: if recipe.Station and recipe.Station ~= "Hand" then continue end. Станционные рецепты обрабатываются StationHandler на сервере, а не CraftHandler.

Технологии
Некоторые рецепты требуют разблокированную технологию (RequiresTech). Технологии разблокируются при первом убийстве босса и сохраняются в DataStore.

Клиент (CraftPanel)
CraftPanel.luau отображает список доступных ручных рецептов, необходимые материалы (зелёный — достаточно, красный — нет), кнопку крафта и прогресс-бар. Заблокированные рецепты (RequiresTech) показываются затемнёнными. Станционные рецепты скрыты.

Remotes
Remote	Направление	Описание
CraftItem	Client → Server	Запрос ручного крафта
CraftQueueUpdate	Server → Client	Обновление прогресса
Сумки (Bags)
Сумка — предмет типа Bag с BagData = { ExtraRows = N }. При экипировке в слот Bag разблокируются N дополнительных рядов (по 8 слотов). Максимум: 5 рядов × 8 = 40 слотов.

При снятии сумки, если в разблокированных слотах есть предметы — они выбрасываются на землю через DropItem.

Синхронизация
Любое изменение инвентаря вызывает InventorySync.sendFullUpdate(player). Формат данных:

Copy{
    slots = { [1] = false, [2] = { Id = "wood", Amount = 5, ... }, ... },
    equipment = { Head = false, Chest = { Id = "hide_chest", ... }, ... },
    activeWeaponSlot = 3,
    unlockedSlots = 24
}
Клиент получает через UpdateInventory remote и полностью перерисовывает UI.

Начальная загрузка: клиент вызывает GetInventory:InvokeServer() при инициализации CharacterWindow.

Drag-and-Drop
DragManager управляет перетаскиванием предметов между слотами.

DragManager API
Метод	Описание
init(gui)	Инициализация (screenGui для привязки)
startDrag(slotIndex, itemData, source?, extraData?)	Начать drag. source: "inventory" (по умолчанию), "stationInput", "stationOutput". extraData: { stationId }
createGhost(itemData)	Создать ghost-элемент в DragLayer ScreenGui (DisplayOrder 1000)
destroyGhost()	Уничтожить ghost
isDragging() → bool	Активен ли drag
getSource() → string?	Вернуть source текущего drag
getDragData() → table?	Вернуть { slotIndex, item, source, extraData }
registerDropTarget(frame, callback)	Зарегистрировать drop target
unregisterDropTarget(frame)	Снять регистрацию
tryDrop(mousePos) → bool	Проверить drop targets под курсором
reset(slotFrames)	Сбросить состояние drag
Ghost-элемент рендерится в отдельном ScreenGui "DragLayer" (DisplayOrder 1000) — гарантированно поверх всех окон включая StationUI (815).

Поток drag-and-drop
Зажатие ЛКМ на слоте → DragManager.startDrag(slotIndex, itemData, source). Ghost-элемент следует за курсором (RenderStepped). Отпускание ЛКМ → InventoryGrid обрабатывает в InputEnded.

Обработка завершения drag (InventoryGrid)
При отпускании ЛКМ InventoryGrid проверяет source из dragData:

Source	Поведение при отпускании
"inventory"	tryDrop → swap между слотами → equip → drop за UI
"stationInput"	tryDrop → если не dropped: StationTakeInput:FireServer(stationId, slotIndex)
"stationOutput"	tryDrop → если не dropped: StationTakeItem:FireServer(stationId, slotIndex)
Для station source: если drag отпущен не над зарегистрированным drop target — предмет забирается в инвентарь через соответствующий remote.

Drop targets
Цель	Действие
Слот инвентаря	SwapSlots (обмен предметами) — только для source="inventory"
Слот экипировки	EquipItem (авто-экипировка) — только для source="inventory"
Input-слот станции	StationDeposit (положить из инвентаря) — только для source="inventory"
За пределами UI	DropItem (выброс на землю) — только для source="inventory"
SlotBehavior — ПКМ приоритеты
При ПКМ на слоте инвентаря SlotBehavior проверяет приоритеты:

Приоритет	Условие	Действие
1	StationGui.StationOpen == true	StationDeposit:FireServer(stationId, slotIndex)
2	ContainerUI.ContainerOpen == true	ContainerDepositItem:FireServer(containerId, slotIndex)
3	Предмет с EquipSlot	EquipItem:FireServer(slotIndex)
3	Consumable	UseItem:FireServer(slotIndex) (с cooldown)
3	Weapon	SetActiveWeapon:FireServer(slotIndex)
Tooltip
Модульная система в character/tooltip/. ItemTooltip.init(gui) создаёт ScreenGui с DisplayOrder 999.

Подмодули
Модуль	Описание
init.luau	Создание ScreenGui, управление показом/скрытием
TooltipConstants.luau	Размеры, цвета, отступы
TooltipHeader.luau	Иконка, имя, тип, уровень предмета
TooltipAttributes.luau	Бонусы статов (зелёный текст)
TooltipDescription.luau	Описание предмета
TooltipFooter.luau	Подсказка действия (ПКМ — использовать, и т.д.)
InventoryManager API
Метод	Описание
create(player)	Создание инвентаря (24/40 слотов, equipment, activeWeaponSlot)
getInventory(player) → table	Полная структура инвентаря
addItem(player, itemData) → bool, slotIndex	Добавить предмет (стакинг в существующие, затем новый слот)
addItemFromConfig(player, itemId, amount) → bool	Добавить предмет по Id из Config.Items
removeItem(player, slotIndex, amount) → bool	Удалить предмет/уменьшить стак по индексу слота
removeItemById(player, itemId, amount) → bool	Удалить указанное количество по Id (из нескольких стаков)
countItem(player, itemId) → number	Подсчёт количества предмета во всём инвентаре
swapSlots(player, from, to) → bool	Обмен слотов (с проверкой locked)
equipItem(player, slotIndex) → bool	Экипировать предмет
unequipItem(player, equipSlotId) → bool	Снять экипировку
setActiveWeapon(player, slotIndex) → bool	Выбрать активное оружие
getSlots(player) → table	Получить все слоты
getEquipment(player) → table	Получить экипировку
getActiveWeaponSlot(player) → number	Номер слота активного оружия
getUnlockedSlots(player) → number	Количество разблокированных слотов
recalcUnlockedSlots(player)	Пересчёт разблокированных слотов (после смены сумки)
getItemsInLockedSlots(player) → table	Извлечь предметы из заблокированных слотов
remove(player)	Удалить инвентарь игрока из памяти

---

### 5. `Systems_UI.md`

Изменения: DragLayer в ScreenGui иерархии, обновлён StationUI (drag-and-drop, progress bar интерполяция), обновлён DragManager описание, добавлены BuildingMenu и BuildingPlacer.

```md
# UI Systems

> Все клиентские UI модули: HUD, окна, tooltip, уведомления.

---

## Архитектура

Каждый UI модуль — отдельный LocalScript или ModuleScript в `src/client/ui/`. Большинство создают собственный ScreenGui программно (без prefab). Обновление данных — event-driven через Remotes, не polling.

### ScreenGui иерархия (DisplayOrder)

| DisplayOrder | ScreenGui | Модуль |
|---|---|---|
| 1 | PlayerHUD | PlayerHPBlock, ServantHPBlock |
| 5 | BloodPoolGui | BloodPoolUI |
| 10 | EnemyHPBarGui | EnemyHPBar (Billboard) |
| 12 | BlockInteractUI | BlockInteract (Billboard-подсказка [F]) |
| 15 | EnemyLabelsGui | EnemyLabels (Billboard) |
| 20 | CastBarUI | CastBar |
| 30 | BuffBarGui | BuffBar |
| 40 | DamageNumbersGui | DamageNumbers |
| 50 | ResourceNumbersGui | ResourceNumbers |
| 100 | TargetInfoGui | TargetInfo |
| 200 | MinimapGui | Minimap |
| 300 | DayNightGui | DayNightHUD |
| 500 | DeathScreenGui | DeathScreen |
| 700 | LootGui | LootUI |
| 750 | NotifyGui | NotifyModule |
| 800 | CharacterWindowGui | CharacterWindow |
| 805 | ServantWindowGui | ServantWindow |
| 810 | AbilitiesBarGui | AbilitiesBar |
| 815 | StationGui | StationUI (перерабатывающие станции) |
| 820 | ContainerGui | ContainerUI |
| 850 | CaptureGui | CaptureUI |
| 900 | AbilityTooltipGui | AbilityTooltip |
| 950 | JournalGui | JournalWindow (Bosses + Spellbook) |
| 999 | ItemTooltipGui | ItemTooltip |
| 1000 | DragLayer | DragManager ghost-элемент (поверх всех окон) |

---

## HUD — постоянные элементы

### PlayerHPBlock

Файл: `PlayerHPBlock.client.luau`

HP bar, XP bar и круг уровня игрока. Расположен в левом нижнем углу. Обновляется через `DamageEvent`, `HealEvent`, `UpdateLevel` remotes. Tween-анимация при изменении HP.

### ServantHPBlock

Файл: `ServantHPBlock.client.luau`

HP bar, XP bar и круг уровня активного слуги. Расположен под PlayerHPBlock. Обновляется через `DamageEvent`, `UpdateServantLevel`. Скрывается если слуга не призван.

### BloodPoolUI

Файл: `BloodPoolUI.client.luau`

Колба крови справа от HP bar. Показывает тип крови (цвет), качество (tween fill), количество (убывающий уровень). Обновляется через `UpdateStats` remote.

### BuffBar

Файл: `BuffBar.client.luau`

Активные баффы/дебаффы в левом верхнем углу. Каждый слот: иконка, таймер обратного отсчёта, рамка (зелёная — бафф, красная — дебафф). Tooltip при наведении. Обновляется через `UpdateBuffs` remote.

### AbilitiesBar

Файл: `abilities/AbilitiesBar.client.luau`

8 слотов способностей внизу экрана: LMB, Q, E, Space, R, T, Z, X. Иконки привязаны к текущему оружию. Обновляется event-driven при смене Tool (ChildAdded/ChildRemoved). Нажатие Q/E/... отправляет `UseAbility` remote.

Зависимости: `AbilityTooltip.luau` — tooltip с описанием, уроном, cooldown (отдельный ScreenGui, DisplayOrder 900). `AbilityCooldowns.luau` — визуальный cooldown: шторка сверху вниз + число секунд.

### ActionBarHUD

Файл: `character/ActionBarHUD.luau`

Нижняя панель слотов 1–8 из инвентаря. Отображает предметы, подсветку активного оружия, cooldown consumable. Интегрирован с CharacterWindow через SlotFactory и SlotBehavior.

### DayNightHUD

Файл: `DayNightHUD.client.luau`

Индикатор времени суток и фазы луны. Обновляется через Remotes или Lighting изменения.

### Minimap

Файл: `Minimap.client.luau`

Круглая карта с фиксированной ориентацией (север = вверх). Иконка игрока вращается по LookVector. Зум: кнопки +/− и скролл мыши (при наведении на миникарту).

| Точка | Цвет | Описание |
|---|---|---|
| Игрок | Белый | Иконка с направлением |
| Враги | Красный | Все враги в радиусе |
| Боссы | Фиолетовый | Боссы |
| Игроки | Синий | Другие игроки |
| Ресурсы | Жёлтый | Ресурсные ноды |

Dot pool для производительности — переиспользование UI элементов вместо создания новых.

---

## Боевой HUD

### CastBar

Файл: `CastBar.client.luau`

Полоска каста с иконкой, названием и таймером. Показывается при получении `CastStart` remote. Tween-заполнение. Отмена: `CastCancel` remote, CancelKey, стан, урон (если CancelOnDamage). Применяет замедление движения по параметрам `MovementMode` и `SpeedMult`.

`CastComplete` — BindableEvent в ScreenGui "CastBarUI", используется `RangedInput` для определения завершения каста.

### DamageNumbers

Файл: `DamageNumbers.client.luau`

Всплывающие числа урона над целями. Красные — обычный урон, жёлтые — крит. Анимация: подъём вверх + fade out. Обновляется через `DamageEvent` remote.

### ResourceNumbers

Файл: `ResourceNumbers.client.luau`

Жёлтые числа "+N ресурс" над ресурсными нодами при сборе. Обновляется через `ResourceGathered` remote.

### ProjectileVisuals

Файл: `combat/ProjectileVisuals.client.luau`

Визуализация снарядов. Создаёт neon Part (0.4×0.4×1.5) с Trail. Цвет Trail из ProjectileConfig. Heartbeat обновляет позицию. Hit эффект: расширяющийся шар с fade out. Подробнее — `Systems_Combat.md`.

---

## Окна

### CharacterWindow

Файл: `character/CharacterWindow.client.luau`

Окно персонажа (клавиша C). Оркестратор, объединяющий панели:

| Панель | Модуль | Описание |
|---|---|---|
| Инвентарь | InventoryGrid.luau | Сетка слотов, drag-and-drop, обработка station drag source |
| Экипировка (левая) | EquipmentPanel.luau | Head, Chest, Legs, Feet, Hands |
| Экипировка (правая) | EquipmentPanel.luau | Cloak, Amulet, Ring1, Ring2, Bag |
| Крафт | CraftPanel.luau | Рецепты (только ручные), материалы, прогресс |
| Атрибуты | AttributesPanel.luau | Таблица 20 статов |
| Кровь | BloodPoolPanel.luau | Тип, качество, бонусы |

Вспомогательные модули: `UIConstants.luau` — размеры, цвета, layout. `SlotFactory.luau` — создание UI-слотов. `SlotBehavior.luau` — клик, ПКМ (deposit в станцию/сундук), drag поведение. `DragManager.luau` — drag-and-drop с source routing и DragLayer. `CooldownManager.luau` — визуальный cooldown (RenderStepped).

Внешнее управление: BindableEvent "ToggleCharacterWindow" в ScreenGui "CharacterGui". Fire(true) — открыть, Fire(false) — закрыть, Fire() — toggle. Используется: ContainerUI (открывает инвентарь при открытии сундука), StationUI (открывает при открытии станции).

### ServantWindow

Файл: `servant/ServantWindow.client.luau`

Окно слуг (клавиша V). Оркестратор:

| Панель | Модуль | Описание |
|---|---|---|
| Коллекция | ServantCollection.luau | Список захваченных слуг |
| Статы | ServantStatsPanel.luau | Статы выбранного слуги |
| Экипировка | ServantEquipPanel.luau | Слоты экипировки слуги |
| Команды | ServantActionBar.luau | Призвать, отозвать, режим, команды |

### StationUI

Файл: `building/StationUI.client.luau`

Универсальный UI перерабатывающих станций (Лесопилка, Дробилка и др.). Название окна берётся из `payload.StationName`. Расположен справа от экрана (RIGHT_MARGIN 260, TOP_OFFSET 40). DisplayOrder 815 — выше AbilitiesBar (810).

Структура окна: заголовок (название + кнопка X), рецепты (ScrollingFrame, 2 колонки с toggle вкл/выкл и иконкой результата), progress bar (текущий крафт с клиентской интерполяцией через RenderStepped), input-слоты (4×2), output-слоты (4×2), кнопка "Забрать всё".

Слоты станции работают аналогично слотам инвентаря: ЛКМ начинает drag (DragManager.startDrag с source "stationInput" / "stationOutput" и extraData {stationId}), ПКМ мгновенно забирает предмет в инвентарь (StationTakeInput для input, StationTakeItem для output). Input-слоты также зарегистрированы как drop targets для приёма drag из инвентаря (source="inventory" → StationDeposit).

Progress bar использует клиентскую интерполяцию: при получении StationUpdate запоминается серверный Elapsed и локальный os.clock(), затем каждый кадр elapsed вычисляется как `startElapsed + (now - startTime)`. Это обеспечивает плавную анимацию без ежекадровых сетевых обновлений.

При открытии автоматически открывает CharacterWindow (через BindableEvent ToggleCharacterWindow). При закрытии — закрывает.

WindowManager интеграция: push("StationUI") при открытии, remove при закрытии. Escape закрывает верхнее окно.

Публичное состояние: BoolValue "StationOpen" и StringValue "StationOpenId" в ScreenGui "StationGui" — используется SlotBehavior для ПКМ deposit.

Remotes: StationOpened (открыть UI), StationUpdate (обновить слоты/крафт), StationClosed (сервер закрыл), StationDeposit, StationTakeItem, StationTakeInput, StationTakeAll, StationToggleRecipe, StationClose (клиент → сервер).

### ContainerUI

Файл: `ContainerUI.client.luau`

UI для контейнеров (сундуки). Сетка слотов. `ContainerAnimator.client.luau` — анимация открытия/закрытия крышки контейнера.

### BossJournal / JournalWindow

Файл: `journal/JournalWindow.luau`

Общее окно с табами: **Bosses** и **Spellbook**. Открывается через MenuBar (иконка книги) или горячую клавишу J. Каждый таб — отдельная страница (BossesPage, SpellbookPage) с методами `build`, `onActivate`, `onDeactivate`, `setVisible`.

---

## Строительство

### BuildingMenu

Файл: `building/BuildingMenu.client.luau`

UI строительства (клавиша B). Категории блоков: Foundation, Wall, Roof, Functional. Каждая категория содержит список блоков со стоимостью. Кнопка «Поставить Сердце замка» — запускает BuildingPlacer в режиме Castle Heart. Режим удаления (Delete Mode) — позволяет удалять блоки кликом.

При закрытии меню проверяется `BuildingPlacer.isActive()` — если placer активен, cleanup не вызывается, чтобы не уничтожить ghost-preview.

### BuildingPlacer

Файл: `building/BuildingPlacer.luau`

Ghost-preview блока с привязкой к сетке (GridSize = 8). Валидация размещения (зелёный/красный цвет ghost). Edge-snap для стен на фундаментах. Delete mode.

API: startPlacing(blockTypeId), startPlacingHeart(), stopPlacing(), cleanup(), isActive() → bool.

### BlockInteract

Файл: `building/BlockInteract.client.luau`

Сканирует ближайшие функциональные блоки (исключая Chest — обрабатывается ContainerUI) каждые 0.15с. При обнаружении показывает Billboard-подсказку ([F] Открыть станцию, [F] Открыть / Закрыть и т.д.). Нажатие F → `InteractBlock:FireServer(blockId)`.

### WindowManager

Файл: `WindowManager.luau`

Стек окон для управления Escape-закрытием. `push(name, closeFn)` — добавить окно в стек. `remove(name)` — убрать. При Escape вызывается closeFn верхнего окна. Используется StationUI, ContainerUI и другими модальными окнами.

---

## Overlay-экраны

### DeathScreen

Файл: `DeathScreen.client.luau`

Экран смерти. Показывается при получении `PlayerDied` remote. Таймер обратного отсчёта, кнопка «Возродиться» (активируется после таймера). Нажатие отправляет `PlayerRespawn` remote.

### CaptureUI

Файл: `CaptureUI.client.luau`

Cast bar захвата врага. Показывается при начале захвата (`CaptureRequest`). Отменяется движением или повторным нажатием T.

### LootUI

Файл: `LootUI.client.luau`

Подсказка подбора лута. Показывает иконку и имя предмета при приближении к лут-дропу. Клавиша F — подобрать (`PickupLoot` remote).

---

## Уведомления

### NotifyModule

Файл: `NotifyModule.luau`

Система toast-уведомлений. Уведомления появляются в правой части экрана, автоматически исчезают через несколько секунд. Поддерживает типы: info, success, warning, error.

### NotifyListener

Файл: `NotifyListener.client.luau`

Слушает `Notify` remote и вызывает `NotifyModule.show(message, type)`.

---

## Tooltip

### ItemTooltip

Файл: `character/tooltip/init.luau`

Модульный tooltip предметов. ScreenGui с DisplayOrder 999 (поверх всех окон кроме DragLayer). Показывается при наведении на слот инвентаря, экипировки, станции или сундука.

| Подмодуль | Описание |
|---|---|
| TooltipConstants.luau | Размеры, цвета, шрифты |
| TooltipHeader.luau | Иконка, имя, тип, уровень предмета, цвет рамки по типу |
| TooltipAttributes.luau | Бонусы статов (зелёный текст: "+20 HP", "+5% PhysResistance") |
| TooltipDescription.luau | Текст описания предмета |
| TooltipFooter.luau | Подсказка действия: "ПКМ — экипировать", "ПКМ — использовать" |

### AbilityTooltip

Файл: `abilities/AbilityTooltip.luau`

Tooltip способностей. Отдельный ScreenGui с DisplayOrder 900. Показывает имя, описание, урон, cooldown, тип урона. Появляется при наведении на слот AbilitiesBar.

---

## Камера и ввод

### IsometricCamera

Файл: `camera/IsometricCamera.client.luau`

Изометрическая камера. Фиксированный угол, следует за персонажем. Зум: колесо мыши.

### MouseLook

Файл: `input/MouseLook.client.luau`

Вращение камеры при зажатии ПКМ. Перемещает курсор мыши для вращения, возвращает при отпускании.

### MenuBar

Файл: `MenuBar.luau` + `MenuBarInit.client.luau`

Иконки меню в правом нижнем углу. Открывают окна (Boss Journal и т.д.).

---

## Отладка

### DebugKeys

Файл: `debug/DebugKeys.client.luau`

Клиентские хоткеи для отладки (только Studio). Отправляет `DebugCommand` remote при нажатии F5–F9.

| Клавиша | Команда |
|---|---|
| F5 | save |
| F6 | data |
| F7 | addxp 500 |
| F8 | wipe |
| F9 | togglesave |

---

## Конвенции UI

### Создание

Все UI элементы создаются программно через `Instance.new()`. Prefab не используются. Каждый модуль создаёт свой ScreenGui с уникальным Name и DisplayOrder.

### Обновление данных

Event-driven через Remotes. Модули подписываются на `Remote.OnClientEvent:Connect(...)`. Polling (RenderStepped/Heartbeat) используется только для анимаций и визуальных эффектов (cooldown шторки, tween, позиционирование minimap точек, progress bar интерполяция в StationUI).

### Стиль

Общие константы стиля в `UIConstants.luau`: размеры слотов, отступы, цвета фона, рамок, текста. Шрифт: `GothamBold` / `Gotham`. Скругление: `UICorner` с `CornerRadius = UDim.new(0, 6)`.

### ResetOnSpawn

Все ScreenGui имеют `ResetOnSpawn = false` — UI не пересоздаётся при респавне персонажа.

---

## Журнал (Journal)

### JournalWindow

Файл: `journal/JournalWindow.luau`

Общее окно с табами: **Bosses** и **Spellbook**. Открывается через MenuBar (иконка книги) или горячую клавишу J. Каждый таб — отдельная страница (BossesPage, SpellbookPage) с методами `build`, `onActivate`, `onDeactivate`, `setVisible`.

### Spellbook

Файл: `journal/spellbook/SpellbookPage.luau`

Страница книги заклинаний внутри JournalWindow. Оркестратор, объединяющий компоненты:

| Компонент | Модуль | Описание |
|---|---|---|
| Табы школ | SchoolTabs.luau | Blood / Chaos — переключают содержимое |
| Инфо школы | SchoolInfoPanel.luau | Описание, пассивка, тир-бонусы (с галочкой если закрыт) |
| Прогресс | TierProgressBar.luau | Шкала I → II → III → ULT с заполнением |
| Сетка | SpellGrid.luau | Ряды по тирам, SpellCard для каждого заклинания |
| Детали | SpellDetailPanel.luau | Правая панель: иконка, название, описание, изучение/экипировка |
| Слоты | SpellSlotBar.luau | R, G, Z — экипированные заклинания |

SpellDetailPanel разбит на подмодули: SpellDetailBuilder (UI-конструкция), SpellDetailLearn (кнопка изучения с проверкой поинтов), SpellDetailEquip (кнопки экипировки в слоты с hover-состояниями). При изучении или экипировке выбранное заклинание не сбрасывается — обновляется только состояние кнопок.

Данные загружаются через `GetSpellData` RemoteFunction при первом открытии и обновляются через `UpdateSpellData` RemoteEvent.

### AbilitiesBar (обновлённая архитектура v1.7)

Файл: `abilities/AbilitiesBar.client.luau`

Секционная архитектура — 4 независимые секции:

| Секция | Модуль | Слоты | Описание |
|---|---|---|---|
| Оружие | WeaponSection.luau | LMB, Q, E, Space | Обновляется при смене оружия |
| Заклинания | SpellSection.luau | R, G | Basic заклинания, SpellAimSender |
| Ультимейт | UltimateSection.luau | Z | Ultimate заклинания, SpellAimSender |
| Класс | ClassSection.luau | X | Зарезервировано |

Общие утилиты: AbilitiesConstants (стили), SlotFactory (фабрика слотов), MouseUtil (getMouseWorldPosition), AbilityTooltip, AbilityCooldowns, SpellAimSender.

SpellAimSender автоматически запускается при касте заклинания с CastTime > 0.05 и останавливается при CastComplete или CastCancel.