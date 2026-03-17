# Rise — Architecture & Project Reference

> Общая документация проекта. Описывает структуру, технологии, конвенции и версии.
> Детали отдельных систем — в файлах `Systems_*.md`.

## Документация

| Файл | Содержание |
|---|---|
| Architecture.md | Структура проекта, конвенции, версии (этот файл) |
| Game_Overview.md | Дизайн-документ игры (в Docs/) |
| Audit_Architecture.md | Архитектурный аудит (P0-P2 проблемы и решения) |
| Systems_Combat.md | Боевая система: мили, дальний бой, снаряды, способности, каст, магия |
| Systems_Inventory.md | Инвентарь, предметы, крафт, экипировка |
| Systems_Building.md | Строительство замков, перерабатывающие станции |
| Systems_Entities.md | Враги, боссы, слуги, AI |
| Systems_Player.md | Статы, уровни, кровь, смерть, баффы |
| Systems_UI.md | Клиентские UI модули |
| Remotes.md | Полный список RemoteEvents и RemoteFunctions |
| Dependencies.md | Зависимости модулей (сервер + клиент) |
| debug_commands.md | Отладочные команды |

---

## Технологии

- **Roblox Studio** + **Rojo** (sync с файловой системой)
- Язык: **Luau** (.luau)
- Rojo маппинг: `.client.luau` → LocalScript, `.server.luau` → ServerScript, `.luau` → ModuleScript

---

## Структура файлов

src/ ├── shared/ # ReplicatedStorage │ ├── Config.luau # Коллектор: require всех config/* модулей │ ├── Remotes.luau # Единый реестр RemoteEvent/RemoteFunction │ ├── LevelColorUtil.luau # Цвет уровня по разнице │ ├── EnemyUtil.luau # getHead() для headless моделей │ └── config/ │ ├── PlayerConfig.luau │ ├── EnemyConfig.luau │ ├── WeaponConfig.luau # Коллектор: собирает weapons/* подмодули │ ├── ProjectileConfig.luau # Снаряды: arrow, power_arrow, rain_arrow, shadowbolt, chaos_bolt, void_orb, chaos_barrage_bolt │ ├── SpellConfig.luau # Коллектор: собирает spells/* подмодули + SpellSlots │ ├── weapons/ │ │ ├── SwordConfig.luau │ │ ├── AxeConfig.luau │ │ └── BowConfig.luau │ ├── spells/ # Школы магии (v1.7 Phase 5) │ │ ├── BloodSchool.luau # Blood: школа, пассивка Leech, тир-бонусы, заклинания │ │ └── ChaosSchool.luau # Chaos: школа, пассивка Ignite, тир-бонусы, заклинания │ ├── ItemConfig.luau # Коллектор: собирает items/* подмодули + ItemTypes │ ├── items/ │ │ ├── WeaponItems.luau │ │ ├── ArmorItems.luau │ │ ├── AccessoryItems.luau │ │ ├── ConsumableItems.luau │ │ └── ResourceItems.luau # Blood Essence, Wood, Stone, Rugged Hide, Wooden Plank, Sawdust, Blood Plank, Trash, Stone Brick │ ├── BuffConfig.luau │ ├── BloodConfig.luau │ ├── InventoryConfig.luau │ ├── CraftConfig.luau # Рецепты: ручной крафт + станции (Station field) │ ├── ResourceConfig.luau │ ├── LootConfig.luau │ ├── ServantConfig.luau │ ├── StatsConfig.luau │ ├── BossConfig.luau │ ├── BuildingConfig.luau # Строительство: BlockTypes, CastleHeart, Permissions │ ├── StationConfig.luau # Перерабатывающие станции: Sawmill, Crusher │ └── DayNightConfig.luau │ ├── server/ # ServerScriptService │ ├── Main.server.luau # Точка входа: загружает модули для EventBus подписок │ ├── PlayerLifecycle.server.luau # PlayerAdded/Removing, CharacterAdded, BindToClose │ ├── building/ │ │ └── BuildingServer.server.luau # Remote-оркестратор: Castle Heart, блоки, Permissions, InteractBlock, Station remotes │ ├── modules/ │ │ ├── EventBus.luau │ │ ├── HealthManager.luau │ │ ├── BloodManager.luau │ │ ├── InventoryManager.luau │ │ ├── InventorySync.luau │ │ ├── LootManager.luau │ │ ├── LevelManager.luau │ │ ├── EnemySpawner.luau │ │ ├── BuffManager.luau │ │ ├── AbilityManager.luau # Способности Q/E (→ Systems_Combat.md) │ │ ├── CastManager.luau # Каст-система (→ Systems_Combat.md) │ │ ├── ResourceManager.luau │ │ ├── StatsManager.luau │ │ ├── DataService.luau │ │ ├── SpellProgressManager.luau # Spell Points, изучение, экипировка, тировые бонусы │ │ ├── SpellCastManager.luau # Кастование заклинаний, charges, channelling │ │ ├── LeechHandler.luau # Blood пассивка: heal on hit/kill │ │ ├── IgniteHandler.luau # Chaos пассивка: DoT, explosion, chain │ │ ├── spellEffects/ # Обработчики эффектов заклинаний │ │ │ ├── ProjectileEffect.luau │ │ │ ├── MultiProjectileEffect.luau │ │ │ ├── ChannelledProjectileEffect.luau │ │ │ ├── TargetAreaProjectileEffect.luau │ │ │ ├── AoEDamageEffect.luau │ │ │ ├── AoEHealEffect.luau │ │ │ ├── AoEBuffEffect.luau │ │ │ ├── AoEApplyPassiveEffect.luau │ │ │ ├── BeamEffect.luau │ │ │ ├── BlockEffect.luau │ │ │ ├── FrontalBlockEffect.luau │ │ │ ├── ImmaterialEffect.luau │ │ │ ├── HealCasterEffect.luau │ │ │ └── PullEffect.luau │ │ ├── boss/ │ │ │ ├── BossManager.luau │ │ │ ├── BossPlayerData.luau │ │ │ └── BossInteraction.luau │ │ ├── servant/ │ │ │ ├── ServantManager.luau │ │ │ └── ServantEquipment.luau │ │ └── building/ # Строительная система (→ Systems_Building.md) │ │ ├── BuildingManager.luau # CRUD замков, блоков, экономика │ │ ├── BuildingValidator.luau # Валидация размещения │ │ ├── BuildingSerializer.luau # Сериализация DataStore (блоки, контейнеры, станции) │ │ ├── CastleBorder.luau # Claim-территория, коллизии, права │ │ ├── CastleHeartManager.luau # Визуал Castle Heart (орб, свет) │ │ ├── BlockHealth.luau # HP блоков, урон, разрушение │ │ ├── FunctionalDispatcher.luau # Маршрутизатор: Door, Chest, Station → хендлеры │ │ ├── DoorHandler.luau # Двери: открытие/закрытие │ │ ├── ChestHandler.luau # Сундуки: слоты, deposit, take │ │ └── StationHandler.luau # Универсальный обработчик станций (Sawmill, Crusher, ...) │ ├── combat/ # Боевые модули (→ Systems_Combat.md) │ │ ├── CombatManager.server.luau # + BeamUpdate handler │ │ ├── WeaponUtil.luau │ │ ├── DamageCalc.luau │ │ ├── TargetFinder.luau │ │ ├── ResourceHit.luau │ │ ├── MeleeHandler.luau │ │ ├── RangedHandler.luau │ │ └── ProjectileManager.luau │ ├── blood/ │ │ └── BloodServer.server.luau │ ├── debug/ │ │ └── DebugCommands.server.luau # + /spellpoint │ ├── enemy/ │ │ ├── EnemyAI.server.luau │ │ ├── EnemyBehaviors.luau │ │ ├── EnemyTargeting.luau │ │ ├── EnemyStateManager.luau │ │ ├── EnemyManager.server.luau │ │ ├── BossServer.server.luau │ │ ├── BossBehaviors.luau │ │ └── BossAbilities.luau │ ├── inventory/ │ │ ├── InventoryServer.server.luau │ │ ├── WeaponHandler.luau │ │ ├── CraftHandler.luau │ │ └── UseItemHandler.luau │ ├── loot/ │ │ └── LootServer.server.luau │ ├── resource/ │ │ └── ResourceSpawner.server.luau │ └── servant/ │ ├── ServantServer.server.luau │ └── ServantAI.server.luau │ └── client/ # StarterPlayerScripts ├── camera/ │ └── IsometricCamera.client.luau ├── combat/ # (→ Systems_Combat.md) │ ├── CombatInput.client.luau │ ├── MeleeInput.luau │ ├── RangedInput.luau │ ├── ProjectileVisuals.client.luau │ ├── DamageNumbers.client.luau │ ├── BeamVisual.client.luau # Визуализация Beam заклинаний │ └── SpellVFX.client.luau # VFX для всех spell эффектов ├── debug/ │ └── DebugKeys.client.luau ├── input/ │ └── MouseLook.client.luau └── ui/ # (→ Systems_UI.md) ├── BloodPoolUI.client.luau ├── EnemyLabels.client.luau ├── BuffBar.client.luau ├── PlayerHPBlock.client.luau ├── ServantHPBlock.client.luau ├── TargetInfo.client.luau ├── EnemyHPBar.client.luau ├── ResourceNumbers.client.luau ├── CaptureUI.client.luau ├── CastBar.client.luau ├── CoreGuiSetup.client.luau ├── LootUI.client.luau ├── DeathScreen.client.luau ├── DayNightHUD.client.luau ├── Minimap.client.luau ├── MenuBar.luau ├── MenuBarInit.client.luau ├── NotifyModule.luau ├── NotifyListener.client.luau ├── ContainerUI.client.luau ├── ContainerAnimator.client.luau ├── WindowManager.luau # Стек окон: push/remove, Escape-закрытие ├── building/ # Строительный UI (→ Systems_Building.md) │ ├── StationUI.client.luau # Универсальный UI станций (Sawmill, Crusher, ...) │ └── BlockInteract.client.luau # Подсказка [F] и InteractBlock для функц. блоков ├── abilities/ # Панель способностей (секционная архитектура) │ ├── AbilitiesBar.client.luau # Оркестратор: собирает секции │ ├── AbilitiesConstants.luau # Константы стилей │ ├── SlotFactory.luau # Фабрика UI-слотов │ ├── MouseUtil.luau # getMouseWorldPosition │ ├── AbilityTooltip.luau │ ├── AbilityCooldowns.luau │ ├── WeaponSection.luau # LMB, Q, E, Space │ ├── SpellSection.luau # R, G (Basic заклинания) │ ├── UltimateSection.luau # Z (Ultimate заклинания) │ ├── ClassSection.luau # X (зарезервировано) │ └── SpellAimSender.luau # Отправка позиции курсора при касте ├── journal/ # Журнал (табы: Bosses, Spellbook) │ ├── JournalInit.client.luau # Точка входа │ ├── JournalWindow.luau # Общее окно с табами │ ├── JournalConstants.luau # Общие константы │ ├── bosses/ # Журнал боссов │ │ ├── BossesPage.luau │ │ ├── BossCard.luau │ │ ├── BossTooltip.luau │ │ └── ActTabs.luau │ └── spellbook/ # Книга заклинаний │ ├── SpellbookPage.luau │ ├── SpellbookConstants.luau │ ├── SchoolTabs.luau │ ├── SchoolInfoPanel.luau │ ├── TierProgressBar.luau │ ├── SpellGrid.luau │ ├── SpellCard.luau │ ├── SpellDetailPanel.luau │ ├── SpellDetailBuilder.luau │ ├── SpellDetailLearn.luau │ ├── SpellDetailEquip.luau │ └── SpellSlotBar.luau ├── servant/ │ ├── ServantWindow.client.luau │ ├── ServantCollection.luau │ ├── ServantStatsPanel.luau │ ├── ServantEquipPanel.luau │ └── ServantActionBar.luau └── character/ ├── CharacterWindow.client.luau ├── UIConstants.luau ├── SlotFactory.luau ├── SlotBehavior.luau ├── DragManager.luau ├── EquipmentPanel.luau ├── CraftPanel.luau ├── InventoryGrid.luau ├── ActionBarHUD.luau ├── CooldownManager.luau ├── AttributesPanel.luau ├── BloodPoolPanel.luau └── tooltip/ ├── init.luau ├── TooltipConstants.luau ├── TooltipHeader.luau ├── TooltipAttributes.luau ├── TooltipDescription.luau └── TooltipFooter.luau


---

## EventBus

Серверная event-шина для развязки модулей. Модули подписываются через `EventBus.on(eventName, callback)`, события вызываются через `EventBus.fire(eventName, ...)`. Для отписки: `EventBus.off(eventName, callback)` (v1.8).

| Событие | Аргументы | Кто вызывает | Кто слушает |
|---|---|---|---|
| EntityDying | entity, attacker | HealthManager.die() | LootManager, LevelManager, HealthManager, LeechHandler, IgniteHandler |
| EntityTookDamage | entity, damage, attacker | HealthManager.takeDamage() | LeechHandler, IgniteHandler |
| EntityRemoved | enemyType, spawnPos, spawnLevel | HealthManager.die(), ServantManager | EnemySpawner |
| PlayerDied | player, entity, attacker | HealthManager.die() | HealthManager |
| PlayerCleanup | player | PlayerLifecycle (v1.8) | Все модули с per-player данными |
| BlockDestroyedByDamage | part, blockId, typeId, castle | BlockHealth | BuildingManager |
| HeartDestroyedByDamage | ownerId | BlockHealth | BuildingManager |

---

## Config — секции

| Модуль | Секция | Описание |
|---|---|---|
| PlayerConfig | Config.Player | BaseHP=100, HPPerLevel=20, MaxLevel=20, BaseXP=100, RespawnTime=10 |
| EnemyConfig | Config.Enemies | Warrior, Wolf, TrainingDummy — уровни, агро, PackRadius |
| WeaponConfig | Config.Weapons | Sword, Axe, Bow — комбо, способности, тип (→ Systems_Combat.md) |
| ProjectileConfig | Config.Projectiles | arrow, power_arrow, rain_arrow, shadowbolt, chaos_bolt, void_orb, chaos_barrage_bolt |
| SpellConfig | SpellConfig.MagicSchools, SpellConfig.Spells, SpellConfig.SpellSlots | Школы магии (Blood, Chaos), заклинания, слоты R/G/Z |
| ItemConfig | Config.Items + Config.ItemTypes | Коллектор: WeaponItems, ArmorItems, AccessoryItems, ConsumableItems, ResourceItems |
| BuffConfig | Config.Buffs | damage_boost, slow и т.д. |
| BloodConfig | Config.Blood | DrainRate, типы, TierThresholds |
| InventoryConfig | Config.Inventory + Config.Equipment + Config.Bags | Rows/Cols, Equipment Slots, Bag ExtraRows |
| CraftConfig | Config.Crafting | Рецепты крафта: ручные (Station = nil) и станционные (Station = "Sawmill" / "Crusher") |
| ResourceConfig | Config.ResourceNodes | Tree, Rock — MaxHP, ResourcePerHit, RespawnTime |
| LootConfig | Config.Loot | DropLifetime, PickupRange, PickupKey |
| ServantConfig | Config.Servants | Лимиты, режимы, команды, EquipmentSlots |
| StatsConfig | Config.Stats | 20 статов: Id, Name, Base, Format, Category |
| BossConfig | Config.Bosses | BloodWarrior, SawmillBoss — Abilities, Loot, Unlocks, SpellPointRewards |
| DayNightConfig | Config.DayNight | Цикл дня/ночи, фазы луны |
| BuildingConfig | Config.Building | GridSize, CastleHeart (Levels, Visual), BlockTypes, Permissions, BlockCategories |
| StationConfig | Config.Stations | Sawmill, Crusher — Name, InputSlots, OutputSlots, InteractRange, CraftingColor |

---

## Ключевые конвенции

### Уровни и опыт

Игрок стартует на уровне 1, максимум 20. MaxHP = `BaseHP + HPPerLevel × (Level - 1)`. XP для следующего уровня = `BaseXP × Level`. XP начисляется за убийства через EventBus → EntityDying. Слуги получают XP зеркально. Damage modifiers: +1% за уровень выше, -4% за уровень ниже (cap ±100%, min damage 1).

### Система статов (v1.6)

20 статов в StatsConfig: MaxHP, PhysicalPower, MagicalPower, AttackSpeed, MoveSpeed, PhysCritChance, PhysCritDamage, MagicCritChance, MagicCritDamage, PhysResistance, MagicResistance, HealthRegen, HealingReceived, FamiliarDamage, BloodDrainRate, BloodBonusPower, ResourceDamage, ResourceYield, WeaponCDSpeed, MagicCDSpeed. StatsManager.recalculate: base + equipment + blood tier + spell tier bonuses + buff modifiers. HP реген: 1% MaxHP/тик × HealthRegen, только вне боя.

### Система магии (v1.7)

Две школы: Blood (пассивка Leech) и Chaos (пассивка Ignite). Spell Points получаются с боссов (первое убийство). Заклинания имеют тиры I–III + Ultimate. Тиры независимы — можно изучать в любой последовательности. Закрытие полного тира даёт пассивный бонус школы. Экипировка: R и G — Basic заклинания, Z — только Ultimate. SpellCastManager использует позицию курсора на момент завершения каста (SpellAim). Эффекты заклинаний модульные — по файлу на тип эффекта в `spellEffects/`.

### Система строительства (v1.9)

Замки размещаются через Castle Heart (claim-территория с уровнями). Блоки категоризированы: Foundation, Wall, Roof, Functional. Функциональные блоки маршрутизируются через FunctionalDispatcher: Door (открытие/закрытие), Chest (слоты хранилища), Station (универсальные перерабатывающие станции). Станции определяются полем `Functional = "Station"` + `FunctionalData.StationType` в BuildingConfig. StationHandler обслуживает все типы станций (Sawmill, Crusher) через единый код — рецепты фильтруются по `recipe.Station == stationType`. Крафт-цикл привязан к RunService.Heartbeat. Права доступа управляются через CastleBorder (союзники, кооперативная стройка). Сериализация: BuildingSerializer сохраняет блоки + контейнеры + станции в DataStore.

### DataStore (v1.7+)

DataService централизует save/load. DATASTORE_NAME = "RisePlayerData_v1". Сохраняет: Level, XP, Inventory, Blood, BossEssence, UnlockedTechs, Servants, Magic (SpellPoints, LearnedSpells, EquippedSpells, ClaimedBossRewards), Castle (CenterPos, Claim, BloodEssence, Blocks, Containers, Stations). Autosave каждые 120с. Использует `UpdateAsync` с version guard для защиты от конкурентной перезаписи (v1.8). `SAVE_ENABLED = not RunService:IsStudio()` — автоматически включается в production. PlayerLifecycle координирует load → init → CharacterAdded; save → cleanup при выходе. BindToClose отслеживает все потоки сохранений с таймаутом 25 сек (v1.8).

### Безопасность

Серверные модули в ServerScriptService, не реплицируются клиенту. DropItem remote имеет rate-limit (0.3с). SpellAim remote имеет rate-limit (50ms per player, v1.8). BuildingServer rate-limit 0.3с на мутирующие операции. Все боевые расчёты авторитетны на сервере. SpellCastManager валидирует все входящие данные (cooldown, charges, IsDead, слот). Station remotes валидируют типы аргументов (string/number).

### Горячие клавиши

| Клавиша | Действие |
|---|---|
| C | Окно персонажа |
| V | Окно слуг |
| J | Журнал (Bosses / Spellbook) |
| 1-8 | ActionBar (оружие / consumable) |
| LMB | Атака (комбо мили / каст+выстрел дальний) |
| Q, E | Способности оружия |
| Space | Dash (зарезервировано) |
| R | Заклинание (Basic, слот R) |
| G | Заклинание (Basic, слот G) |
| Z | Заклинание (Ultimate, слот Z) |
| X | Зарезервировано (классовый спелл) |
| F | Выпить кровь / подобрать лут / добить босса / взаимодействие с блоком |
| T | Захватить врага / захватить босса |
| ПКМ (зажатие) | Вращение камеры |
| ПКМ на слоте | Экипировать / использовать / deposit в станцию или сундук |
| Колесо мыши | Зум камеры / зум миникарты |
| Drag за UI | Выбросить предмет |
| ~ или F2 | Консоль отладки (Studio) |
| Escape | Закрыть верхнее окно (WindowManager стек) |

---

## Известные технические долги

1. **ServantUI.client.luau** — монолит ~300 строк. Разбить на модули (папка servant/ зарезервирована).
2. **CraftPanel.luau** — 19 КБ. Разбить на CraftRecipeList + CraftDetails.

---

## Версии

| Версия | Ветка | Основное |
|---|---|---|
| 1.0 | — | Базовый бой, инвентарь, экипировка, враги, камера |
| 1.1 | develop_1.1 | Кровь, слуги, floating damage, лут |
| 1.2 | develop_1.2 | Крафт, consumables, cooldown визуал, UI рефакторинг, Remote registry |
| 1.3 | develop_1.3 | Drag-and-drop, модульный ItemTooltip, дроп на землю, EventBus, техдолг |
| 1.4 | develop_1.4 | Динамическое оружие (Axe), BuffManager, AbilityManager, ResourceManager |
| 1.5 | develop_1.5 | Модульный Config, Level/XP, Wolf, крафт брони, Target Info, LevelColorUtil |
| 1.6 | develop_1.6 | Stats (20 статов), Blood Tiers, Boss System, Minimap, Death System, DataStore, Debug |
| 1.7 | develop_1.7 | Рефакторинг: ItemConfig → items/, BossManager → boss/, ServantManager → servant/, WeaponConfig → weapons/, боевая система → combat/ (CombatManager, DamageCalc, TargetFinder, MeleeHandler, RangedHandler, ProjectileManager), дальний бой (Bow, снаряды, каст). **Система магии**: SpellConfig (Blood/Chaos школы), SpellProgressManager (spell points, тиры), SpellCastManager (каст, charges, channelling, SpellAim), 14 модульных spellEffects, LeechHandler/IgniteHandler пассивки, Beam система (BeamEffect + BeamVisual), SpellVFX (клиентские эффекты), Spellbook UI (Journal интеграция, 12 модулей), AbilitiesBar секционная архитектура (Weapon/Spell/Ultimate/Class секции), DataService + Magic данные |
| 1.8 | develop_1.8 | **Архитектурный аудит и фиксы**: DataService: SetAsync → UpdateAsync + version guard; SAVE_ENABLED по RunService:IsStudio(); BindToClose race condition fix (thread tracking + 25s timeout); HealthManager GC + cleanup(); EnemyAI activation distance (100 studs) + batch processing; EventBus.off(); SpellAim rate-limit; tick() → os.clock() (все серверные файлы); CharacterUtil shared module; PlayerCleanup EventBus event; LootManager periodic cleanup; TargetFinder spatial hash grid (CELL_SIZE=50, обновление 0.2с); Game Overview document; Roadmap 1.9 |
| 1.9 | develop_1.9 | **Система строительства замков**: BuildingManager (CRUD блоков, Castle Heart с уровнями, claim-территория, HP блоков, экономика), BuildingConfig (BlockTypes: фундаменты, стены, крыши, двери, сундуки, станции), BuildingSerializer (DataStore), CastleBorder (claim, коллизии, права, союзники), CastleHeartManager (визуал орба), BlockHealth (разрушение), FunctionalDispatcher (Door/Chest/Station). **Перерабатывающие станции**: StationHandler (универсальный — Sawmill, Crusher), StationConfig, рецепты с полем Station в CraftConfig. **Клиент**: StationUI (универсальный UI станций), BlockInteract (подсказка F), WindowManager (стек окон, Escape), SlotBehavior (ПКМ deposit в станцию/сундук). **Новые ресурсы**: Wooden Plank, Sawdust, Blood Plank, Trash, Stone Brick. BuildingServer.server.luau — remote-оркестратор строительства. **Station Remotes**: StationOpened, StationUpdate, StationClosed, StationDeposit, StationTakeItem, StationTakeAll, StationToggleRecipe, StationClose |