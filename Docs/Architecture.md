# Rise — Architecture & Project Reference

> Документация для восстановления контекста. Описывает структуру, зависимости и конвенции проекта.

## Технологии

- **Roblox Studio** + **Rojo** (sync с файловой системой)
- Язык: **Luau** (.luau)
- Rojo маппинг: `.client.luau` → LocalScript, `.server.luau` → ServerScript, `.luau` → ModuleScript

---

## Структура файлов

src/ ├── shared/ # ReplicatedStorage │ ├── Config.luau # Коллектор: require всех config/* модулей │ ├── Remotes.luau # Единый реестр RemoteEvent/RemoteFunction │ ├── LevelColorUtil.luau # Shared: цвет уровня по разнице (white→yellow→orange→red→skull) │ ├── EnemyUtil.luau # Shared: getHead() для headless моделей (Wolf и т.д.) │ └── config/ # Модульные конфиги │ ├── PlayerConfig.luau │ ├── EnemyConfig.luau │ ├── WeaponConfig.luau │ ├── ItemConfig.luau # Коллектор: собирает items/* подмодули + ItemTypes │ ├── items/ # Подмодули предметов (v1.7) │ │ ├── WeaponItems.luau │ │ ├── ArmorItems.luau │ │ ├── AccessoryItems.luau │ │ ├── ConsumableItems.luau │ │ └── ResourceItems.luau │ ├── BuffConfig.luau │ ├── BloodConfig.luau │ ├── InventoryConfig.luau │ ├── CraftConfig.luau │ ├── ResourceConfig.luau │ ├── LootConfig.luau │ ├── ServantConfig.luau │ ├── StatsConfig.luau │ └── BossConfig.luau │ ├── server/ # ServerScriptService │ ├── Main.server.luau # Точка входа: загружает модули для регистрации EventBus подписок │ ├── PlayerLifecycle.server.luau # Единый entry point: PlayerAdded/Removing, CharacterAdded, BindToClose │ ├── modules/ # Серверные модули (НЕ видны клиенту) │ │ ├── EventBus.luau # Простая event-шина: on(event, cb), fire(event, ...) │ │ ├── HealthManager.luau # HP, урон, смерть (fires EventBus), лечение, setMaxHP, система смерти │ │ ├── BloodManager.luau # Логика крови (тип, качество, расход, баффы) │ │ ├── InventoryManager.luau # CRUD инвентаря, экипировка, активное оружие, bag slots │ │ ├── InventorySync.luau # sendFullUpdate / getFullData (общая точка) │ │ ├── LootManager.luau # Дроп лута (слушает EntityDying), подбор, очистка │ │ ├── LevelManager.luau # Уровни, XP, MaxHP формулы, damage modifiers, servant XP │ │ ├── EnemySpawner.luau # Спавн/респавн (слушает EntityRemoved), random level range │ │ ├── BuffManager.luau # Баффы/дебаффы: applyBuff, removeBuff, getStatModifier, _sendUpdate │ │ ├── AbilityManager.luau # Способности Q/E: useAbility, cooldown, DirectDamage/AoEDamage/ApplyBuff │ │ ├── ResourceManager.luau # Ресурсные ноды: init, hit, _destroyNode, _respawnNode │ │ ├── StatsManager.luau # 20 статов: recalculate, get, getAll, tickRegen, markCombat │ │ ├── DataService.luau # DataStore: load/save/collect, autosave, retry, SAVE_ENABLED toggle │ │ ├── boss/ # Босс-система (v1.7 — разделена на подмодули) │ │ │ ├── BossManager.luau # Фасад: спавн, состояния (Alive→Downed→Dead), делегирует в подмодули │ │ │ ├── BossPlayerData.luau # Per-player данные: эссенция, техники, клиентские данные │ │ │ └── BossInteraction.luau # Взаимодействия: finishBoss, captureBoss (награды, лут, XP) │ │ └── servant/ # Слуги (v1.7 — разделена на подмодули) │ │ ├── ServantManager.luau # Захват, призыв, отзыв, режимы, createFromEgg, rename │ │ └── ServantEquipment.luau # Экипировка слуг: equip/unequip, recalcStats, syncEntity │ ├── blood/ │ │ └── BloodServer.server.luau │ ├── combat/ │ │ └── WeaponManager.server.luau # Атака игрока: damage modifiers, blood/buff бонусы, resource hit │ ├── debug/ │ │ └── DebugCommands.server.luau # F5-F9 команды (save, data dump, XP, wipe, toggle save) │ ├── enemy/ │ │ ├── EnemyAI.server.luau # Главный AI loop (0.2s tick) │ │ ├── EnemyBehaviors.luau # Состояния: Idle/Patrol/Chase/Attack/Return, damage modifiers │ │ ├── EnemyTargeting.luau # findNearestPlayer (с IsDead проверкой), alertPack (стайное агро) │ │ ├── EnemyStateManager.luau # Хранение состояний, checkTookDamage, patrol points │ │ ├── EnemyManager.server.luau # Спавн из SpawnPoints в workspace │ │ ├── BossServer.server.luau # Спавн боссов из SpawnPoints, remotes Finish/Capture/GetBossData │ │ ├── BossBehaviors.luau # AI боссов: Chase/Attack/Return, leash, enrage, IsDead проверки │ │ └── BossAbilities.luau # Способности боссов: pickAbility, execute, cooldowns │ ├── inventory/ │ │ ├── InventoryServer.server.luau # Equip/Unequip/Swap/Craft/Use remotes, recalcPlayerMaxHP │ │ ├── WeaponHandler.luau │ │ ├── CraftHandler.luau │ │ └── UseItemHandler.luau │ ├── loot/ │ │ └── LootServer.server.luau │ ├── resource/ │ │ └── ResourceSpawner.server.luau │ └── servant/ │ ├── ServantServer.server.luau # Remotes: capture, summon, dismiss, equip, rename, favorite │ └── ServantAI.server.luau # AI цикл слуг: follow/attack/stay, FamiliarDamage modifier │ └── client/ # StarterPlayerScripts ├── camera/ │ └── IsometricCamera.client.luau ├── combat/ │ ├── CombatInput.client.luau │ └── DamageNumbers.client.luau ├── debug/ │ └── DebugKeys.client.luau # F5-F9 клиентские хоткеи ├── input/ │ └── MouseLook.client.luau └── ui/ ├── BloodPoolUI.client.luau # Колба крови: HUD, tween fill/color ├── EnemyLabels.client.luau # Billboard labels: "Выпить кровь [F]", "Захватить [T]" ├── BuffBar.client.luau # Баффы/дебаффы: иконки, таймеры, tooltip (top-left) ├── PlayerHPBlock.client.luau # HP bar, XP bar, level circle (игрок) ├── ServantHPBlock.client.luau # HP bar, XP bar, level circle (слуга) ├── TargetInfo.client.luau # Target tooltip: имя, уровень, HP, blood (top-center) ├── EnemyHPBar.client.luau # Billboard HP bar: hover/linger/damaged, level color, tween ├── ResourceNumbers.client.luau # Жёлтые числа "+N ресурс" ├── CaptureUI.client.luau # Cast bar захвата ├── CoreGuiSetup.client.luau ├── LootUI.client.luau ├── DeathScreen.client.luau # Экран смерти: таймер, кнопка «Возродиться» ├── Minimap.client.luau # Круглая миникарта: N/S/E/W, зум, точки врагов/боссов/игроков ├── MenuBar.luau # Нижний правый угол: иконки меню (Boss Journal и др.) ├── MenuBarInit.client.luau # Инициализация MenuBar ├── NotifyModule.luau # Система уведомлений (toast messages) ├── NotifyListener.client.luau # Слушает Remotes.Notify ├── ServantUI.client.luau ├── abilities/ │ ├── AbilitiesBar.client.luau # 8 слотов способностей: LMB/Q/E/Space/R/T/Z/X │ ├── AbilityTooltip.luau # Tooltip способностей (отдельный ScreenGui, z-order 900) │ └── AbilityCooldowns.luau # Cooldown tracking для ability слотов ├── boss/ # Boss Journal UI (v1.6) │ ├── BossJournalInit.client.luau # Entry point │ ├── BossJournal.luau # Полноэкранное окно, скролл, фильтрация по актам │ ├── BossCard.luau # Карточка босса: имя, уровень, эссенция, техники │ ├── BossTooltip.luau # Tooltip технологий │ ├── BossJournalConstants.luau # UI константы и палитра │ └── ActTabs.luau # Табы актов ├── servant/ # (пока пустая, зарезервирована для ServantUI модулей) └── character/ ├── CharacterWindow.client.luau ├── UIConstants.luau # Layout + HUD bar constants + colors ├── SlotFactory.luau ├── SlotBehavior.luau ├── DragManager.luau ├── EquipmentPanel.luau ├── CraftPanel.luau ├── InventoryGrid.luau ├── ActionBarHUD.luau ├── CooldownManager.luau ├── AttributesPanel.luau # Таблица 20 статов (v1.6) ├── BloodPoolPanel.luau # Тип крови, качество, бонусы (v1.6) └── tooltip/ ├── init.luau (ItemTooltip) ├── TooltipConstants.luau ├── TooltipHeader.luau ├── TooltipAttributes.luau ├── TooltipDescription.luau └── TooltipFooter.luau


---

## EventBus

Серверная event-шина для развязки модулей. Модули подписываются через `EventBus.on(eventName, callback)`, события вызываются через `EventBus.fire(eventName, ...)`.

### События
| Событие | Аргументы | Кто вызывает | Кто слушает |
|---|---|---|---|
| EntityDying | entity, attacker | HealthManager.die() | LootManager (дроп лута), LevelManager (XP), HealthManager (EntityDied клиентам) |
| EntityRemoved | enemyType, spawnPos, spawnLevel | HealthManager.die(), ServantManager.captureEnemy() | EnemySpawner (респавн) |
| PlayerDied | player, entity, attacker | HealthManager.die() | HealthManager (заморозка, PlayerDied клиенту, авто-респавн) |

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
| UpdateStats | Server → Client | Обновление статов игрока |
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
| PlayerDied | Server → Client | Уведомление о смерти игрока (respawnTime) |
| PlayerRespawn | Client → Server | Запрос респавна |
| BossFinish | Client → Server | Добить босса (bossId) |
| BossCapture | Client → Server | Захватить босса (bossId) |
| BossFinishResult | Server → Client | Результат добивания |
| BossCaptureResult | Server → Client | Результат захвата босса |
| UnlockTech | Server → Client | Разблокировка технологии (bossId) |
| Notify | Server → Client | Toast-уведомление (message, type) |
| DebugCommand | Client → Server | Дебаг команда (commandName) |

### RemoteFunctions
| Имя | Направление | Назначение |
|---|---|---|
| GetInventory | Client → Server | Получить {slots, equipment, activeWeaponSlot, unlockedSlots} |
| GetServants | Client → Server | Получить {captured, activeId} |
| GetBossData | Client → Server | Получить данные боссов для журнала |
| GetPlayerStats | Client → Server | Получить все статы игрока |

---

## Config — секции (модульные)

| Модуль | Секция | Описание |
|---|---|---|
| PlayerConfig | Config.Player | BaseHP=100, HPPerLevel=20, MaxLevel=20, BaseXP=100, RespawnTime=10 |
| EnemyConfig | Config.Enemies | Warrior (Lv5), Wolf (Lv3-5, PackRadius, CanCapture=false), TrainingDummy |
| WeaponConfig | Config.Weapons | Sword, Axe — комбо, способности Q/E, ResourceDamage |
| ItemConfig | Config.Items + Config.ItemTypes | Коллектор из items/*: WeaponItems, ArmorItems, AccessoryItems, ConsumableItems, ResourceItems |
| BuffConfig | Config.Buffs | Определения баффов: damage_boost, slow и т.д. |
| BloodConfig | Config.Blood | DrainRate, типы (Outcast, Warrior, Creature), TierThresholds (I/II/MAX), SpeedBonus |
| InventoryConfig | Config.Inventory + Config.Equipment + Config.Bags | Rows/Cols, Equipment Slots (Left+Right), Bag ExtraRows |
| CraftConfig | Config.Crafting | Рецепты: potions, hide armor (5 рецептов × 100 rugged_hide) |
| ResourceConfig | Config.ResourceNodes | Tree, Rock — MaxHP, ResourcePerHit, RespawnTime |
| LootConfig | Config.Loot | DropLifetime=300, PickupRange=6, PickupKey=F |
| ServantConfig | Config.Servants | Лимиты, режимы, команды, CaptureThreshold, EquipmentSlots, PowerBase |
| StatsConfig | Config.Stats | 20 статов: Id, Name, Description, Base, Format, Category; DisplayOrder, EquipmentStats |
| BossConfig | Config.Bosses | BloodWarrior (Lv6, Act 1), SawmillBoss (Lv14, Act 1); Abilities, Loot, Unlocks, EssenceRequired, DownedTimeout, InteractRange |

---

## Ключевые конвенции

### Уровни и опыт
- Игрок стартует на уровне 1, максимум 20. Формула MaxHP: `BaseHP + HPPerLevel * (Level - 1)`.
- XP для следующего уровня: `BaseXP * Level`. XP начисляется за убийства (EventBus → EntityDying).
- Слуги получают XP зеркально игроку с собственным BaseHP из конфига врага.
- Damage modifiers: overleveled +1% dmg per level, underleveled -4% dmg per level, capped ±100%, min damage 1.
- Модификаторы применяются в WeaponManager (атака игрока) и EnemyBehaviors (атака врагов).

### Система статов (v1.6)
- 20 статов определены в StatsConfig: MaxHP, PhysicalPower, MagicalPower, AttackSpeed, MoveSpeed, PhysCritChance, PhysCritDamage, MagicCritChance, MagicCritDamage, PhysResistance, MagicResistance, HealthRegen, HealingReceived, FamiliarDamage, BloodDrainRate, BloodBonusPower, ResourceDamage, ResourceYield, WeaponCDSpeed, MagicCDSpeed.
- StatsManager.recalculate: base + equipment bonuses + blood tier bonuses + buff modifiers.
- Интегрирован с WeaponManager (PhysicalPower, AttackSpeed, PhysCritChance/Damage, PhysResistance), HealthManager (HealingReceived, HealthRegen), Humanoid (WalkSpeed → MoveSpeed, MaxHealth → MaxHP).
- HP реген: 1% MaxHP/тик × HealthRegen множитель, только вне боя.

### Система смерти (v1.6)
- При HP = 0 персонаж замораживается (WalkSpeed/JumpPower/JumpHeight = 0), Health ставится на 1 (не 0, чтобы не вызвать Roblox auto-respawn), MaxHealth = math.huge.
- Клиент получает PlayerDied remote с respawnTime, показывает DeathScreen с таймером и кнопкой «Возродиться».
- Сервер имеет страховочный task.delay(respawnTime + 2) на случай потери remote.
- WeaponManager проверяет IsDead перед обработкой атак.
- EnemyTargeting и BossBehaviors проверяют IsDead и сбрасывают AggroTarget на мёртвых игроков.

### Босс-система (v1.6)
- Боссы определяются в BossConfig с Abilities, Loot, Unlocks, EssenceRequired.
- Жизненный цикл: ALIVE → DOWNED (при HP=1, таймер DownedTimeout) → DEAD (добивание F / захват T / авто-смерть).
- Эссенция per-player: убийство даёт +1 эссенцию, при заполнении можно захватить (T) вместо добивания.
- Захват создаёт слугу через ServantManager.createFromEgg.
- Unlocks: технологии (рецепты крафта) разблокируются при первом убийстве.
- BossBehaviors: отдельный AI с leash (AggroRange × 3), enrage, способностями (BossAbilities).

### Миникарта (v1.6)
- Круглая карта с фиксированной ориентацией (север = вверх).
- Иконка игрока вращается по LookVector, точки: враги (красные), боссы (фиолетовые), игроки (синие), ресурсы (жёлтые).
- Зум: кнопки +/− и скролл мыши. Dot pool для производительности.

### DataStore (v1.6)
- DataService централизует save/load всех данных. DATASTORE_NAME = "RisePlayerData_v1".
- Сохраняет: Level, XP, Inventory (slots + equipment), Blood, BossEssence, UnlockedTechs, Servants.
- Autosave каждые 120 сек. MAX_RETRIES = 3. SAVE_ENABLED toggle (F9).
- PlayerLifecycle координирует: load → init → CharacterAdded; save → cleanup при выходе.

### Враги
- Конфиг врагов поддерживает `MinLevel`/`MaxLevel` для рандомного уровня при спавне; `Level` — фиксированный.
- SpawnPoint атрибут `Level` переопределяет конфиг (для уникальных врагов/боссов).
- Все враги агрят при входе игрока в AggroRange (Idle/Patrol → Chase).
- `PackRadius` — стайное агро: при обнаружении цели оповещаются враги того же типа в радиусе.
- `CanCapture = false` запрещает захват (Wolf).
- Headless модели (Wolf) поддерживаются через `EnemyUtil.getHead()` (fallback: UpperTorso → Torso → HumanoidRootPart → PrimaryPart).

### Предметы
- Все предметы определяются в `Config.Items` через модульные подфайлы в `config/items/` (v1.7).
- Подфайлы: WeaponItems, ArmorItems, AccessoryItems, ConsumableItems, ResourceItems. ItemConfig.luau — коллектор.
- Поля: Id, Name, Description, Icon, Type, ItemLevel, Stackable, MaxStack, и опционально EquipSlot, Stats, UseEffect, BagData.
- Добавление предметов в инвентарь: `InventoryManager.addItemFromConfig(player, itemId, amount)`.
- Consumable предметы имеют `UseEffect = { Type = "Heal"/"AddServant"/"ApplyBuffs"/"DrinkBloodVial", ... }`.
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

### Кровь
- Три типа: Outcast (без бонусов), Warrior (PhysicalPower + WeaponCDSpeed), Creature (MoveSpeed + HealingReceived).
- Тиры по качеству: I (1-49%), II (50-99%), MAX (100%). MAX даёт BoostAll ×1.20.
- BloodAmount расходуется по DrainRate. Пополнение через DrinkBloodRequest (F рядом с врагом) или Blood Vials.

### Слуги (v1.7 — рефакторинг)
- ServantManager разделён на ServantManager (логика) и ServantEquipment (экипировка, расчёт статов).
- Power = PowerBase + PowerBase × Expertise/100 + сумма ItemLevel экипировки.
- ATK = baseATK + Power/10. MaxHP = baseHP + Power.
- Режимы: Aggressive, Defensive, Passive. Команды: Follow, Stay, AttackTarget.

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
- Рецепты могут требовать разблокированную технологию босса (RequiresTech).

### Cooldown (Consumable)
- Клиент запускает `CooldownManager.startCooldown()` сразу. Сервер проверяет авторитетно.
- Визуал: шторка сверху вниз + число секунд.

### Безопасность
- Серверные модули в ServerScriptService, НЕ реплицируются клиенту.
- `DropItem` remote имеет rate-limit (0.3с).

### Debug (v1.6)
- DebugCommands.server.luau — обработка команд F5-F9 (только в Studio RunService:IsStudio()).
- DebugKeys.client.luau — отправляет DebugCommand remote.
- F5 = save, F6 = data dump, F7 = +500 XP, F8 = wipe DataStore, F9 = toggle save.

### Горячие клавиши
| Клавиша | Действие |
|---|---|
| C | Окно персонажа |
| V | Окно слуг |
| 1-8 | ActionBar (оружие / consumable) |
| LMB | Атака (комбо) |
| Q, E, Space, R, T, Z, X | Способности (зависят от оружия) |
| F | Выпить кровь / подобрать лут / добить босса |
| T | Захватить врага / захватить босса |
| ПКМ (зажатие) | Вращение камеры |
| ПКМ на слоте | Экипировать / использовать |
| Колесо мыши | Зум камеры / зум миникарты (при наведении) |
| Drag за UI | Выбросить предмет |
| F5-F9 | Debug команды (только Studio) |

---

## Зависимости модулей (серверная сторона)

Main.server.luau └── require: HealthManager, LootManager, EnemySpawner (регистрация EventBus подписок)

PlayerLifecycle.server.luau └── require: DataService, InventoryManager, InventorySync, BloodManager, LevelManager, boss/BossManager, servant/ServantManager, HealthManager, StatsManager

EventBus.luau (standalone)

HealthManager → EventBus, Config, Remotes, StatsManager, boss/BossManager (lazy) LevelManager → Config, Remotes, EventBus, Players LootManager → InventoryManager, Config, EventBus EnemySpawner → HealthManager, Config, EventBus BloodManager → Config BuffManager → Config, Remotes, Players AbilityManager → Config, Remotes, HealthManager, BuffManager, ResourceManager, Players ResourceManager → Config, InventoryManager, InventorySync, Remotes, Players StatsManager → Config, Remotes, InventoryManager, BloodManager, BuffManager DataService → Config, InventoryManager, LevelManager, BloodManager, boss/BossManager, servant/ServantManager

boss/BossManager → Config, Remotes, EventBus, HealthManager, BossPlayerData, BossInteraction boss/BossPlayerData → Config, Remotes boss/BossInteraction → Config, Remotes, LevelManager, LootManager (lazy), servant/ServantManager (lazy), BossPlayerData

servant/ServantManager → Config, EventBus, ServantEquipment servant/ServantEquipment → Config

InventoryServer.server.luau (оркестратор) ├── InventoryManager, InventorySync, HealthManager, LevelManager ├── WeaponHandler → InventoryManager, Config ├── CraftHandler → InventoryManager, InventorySync, Remotes, Config, boss/BossManager (lazy) └── UseItemHandler → InventoryManager, InventorySync, HealthManager, servant/ServantManager, BuffManager, BloodManager, StatsManager, Config

WeaponManager → HealthManager, BloodManager, BuffManager, ResourceManager, AbilityManager, LevelManager, StatsManager, Remotes, Config EnemyAI → EnemyBehaviors, BossBehaviors, EnemyStateManager, BossAbilities EnemyBehaviors → HealthManager, LevelManager, Config, EnemyStateManager, EnemyTargeting BossBehaviors → HealthManager, LevelManager, boss/BossManager, Config, EnemyStateManager, EnemyTargeting, BossAbilities EnemyTargeting → Players, EnemyStateManager EnemyManager → EnemySpawner, Config BossServer → boss/BossManager, Config, Remotes ServantServer → servant/ServantManager, InventoryManager, InventorySync, HealthManager, Config, Remotes ServantAI → HealthManager, StatsManager, Config


---

## Зависимости модулей (клиентская сторона)

CharacterWindow.client.luau (оркестратор) ├── UIConstants ← Config ├── SlotFactory ← UIConstants ├── SlotBehavior ← Config, UIConstants, DragManager, CooldownManager, ItemTooltip ├── DragManager ← UIConstants ├── EquipmentPanel ← Config, UIConstants, SlotFactory, ItemTooltip ├── CraftPanel ← Config, UIConstants, Remotes ├── InventoryGrid ← Config, UIConstants, SlotFactory, SlotBehavior, DragManager, CooldownManager, ItemTooltip, ActionBarHUD, Remotes ├── ActionBarHUD ← UIConstants, SlotFactory, SlotBehavior ├── CooldownManager (standalone, RenderStepped loop) ├── AttributesPanel ← Remotes, Config (StatsConfig) ├── BloodPoolPanel ← Config (BloodConfig) └── ItemTooltip (tooltip/)

AbilitiesBar.client.luau ← Remotes, Config, AbilityTooltip, AbilityCooldowns AbilityTooltip.luau (standalone, создаёт ScreenGui DisplayOrder 900) AbilityCooldowns.luau (standalone)

PlayerHPBlock.client.luau ← Remotes, UIConstants (создаёт PlayerHUD ScreenGui) ServantHPBlock.client.luau ← Remotes, UIConstants (использует PlayerHUD ScreenGui) BloodPoolUI.client.luau ← Config, Remotes, TweenService EnemyLabels.client.luau ← Config, EnemyUtil TargetInfo.client.luau ← LevelColorUtil, TweenService EnemyHPBar.client.luau ← LevelColorUtil, EnemyUtil, TweenService BuffBar.client.luau ← Remotes, Config ResourceNumbers.client.luau ← Remotes, Config CaptureUI.client.luau ← Config, Remotes DeathScreen.client.luau ← Remotes Minimap.client.luau ← RunService (Heartbeat), Players, workspace IsometricCamera.client.luau (standalone) MenuBar.luau ← boss/BossJournal BossJournal.luau ← Remotes, BossCard, ActTabs, BossJournalConstants BossCard.luau ← BossJournalConstants, BossTooltip NotifyModule.luau (standalone) NotifyListener.client.luau ← Remotes, NotifyModule DebugKeys.client.luau ← Remotes, UserInputService


---

## Известные технические долги

1. ~~HealthManager.die() бог-функция~~ → **закрыто** (EventBus, v1.3)
2. **ServantUI.client.luau** — монолит ~300 строк. Разбить на модули (папка servant/ зарезервирована).
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
14. **CraftPanel.luau** — 19 КБ. Разбить на CraftRecipeList + CraftDetails.
15. [ ] Интеграция статов: AbilityManager (MagicalPower, MagicCrit*, CDSpeed), BloodManager (BloodDrainRate, BloodBonusPower), ResourceManager (ResourceDamage, ResourceYield).

---

## Версии

| Версия | Ветка | Основное |
|---|---|---|
| 1.0 | — | Базовый бой, инвентарь, экипировка, враги, камера |
| 1.1 | develop_1.1 | Кровь, слуги, floating damage, лут |
| 1.2 | develop_1.2 | Крафт, consumables, cooldown визуал, UI рефакторинг, Remote registry |
| 1.3 | develop_1.3 | Drag-and-drop, модульный ItemTooltip, дроп на землю, EventBus, рефакторинг техдолга |
| 1.4 | develop_1.4 | Динамическое оружие (Axe), BuffManager, AbilityManager, ResourceManager, SlotBehavior, вращение камеры |
| 1.5 | develop_1.5 | Модульный Config, Level/XP система, Wolf (random level, pack aggro), крафт брони, правая панель экипировки (Cloak-Bag), Target Info, рефакторинг UI (BloodUI→BloodPoolUI+EnemyLabels, PlayerHPBar→Player+ServantHPBlock, AbilitiesBar→modules), tween анимации, LevelColorUtil, EnemyUtil, damage modifiers |
| 1.6 | develop_1.6 | Stats Foundation (20 статов, StatsManager), Blood Tiers, Character Window (AttributesPanel, BloodPoolPanel), DataStore (DataService), Boss System (BossManager, BossAI, BossAbilities, BossJournal UI, MenuBar), Minimap, Death System (DeathScreen, freeze, PlayerDied/PlayerRespawn), Debug Tools (F5-F9), PlayerLifecycle |
| 1.7 | develop_1.7 | Рефакторинг: ItemConfig → items/ подмодули (WeaponItems, ArmorItems, AccessoryItems, ConsumableItems, ResourceItems), BossManager → modules/boss/ (BossManager фасад + BossPlayerData + BossInteraction), ServantManager → modules/servant/ (ServantManager + ServantEquipment) |