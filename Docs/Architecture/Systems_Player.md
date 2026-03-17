# Player Systems

> Статы, уровни, кровь, смерть, баффы, регенерация.

---

## Система статов

### Обзор

20 статов определены в `StatsConfig.luau`. Каждый стат имеет Id, Name, Description, Base (начальное значение), Format (Number/Percent), Category (Offensive/Defensive/Utility). `StatsManager` пересчитывает статы при любом изменении экипировки, крови или баффов.

### Список статов

| Id | Name | Base | Format | Category | Описание |
|---|---|---|---|---|---|
| MaxHP | Макс. здоровье | 100 | Number | Defensive | Максимум HP (+ HPPerLevel × (Level-1)) |
| PhysicalPower | Физ. сила | 1.0 | Number | Offensive | Множитель физ. урона |
| MagicalPower | Маг. сила | 1.0 | Number | Offensive | Множитель маг. урона |
| AttackSpeed | Скорость атаки | 1.0 | Number | Offensive | Делитель cooldown оружия |
| MoveSpeed | Скорость движения | 1.0 | Number | Utility | Множитель WalkSpeed |
| PhysCritChance | Физ. крит. шанс | 0.05 | Percent | Offensive | Шанс крита (Physical/Ranged) |
| PhysCritDamage | Физ. крит. урон | 1.5 | Number | Offensive | Множитель крита (Physical/Ranged) |
| MagicCritChance | Маг. крит. шанс | 0.05 | Percent | Offensive | Шанс крита (Magic) |
| MagicCritDamage | Маг. крит. урон | 1.5 | Number | Offensive | Множитель крита (Magic) |
| PhysResistance | Физ. сопротивление | 0 | Number | Defensive | Снижение физ. урона (%) |
| MagicResistance | Маг. сопротивление | 0 | Number | Defensive | Снижение маг. урона (%) |
| HealthRegen | Регенерация HP | 1.0 | Number | Defensive | Множитель скорости регена |
| HealingReceived | Получаемое лечение | 1.0 | Number | Defensive | Множитель входящего хила |
| FamiliarDamage | Урон слуги | 1.0 | Number | Offensive | Множитель урона слуги |
| BloodDrainRate | Скорость расхода крови | 1.0 | Number | Utility | Множитель расхода крови |
| BloodBonusPower | Бонус силы крови | 1.0 | Number | Utility | Множитель бонусов крови |
| ResourceDamage | Урон по ресурсам | 1.0 | Number | Utility | Множитель урона по нодам |
| ResourceYield | Сбор ресурсов | 1.0 | Number | Utility | Множитель количества ресурсов |
| WeaponCDSpeed | Скорость CD оружия | 1.0 | Number | Offensive | Делитель cooldown способностей (Physical) |
| MagicCDSpeed | Скорость CD магии | 1.0 | Number | Offensive | Делитель cooldown способностей (Magic) |

### StatsManager API

| Метод | Описание |
|---|---|
| recalculate(player) | Пересчитать все статы: base + equipment + blood tier + buff modifiers |
| get(player, statId) → number | Получить текущее значение стата |
| getAll(player) → table | Получить все статы |
| tickRegen(player) | Тик регенерации HP (вызывается периодически) |
| markCombat(player) | Пометить игрока "в бою" (блокирует реген) |

### Формула пересчёта

Copy
finalValue = baseStat

sum(equipment bonuses)
blood tier bonuses × buff multipliers (BuffManager.getStatModifier)

Применение к Humanoid: `WalkSpeed = 16 × MoveSpeed`, `MaxHealth = MaxHP`. HP реген: `1% MaxHP × HealthRegen` за тик, только вне боя.

### Интеграция

Статы используются в следующих модулях:

- **DamageCalc** — PhysicalPower, MagicalPower, PhysCritChance, PhysCritDamage, MagicCritChance, MagicCritDamage, PhysResistance, MagicResistance
- **MeleeHandler** — AttackSpeed (делитель cooldown)
- **RangedHandler** — AttackSpeed (делитель cooldown)
- **AbilityManager** — WeaponCDSpeed, MagicCDSpeed (делитель cooldown способностей)
- **HealthManager** — HealingReceived, HealthRegen, MaxHP
- **ResourceHit** — ResourceDamage
- **ResourceManager** — ResourceYield
- **ServantAI** — FamiliarDamage
- **BloodManager** — BloodDrainRate, BloodBonusPower

---

## Система уровней

### Обзор

Игрок стартует на уровне 1, максимум — 20 (`Config.Player.MaxLevel`). XP начисляется за убийства через EventBus → EntityDying. Слуги получают XP зеркально игроку.

### Формулы

| Формула | Описание |
|---|---|
| `BaseXP × Level` | XP до следующего уровня |
| `BaseHP + HPPerLevel × (Level - 1)` | Максимальное HP |
| `+1% за каждый уровень выше цели` | Damage modifier (overleveled) |
| `-4% за каждый уровень ниже цели` | Damage modifier (underleveled) |

Damage modifier ограничен ±100%, минимальный урон — 1.

### LevelManager API

| Метод | Описание |
|---|---|
| addXP(player, amount) | Добавить XP, auto level-up |
| getLevel(player) → number | Текущий уровень |
| getXP(player) → number, number | Текущий XP, XP до следующего уровня |
| getDamageModifier(attacker, target) → number | Модификатор урона по разнице уровней |

### Remotes

| Remote | Направление | Описание |
|---|---|---|
| UpdateLevel | Server → Client | level, xp, xpRequired |
| UpdateServantLevel | Server → Client | servantId, level, xp |

---

## Система крови

### Обзор

Игрок может выпить кровь поверженного врага (клавиша F рядом с downed-врагом). Тип крови определяется типом врага. Кровь постепенно расходуется по DrainRate.

### Типы крови

| Тип | Бонусы |
|---|---|
| Outcast | Нет бонусов |
| Warrior | PhysicalPower + WeaponCDSpeed |
| Creature | MoveSpeed + HealingReceived |

### Тиры качества

| Тир | Диапазон | Эффект |
|---|---|---|
| I | 1–49% | Базовые бонусы типа |
| II | 50–99% | Усиленные бонусы |
| MAX | 100% | Бонусы + BoostAll ×1.20 |

### BloodManager API

| Метод | Описание |
|---|---|
| drinkBlood(player, bloodType, quality) | Установить тип и качество крови |
| getBlood(player) → type, quality, amount | Текущая кровь |
| tick(player) | Расход крови по DrainRate × BloodDrainRate стат |

### Пополнение

Два способа: DrinkBloodRequest (F рядом с врагом) или Blood Vials (consumable). Качество крови от врага зависит от его уровня относительно игрока.

---

## Система смерти

### Респавн

При нажатии кнопки «Возродиться» клиент отправляет `PlayerRespawn` remote. Сервер (HealthManager) проверяет привязку к гробу через `CoffinHandler.getRespawnPosition(userId)`. Если привязка есть — персонаж телепортируется к позиции перед гробом после загрузки. Если нет — стандартный респавн.

### Серверная логика

При HP = 0 `HealthManager.die()` выполняет следующее:

1. Устанавливает атрибут `IsDead = true` на персонаже
2. Замораживает персонажа: `WalkSpeed = 0`, `JumpPower = 0`, `JumpHeight = 0`
3. Устанавливает `Health = 1` (не 0, чтобы не вызвать Roblox auto-respawn)
4. Устанавливает `MaxHealth = math.huge` (предотвращает повторную смерть)
5. Вызывает EventBus: `PlayerDied`
6. Отправляет `PlayerDied` remote клиенту с `respawnTime`
7. Запускает страховочный `task.delay(respawnTime + 2)` на случай потери remote

### Клиентская логика (DeathScreen)

При получении `PlayerDied` remote показывается экран смерти с таймером обратного отсчёта и кнопкой «Возродиться». Кнопка активируется после истечения таймера. Нажатие отправляет `PlayerRespawn` remote на сервер.

### Проверки IsDead

Следующие системы проверяют `IsDead` перед выполнением действий:

- **CombatManager** — через validateCharacter в MeleeHandler и RangedHandler
- **AbilityManager** — `character:GetAttribute("IsDead")`
- **EnemyTargeting** — сбрасывает AggroTarget на мёртвых игроков
- **BossBehaviors** — сбрасывает AggroTarget на мёртвых игроков

---

## Система баффов

### Обзор

`BuffManager` управляет временными модификаторами на сущностях (игроки, враги, слуги). Баффы определяются в `BuffConfig.luau` с типом (buff/debuff), эффектами и иконкой.

### BuffManager API

| Метод | Описание |
|---|---|
| applyBuff(entity, buffId, duration, source) | Наложить бафф/дебафф |
| removeBuff(entity, buffId) | Снять бафф |
| getStatModifier(entity, statName) → number | Суммарный множитель от всех активных баффов |
| getActiveBuffs(entity) → table | Список активных баффов |

### Интеграция

Баффы влияют на статы через `StatsManager.recalculate()`, который вызывает `BuffManager.getStatModifier()` для каждого стата. Изменение баффов вызывает пересчёт статов.

### Клиент (BuffBar)

`BuffBar.client.luau` отображает активные баффы в левом верхнем углу. Зелёная рамка — бафф, красная — дебафф. Каждый слот показывает иконку, оставшееся время и tooltip при наведении.

### Источники баффов

| Источник | Пример |
|---|---|
| Способности (ApplyBuff) | Axe Q: axe_frenzy (+30% dmg, 5с) |
| Способности (ApplyDebuff) | Sword E: slow (3с на целях) |
| Consumables | Potion: damage_boost (30с) |
| Кровь (Blood Tier) | Warrior MAX: BoostAll ×1.20 |
| Дебаг | `/buff damage_boost 30` |

---

## Регенерация HP

Регенерация работает периодически через `StatsManager.tickRegen(player)`. Формула за тик: `1% × MaxHP × HealthRegen`. Реген блокируется, если игрок «в бою» — флаг устанавливается `StatsManager.markCombat(player)` при атаке или получении урона и сбрасывается через несколько секунд бездействия.

---

## DataStore

### Обзор

`DataService` централизует сохранение и загрузку данных. Имя хранилища: `RisePlayerData_v1`. Автосохранение каждые 120 секунд. MAX_RETRIES = 3 при ошибках. Toggle: `/togglesave` или F9 (только Studio).

### Сохраняемые данные

| Поле | Источник |
|---|---|
| Level, XP | LevelManager |
| Inventory (slots + equipment) | InventoryManager |
| Blood (type, quality, amount) | BloodManager |
| BossEssence | BossPlayerData |
| UnlockedTechs | BossPlayerData |
| Servants | ServantManager |
| Magic (SpellPoints, Learned, Equipped, ClaimedRewards) | SpellProgressManager |
| Castle (CenterPos, Claim, BloodEssence, Blocks, Containers, Stations) | BuildingManager |

### Жизненный цикл

PlayerAdded: DataService.load(player) → InventoryManager.init(player, data) → LevelManager.init(player, data) → BloodManager.init(player, data) → BossManager.initPlayer(player, data) → ServantManager.initPlayer(player, data) → StatsManager.recalculate(player)

PlayerRemoving: DataService.save(player) → собирает данные из всех менеджеров → cleanup в каждом менеджере

BindToClose: → сохраняет данные всех онлайн игроков