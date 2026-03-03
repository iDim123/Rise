# Rise — Architecture & Project Reference

> Документация для восстановления контекста. Описывает структуру, зависимости и конвенции проекта.

## Технологии

- **Roblox Studio** + **Rojo** (sync с файловой системой)
- Язык: **Luau** (.luau)
- Rojo маппинг: `.client.luau` → LocalScript, `.server.luau` → ServerScript, `.luau` → ModuleScript

---

## Структура файлов

src/ ├── shared/ # ReplicatedStorage │ ├── Config.luau # Все игровые настройки (единый источник данных) │ ├── Remotes.luau # Единый реестр RemoteEvent/RemoteFunction │ └── modules/ │ ├── BloodManager.luau # Логика крови (тип, качество, расход, баффы) │ ├── HealthManager.luau # HP, урон, смерть, респавн, лечение │ ├── InventoryManager.luau # CRUD инвентаря, экипировка, активное оружие │ ├── InventorySync.luau # sendFullUpdate / getFullData (общая точка) │ ├── LootManager.luau # Дроп лута, подбор, очистка │ └── ServantManager.luau # Захват, призыв, отзыв, режимы слуг │ ├── server/ # ServerScriptService │ ├── Main.server.luau # Точка входа: require HealthManager (инициализация) │ ├── blood/ │ │ └── BloodServer.server.luau # DrinkBloodRequest, тик расхода крови │ ├── combat/ │ │ └── WeaponManager.server.luau # AttackRequest → проверка, урон, баффы крови │ ├── enemy/ │ │ ├── EnemyAI.server.luau # AI врагов: Idle/Patrol/Chase/Attack/Return │ │ └── EnemyManager.server.luau # Начальный спавн врагов из ServerStorage │ ├── inventory/ │ │ ├── InventoryServer.server.luau # Оркестратор: связывает Remote → Handler │ │ ├── WeaponHandler.luau # SetActiveWeapon → замена Tool в руке │ │ ├── CraftHandler.luau # Крафт-очередь, прогресс, выдача результата │ │ └── UseItemHandler.luau # Использование Consumable, кулдауны, хил │ ├── loot/ │ │ └── LootServer.server.luau # PickupLoot, периодическая очистка │ └── servant/ │ ├── ServantServer.server.luau # Capture, Summon, Dismiss, Mode, Command, Rename │ └── ServantAI.server.luau # AI слуг: Follow/Attack/Stay по режиму │ └── client/ # StarterPlayerScripts ├── camera/ │ └── IsometricCamera.client.luau # Изометрическая камера, зум колёсиком ├── combat/ │ ├── CombatInput.client.luau # ЛКМ → атака, комбо, автоатака при зажатии │ └── DamageNumbers.client.luau # Floating damage/heal числа над головами ├── input/ │ └── MouseLook.client.luau # Поворот персонажа к курсору мыши └── ui/ ├── BloodUI.client.luau # Полоска крови, надпись "Выпить кровь [F]" ├── CaptureUI.client.luau # Прогресс-бар захвата, надпись "Захватить [T]" ├── CoreGuiSetup.client.luau # Отключение чата и стандартного Backpack ├── EnemyHPBar.client.luau # HP-бар над врагами с % крови ├── LootUI.client.luau # Подсказка подбора лута [F] ├── PlayerHPBar.client.luau # HP-бар игрока + HP-бар слуги ├── ServantUI.client.luau # Окно слуг [V]: список, детали, режимы └── character/ # Окно персонажа [C] ├── CharacterWindow.client.luau # Оркестратор: табы, hotkeys, refresh ├── UIConstants.luau # Размеры, отступы, цвета (из Config) ├── SlotFactory.luau # Создание/обновление слота (иконка, текст, cooldown overlay) ├── DragManager.luau # Drag-and-drop: ghost, состояние, RenderStepped ├── EquipmentPanel.luau # 5 слотов экипировки, ПКМ → снять ├── CraftPanel.luau # Список рецептов, tooltip, очередь, прогресс-бар ├── InventoryGrid.luau # ActionBar (1-8) + инвентарь (9-40) + Sort ├── ActionBarHUD.luau # Нижняя панель быстрого доступа (ScreenGui) └── CooldownManager.luau # Таймеры кулдаунов, шторка + текст на слотах


---

## Remotes.luau — полный список

### RemoteEvents
| Имя | Направление | Назначение |
|---|---|---|
| AttackRequest | Client → Server | Запрос атаки (mousePos, comboIndex) |
| DamageEvent | Server → Client | Визуализация урона (entity, hp, damage) |
| EntityDied | Server → Client | Уведомление о смерти |
| HealEvent | Server → Client | Визуализация хила |
| UpdateInventory | Server → Client | Полное обновление инвентаря |
| SwapSlots | Client → Server | Перестановка слотов (from, to) |
| EquipItem | Client → Server | Экипировать предмет (slotIndex) |
| UnequipItem | Client → Server | Снять экипировку (equipSlotId) |
| SetActiveWeapon | Client → Server | Выбрать оружие в ActionBar (slotIndex) |
| CraftItem | Client → Server | Поставить в очередь крафта (recipeId) |
| CraftQueueUpdate | Server → Client | Обновление очереди/прогресса крафта |
| UseItem | Client → Server | Использовать Consumable (slotIndex) |
| DrinkBloodRequest | Client → Server | Выпить кровь ближайшего врага |
| CaptureRequest | Client → Server | Начать/отменить захват ("start"/"cancel") |
| CaptureResult | Server → Client | Результат захвата (success, message) |
| SummonServant | Client → Server | Призвать слугу (servantId) |
| DismissServant | Client → Server | Отозвать слугу |
| SetServantMode | Client → Server | Сменить режим (Aggressive/Defensive/Passive) |
| ServantCommand | Client → Server | Команда слуге (Follow/Stay/AttackTarget) |
| RenameServant | Client → Server | Переименовать слугу (servantId, newName) |
| PickupLoot | Client → Server | Подобрать лут (lootPart) |

### RemoteFunctions
| Имя | Направление | Назначение |
|---|---|---|
| GetInventory | Client → Server | Получить {slots, equipment, activeWeaponSlot} |
| GetServants | Client → Server | Получить {captured, activeId} |

---

## Config.luau — секции

| Секция | Описание |
|---|---|
| Config.Player | MaxHP (200), RespawnTime (5) |
| Config.Enemies | Warrior, TrainingDummy — HP, урон, агро, скорость, лут, кровь |
| Config.Weapons | Sword — урон, дальность, комбо (3 удара) |
| Config.Inventory | Rows=5, Columns=8, SlotSize=50, Padding=4, ActionBarRow=1 |
| Config.Equipment | Slots: Head, Chest, Legs, Feet, Hands |
| Config.ItemTypes | Weapon, Head, Chest, Legs, Feet, Hands, Consumable, Misc, Resource |
| Config.Blood | DrainRate, типы (Outcast, Warrior), баффы |
| Config.Servants | Лимиты, режимы, команды, дистанции |
| Config.Items | blood_essence, health_potion, Sword, iron_helmet — **все предметы тут** |
| Config.Loot | DropLifetime, PickupRange, PickupKey |
| Config.Crafting | Recipes: health_potion (10 essence, 1s), health_potion_x5 (50 essence, 3s) |

---

## Ключевые конвенции

### Предметы
- Все предметы определяются в `Config.Items` с полями: Id, Name, Description, Icon, Type, Stackable, MaxStack, и опционально EquipSlot, Stats, UseEffect.
- Добавление предметов в инвентарь: `InventoryManager.addItemFromConfig(player, itemId, amount)`.
- Consumable предметы имеют `UseEffect = { Type = "Heal", Amount = N, Cooldown = N }`.

### Инвентарь
- 40 слотов (5 рядов × 8 колонок). Слоты 1-8 = ActionBar (первый ряд).
- Пустой слот = `false`. Занятый = таблица `{Id, Name, Icon, Amount, Type, ...}`.
- Экипировка хранится отдельно: `equipment[slotId]` (Head, Chest, Legs, Feet, Hands).
- `activeWeaponSlot` — номер слота ActionBar с выбранным оружием.

### Обновление клиента
- Любое изменение инвентаря на сервере → `InventorySync.sendFullUpdate(player)`.
- Клиент получает `UpdateInventory` → `refreshUI(data)` в CharacterWindow.
- Формат данных: `{ slots = {...}, equipment = {...}, activeWeaponSlot = number|nil }`.

### Крафт
- Клиент кликает рецепт → `CraftItem:FireServer(recipeId)`.
- Сервер добавляет в очередь, обрабатывает последовательно.
- Прогресс отправляется через `CraftQueueUpdate` (counts, recipeId, progress 0-1).
- Клиент показывает счётчик очереди (жёлтый "xN") и прогресс-бар на строке рецепта.

### Cooldown (Consumable)
- Клиент запускает `CooldownManager.startCooldown(itemId, duration)` сразу при использовании.
- Сервер проверяет свой кулдаун независимо (авторитетный).
- Визуал: тёмная шторка сверху вниз + белое число секунд по центру с чёрной обводкой.
- `CooldownManager` обновляет все зарегистрированные слоты каждый кадр (RenderStepped).

### Горячие клавиши
| Клавиша | Действие |
|---|---|
| C | Открыть/закрыть окно персонажа |
| V | Открыть/закрыть окно слуг |
| 1-8 | Выбрать оружие или использовать Consumable (ActionBar) |
| F | Выпить кровь / подобрать лут (приоритет по контексту) |
| T | Захватить врага (начать/отменить каст) |
| ЛКМ | Атака (зажатие = автоатака) |
| ПКМ на слоте | Экипировать / использовать Consumable |
| Колесо мыши | Зум камеры |

### Зависимости модулей (серверная сторона)
Main.server.luau └── HealthManager

InventoryServer.server.luau (оркестратор) ├── InventoryManager ├── InventorySync ├── WeaponHandler → InventoryManager, Config ├── CraftHandler → InventoryManager, InventorySync, Remotes, Config └── UseItemHandler → InventoryManager, InventorySync, HealthManager, Config

BloodServer → BloodManager, HealthManager, Remotes WeaponManager → HealthManager, BloodManager, Remotes EnemyAI → HealthManager, Config EnemyManager → HealthManager, Config ServantServer → ServantManager, Remotes, Config ServantAI → HealthManager, Config LootServer → LootManager, InventorySync, Remotes


### Зависимости модулей (клиентская сторона)
CharacterWindow.client.luau (оркестратор) ├── UIConstants ← Config ├── SlotFactory ← UIConstants ├── DragManager ← UIConstants ├── EquipmentPanel ← Config, UIConstants, SlotFactory ├── CraftPanel ← Config, UIConstants, Remotes ├── InventoryGrid ← Config, UIConstants, SlotFactory, DragManager, CooldownManager ├── ActionBarHUD ← UIConstants, SlotFactory, CooldownManager └── CooldownManager (standalone, RenderStepped loop)


---

## Известные технические долги

1. **HealthManager.die()** содержит логику респавна врагов (клонирование, атрибуты, кровь). Дублируется в ServantManager.captureEnemy(). Нужен общий `EnemySpawner.luau`.
2. **ServantUI.client.luau** — монолит ~300 строк. Разбить на модули по аналогии с `character/`.
3. **CombatInput.client.luau** — нет проверки `gameProcessed` для ЛКМ (атака при клике по UI).
4. **Crafting Result** — использует inline-данные из рецепта вместо `addItemFromConfig`. Можно упростить.
5. **EnemyHPBar** — создаёт BillboardGui каждый кадр (проверка через FindFirstChild, но всё равно лишняя нагрузка).

---

## Версии

| Версия | Ветка | Основное |
|---|---|---|
| 1.0 | — | Базовый бой, инвентарь, экипировка, враги, камера |
| 1.1 | develop_1.1 | Кровь, слуги, floating damage, лут |
| 1.2 | develop_1.2 | Крафт, consumables, cooldown визуал, UI рефакторинг, Remote registry |