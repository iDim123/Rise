# Combat System

> Боевая система Rise: мили, дальний бой, снаряды, способности, каст-система.

---

## Архитектура

Боевая система разделена на сервер и клиент. Сервер — авторитетный: рассчитывает урон, проверяет cooldown, управляет снарядами. Клиент отвечает за ввод, анимации и визуализацию.

### Серверные модули (`src/server/combat/`)

| Модуль | Назначение |
|---|---|
| CombatManager.server.luau | Роутер: принимает AttackRequest, RangedRelease, UseAbility, направляет в нужный обработчик |
| WeaponUtil.luau | getConfig(player), getType(cfg), isRanged(cfg) — общий доступ к конфигу оружия |
| DamageCalc.luau | Единый расчёт урона: power scaling, crit, resist, level modifier |
| TargetFinder.luau | Поиск целей: spatial hash grid (CELL_SIZE=50), inRadius, inCone, closestInCone, sphereOverlap, raycast |
| ResourceHit.luau | Удар по ресурсным нодам: hitInCone (мили), hitInRadius (AoE) |
| MeleeHandler.luau | Мили-атака: cooldown, комбо, поиск целей, урон, ресурсы |
| RangedHandler.luau | Дальняя атака: каст → ожидание RangedRelease → выстрел снаряда |
| ProjectileManager.luau | Виртуальная симуляция снарядов: движение, hit detection, pierce, лимит 50 |

### Клиентские модули (`src/client/combat/`)

| Модуль | Назначение |
|---|---|
| CombatInput.client.luau | Роутер ввода: LMB → MeleeInput или RangedInput по типу оружия |
| MeleeInput.luau | Мили: комбо-цепочка, анимации, AttackRequest |
| RangedInput.luau | Дальний бой: FSM (Idle→Casting→Ready), авто-перезарядка, RangedRelease |
| ProjectileVisuals.client.luau | Визуализация снарядов: neon Part + Trail, hit эффекты, fade out |
| DamageNumbers.client.luau | Всплывающие числа урона |

### Серверные модули поддержки (`src/server/modules/`)

| Модуль | Назначение |
|---|---|
| CastManager.luau | Универсальная каст-система: таймер, движение, отмена по стану/урону/движению |
| AbilityManager.luau | Способности Q/E: cooldown, эффекты (DirectDamage, AoEDamage, ApplyBuff, ApplyDebuff, Projectile, AoEProjectile) |

---

## Поток данных

### Мили-атака (Sword, Axe)

Copy
Client: LMB down → CombatInput → MeleeInput.start() → attackLoop: вычисляет comboIndex, играет анимацию → AttackRequest:FireServer(mousePos, comboIndex)

Server: CombatManager → WeaponUtil.isRanged? → нет → MeleeHandler.attack(player, mousePos, comboIndex, cfg) → isOnCooldown? → TargetFinder.inCone() → DamageCalc.calculate() → HealthManager.takeDamage() → ResourceHit.hitInCone()

Client: LMB up → MeleeInput.stop() → прекращает attackLoop


### Дальняя атака (Bow)

Client: LMB down → CombatInput → RangedInput.start() → beginCast() → state = CASTING → AttackRequest:FireServer(mousePos)

Server: CombatManager → WeaponUtil.isRanged? → да → RangedHandler.attack(player, mousePos, cfg) → CastManager.start(Duration=0.8, Slowed) → CastStart → Client (CastBar показывает полоску)

Server: CastManager → OnComplete → RangedHandler: pendingCasts[player], ждёт RangedRelease → Fallback: через 1с стреляет по LookVector

Client: CastBar → CastComplete event → RangedInput: если isHolding → sendReleaseAndRefire() → RangedRelease:FireServer(mousePos) → cleanup() → task.delay(cooldown) → beginCast() (авто-перезарядка)

Server: CombatManager → RangedRelease → RangedHandler.onRelease(player, mousePos) → applyCooldown() → fireProjectile() → ProjectileManager.fire() → виртуальный снаряд, Heartbeat обновление → sphereOverlap hit detection → DamageCalc → HealthManager.takeDamage() → ProjectileFired/ProjectileHit/ProjectileRemoved → Client

Client: ProjectileVisuals → создаёт neon Part + Trail → Heartbeat: обновляет позицию → hit: эффект взрыва, fade out


### Способности (Q / E)

Client: AbilitiesBar → KeyCode.Q/E → UseAbility:FireServer(key, mousePos)

Server: CombatManager → AbilityManager.useAbility() → cooldown check (WeaponCDSpeed / MagicCDSpeed) → для каждого Effect: DirectDamage → TargetFinder.closestInCone → DamageCalc → takeDamage AoEDamage → TargetFinder.inRadius → DamageCalc → takeDamage (all) ApplyBuff → BuffManager.applyBuff ApplyDebuff → TargetFinder.inRadius → BuffManager.applyBuff (all) Projectile → ProjectileManager.fire (power_arrow, pierce) AoEProjectile → N × ProjectileManager.fire (rain_arrow, сверху вниз) → AbilityCooldown → Client


---

## RangedInput — конечный автомат

     LMB down              CastComplete           LMB up
IDLE ──────────────→ CASTING ──────────────→ READY ──────────→ (sendRelease) │ │ │ LMB up (early) │ │ → сохраняет earlyReleasePos │ │ → при CastComplete отправляет │ │ сохранённую позицию │ │ │ │ CastCancel │ └──────────→ IDLE │ │ isHolding = true? │ ← ── ── ── ── ── ── ── ── ── ── ── ── ── ── ── ── ── ── ┘ task.delay(cooldown + 0.05) → beginCast() (авто-перезарядка)


Три состояния: **Idle** (ожидание), **Casting** (каст идёт, CastBar показывается), **Ready** (каст завершён, ожидание отпускания LMB). Если `isHolding = true` при завершении каста, происходит немедленный `sendReleaseAndRefire` — отправка `RangedRelease` и запуск нового каста через `cooldown + 0.05с`.

---

## DamageCalc — формула урона

powerScaling = baseDamage × (1 + power / 10) power = PhysicalPower (Physical/Ranged) или MagicalPower (Magic)

crit: если random < critChance → damage × critMultiplier Physical/Ranged: PhysCritChance, PhysCritDamage Magic: MagicCritChance, MagicCritDamage

resistance = 1 - resist/100 Physical/Ranged: PhysResistance Magic: MagicResistance

levelModifier = LevelManager.getDamageModifier(attacker, target) +1% за каждый уровень выше, -4% за каждый уровень ниже (cap ±100%)

finalDamage = math.max(1, math.floor(afterResist × levelModifier))


Возвращает `finalDamage, isCrit`.

---

## ProjectileManager — снаряды

Виртуальная симуляция на сервере. Клиент получает события для визуализации.

### Параметры снаряда (ProjectileConfig)

| Поле | arrow | power_arrow | rain_arrow |
|---|---|---|---|
| Speed | 120 | 160 | 80 |
| MaxDistance | 60 | 80 | 30 |
| Gravity | 0 | 0 | 50 |
| PierceCount | 0 | 2 | 0 |
| Lifetime | 3 | 3 | 2 |
| HitRadius | 2 | 2.5 | 3 |
| TrailColor | 255,220,100 | 255,100,100 | 200,200,255 |

### Механика

Каждый кадр (Heartbeat) обновляется позиция: `position += direction × speed × dt`. Вертикальная скорость: `velocityY -= gravity × dt`, `position.Y += velocityY × dt`. Горизонтальное расстояние отслеживается отдельно (gravity не влияет на дистанцию). Удаление снаряда: превышен MaxDistance, Lifetime, попадание в землю (Raycast вниз), или pierce исчерпан.

Hit detection: `TargetFinder.sphereOverlap(position, hitRadius)` каждый кадр. Список `hitList` предотвращает двойное попадание. Pierce: `pierceLeft` уменьшается при каждом попадании; при `pierceLeft < 0` снаряд удаляется.

Лимит: максимум 50 активных снарядов. При превышении удаляется самый старый.

### Remotes

| Remote | Направление | Данные |
|---|---|---|
| ProjectileFired | Server → All Clients | id, origin, direction, projectileId, speed, gravity |
| ProjectileHit | Server → All Clients | id, position, isCrit |
| ProjectileRemoved | Server → All Clients | id |

---

## CastManager — каст-система

Универсальный серверный модуль для действий с временем каста (натяжение лука, взаимодействие с контейнерами).

### API

| Метод | Описание |
|---|---|
| start(player, params) → castId | Запуск каста. Возвращает nil если уже кастуется |
| cancel(player, reason) | Отмена каста |
| isActive(player) → bool | Проверка активного каста |
| getCast(player) → castData | Данные текущего каста |

### Параметры (params)

| Поле | Тип | Описание |
|---|---|---|
| Duration | number | Время каста в секундах |
| Label | string | Текст на CastBar |
| MovementMode | string | "Locked" / "Slowed" / "Free" / "CancelOnMove" |
| SpeedMult | number | Множитель скорости при "Slowed" (0-1) |
| CancelKey | string | Клавиша отмены ("MMB", "RMB", KeyCode) |
| CancelOnStun | bool | Отменять при стане (default true) |
| CancelOnDamage | bool | Отменять при получении урона |
| OnComplete | function | Callback при успешном завершении |
| OnCancel | function | Callback при отмене |

### Клиент (CastBar.client.luau)

CastBar получает `CastStart` remote с параметрами (Duration, Label, Icon, MovementMode, SpeedMult, BaseSpeed). Показывает полоску с tween-заполнением, применяет замедление (`baseSpeed × speedMult`), по завершении вызывает `CastComplete` (BindableEvent в ScreenGui "CastBarUI"). Отмена: `CastCancel` remote или клавиша CancelKey.

---

## Конфиги оружия

### Структура (`src/shared/config/weapons/`)

Каждое оружие — отдельный файл: `SwordConfig.luau`, `AxeConfig.luau`, `BowConfig.luau`. Коллектор `WeaponConfig.luau` автоматически загружает все файлы из папки `weapons/` и возвращает `{ Weapons = { Sword = ..., Axe = ..., Bow = ... } }`.

### Общие поля

| Поле | Тип | Описание |
|---|---|---|
| Type | string | "Melee" или "Ranged" |
| Damage | number | Базовый урон |
| Range | number | Дальность (studs) |
| Cooldown | number | Время между атаками (сек) |
| ResourceDamage | number | Урон по ресурсным нодам |
| Combo | table | Массив комбо-ударов: { Damage, AnimationId } |
| ComboAbility | table | Данные для слота LMB в AbilitiesBar |
| Abilities | table | Q и E способности |

### Дополнительные поля (Ranged)

| Поле | Тип | Описание |
|---|---|---|
| CastTime | number | Время натяжения (сек) |
| ProjectileId | string | Ключ из ProjectileConfig |
| CastMovementMode | string | Режим движения при касте |
| CastSpeedMult | number | Множитель скорости при касте |

### Пример: Bow

```lua
{
    Type = "Ranged",
    Damage = 18,
    Range = 60,
    Cooldown = 0.3,
    CastTime = 0.8,
    ProjectileId = "arrow",
    ResourceDamage = 0,
    CastMovementMode = "Slowed",
    CastSpeedMult = 0.5,
    Abilities = {
        Q = { Id = "power_shot", Effects = {{ Type = "Projectile", ProjectileId = "power_arrow", Damage = 50, PierceCount = 2 }} },
        E = { Id = "arrow_rain", Effects = {{ Type = "AoEProjectile", ProjectileId = "rain_arrow", Damage = 25, Radius = 12, Count = 8, SpawnHeight = 40 }} }
    }
}
Типы эффектов способностей
Тип	Описание	Используется
DirectDamage	Урон ближайшей цели в конусе	Sword Q (sword_slash)
AoEDamage	Урон всем целям в радиусе	Axe E (axe_whirlwind)
ApplyBuff	Бафф на игрока	Axe Q (axe_frenzy)
ApplyDebuff	Дебафф на целей в радиусе	Sword E (sword_thrust)
Projectile	Одиночный снаряд	Bow Q (power_shot)
AoEProjectile	Дождь снарядов в область	Bow E (arrow_rain)
Вспомогательные модули
WeaponUtil
Единая точка доступа к конфигу оружия. Ленивая загрузка InventoryManager. getConfig(player) возвращает конфиг и предмет из активного слота. getType(cfg) возвращает "Melee" по умолчанию для обратной совместимости.

TargetFinder (v1.8: spatial hash grid)
Использует пространственный хэш-грид (CELL_SIZE=50 studs, обновление каждые 0.2с) для быстрого поиска целей. Запросы читают только ячейки, пересекающие AABB запроса → O(K) вместо O(N), где K — количество entity в релевантных ячейках. При 100 врагах на карте запрос inRadius(30) проверяет ~4 ячейки вместо всех 100+ entity.

Метод	Описание
inRadius(pos, radius, ignore)	Все враги/игроки в радиусе (spatial hash)
inCone(pos, dir, range, dotMin, ignore)	Все цели в конусе (spatial hash + dot product ≥ dotMin)
closestInCone(pos, dir, range, dotMin, ignore)	Ближайшая цель в конусе
sphereOverlap(pos, radius, hitList)	Все Humanoid в радиусе для снарядов (spatial hash)
refreshGrid()	Принудительное обновление грида
getGridStats()	Диагностика: количество ячеек и entity
ResourceHit
Метод	Описание
hitInCone(player, rootPart, dir, range, cfg)	Удар по первой ноде в конусе (мили)
hitInRadius(player, rootPart, radius, cfg)	Удар по всем нодам в радиусе (AoE)
Использует горизонтальное расстояние (игнорирует Y) для консистентности с наземными ресурсами.

flatDirection
Все направления атак и снарядов рассчитываются без Y-компоненты: Vector3.new(dir.X, 0, dir.Z).Unit. Это обеспечивает горизонтальный полёт стрел и одинаковое направление для ЛКМ и Q/E. На клиенте (RangedInput, AbilitiesBar) позиция мыши вычисляется проекцией луча камеры на горизонтальную плоскость (groundY = rootPart.Y - 3).

---

## Система магии — заклинания

### Архитектура

Магия — отдельная боевая система, не привязанная к оружию. Заклинания экипируются в слоты R (Basic), G (Basic), Z (Ultimate) через Spellbook UI. Кастование обрабатывается `SpellCastManager`, эффекты — модульными обработчиками в `spellEffects/`.

### Серверные модули

| Модуль | Назначение |
|---|---|
| SpellProgressManager.luau | Spell Points, изучение, экипировка, тировые бонусы, синхронизация с UI |
| SpellCastManager.luau | Кастование, cooldown, charges, channelling, SpellAim, делегирование в spellEffects |
| LeechHandler.luau | Blood пассивка: heal on hit (10-12%), heal on kill (3-5%), slow (T3) |
| IgniteHandler.luau | Chaos пассивка: DoT, explosion, chain ignite |

### Обработчики эффектов (spellEffects/)

| Модуль | Тип эффекта | Используется в |
|---|---|---|
| ProjectileEffect | Projectile | shadowbolt |
| MultiProjectileEffect | MultiProjectile | chaos_volley, chaos_barrage |
| ChannelledProjectileEffect | ChannelledProjectile | (расширение) |
| TargetAreaProjectileEffect | TargetAreaProjectile | void |
| AoEDamageEffect | AoEDamage | blood_rite (OnBlockTriggered) |
| AoEHealEffect | AoEHeal | blood_rage |
| AoEBuffEffect | AoEBuff | blood_rage |
| AoEApplyPassiveEffect | AoEApplyPassive | blood_rage, blood_rite |
| BeamEffect | Beam | crimson_beam |
| BlockEffect | Block | blood_rite |
| FrontalBlockEffect | FrontBlock | chaos_barrier |
| ImmaterialEffect | Immaterial | blood_rite (OnBlockTriggered) |
| HealCasterEffect | HealCaster | crimson_beam (OnHitEnemy) |
| PullEffect | Pull | void (OnHitEffects) |

### Поток данных — кастование заклинания

Copy
Client: R/G/Z key → SpellSection/UltimateSection → CastSpell:FireServer(slot, mousePos) → SpellAimSender.start() (отправляет SpellAim каждые 50мс)

Server: CombatManager → SpellCastManager.castSpell(player, slot, mousePos) → Проверки: экипировано, cooldown, charges, IsDead, не в касте → CastManager.start(Duration, MovementMode) → CastStart → Client (CastBar) → SpellAim remote обновляет lastMousePosition[userId]

Server: CastManager → OnComplete → SpellCastManager._execute(player, spell, lastMousePosition) → Для каждого Effect: загружает handler из spellEffects/ → handler.execute(player, effectCfg, mousePos, spellConfig) → SpellCooldown → Client → SpellChargeUpdate → Client (если charges)

Client: CastBar → CastComplete → SpellAimSender.stop()


### Beam — особый поток

Client: Z key → CastSpell → Server: CastManager → OnComplete → BeamEffect.execute() → BeamStart → All Clients (BeamVisual создаёт Part) → Heartbeat loop: SpellAim → Server обновляет direction → BeamTick → All Clients (обновляют визуал) → TickRate (0.2s): damage enemies, heal allies в луче → По завершении Duration → BeamEnd → All Clients (cleanup)


### Charges

Заклинания с `Charges > 1` (void: 2 заряда) хранят массив таймеров в SpellCastManager. При использовании тратится 1 заряд, запускается независимый таймер `ChargeRechargeTime`. Клиент получает `SpellChargeUpdate` с количеством зарядов и временами восстановления.

### SpellAim — прицеливание в конце каста

Проблема: позиция курсора фиксировалась при начале каста. Решение: клиент отправляет `SpellAim` remote каждые 50мс через `SpellAimSender`. Сервер хранит `lastMousePosition[userId]` и использует его в `OnComplete`. Автоматически останавливается при завершении каста или `CastCancel`.