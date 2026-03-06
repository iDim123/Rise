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
│   ├── Config.luau                  # Коллектор: require всех config/* модулей
│   ├── Remotes.luau                 # Единый реестр RemoteEvent/RemoteFunction
│   ├── LevelColorUtil.luau          # Shared: цвет уровня по разнице (white→yellow→orange→red→skull)
│   ├── EnemyUtil.luau               # Shared: getHead() для headless моделей (Wolf и т.д.)
│   └── config/                      # Модульные конфиги
│       ├── PlayerConfig.luau
│       ├── EnemyConfig.luau
│       ├── WeaponConfig.luau
│       ├── ItemConfig.luau
│       ├── BuffConfig.luau
│       ├── BloodConfig.luau
│       ├── InventoryConfig.luau
│       ├── CraftConfig.luau
│       ├── ResourceConfig.luau
│       ├── LootConfig.luau
│       └── ServantConfig.luau
│
├── server/                          # ServerScriptService
│   ├── Main.server.luau             # Точка входа: загружает модули для регистрации EventBus подписок
│   ├── modules/                     # Серверные модули (НЕ видны клиенту)
│   │   ├── EventBus.luau           # Простая event-шина: on(event, cb), fire(event, ...)
│   │   ├── HealthManager.luau      # HP, урон, смерть (fires EventBus), лечение, setMaxHP
│   │   ├── BloodManager.luau       # Логика крови (тип, качество, расход, баффы)
│   │   ├── InventoryManager.luau   # CRUD инвентаря, экипировка, активное оружие, bag slots
│   │   ├── InventorySync.luau      # sendFullUpdate / getFullData (общая точка)
│   │   ├── LootManager.luau        # Дроп лута (слушает EntityDying), подбор, очистка
│   │   ├── LevelManager.luau       # Уровни, XP, MaxHP формулы, damage modifiers, servant XP
│   │   ├── ServantManager.luau     # Захват, призыв, отзыв, режимы, экипировка, createFromEgg
│   │   ├── EnemySpawner.luau       # Спавн/респавн (слушает EntityRemoved), random level range
│   │   ├── BuffManager.luau        # Баффы/дебаффы: applyBuff, removeBuff, getStatModifier, _sendUpdate
│   │   ├── AbilityManager.luau     # Способности Q/E: useAbility, cooldown, DirectDamage/AoEDamage/ApplyBuff
│   │   └── ResourceManager.luau    # Ресурсные ноды: init, hit, _destroyNode, _respawnNode
│   ├── blood/
│   │   └── BloodServer.server.luau
│   ├── combat/
│   │   └── WeaponManager.server.luau  # Атака игрока: damage modifiers, blood/buff бонусы, resource hit
│   ├── enemy/
│   │   ├── EnemyAI.server.luau        # Главный AI loop (0.2s tick)
│   │   ├── EnemyBehaviors.luau        # Состояния: Idle/Patrol/Chase/Attack/Return, damage modifiers
│   │   ├── EnemyTargeting.luau        # findNearestPlayer, alertPack (стайное агро)
│   │   ├── EnemyStateManager.luau     # Хранение состояний, checkTookDamage, patrol points
│   │   └── EnemyManager.server.luau   # Спавн из SpawnPoints в workspace
│   ├── inventory/
│   │   ├── InventoryServer.server.luau # Equip/Unequip/Swap/Craft/Use remotes, recalcPlayerMaxHP
│   │   ├── WeaponHandler.luau
│   │   ├── CraftHandler.luau
│   │   └── UseItemHandler.luau
│   ├── loot/
│   │   └── LootServer.server.luau
│   ├── resource/
│   │   └── ResourceSpawner.server.luau
│   └── servant/
│       ├── ServantServer.server.luau
│       └── ServantAI.server.luau
│
└── client/                          # StarterPlayerScripts
    ├── camera/
    │   └── IsometricCamera.client.luau
    ├── combat/
    │   ├── CombatInput.client.luau
    │   └── DamageNumbers.client.luau
    ├── input/
    │   └── MouseLook.client.luau
    └── ui/
        ├── BloodPoolUI.client.luau      # Колба крови: HUD, tween fill/color
        ├── EnemyLabels.client.luau      # Billboard labels: "Выпить кровь [F]", "Захватить [T]"
        ├── BuffBar.client.luau          # Баффы/дебаффы: иконки, таймеры, tooltip (top-left)
        ├── PlayerHPBlock.client.luau    # HP bar, XP bar, level circle (игрок)
        ├── ServantHPBlock.client.luau   # HP bar, XP bar, level circle (слуга)
        ├── TargetInfo.client.luau       # Target tooltip: имя, уровень, HP, blood (top-center)
        ├── EnemyHPBar.client.luau       # Billboard HP bar: hover/linger/damaged, level color, tween
        ├── ResourceNumbers.client.luau  # Жёлтые числа "+N ресурс"
        ├── CaptureUI.client.luau        # Cast bar захвата
        ├── CoreGuiSetup.client.luau
        ├── LootUI.client.luau
        ├── ServantUI.client.luau
        ├── abilities/
        │   ├── AbilitiesBar.client.luau # 8 слотов способностей: LMB/Q/E/Space/R/T/Z/X
        │   ├── AbilityTooltip.luau      # Tooltip способностей (отдельный ScreenGui, z-order 900)
        │   └── AbilityCooldowns.luau    # Cooldown tracking для ability слотов
        └── character/
            ├── CharacterWindow.client.luau
            ├── UIConstants.luau         # Layout + HUD bar constants + colors
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
| EntityDying | entity, attacker | HealthManager.die() | LootManager (дроп лута), LevelManager (XP), HealthManager (EntityDied клиентам) |
| EntityRemoved | enemyType, spawnPos, spawnLevel | HealthManager.die(), ServantManager.captureEnemy() | EnemySpawner (респавн) |
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
| UpdateLevel | Server → Client | Обновление уровня/XP игрока |
| UpdateServantLevel | Server → Client | Обновление уровня/XP слуги |
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
| EquipServantItem | Client → Server | Экипировать предмет на слугу |
| UnequipServantItem | Client → Server | Снять экипировку со слуги |
| ToggleServantFavorite | Client → Server | Переключить избранное (servantId) |
| UpdateServantData | Server → Client | Обновление данных слуг |

### RemoteFunctions
| Имя | Направление | Назначение |
|---|---|---|
| GetInventory | Client → Server | Получить {slots, equipment, activeWeaponSlot, unlockedSlots} |
| GetServants | Client → Server | Получить {captured, activeId} |

---

## Config — секции (модульные)

| Модуль | Секция | Описание |
|---|---|---|
| PlayerConfig | Config.Player | BaseHP=100, HPPerLevel=20, MaxLevel=20, BaseXP=100, RespawnTime=5 |
| EnemyConfig | Config.Enemies | Warrior (Lv5), Wolf (Lv3-5, PackRadius, CanCapture=false), TrainingDummy |
| WeaponConfig | Config.Weapons | Sword, Axe — комбо, способности Q/E, ResourceDamage |
| ItemConfig | Config.Items + Config.ItemTypes | Все предметы: ресурсы, оружие, броня, bags, consumables |
| BuffConfig | Config.Buffs | Определения баффов: damage_boost, slow и т.д. |
| BloodConfig | Config.Blood | DrainRate, типы (Outcast, Warrior, Creature), SpeedBonus |
| InventoryConfig | Config.Inventory + Config.Equipment + Config.Bags | Rows/Cols, Equipment Slots (Left+Right), Bag ExtraRows |
| CraftConfig | Config.Crafting | Рецепты: potions, hide armor (5 рецептов × 100 rugged_hide) |
| ResourceConfig | Config.ResourceNodes | Tree, Rock — MaxHP, ResourcePerHit, RespawnTime |
| LootConfig | Config.Loot | DropLifetime=300, PickupRange=6, PickupKey=F |
| ServantConfig | Config.Servants | Лимиты, режимы, команды, CaptureThreshold, EquipmentSlots |

---

## Ключевые конвенции

### Уровни и опыт
- Игрок стартует на уровне 1, максимум 20. Формула MaxHP: `BaseHP + HPPerLevel * (Level - 1)`.
- XP для следующего уровня: `BaseXP * Level`. XP начисляется за убийства (EventBus → EntityDying).
- Слуги получают XP зеркально игроку с собственным BaseHP из конфига врага.
- Damage modifiers: overleveled +1% dmg per level, underleveled -4% dmg per level, capped ±100%, min damage 1.
- Модификаторы применяются в WeaponManager (атака игрока) и EnemyBehaviors (атака врагов).

### Враги
- Конфиг врагов поддерживает `MinLevel`/`MaxLevel` для рандомного уровня при спавне; `Level` — фиксированный.
- SpawnPoint атрибут `Level` переопределяет конфиг (для уникальных врагов/боссов).
- Все враги агрят при входе игрока в AggroRange (Idle/Patrol → Chase).
- `PackRadius` — стайное агро: при обнаружении цели оповещаются враги того же типа в радиусе.
- `CanCapture = false` запрещает захват (Wolf).
- Headless модели (Wolf) поддерживаются через `EnemyUtil.getHead()` (fallback: UpperTorso → Torso → HumanoidRootPart → PrimaryPart).

### Предметы
- Все предметы определяются в `Config.Items` с полями: Id, Name, Description, Icon, Type, ItemLevel, Stackable, MaxStack, и опционально EquipSlot, Stats, UseEffect, BagData.
- Добавление предметов в инвентарь: `InventoryManager.addItemFromConfig(player, itemId, amount)`.
- Consumable предметы имеют `UseEffect = { Type = "Heal"/"AddServant"/"ApplyBuffs", ... }`.
- Броня с `Stats.HP` увеличивает MaxHP при экипировке (recalcPlayerMaxHP).
- Bags (`BagData.ExtraRows`) разблокируют дополнительные ряды инвентаря.

### Инвентарь
- По умолчанию 24 слота (3 ряда × 8 колонок), максимум 40 (5 рядов). Слоты 1-8 = ActionBar.
- Пустой слот = `false`. Занятый = таблица `{Id, Name, Icon, Amount, Type, ...}`.
- Экипировка: Left panel (Head, Chest, Legs, Feet, Hands), Right panel (Cloak, Amulet, Ring1, Ring2, Bag).
- Заблокированные слоты (сверх unlocked) затемнены с иконкой замка. При снятии Bag — предметы выпадают.
- `activeWeaponSlot` — номер слота ActionBar с выбранным оружием. При swapSlots перемещается за оружием.

### Баффы и дебаффы
- `BuffManager.applyBuff(entity, buffId, duration, source)` — применяет бафф/дебафф.
- `BuffManager.getStatModifier(entity, statName)` — суммарный модификатор (DamageBonus, DamageReduction и т.д.).
- Клиент: BuffBar в левом верхнем углу с таймерами и tooltip. Зелёная рамка = бафф, красная = дебафф.

### Способности (Abilities)
- 8 слотов: LMB, Q, E, Space, R, T, Z, X. Привязаны к текущему оружию.
- `AbilityManager.useAbility(player, key, mousePosition)` — валидация, cooldown, эффекты.
- Типы: DirectDamage, AoEDamage, ApplyBuff, ApplyDebuff.
- Клиент: AbilitiesBar с модулями AbilityTooltip (z-order 900) и AbilityCooldowns.
- updateAbilities() вызывается event-driven (Tool add/remove), не каждый кадр.

### Target Info
- TargetInfo HUD (top-center): имя, уровень (цвет по разнице), HP bar (tween), blood type/quality.
- Работает на врагов и других игроков. Fade in/out анимация.
- Уровень: white (≤-5) → yellow (≤0) → orange (≤4) → red (≤9) → skull (≥10). Через LevelColorUtil.

### Enemy HP Bar (Billboard)
- Скрыт по умолчанию. Показывается при hover (3s linger) или если враг повреждён.
- Tween HP bar. Level label с цветом через LevelColorUtil.
- Humanoid DisplayDistanceType = None (скрывает дефолтное имя Roblox).

### Ресурсы (Resource Gathering)
- Ноды (Tree, Rock) в `Workspace → Resources` с атрибутом `NodeType`.
- `ResourceManager.hit()` → добавляет ресурс в инвентарь → `ResourceGathered` клиенту.
- При HP = 0 нода прозрачна, респавн через RespawnTime.

### Обновление клиента
- Любое изменение инвентаря → `InventorySync.sendFullUpdate(player)`.
- Формат: `{ slots, equipment, activeWeaponSlot, unlockedSlots }`.

### EventBus (серверная event-шина)
- Модули не вызывают друг друга напрямую для жизненного цикла сущностей.
- `HealthManager.die()` помечает смерть и вызывает события. Не знает о лут-системе.
- `LootManager` слушает `EntityDying` → дропает лут.
- `LevelManager` слушает `EntityDying` → начисляет XP.
- `EnemySpawner` слушает `EntityRemoved` → респавнит (с сохранением SpawnLevel).

### Drag-and-drop
- `DragManager` управляет drag-состоянием, ghost-элементом и drop targets.
- Drop targets: экипировка (auto-equip), слоты инвентаря (swap). Drop за пределы → DropItem remote.

### Tooltip
- Модульная система в `character/tooltip/`. `ItemTooltip.init(gui)` создаёт ScreenGui с DisplayOrder 999.
- BuffBar и AbilitiesBar имеют собственные tooltip (AbilityTooltip — DisplayOrder 900).

### Крафт
- Клиент → `CraftItem:FireServer(recipeId)` → сервер ставит в очередь → `CraftQueueUpdate`.

### Cooldown (Consumable)
- Клиент запускает `CooldownManager.startCooldown()` сразу. Сервер проверяет авторитетно.
- Визуал: шторка сверху вниз + число секунд.

### Безопасность
- Серверные модули в ServerScriptService, НЕ реплицируются клиенту.
- `DropItem` remote имеет rate-limit (0.3с).

### Горячие клавиши
| Клавиша | Действие |
|---|---|
| C | Окно персонажа |
| V | Окно слуг |
| 1-8 | ActionBar (оружие / consumable) |
| LMB | Атака (комбо) |
| Q, E, Space, R, T, Z, X | Способности (зависят от оружия) |
| F | Выпить кровь / подобрать лут |
| T | Захватить врага |
| ПКМ (зажатие) | Вращение камеры |
| ПКМ на слоте | Экипировать / использовать |
| Колесо мыши | Зум камеры |
| Drag за UI | Выбросить предмет |

---

## Зависимости модулей (серверная сторона)

Main.server.luau
└── require: HealthManager, LootManager, EnemySpawner (регистрация EventBus подписок)

EventBus.luau (standalone)

HealthManager → EventBus, Config, Remotes, LevelManager
LevelManager → Config, Remotes, EventBus, Players
LootManager → InventoryManager, Config, EventBus
EnemySpawner → HealthManager, Config, EventBus
ServantManager → EventBus, Config
BloodManager → Config
BuffManager → Config, Remotes, Players
AbilityManager → Config, Remotes, HealthManager, BuffManager, ResourceManager, Players
ResourceManager → Config, InventoryManager, InventorySync, Remotes, Players
InventoryManager → Config
InventorySync → InventoryManager, Remotes

InventoryServer.server.luau (оркестратор)
├── InventoryManager, InventorySync, HealthManager, LevelManager
├── WeaponHandler → InventoryManager, Config
├── CraftHandler → InventoryManager, InventorySync, Remotes, Config
└── UseItemHandler → InventoryManager, InventorySync, HealthManager, ServantManager, BuffManager, Config

WeaponManager → HealthManager, BloodManager, BuffManager, ResourceManager, AbilityManager, LevelManager, Remotes, Config
EnemyAI → EnemyBehaviors, EnemyStateManager
EnemyBehaviors → HealthManager, LevelManager, Config, EnemyStateManager, EnemyTargeting
EnemyTargeting → Players, EnemyStateManager
EnemyManager → EnemySpawner, Config

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

AbilitiesBar.client.luau ← Remotes, Config, AbilityTooltip, AbilityCooldowns
AbilityTooltip.luau (standalone, создаёт ScreenGui DisplayOrder 900)
AbilityCooldowns.luau (standalone)

PlayerHPBlock.client.luau ← Remotes, UIConstants (создаёт PlayerHUD ScreenGui)
ServantHPBlock.client.luau ← Remotes, UIConstants (использует PlayerHUD ScreenGui)
BloodPoolUI.client.luau ← Config, Remotes, TweenService
EnemyLabels.client.luau ← Config, EnemyUtil
TargetInfo.client.luau ← LevelColorUtil, TweenService
EnemyHPBar.client.luau ← LevelColorUtil, EnemyUtil, TweenService
BuffBar.client.luau ← Remotes, Config
ResourceNumbers.client.luau ← Remotes, Config
CaptureUI.client.luau ← Config, Remotes
IsometricCamera.client.luau (standalone)

---

## Известные технические долги

1. ~~HealthManager.die() бог-функция~~ → **закрыто** (EventBus, v1.3)
2. **ServantUI.client.luau** — монолит ~300 строк. Разбить на модули.
3. ~~CombatInput.client.luau — нет проверки gameProcessed~~ → **закрыто**
4. ~~UseItemHandler.AddServant дублирует recalcStats~~ → **закрыто** (v1.3)
5. ~~CraftPanel.updateTooltip — resultItem scope~~ → **закрыто** (v1.3)
6. ~~InventoryManager.addItem — не сохраняет ItemLevel~~ → **закрыто** (v1.3)
7. ~~WeaponManager — жёсткая привязка к Sword~~ → **закрыто** (v1.4)
8. ~~EnemyHPBar — обновляет каждый кадр~~ → **закрыто** (AttributeChanged + hover/linger, v1.5)
9. ~~BloodUI / CaptureUI — дублируют итерацию~~ → **закрыто** (EnemyLabels объединяет, v1.5)
10. ~~Нет rate-limit на DropItem~~ → **закрыто** (v1.3)
11. ~~Дублирование слот-логики~~ → **закрыто** (SlotBehavior, v1.4)
12. ~~EnemySpawner.spawn — return nil~~ → **закрыто** (v1.3)
13. ~~BuffBar/AbilitiesBar standalone~~ → **закрыто** (AbilitiesBar разбит на модули, v1.5)
14. **CraftPanel.luau** — 17.6 КБ. Отложено (система стабильна, не расширяется).

---

## Версии

| Версия | Ветка | Основное |
|---|---|---|
| 1.0 | — | Базовый бой, инвентарь, экипировка, враги, камера |
| 1.1 | develop_1.1 | Кровь, слуги, floating damage, лут |
| 1.2 | develop_1.2 | Крафт, consumables, cooldown визуал, UI рефакторинг, Remote registry |
| 1.3 | develop_1.3 | Drag-and-drop, модульный ItemTooltip, дроп на землю, EventBus, рефакторинг техдолга |
| 1.4 | develop_1.4 | Динамическое оружие (Axe), BuffManager, AbilityManager, ResourceManager, SlotBehavior, вращение камеры |
| 1.5 | develop_1.5 | Модульный Config, Level/XP система, Wolf (random level, pack aggro), крафт брони, правая панель экипировки (Cloak-Bag), Target Info, рефакторинг UI (BloodUI→BloodPoolUI+EnemyLabels, PlayerHPBar→Player+ServantHPBlock, AbilitiesBar→modules), tween анимации, LevelColorUtil, EnemyUtil, damage modifiers для врагов |