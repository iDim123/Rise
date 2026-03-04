# Rise — Architecture & Project Reference

> Документация для восстановления контекста. Описывает структуру, зависимости и конвенции проекта.

## Технологии

- **Roblox Studio** + **Rojo** (sync с файловой системой)
- Язык: **Luau** (.luau)
- Rojo маппинг: `.client.luau` → LocalScript, `.server.luau` → ServerScript, `.luau` → ModuleScript

---

## Структура файлов

src/
├── shared/                          # ReplicatedStorage
│   ├── Config.luau                  # Все игровые настройки (единый источник данных)
│   └── Remotes.luau                 # Единый реестр RemoteEvent/RemoteFunction
│
├── server/                          # ServerScriptService
│   ├── Main.server.luau             # Точка входа: загружает модули для регистрации EventBus подписок
│   ├── modules/                     # Серверные модули (НЕ видны клиенту)
│   │   ├── EventBus.luau           # Простая event-шина: on(event, cb), fire(event, ...)
│   │   ├── HealthManager.luau      # HP, урон, смерть (fires EventBus), лечение
│   │   ├── BloodManager.luau       # Логика крови (тип, качество, расход, баффы)
│   │   ├── InventoryManager.luau   # CRUD инвентаря, экипировка, активное оружие
│   │   ├── InventorySync.luau      # sendFullUpdate / getFullData (общая точка)
│   │   ├── LootManager.luau        # Дроп лута (слушает EntityDying), подбор, очистка
│   │   ├── ServantManager.luau     # Захват, призыв, отзыв, режимы, экипировка, createFromEgg
│   │   ├── EnemySpawner.luau       # Спавн/респавн (слушает EntityRemoved)
│   │   ├── BuffManager.luau        # Баффы/дебаффы: applyBuff, removeBuff, getStatModifier, _sendUpdate
│   │   ├── AbilityManager.luau     # Способности Q/E: useAbility, cooldown, DirectDamage/AoEDamage/ApplyBuff
│   │   └── ResourceManager.luau    # Ресурсные ноды: init, hit, _destroyNode, _respawnNode
│   ├── blood/
│   │   └── BloodServer.server.luau
│   ├── combat/
│   │   └── WeaponManager.server.luau
│   ├── enemy/
│   │   ├── EnemyAI.server.luau
│   │   └── EnemyManager.server.luau
│   ├── inventory/
│   │   ├── InventoryServer.server.luau
│   │   ├── WeaponHandler.luau
│   │   ├── CraftHandler.luau
│   │   └── UseItemHandler.luau
│   ├── loot/
│   │   └── LootServer.server.luau
│   ├── resource/
│   │   └── ResourceSpawner.server.luau  # Спавн ресурсных нод из ServerStorage/resources
│   └── servant/
│       ├── ServantServer.server.luau
│       └── ServantAI.server.luau
│
└── client/                          # StarterPlayerScripts
    ├── camera/
    │   └── IsometricCamera.client.luau  # Изометрическая камера + вращение ПКМ (yaw) + zoom
    ├── combat/
    │   ├── CombatInput.client.luau
    │   └── DamageNumbers.client.luau
    ├── input/
    │   └── MouseLook.client.luau
    └── ui/
        ├── BloodUI.client.luau
        ├── BuffBar.client.luau          # UI баффов/дебаффов: иконки, таймеры, tooltip
        ├── AbilitiesBar.client.luau     # UI способностей: LMB/Q/E слоты, cooldown overlay
        ├── ResourceNumbers.client.luau  # Жёлтые числа "+N ресурс" над головой игрока
        ├── CaptureUI.client.luau
        ├── CoreGuiSetup.client.luau
        ├── EnemyHPBar.client.luau
        ├── LootUI.client.luau
        ├── PlayerHPBar.client.luau
        ├── ServantUI.client.luau
        └── character/
            ├── CharacterWindow.client.luau
            ├── UIConstants.luau
            ├── SlotFactory.luau
            ├── SlotBehavior.luau
            ├── DragManager.luau
            ├── EquipmentPanel.luau
            ├── CraftPanel.luau
            ├── InventoryGrid.luau
            ├── ActionBarHUD.luau
            ├── CooldownManager.luau
            └── tooltip/
                ├── init.luau (ItemTooltip)
                ├── TooltipConstants.luau
                ├── TooltipHeader.luau
                ├── TooltipAttributes.luau
                ├── TooltipDescription.luau
                └── TooltipFooter.luau

---

## EventBus

Серверная event-шина для развязки модулей. Модули подписываются через `EventBus.on(eventName, callback)`, события вызываются через `EventBus.fire(eventName, ...)`.

### События
| Событие | Аргументы | Кто вызывает | Кто слушает |
|---|---|---|---|
| EntityDying | entity, attacker | HealthManager.die() | LootManager (дроп лута), HealthManager (EntityDied клиентам) |
| EntityRemoved | enemyType, spawnPos | HealthManager.die(), ServantManager.captureEnemy() | EnemySpawner (респавн) |
| PlayerDied | player, entity, attacker | HealthManager.die() | HealthManager (EntityDied клиентам, респавн) |

---

## Remotes.luau — полный список

### RemoteEvents
| Имя | Направление | Назначение |
|---|---|---|
| AttackRequest | Client → Server | Запрос атаки (mousePos, comboIndex) |
| UseAbility | Client → Server | Использовать способность (key, mousePosition) |
| AbilityCooldown | Server → Client | Кулдаун способности (key, duration) |
| DamageEvent | Server → Client | Визуализация урона (entity, hp, damage) |
| EntityDied | Server → Client | Уведомление о смерти |
| HealEvent | Server → Client | Визуализация хила |
| UpdateInventory | Server → Client | Полное обновление инвентаря |
| UpdateBuffs | Server → Client | Обновление списка баффов/дебаффов |
| ResourceGathered | Server → Client | Уведомление о сборе ресурса (node, resourceId, amount) |
| SwapSlots | Client → Server | Перестановка слотов (from, to) |
| EquipItem | Client → Server | Экипировать предмет (slotIndex) |
| UnequipItem | Client → Server | Снять экипировку (equipSlotId) |
| SetActiveWeapon | Client → Server | Выбрать оружие в ActionBar (slotIndex) |
| CraftItem | Client → Server | Поставить в очередь крафта (recipeId) |
| CraftQueueUpdate | Server → Client | Обновление очереди/прогресса крафта |
| UseItem | Client → Server | Использовать Consumable (slotIndex) |
| DropItem | Client → Server | Выбросить предмет на землю (slotIndex) |
| DrinkBloodRequest | Client → Server | Выпить кровь ближайшего врага |
| CaptureRequest | Client → Server | Начать/отменить захват ("start"/"cancel") |
| CaptureResult | Server → Client | Результат захвата (success, message) |
| SummonServant | Client → Server | Призвать слугу (servantId) |
| DismissServant | Client → Server | Отозвать слугу |
| SetServantMode | Client → Server | Сменить режим (Aggressive/Defensive/Passive) |
| ServantCommand | Client → Server | Команда слуге (Follow/Stay/AttackTarget) |
| RenameServant | Client → Server | Переименовать слугу (servantId, newName) |
| PickupLoot | Client → Server | Подобрать лут (lootPart) |
| EquipServantItem | Client → Server | Экипировать предмет на слугу (servantId, slotIndex, equipSlotId) |
| UnequipServantItem | Client → Server | Снять экипировку со слуги (servantId, equipSlotId) |
| ToggleServantFavorite | Client → Server | Переключить избранное (servantId) |
| UpdateServantData | Server → Client | Обновление данных слуг |

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
| Config.Weapons | Sword, Axe — урон, дальность, комбо, ResourceDamage, Abilities (Q/E), ComboAbility (LMB) |
| Config.Inventory | Rows=5, Columns=8, SlotSize=50, Padding=4, ActionBarRow=1 |
| Config.Equipment | Slots: Head, Chest, Legs, Feet, Hands |
| Config.ItemTypes | Weapon, Head, Chest, Legs, Feet, Hands, Amulet, Ring, Consumable, Misc, Resource |
| Config.Blood | DrainRate, типы (Outcast, Warrior), баффы |
| Config.Buffs | Определения баффов: Id, Name, Description, Icon, Type (buff/debuff), StatModifier |
| Config.ResourceNodes | Tree (MaxHP, ResourceId, ResourcePerHit, RespawnTime), Rock |
| Config.Servants | Лимиты, режимы, команды, дистанции, EquipmentSlots (8 слотов включая Amulet, Ring1, Ring2) |
| Config.Items | blood_essence, health_potion, Sword, Axe, iron_helmet, debug_servant_egg, debug_buff_potion, wood, stone — **все предметы тут** |
| Config.Loot | DropLifetime, PickupRange, PickupKey |
| Config.Crafting | Recipes: health_potion (10 essence, 1s), health_potion_x5 (50 essence, 3s) |

---

## Ключевые конвенции

### Предметы
- Все предметы определяются в `Config.Items` с полями: Id, Name, Description, Icon, Type, ItemLevel, Stackable, MaxStack, и опционально EquipSlot, Stats, UseEffect.
- Добавление предметов в инвентарь: `InventoryManager.addItemFromConfig(player, itemId, amount)`.
- Consumable предметы имеют `UseEffect = { Type = "Heal", Amount = N, Cooldown = N }`, `{ Type = "AddServant", Cooldown = N }`, или `{ Type = "ApplyBuffs", Buffs = {{BuffId, Duration}}, Cooldown = N }`.
- Создание слуги из яйца делегируется `ServantManager.createFromEgg(player, enemyType, bloodQuality)` — единая точка расчёта статов.

### Инвентарь
- 40 слотов (5 рядов × 8 колонок). Слоты 1-8 = ActionBar (первый ряд).
- Пустой слот = `false`. Занятый = таблица `{Id, Name, Icon, Amount, Type, ItemLevel, ...}`.
- Экипировка хранится отдельно: `equipment[slotId]` (Head, Chest, Legs, Feet, Hands).
- `activeWeaponSlot` — номер слота ActionBar с выбранным оружием.
- При `swapSlots` — `activeWeaponSlot` автоматически перемещается за оружием.
- Оружие (Type = "Weapon") экипируется через ActionBar (клавиши 1-8), а не через панель экипировки. EquipSlot для оружия не используется.

### Баффы и дебаффы
- `BuffManager.applyBuff(entity, buffId, duration, source)` — применяет бафф/дебафф.
- `BuffManager.getStatModifier(entity, statName)` — возвращает суммарный модификатор (DamageBonus, DamageReduction и т.д.).
- `BuffManager._sendUpdate(entity)` — отправляет клиенту таблицу активных баффов через `UpdateBuffs`.
- Клиент отображает баффы (зелёная рамка) и дебаффы (красная рамка) в `BuffBar.client.luau` с таймерами и tooltip.
- Consumable предметы могут применять баффы через `UseEffect.Type = "ApplyBuffs"`.

### Способности (Abilities)
- Каждое оружие в `Config.Weapons` имеет `Abilities` (массив для Q/E) и `ComboAbility` (для LMB).
- `AbilityManager.useAbility(player, key, mousePosition)` — валидация, cooldown, применение эффектов.
- Типы эффектов: `DirectDamage`, `AoEDamage`, `ApplyBuff`, `ApplyDebuff`.
- Способности также наносят урон ресурсным нодам через `_hitResourceNodes`.
- Клиент: `AbilitiesBar.client.luau` показывает 3 слота (LMB/Q/E) с иконками, tooltip и cooldown overlay.
- Ввод Q/E → `Remotes.UseAbility:FireServer(key, mousePosition)`.

### Ресурсы (Resource Gathering)
- Ресурсные ноды (Tree, Rock) определяются в `Config.ResourceNodes` с полями: MaxHP, ResourceId, ResourcePerHit, RespawnTime.
- Ноды размещаются в `Workspace → Resources` с атрибутом `NodeType` (String).
- `ResourceSpawner.server.luau` инициализирует ноды из `ServerStorage/resources`.
- `ResourceManager.hit(player, node, damage)` — наносит урон ноде, добавляет ресурс в инвентарь, отправляет `ResourceGathered` клиенту.
- При HP = 0 нода становится прозрачной, респавнится через `RespawnTime` секунд с отключённым коллайдером (включается когда игроки отойдут).
- `WeaponManager` использует `weaponConfig.ResourceDamage` для расчёта урона нодам (горизонтальная дистанция, без учёта высоты).
- Клиент: `ResourceNumbers.client.luau` показывает жёлтые числа "+N ресурс" над головой игрока.

### Обновление клиента
- Любое изменение инвентаря на сервере → `InventorySync.sendFullUpdate(player)`.
- Клиент получает `UpdateInventory` → `refreshUI(data)` в CharacterWindow.
- Формат данных: `{ slots = {...}, equipment = {...}, activeWeaponSlot = number|nil }`.

### EventBus (серверная event-шина)
- Модули не вызывают друг друга напрямую для жизненного цикла сущностей.
- `HealthManager.die()` только помечает смерть и вызывает события. Не знает о лут-системе и респавне.
- `LootManager` слушает `EntityDying` → дропает лут.
- `EnemySpawner` слушает `EntityRemoved` → респавнит врага.
- `ServantManager.captureEnemy()` вызывает `EventBus.fire("EntityRemoved")` после уничтожения врага.
- Подписки регистрируются при `require` модуля. `Main.server.luau` загружает HealthManager, LootManager, EnemySpawner для гарантии регистрации.

### Drag-and-drop
- `DragManager` управляет drag-состоянием, ghost-элементом и drop targets.
- Drag начинается из `InventoryGrid` или `ActionBarHUD` по `MouseButton1Down`.
- Drop targets: экипировка игрока (auto-equip), слоты инвентаря (swap).
- Drop за пределы UI → `DropItem` remote → лут выбрасывается на землю.
- Ghost создаётся сразу в позиции курсора (без мерцания).
- Проверка области ActionBar включает +30px вниз для bind labels.

### Tooltip
- Модульная система в `character/tooltip/`.
- `ItemTooltip.init(gui)` создаёт отдельный ScreenGui с `DisplayOrder = 999`.
- `ItemTooltip.show(itemData, slotFrame)` собирает секции и позиционирует tooltip.
- Позиционирование использует `tooltipGui.AbsoluteSize` для корректного clamp к границам экрана.
- Tooltip показывается при наведении на: инвентарь, ActionBar, экипировку игрока, экипировку слуги.
- BuffBar и AbilitiesBar имеют собственные tooltip с clamp к краям экрана.

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

### Безопасность
- Серверные модули находятся в `src/server/modules/` (ServerScriptService) и НЕ реплицируются клиенту.
- `DropItem` remote имеет rate-limit (0.3 с между вызовами).
- Модули ссылаются друг на друга через `script.Parent`, на `Config`/`Remotes` — через `ReplicatedStorage`.

### Горячие клавиши
| Клавиша | Действие |
|---|---|
| C | Открыть/закрыть окно персонажа |
| V | Открыть/закрыть окно слуг |
| 1-8 | Выбрать оружие или использовать Consumable (ActionBar) |
| Q | Способность 1 (зависит от оружия) |
| E | Способность 2 (зависит от оружия) |
| F | Выпить кровь / подобрать лут (приоритет по контексту) |
| T | Захватить врага (начать/отменить каст) |
| ЛКМ | Атака (зажатие = автоатака, gameProcessed проверяется) |
| ПКМ (зажатие) | Вращение камеры по горизонтали (yaw) |
| ПКМ на слоте | Экипировать / использовать Consumable |
| Колесо мыши | Зум камеры |
| Drag за пределы UI | Выбросить предмет на землю |

---

## Зависимости модулей (серверная сторона)

Main.server.luau
└── require: HealthManager, LootManager, EnemySpawner (регистрация EventBus подписок)

EventBus.luau (standalone, без зависимостей)

HealthManager → EventBus, Config, Remotes
  EventBus подписки: PlayerDied → FireAllClients + LoadCharacter
                     EntityDying → FireAllClients EntityDied

LootManager → InventoryManager, Config, EventBus
  EventBus подписка: EntityDying → dropLoot

EnemySpawner → HealthManager, Config, EventBus
  EventBus подписка: EntityRemoved → respawn

ServantManager → EventBus, Config
  Вызывает: EventBus.fire("EntityRemoved") в captureEnemy()
  createFromEgg() — единая точка создания слуг (используется из UseItemHandler)

InventoryManager → Config
InventorySync → InventoryManager, Remotes
BloodManager → Config (HealthManager через setter)
BuffManager → Config, Remotes, Players
AbilityManager → Config, Remotes, HealthManager, BuffManager, ResourceManager, Players
ResourceManager → Config, InventoryManager, InventorySync, Remotes, Players

InventoryServer.server.luau (оркестратор)
├── InventoryManager, InventorySync
├── WeaponHandler → InventoryManager, Config
├── CraftHandler → InventoryManager, InventorySync, Remotes, Config
└── UseItemHandler → InventoryManager, InventorySync, HealthManager, ServantManager, BuffManager, Config

BloodServer → BloodManager, HealthManager, Remotes
WeaponManager → HealthManager, BloodManager, BuffManager, ResourceManager, AbilityManager, Remotes, Config
EnemyAI → HealthManager, Config
EnemyManager → EnemySpawner, Config
ServantServer → ServantManager, HealthManager, InventoryManager, InventorySync, Remotes, Config
ServantAI → HealthManager, Config
LootServer → LootManager, InventoryManager, InventorySync, Remotes
ResourceSpawner → ResourceManager, Config

---

## Зависимости модулей (клиентская сторона)

CharacterWindow.client.luau (оркестратор)
├── UIConstants ← Config
├── SlotFactory ← UIConstants
├── SlotBehavior ← Config, UIConstants, DragManager, CooldownManager, ItemTooltip
├── DragManager ← UIConstants
├── EquipmentPanel ← Config, UIConstants, SlotFactory, ItemTooltip
├── CraftPanel ← Config, UIConstants, Remotes
├── InventoryGrid ← Config, UIConstants, SlotFactory, SlotBehavior, DragManager, CooldownManager, ItemTooltip, ActionBarHUD, Remotes
├── ActionBarHUD ← UIConstants, SlotFactory, SlotBehavior
├── CooldownManager (standalone, RenderStepped loop)
└── ItemTooltip (tooltip/)
    ├── TooltipConstants
    ├── TooltipHeader ← TooltipConstants
    ├── TooltipAttributes ← TooltipConstants, Config
    ├── TooltipDescription ← TooltipConstants
    └── TooltipFooter ← TooltipConstants

BuffBar.client.luau ← Remotes, Config (standalone UI)
AbilitiesBar.client.luau ← Remotes, Config (standalone UI)
ResourceNumbers.client.luau ← Remotes, Config (standalone UI)
IsometricCamera.client.luau (standalone, UserInputService + RunService)

---

## Известные технические долги

1. ~~HealthManager.die() бог-функция~~ → **закрыто** (EventBus, v1.3)
2. **ServantUI.client.luau** — монолит ~300 строк. Разбить на модули по аналогии с `character/`.
3. ~~CombatInput.client.luau — нет проверки gameProcessed~~ → **закрыто** (уже было исправлено)
4. ~~UseItemHandler.AddServant дублирует recalcStats~~ → **закрыто** (ServantManager.createFromEgg, v1.3)
5. ~~CraftPanel.updateTooltip — resultItem scope~~ → **закрыто** (v1.3)
6. ~~InventoryManager.addItem — не сохраняет ItemLevel~~ → **закрыто** (v1.3)
7. ~~WeaponManager — жёсткая привязка к Config.Weapons.Sword~~ → **закрыто** (динамическое определение оружия, v1.4)
8. **EnemyHPBar** — обновляет все HP-бары каждый RenderStepped даже если HP не менялось.
9. **BloodUI / CaptureUI** — оба итерируют всех врагов каждый кадр. Можно объединить и снизить частоту.
10. ~~Config.Items.Sword — нет EquipSlot~~ → **не баг** (оружие экипируется через ActionBar).
11. ~~Нет rate-limit на DropItem~~ → **закрыто** (0.3s cooldown, v1.3)
12. ~~Дублирование слот-логики~~ → **закрыто** (SlotBehavior.luau, v1.4)
13. ~~EnemySpawner.spawn — return nil при создании папки~~ → **закрыто** (v1.3)
14. **BuffBar/AbilitiesBar** — standalone UI, не интегрированы в CharacterWindow систему. При рефакторинге UI стоит объединить.

---

## Версии

| Версия | Ветка | Основное |
|---|---|---|
| 1.0 | — | Базовый бой, инвентарь, экипировка, враги, камера |
| 1.1 | develop_1.1 | Кровь, слуги, floating damage, лут |
| 1.2 | develop_1.2 | Крафт, consumables, cooldown визуал, UI рефакторинг, Remote registry |
| 1.3 | develop_1.3 | Drag-and-drop экипировки (игрок + слуга), модульный ItemTooltip, tooltip везде, дроп на землю, серверные модули в ServerScriptService, EventBus, рефакторинг техдолга |
| 1.4 | develop_1.4 | Рефакторинг WeaponManager (динамическое оружие, Axe), BuffManager (баффы/дебаффы + UI), AbilityManager (Q/E способности + LMB combo + UI), ResourceManager (сбор ресурсов Tree/Rock + floating numbers + респавн), SlotBehavior (единая слот-логика), вращение камеры ПКМ, исправление drag-drop ActionBar |