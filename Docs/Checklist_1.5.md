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
  - [x] LootConfig.luau (файл есть, но пустой — 119 байт)
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
  - [x] Overleveled: +1% dmg, -1% taken per level
  - [x] Underleveled: -4% dmg, +4% taken per level
  - [ ] Ограничение ±100%, минимум урона 1 — нужно проверить применение в CombatManager
- [x] TrainingDummy подстраивается под уровень игрока (Level = 1 в конфиге)
- [x] Обновление клиента (Remotes.UpdateLevel, UpdateServantLevel)

## 3. Враг Wolf
- [x] EnemyConfig.Wolf (HP 90, Damage 5, Level 4, WalkSpeed 16)
- [x] PackRadius = 30 (стайное агро)
- [x] CanCapture = false
- [x] BloodType = "Creature"
- [x] Loot: rugged_hide (5-20 за убийство)
- [ ] Агрессивное поведение (первым атакует) — нужно проверить EnemyAI
- [ ] Стайное агро (PackRadius) — нужно проверить реализацию в AI
- [ ] Уровень 3-5 (рандом при спавне) — сейчас Level = 4 (фиксированный)

## 4. Крафт брони из Rugged Hide
- [x] Ресурс rugged_hide в ItemConfig
- [x] 5 рецептов в CraftConfig (Helmet, Chest, Legs, Gauntlets, Boots)
- [x] Каждый стоит 100 Rugged Hide
- [x] Каждый предмет даёт +10 HP (Stats = { HP = 10 })
- [x] Предметы брони в ItemConfig с EquipSlot
- [ ] Бонус HP от брони применяется к MaxHP игрока — нужно проверить

## 5. Правая панель экипировки
- [x] InventoryConfig: Equipment.Slots содержит Left (Head-Feet) и Right (Cloak-Bag)
- [x] Слоты: Cloak, Amulet, Ring1, Ring2, Bag
- [x] Bag: small_bag (+1 ряд), large_bag (+2 ряда)
- [x] DefaultRows = 3 (24 слота), MaxRows = 5 (40 слотов)
- [x] ItemConfig: small_bag, large_bag с BagData
- [ ] EquipmentPanel UI отображает правую панель — нужно проверить
- [ ] Заблокированные слоты затемнены с иконкой замка
- [ ] При снятии сумки предметы из заблокированных слотов выпадают

## 6. Оптимизации
- [x] EnemyHPBar обновляется по изменению HP (AttributeChanged)
- [x] EnemyHPBar: hover + linger логика (3 секунды)
- [ ] Объединить циклы BloodUI и CaptureUI — CaptureUI (3 КБ) и BloodUI (10.6 КБ) всё ещё отдельные файлы с отдельными циклами
- [x] Tween анимации (TargetInfo, EnemyHPBar, BloodPool)
- [ ] Снизить частоту обновлений (BloodUI сканирует каждые 0.2с — можно реже)

## 7. UI рефакторинг
### HUD Layout
- [x] BuffBar — перенесён в левый верхний угол
- [x] TargetInfo — по центру сверху (имя, уровень, HP bar, blood %)
- [x] TargetInfo — цвет уровня по разнице (white → yellow → orange → red → skull)
- [x] TargetInfo — fade in/out анимация
- [x] TargetInfo — tween HP bar
- [x] TargetInfo — работает на врагов и других игроков
- [x] LevelColorUtil — общий модуль
- [ ] PlayerHPBar — разделить на PlayerHPBlock + ServantHPBlock (13.7 КБ)
- [ ] BloodUI — разделить на BloodPoolUI + EnemyLabels (10.6 КБ)
- [ ] AbilitiesBar — разделить на AbilitiesBarUI + AbilitiesCooldowns (13.3 КБ)

### Character Window
- [ ] Левая панель (Head-Feet) + правая панель (Cloak-Bag)
- [ ] Уровень игрока между панелями
- [ ] Заблокированные слоты инвентаря затемнены

### Blood
- [x] Blood type "Creature" — SpeedBonus (2-20%)
- [x] BloodConfig с типом Creature

## 8. Код / Чистота (бонус)
- [ ] Удалить мёртвый код в EnemyHPBar (локальные LVL_ константы, getLevelColor, isSkullLevel)
- [ ] Удалить неиспользуемую переменную LEVEL_TEXT в TargetInfo
- [ ] LootConfig.luau — пустой файл (119 байт), заполнить или удалить
- [ ] Вынести getEnemyHead в shared модуль (дублируется в EnemyHPBar и BloodUI)
- [ ] CraftPanel.luau — самый большой файл (17.6 КБ), рассмотреть декомпозицию