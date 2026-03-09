# Entity Systems

> Враги, боссы, слуги, AI.

---

## Архитектура

Все NPC-сущности (враги, боссы, слуги) — это Model в Workspace с Humanoid. Жизненный цикл управляется серверными модулями через EventBus. AI работает в цикле с тиком 0.2с.

### Серверные модули

| Модуль | Папка | Назначение |
|---|---|---|
| EnemySpawner.luau | modules/ | Спавн/респавн врагов (слушает EntityRemoved) |
| EnemyManager.server.luau | enemy/ | Инициализация спавна из SpawnPoints |
| EnemyAI.server.luau | enemy/ | Главный AI loop (0.2с тик) |
| EnemyBehaviors.luau | enemy/ | Состояния врагов: Idle/Patrol/Chase/Attack/Return |
| EnemyTargeting.luau | enemy/ | Поиск целей, стайное агро |
| EnemyStateManager.luau | enemy/ | Хранение состояний, patrol points |
| BossServer.server.luau | enemy/ | Спавн боссов, remotes Finish/Capture |
| BossBehaviors.luau | enemy/ | AI боссов: Chase/Attack/Return, leash, enrage |
| BossAbilities.luau | enemy/ | Способности боссов: pickAbility, execute, cooldowns |
| BossManager.luau | modules/boss/ | Фасад: спавн, состояния, делегирование |
| BossPlayerData.luau | modules/boss/ | Per-player данные: эссенция, техники |
| BossInteraction.luau | modules/boss/ | Взаимодействия: finishBoss, captureBoss |
| ServantManager.luau | modules/servant/ | Захват, призыв, отзыв, режимы, createFromEgg |
| ServantEquipment.luau | modules/servant/ | Экипировка слуг: equip/unequip, recalcStats |
| ServantServer.server.luau | servant/ | Remotes: capture, summon, dismiss, equip, rename |
| ServantAI.server.luau | servant/ | AI слуг: follow/attack/stay |

### Клиентские модули

| Модуль | Назначение |
|---|---|
| EnemyLabels.client.luau | Billboard labels: "Выпить кровь [F]", "Захватить [T]" |
| EnemyHPBar.client.luau | Billboard HP bar: hover/linger/damaged, level color |
| TargetInfo.client.luau | Target HUD: имя, уровень, HP, blood type |
| ServantWindow.client.luau | Окно слуг (клавиша V) |
| ServantCollection.luau | Список захваченных слуг |
| ServantStatsPanel.luau | Статы слуги |
| ServantEquipPanel.luau | Экипировка слуги |
| ServantActionBar.luau | Команды слуге |

---

## Враги

### Конфигурация (EnemyConfig)

Каждый тип врага определяется в `EnemyConfig.luau`:

| Поле | Тип | Описание |
|---|---|---|
| Name | string | Отображаемое имя |
| Level | number | Фиксированный уровень (если нет Min/MaxLevel) |
| MinLevel / MaxLevel | number | Диапазон для рандомного уровня при спавне |
| HP | number | Базовое HP |
| Damage | number | Базовый урон |
| AttackRange | number | Дальность атаки (studs) |
| AttackSpeed | number | Интервал между атаками (сек) |
| AggroRange | number | Радиус агро (studs) |
| PackRadius | number | Радиус стайного агро (опционально) |
| CanCapture | bool | Можно ли захватить (default true) |
| MoveSpeed | number | Скорость передвижения |

### Спавн

`EnemyManager.server.luau` при старте сервера находит все `SpawnPoint` объекты в Workspace и вызывает `EnemySpawner.spawn()`. SpawnPoint может иметь атрибут `Level` для переопределения уровня из конфига. При гибели врага `EnemySpawner` слушает `EntityRemoved` через EventBus и респавнит с сохранением SpawnLevel.

Рандомный уровень при спавне: если в конфиге есть `MinLevel` и `MaxLevel`, уровень выбирается случайно в диапазоне. Уровень влияет на HP и урон.

### AI — состояния

Copy
    обнаружил цель               цель в AttackRange
IDLE ──────────────→ CHASE ──────────────→ ATTACK ↑ │ │ │ PATROL │ цель потеряна │ цель вне range ↕ ↓ ↓ ↓ PATROL ← ─ ─ ─ ─ ─ RETURN ← ── ── ── ── CHASE


| Состояние | Описание |
|---|---|
| Idle | Стоит на месте, проверяет AggroRange |
| Patrol | Перемещается между patrol points (если заданы) |
| Chase | Бежит к цели, проверяет AttackRange |
| Attack | Атакует цель с интервалом AttackSpeed, применяет damage modifiers |
| Return | Возвращается к точке спавна (цель потеряна или слишком далеко) |

### EnemyTargeting

`findNearestPlayer(enemy)` — находит ближайшего живого игрока в AggroRange. Проверяет `IsDead` атрибут и сбрасывает AggroTarget на мёртвых игроков.

`alertPack(enemy, target)` — стайное агро: при обнаружении цели оповещаются все враги того же типа в `PackRadius`. Используется для волков и подобных стайных врагов.

### Урон от врагов

`EnemyBehaviors` рассчитывает урон врага с учётом damage modifiers (разница уровней: +1%/уровень сверху, -4%/уровень снизу). Применяет урон через `HealthManager.takeDamage()`.

### Headless модели

Некоторые враги (Wolf) не имеют части Head. `EnemyUtil.getHead()` обеспечивает fallback: Head → UpperTorso → Torso → HumanoidRootPart → PrimaryPart. Используется для Billboard GUI (HP bar, labels).

---

## Боссы

### Конфигурация (BossConfig)

Боссы определяются в `BossConfig.luau`:

| Поле | Тип | Описание |
|---|---|---|
| Name | string | Отображаемое имя |
| Level | number | Уровень босса |
| Act | number | Номер акта (для Boss Journal) |
| HP | number | Базовое HP |
| Damage | number | Базовый урон |
| AggroRange | number | Радиус агро |
| Abilities | table | Список способностей |
| Loot | table | Таблица лута |
| Unlocks | table | Разблокируемые технологии |
| EssenceRequired | number | Эссенция для захвата |
| DownedTimeout | number | Время в состоянии Downed (сек) |
| InteractRange | number | Дальность взаимодействия (F/T) |

### Жизненный цикл

            HP = 1           добивание (F)
ALIVE ──────────→ DOWNED ──────────────────→ DEAD │ ↑ │ захват (T) │ │ (если эссенция ≥ req) │ └──────────────────────────┘ │ │ таймаут DownedTimeout └──────────────────────────→ DEAD (авто-смерть)


| Состояние | Описание |
|---|---|
| ALIVE | Босс жив, AI активен |
| DOWNED | HP = 1, босс повержен, таймер DownedTimeout |
| DEAD | Босс мёртв, запускается респавн |

### Эссенция

Per-player система. Каждое убийство босса даёт +1 эссенцию данному игроку. При достижении `EssenceRequired` игрок может захватить босса (T) вместо добивания (F). Данные хранятся в `BossPlayerData` и сохраняются в DataStore.

### Способности боссов

`BossAbilities.luau` управляет способностями: `pickAbility(boss)` выбирает готовую способность по cooldown, `execute(boss, ability, target)` выполняет её. Каждая способность имеет Damage, Range, Cooldown, AnimationId.

### AI боссов (BossBehaviors)

Отдельный от обычных врагов AI с дополнительными механиками:

| Механика | Описание |
|---|---|
| Leash | Если босс убежал дальше `AggroRange × 3` от спавна — возвращается |
| Enrage | При низком HP увеличивается скорость атаки |
| Abilities | Использует способности из BossAbilities |
| IsDead check | Сбрасывает AggroTarget на мёртвых игроков |

### Взаимодействия (BossInteraction)

| Действие | Клавиша | Remote | Описание |
|---|---|---|---|
| Добивание | F | BossFinish | Убивает босса, даёт лут и XP |
| Захват | T | BossCapture | Создаёт слугу через ServantManager.createFromEgg |

### Технологии (Unlocks)

При первом убийстве босса разблокируются технологии — рецепты крафта. Разблокировка сохраняется в DataStore. Клиент получает `UnlockTech` remote.

### Boss Journal (клиент)

Окно журнала боссов (`boss/` UI папка):

| Модуль | Описание |
|---|---|
| BossJournalInit.client.luau | Точка входа |
| BossJournal.luau | Полноэкранное окно, скролл, фильтрация по актам |
| BossCard.luau | Карточка босса: имя, уровень, эссенция, техники |
| BossTooltip.luau | Tooltip технологий |
| BossJournalConstants.luau | UI константы и палитра |
| ActTabs.luau | Табы актов |

---

## Слуги

### Обзор

Слуги — захваченные враги, которые сражаются на стороне игрока. Захват происходит через `CaptureRequest` (клавиша T рядом с downed-врагом) или `BossCapture` (T рядом с downed-боссом при достаточной эссенции).

### Конфигурация (ServantConfig)

| Поле | Описание |
|---|---|
| MaxServants | Максимум захваченных слуг |
| MaxActive | Максимум одновременно призванных |
| CaptureThreshold | HP порог для захвата обычных врагов |
| Modes | Aggressive, Defensive, Passive |
| Commands | Follow, Stay, AttackTarget |
| EquipmentSlots | Слоты экипировки слуги |
| PowerBase | Базовая сила |

### Статы слуги

Power = PowerBase + PowerBase × (Expertise / 100) + sum(ItemLevel экипировки) ATK = baseATK + Power / 10 MaxHP = baseHP + Power


`ServantEquipment.recalcStats(servant)` пересчитывает статы при изменении экипировки.

### Жизненный цикл

Захват (CaptureRequest / BossCapture) → ServantManager.captureEnemy(player, enemy) → Создание записи слуги в данных игрока → EventBus: EntityRemoved (враг удаляется из мира)

Призыв (SummonServant) → ServantManager.summon(player, servantId) → Клонирование модели, спавн рядом с игроком → ServantAI начинает управление

Отзыв (DismissServant) → ServantManager.dismiss(player) → Удаление модели из мира → ServantAI прекращает управление


### AI слуг (ServantAI)

AI слуги зависит от режима и команды:

| Режим | Поведение |
|---|---|
| Aggressive | Атакует ближайшего врага в радиусе |
| Defensive | Атакует только тех, кто атаковал хозяина |
| Passive | Не атакует |

| Команда | Поведение |
|---|---|
| Follow | Следует за хозяином |
| Stay | Остаётся на месте |
| AttackTarget | Атакует указанную цель |

Урон слуги масштабируется статом `FamiliarDamage` хозяина.

### Экипировка слуг

Слуги имеют свои слоты экипировки (определены в ServantConfig.EquipmentSlots). Экипировка берётся из инвентаря хозяина.

| Remote | Направление | Описание |
|---|---|---|
| EquipServantItem | Client → Server | Экипировать предмет на слугу |
| UnequipServantItem | Client → Server | Снять экипировку со слуги |

### Дополнительные возможности

| Функция | Remote | Описание |
|---|---|---|
| Переименование | RenameServant | Задать кастомное имя слуге |
| Избранное | ToggleServantFavorite | Пометить слугу как избранного |
| createFromEgg | — | Создание слуги из "яйца" (захват босса) |

### Remotes слуг

| Remote | Направление | Описание |
|---|---|---|
| SummonServant | Client → Server | Призвать слугу |
| DismissServant | Client → Server | Отозвать слугу |
| SetServantMode | Client → Server | Режим (Aggressive/Defensive/Passive) |
| ServantCommand | Client → Server | Команда (Follow/Stay/AttackTarget) |
| RenameServant | Client → Server | Переименовать слугу |
| ToggleServantFavorite | Client → Server | Переключить избранное |
| UpdateServantData | Server → Client | Обновление данных слуг |
| GetServants | Client → Server (Function) | Получить { captured, activeId } |

### Клиент (ServantWindow)

Окно слуг (клавиша V):

| Модуль | Описание |
|---|---|
| ServantWindow.client.luau | Оркестратор окна |
| ServantCollection.luau | Список захваченных слуг |
| ServantStatsPanel.luau | Статы выбранного слуги |
| ServantEquipPanel.luau | Экипировка слуги |
| ServantActionBar.luau | Кнопки: призвать, отозвать, режим, команды |

---

## EventBus — события сущностей

| Событие | Аргументы | Кто вызывает | Кто слушает |
|---|---|---|---|
| EntityDying | entity, attacker | HealthManager.die() | LootManager (дроп), LevelManager (XP) |
| EntityRemoved | enemyType, spawnPos, spawnLevel | HealthManager.die(), ServantManager.captureEnemy() | EnemySpawner (респавн) |
| PlayerDied | player, entity, attacker | HealthManager.die() | HealthManager (заморозка, remote клиенту) |

---

## Визуализация (клиент)

### EnemyLabels

Billboard labels над врагами. Показываются при приближении игрока:

| Метка | Условие | Клавиша |
|---|---|---|
| "Выпить кровь [F]" | Враг downed, игрок рядом | F |
| "Захватить [T]" | Враг downed, CanCapture = true, игрок рядом | T |

### EnemyHPBar

Billboard HP bar над врагами. Скрыт по умолчанию, показывается при hover (3с linger) или если враг повреждён. Tween-анимация HP. Level label с цветом через `LevelColorUtil`. Humanoid.DisplayDistanceType = None (скрывает дефолтное имя Roblox).

### TargetInfo

HUD панель (top-center): имя цели, уровень (цвет по разнице), HP bar (tween), тип и качество крови. Работает на врагов и других игроков. Fade in/out анимация.

Цвет уровня (LevelColorUtil): white (≤ -5) → yellow (≤ 0) → orange (≤ 4) → red (≤ 9) → skull (≥ 10).