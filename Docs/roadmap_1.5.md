# Roadmap v1.5

## Порядок реализации

1. Рефакторинг Config
2. Система уровней и опыта
3. Новый враг: Wolf
4. Крафт брони из Rugged Hide
5. Экипировка: правая панель
6. Оптимизации (EnemyHPBar, BloodUI/CaptureUI)
7. UI рефакторинг (последним, когда все системы готовы)

---

## 1. Рефакторинг Config

Разбить монолитный `Config.luau` на модули по категориям.

**Структура:**
src/shared/ ├── Config.luau # Точка входа, собирает всё в одну таблицу ├── config/ │ ├── PlayerConfig.luau # Player, Levels, BaseHP, HPPerLevel, MaxLevel, BaseXP │ ├── EnemyConfig.luau # Enemies (Warrior, Wolf, TrainingDummy) │ ├── WeaponConfig.luau # Weapons (Sword, Axe), комбо, способности │ ├── ItemConfig.luau # Items (все предметы) │ ├── BuffConfig.luau # Buffs (определения баффов/дебаффов) │ ├── BloodConfig.luau # Blood (типы крови, баффы, Creature) │ ├── InventoryConfig.luau # Inventory, Equipment slots, Bag │ ├── CraftConfig.luau # Crafting recipes │ ├── ResourceConfig.luau # ResourceNodes (Tree, Rock) │ ├── LootConfig.luau # Loot (DropLifetime, PickupRange) │ └── ServantConfig.luau # Servants (лимиты, режимы, команды)


**Config.luau** становится сборщиком — внешний интерфейс `require(Config)` не меняется.

---

## 2. Система уровней и опыта

### Игрок
- Стартовый уровень: 1
- Максимальный уровень: 20
- `MaxHP = BaseHP + HPPerLevel * (Level - 1)`, BaseHP = 100, HPPerLevel = 20
- `XPToNext = BaseXP * Level`, BaseXP = 100
- При уровне 20 опыт перестаёт копиться
- При повышении уровня меняется только MaxHP
- XP получается только за убийство врагов (у каждого врага фиксированный XP в конфиге)

### Слуги
- Уровень при захвате: 1
- Максимальный уровень: 20 (как у игрока)
- Получают XP только когда призваны (активны в мире)
- Получают столько же XP за убийство, сколько и игрок
- `MaxHP = BaseHP + HPPerLevel * (Level - 1)`, BaseHP берётся из Config.Enemies оригинального типа врага

### Damage Modifier (уровневая разница)
- **Overleveled** (игрок выше врага): `GL_Over = Level_Player - Level_Enemy`, +1% урона и -1% получаемого урона за каждый уровень разницы
- **Underleveled** (игрок ниже врага): `GL_Under = Level_Enemy - Level_Player`, -4% урона и +4% получаемого урона за каждый уровень разницы
- Cap: ±100%
- Минимальный урон: 1 (игрок всегда может нанести хотя бы 1 урон)

### TrainingDummy
- Не даёт опыт (0 XP)
- Уровень всегда равен уровню игрока

### Серверный модуль
- `LevelManager.luau` — addXP, levelUp, getLevel, getXP, getMaxHP, getXPToNext, getDamageModifier

---

## 3. Новый враг: Wolf

- HP и урон на 20% меньше чем у Warrior
- Уровень: 3–5 (задаётся в точке спавна)
- Агрессивный (атакует первым)
- Стайное поведение: если ударить одного волка, все волки в небольшом радиусе агрятся
- Нельзя захватить как слугу
- Кровь: **Creature** (новый тип крови, бонус к скорости бега 2–20% в зависимости от качества)
- Лут: **Rugged Hide** (5–20 шт за убийство)

---

## 4. Крафт брони из Rugged Hide

### Новый ресурс
- `rugged_hide` — Resource, Stackable, падает с волков (5–20 шт)

### Рецепты (5 предметов)
| Предмет | Слот | Стоимость | ItemLevel | Статы |
|---|---|---|---|---|
| Hide Helmet | Head | 100 Rugged Hide | 1 | +10 HP |
| Hide Chestplate | Chest | 100 Rugged Hide | 1 | +10 HP |
| Hide Leggings | Legs | 100 Rugged Hide | 1 | +10 HP |
| Hide Gauntlets | Hands | 100 Rugged Hide | 1 | +10 HP |
| Hide Boots | Feet | 100 Rugged Hide | 1 | +10 HP |

---

## 5. Экипировка: правая панель

### Новые слоты экипировки
| Слот | Описание |
|---|---|
| Cloak | Даёт HP + сопротивление солнцу (функционал солнца в будущем) |
| Amulet | Аксессуар (статы) |
| Ring1 | Кольцо (статы) |
| Ring2 | Кольцо (статы) |
| Bag | Разблокирует дополнительные слоты инвентаря |

### Система Bag
- Изначально доступно 24 слота (3 ряда × 8 колонок), из них 8 = ActionBar
- Bag разблокирует дополнительные слоты: маленькая сумка = +8, большая = +16
- Максимум слотов: 40 (5 рядов × 8)
- Заблокированные слоты: видны, затемнены, со значком замка
- При снятии Bag: заблокированные слоты снова блокируются, предметы из них выбрасываются на землю

---

## 6. Оптимизации

### EnemyHPBar
- Обновлять HP-бар только при изменении HP (событие), а не каждый RenderStepped

### BloodUI / CaptureUI
- Объединить итерацию по врагам
- Снизить частоту обновления (не каждый кадр)

---

## 7. UI рефакторинг

### HUD Layout (нижняя часть экрана)

**Левая часть:**
- Player HP bar (красный)
- Experience bar (под HP bar, жёлтый/синий)
- Уровень игрока (число рядом с HP bar)
- ActionBar (8 слотов, клавиши 1–8)

**Центр:**
- BloodUI — пробирка с кровью (анимация колыхания — идея)

**Правая часть:**
- Servant HP bar (когда слуга призван)
- Servant Experience bar (под HP bar)
- Уровень слуги (число рядом с HP bar)
- AbilitiesBar (8 слотов: LMB, Q, E, Space, R, T, Z, X)
- Servant controls (справа вверху)

### AbilitiesBar расширение
- 8 слотов: LMB, Q, E, Space, R, T, Z, X
- Активные: LMB, Q, E (как сейчас)
- Остальные (Space, R, T, Z, X): отрисованы но неактивны, функционал будет добавлен позже

### Target Info (новый UI элемент)
- Позиция: сверху по центру экрана
- Появляется при наведении курсора на врага
- Показывает: имя, уровень, HP bar, blood%, тип крови

### Окно персонажа
- Equipment tab: левая панель (Head, Chest, Legs, Feet, Hands) + правая панель (Cloak, Amulet, Ring1, Ring2, Bag)
- Player LVL отображается по центру между панелями
- Заблокированные слоты инвентаря: затемнены + значок замка

---

## Конфигурация (новые/изменённые секции Config)

### Config.Player (изменения)
```lua
BaseHP = 100,
HPPerLevel = 20,
MaxLevel = 20,
BaseXP = 100,
RespawnTime = 5,
Config.Enemies (новое: Wolf)
Wolf = {
    -- HP и урон на 20% меньше Warrior
    MinLevel = 3, MaxLevel = 5,  -- задаётся в точке спавна
    Aggressive = true,
    PackRadius = 30,  -- радиус стайного агро
    CanCapture = false,
    XPReward = <значение>,
    Blood = { Type = "Creature", QualityRange = {20, 80} },
    Loot = { { Id = "rugged_hide", AmountMin = 5, AmountMax = 20 } },
}
Config.Blood (новое: Creature)
Creature = {
    Name = "Creature",
    Buffs = { SpeedBonus = { Min = 0.02, Max = 0.20 } },
}
Config.Equipment (изменения)
Slots = { "Head", "Chest", "Legs", "Feet", "Hands", "Cloak", "Amulet", "Ring1", "Ring2", "Bag" }
Config.Inventory (изменения)
DefaultSlots = 24,  -- 3 ряда × 8
MaxSlots = 40,      -- 5 рядов × 8