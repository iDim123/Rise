# Checklist v1.5

## 1. Рефакторинг Config
- [x] Разбить Config.luau на модули в `src/shared/config/`
  - [x] PlayerConfig.luau
  - [x] EnemyConfig.luau
  - [x] WeaponConfig.luau
  - [x] ItemConfig.luau
  - [x] BuffConfig.luau
  - [x] BloodConfig.luau
  - [x] InventoryConfig.luau
  - [x] CraftConfig.luau
  - [x] ResourceConfig.luau
  - [x] LootConfig.luau
  - [x] ServantConfig.luau
- [x] Config.luau — коллектор (require всех подмодулей)

## 2. Система уровней и опыта
- [x] LevelManager.luau на сервере
- [x] Формула MaxHP = BaseHP + HPPerLevel*(Level-1)
- [x] Формула XPToNext = BaseXP * Level
- [x] Максимальный уровень 20
- [x] Начальный уровень 1
- [x] Level-up петля (несколько уровней за раз)
- [x] XP за убийство врагов (EventBus → EntityDying)
- [x] XP слугам (зеркалит игрока)
- [x] TrainingDummy не даёт XP (XPReward = 0)
- [x] Damage modifiers (over/under-leveled)
  - [x] Overleveled: +1% dmg per level (capped +100%)
  - [x] Underleveled: -4% dmg per level (capped -100%)
  - [x] Применяется в WeaponManager (атака игрока) — math.max(1, ...)
  - [x] Применяется в EnemyBehaviors (атака врагов) — math.max(1, ...)
- [x] TrainingDummy подстраивается под уровень игрока (Level = 1 в конфиге)
- [x] Обновление клиента (Remotes.UpdateLevel, UpdateServantLevel)

## 3. Враг Wolf
- [x] EnemyConfig.Wolf (HP 90, Damage 5, WalkSpeed 16)
- [x] MinLevel = 3, MaxLevel = 5 (рандом при спавне)
- [x] PackRadius = 30 (стайное агро) — реализовано в EnemyTargeting.alertPack
- [x] CanCapture = false
- [x] BloodType = "Creature"
- [x] Loot: rugged_hide (5-20 за убийство)
- [x] Агрессивное поведение — все враги агрят при входе в AggroRange
- [x] SpawnPoint Level атрибут переопределяет конфиг (для уникальных врагов)

## 4. Крафт брони из Rugged Hide
- [x] Ресурс rugged_hide в ItemConfig
- [x] 5 рецептов в CraftConfig (Helmet, Chest, Legs, Gauntlets, Boots)
- [x] Каждый стоит 100 Rugged Hide
- [x] Каждый предмет даёт +10 HP (Stats = { HP = 10 })
- [x] Предметы брони в ItemConfig с EquipSlot
- [x] Бонус HP от брони применяется к MaxHP (recalcPlayerMaxHP в InventoryServer)

## 5. Правая панель экипировки
- [x] InventoryConfig: Equipment.Slots содержит Left (Head-Feet) и Right (Cloak-Bag)
- [x] Слоты: Cloak, Amulet, Ring1, Ring2, Bag
- [x] Bag: small_bag (+1 ряд), large_bag (+2 ряда)
- [x] DefaultRows = 3 (24 слота), MaxRows = 5 (40 слотов)
- [x] ItemConfig: small_bag, large_bag с BagData
- [x] EquipmentPanel UI отображает правую панель
- [x] Заблокированные слоты затемнены с иконкой замка
- [x] При снятии сумки предметы из заблокированных слотов выпадают (InventoryServer)

## 6. Оптимизации
- [x] EnemyHPBar обновляется по изменению HP (AttributeChanged)
- [x] EnemyHPBar: hover + linger логика (3 секунды)
- [x] EnemyHPBar: tween HP bar
- [x] Объединить циклы BloodUI и CaptureUI → EnemyLabels.client.luau (drink + capture в одном scan loop)
- [x] Tween анимации (TargetInfo, EnemyHPBar, BloodPool)
- [x] Снизить частоту сканирования EnemyLabels (0.2с → 0.5с)

## 7. UI рефакторинг
### HUD Layout
- [x] BuffBar — перенесён в левый верхний угол
- [x] TargetInfo — по центру сверху (имя, уровень, HP bar, blood %)
- [x] TargetInfo — цвет уровня по разнице (white → yellow → orange → red → skull)
- [x] TargetInfo — fade in/out анимация
- [x] TargetInfo — tween HP bar
- [x] TargetInfo — работает на врагов и других игроков
- [x] LevelColorUtil — общий модуль
- [x] EnemyUtil — общий модуль (getHead для headless моделей)
- [x] PlayerHPBar → PlayerHPBlock.client + ServantHPBlock.client
- [x] BloodUI → BloodPoolUI.client + EnemyLabels.client
- [x] AbilitiesBar → AbilitiesBar.client + AbilityTooltip + AbilityCooldowns
- [x] HUD константы вынесены в UIConstants

### Character Window
- [x] Левая панель (Head-Feet) + правая панель (Cloak-Bag)
- [x] Уровень игрока между панелями
- [x] Заблокированные слоты инвентаря затемнены

### Blood
- [x] Blood type "Creature" — SpeedBonus (2-20%)
- [x] BloodConfig с типом Creature

## 8. Код / Чистота
- [x] Удалён мёртвый код в EnemyHPBar (LVL_ константы заменены на LevelColorUtil)
- [x] LootConfig.luau — содержит DropLifetime, PickupRange, PickupKey
- [x] getEnemyHead вынесен в shared EnemyUtil модуль
- [ ] CraftPanel.luau — самый большой файл (17.6 КБ), отложено (система крафта стабильна)