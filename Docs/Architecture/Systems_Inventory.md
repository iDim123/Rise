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
| InventoryGrid.luau | Сетка инвентаря: слоты, drag-and-drop, контекстное меню |
| EquipmentPanel.luau | Левая и правая панели экипировки |
| ActionBarHUD.luau | Нижняя панель 1-8 (слоты из инвентаря) |
| CraftPanel.luau | Панель крафта: список рецептов, прогресс (фильтрует станционные рецепты) |
| SlotFactory.luau | Создание UI-слотов |
| SlotBehavior.luau | Поведение слотов: клик, ПКМ, drag, deposit в станцию/сундук |
| DragManager.luau | Drag-and-drop: ghost-элемент, drop targets |
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


{
    slots = { [1] = false, [2] = { Id = "wood", Amount = 5, ... }, ... },
    equipment = { Head = false, Chest = { Id = "hide_chest", ... }, ... },
    activeWeaponSlot = 3,
    unlockedSlots = 24
}
Клиент получает через UpdateInventory remote и полностью перерисовывает UI.

Начальная загрузка: клиент вызывает GetInventory:InvokeServer() при инициализации CharacterWindow.

Drag-and-Drop
DragManager управляет перетаскиванием предметов между слотами.

Поток
Зажатие ЛКМ на слоте → DragManager.startDrag(slotIndex, itemData). Ghost-элемент следует за курсором. Отпускание на другом слоте → SwapSlots:FireServer(from, to). Отпускание на экипировке → EquipItem:FireServer(slotIndex). Отпускание за пределами UI → DropItem:FireServer(slotIndex) (rate-limit 0.3с).

Drop targets
Цель	Действие
Слот инвентаря	SwapSlots (обмен предметами)
Слот экипировки	EquipItem (авто-экипировка)
За пределами UI	DropItem (выброс на землю)
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