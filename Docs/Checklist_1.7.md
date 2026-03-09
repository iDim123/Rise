# Checklist v1.7

> Прогресс по Roadmap v1.7. Отмечены выполненные задачи.

---

## Фаза 1 — Рефакторинг архитектуры ✅

- [x] ItemConfig → `config/ItemConfig.luau` коллектор + `config/items/` подмодули
  - [x] WeaponItems.luau
  - [x] ArmorItems.luau
  - [x] AccessoryItems.luau
  - [x] ConsumableItems.luau
  - [x] ResourceItems.luau
- [x] BossManager → `modules/boss/` (BossManager фасад + BossPlayerData + BossInteraction)
- [x] ServantManager → `modules/servant/` (ServantManager + ServantEquipment)
- [x] Обновлены все require-пути (8 файлов)
- [x] Architecture.md обновлён

---

## Фаза 2 — Система контейнеров ✅

- [x] ContainerConfig.luau (wooden_chest, locked_chest)
- [x] ContainerManager.luau (спавн, лут-генерация, таймеры, состояния)
- [x] ContainerServer.server.luau (remotes: Open, TakeItem, TakeAll, Sort, Close)
- [x] ContainerUI.client.luau (подсказка "Open [F]", окно контейнера, auto-close)
- [x] ContainerAnimator.client.luau (анимация открытия/закрытия)
- [x] CastBar.client.luau (универсальный каст-бар: контейнеры, оружие, способности)
- [x] CastManager.luau (серверная каст-система: таймер, движение, отмена)
- [x] Remotes: ContainerOpen, ContainerClose, ContainerTakeItem, ContainerTakeAll, ContainerSort, ContainerOpened, ContainerUpdate, ContainerClosed, CastStart, CastCancel, CastCancelRequest

---

## Фаза 3 — День/Ночь и лунные циклы ✅

- [x] DayNightConfig.luau (цикл, солнечный дебафф, лунные фазы)
- [x] DayNightManager.luau (серверный тик, Lighting, raycast для тени, BuffManager)
- [x] DayNightHUD.client.luau (UI полоска цикла, иконка солнца/луны, лунная фаза)
- [x] BuffConfig.luau обновлён (+sunlight_exposure, +full_moon_speed, +blood_moon_power, +blood_moon_magic)
- [x] Remotes: DayNightSync
- [x] Солнечный дебафф (raycast тень, grace period)
- [x] Лунные баффы (полнолуние, кровавая луна)
- [x] Debug команды: /settime, /timescale, /phase, /lunar

---

## Фаза 4 — Система дистанционного оружия ✅

### Stage A — Рефакторинг боевой системы

- [x] Remotes.luau: +RangedRelease, ProjectileFired, ProjectileHit, ProjectileRemoved
- [x] WeaponUtil.luau — единый доступ к конфигу оружия
- [x] DamageCalc.luau — единый расчёт урона (Physical, Magic, Ranged)
- [x] TargetFinder.luau — поиск целей (inRadius, inCone, closestInCone, sphereOverlap)
- [x] ResourceHit.luau — удар по ресурсным нодам (hitInCone, hitInRadius)
- [x] MeleeHandler.luau — мили-атака (извлечено из WeaponManager)
- [x] CombatManager.server.luau — центральный роутер
- [x] Тест мили-боя через новые модули
- [x] Удаление WeaponManager.server.luau
- [x] Рефакторинг AbilityManager.luau (использует shared модули)
- [x] WeaponConfig → weapons/ (SwordConfig, AxeConfig) + коллектор

### Stage B — Дальний бой (сервер)

- [x] ProjectileConfig.luau (arrow, power_arrow, rain_arrow)
- [x] BowConfig.luau (Ranged, CastTime, ProjectileId, способности Q/E)
- [x] WeaponItems.luau обновлён (Bow entry)
- [x] ProjectileManager.luau (виртуальная симуляция, sphereOverlap, pierce, лимит 50)
- [x] RangedHandler.luau (каст → ожидание RangedRelease → выстрел, fallback по LookVector)
- [x] CombatManager обновлён (прямые require вместо lazy load)
- [x] Тест серверной стрельбы

### Stage C — Клиент

- [x] MeleeInput.luau (извлечено из CombatInput)
- [x] RangedInput.luau (FSM: Idle→Casting→Ready, авто-перезарядка, early release)
- [x] CombatInput.client.luau (роутер: Melee/Ranged по типу оружия)
- [x] ProjectileVisuals.client.luau (neon Part + Trail, hit эффекты, fade out)

### Stage D — Полировка

- [x] Тест Q/E способностей лука (Power Shot, Arrow Rain)
- [x] Debug команды: /bow, /weapon
- [x] Fix: CastBar baseSpeed из сервера (не хардкод 16)
- [x] Fix: CastBar task.delay утечка при последовательных кастах
- [x] Fix: горизонтальное направление снарядов (flatDirection, без Y)
- [x] Fix: унификация getMouseWorldPosition (AbilitiesBar = RangedInput)
- [x] Fix: авто-перезарядка при зажатом ЛКМ (cooldown delay)
- [x] Fix: RangedInput stuck state (forced cleanup, stuck timeout)
- [x] Очистка debug print-ов
- [x] Обновление debug_commands.md
- [x] Документация разбита на файлы:
  - [x] Architecture.md (сокращён)
  - [x] Systems_Combat.md
  - [x] Systems_Player.md
  - [x] Systems_Inventory.md
  - [x] Systems_Entities.md
  - [x] Systems_UI.md
  - [x] Remotes.md
  - [x] Dependencies.md

### Не реализовано из Roadmap (перенесено)

- [ ] Враги с дальним оружием (Archer, EnemyBehaviors Ranged AI, kite-AI)
- [ ] Модели снарядов в ServerStorage/projectiles/ (сейчас используются neon Part)
- [ ] MultiProjectile эффект (веерный залп) — в Roadmap был bow_multishot
- [ ] fire_arrow / enemy_arrow типы снарядов
- [ ] OnHitEffects в ProjectileConfig (ApplyDebuff при попадании)
- [ ] Прицел дальности при экипированном луке

---

## Фаза 5 — Система магии 🔲

Не начата. Запланирована в Roadmap_1.7.md.

- [ ] SpellConfig.luau (школы: Blood, Chaos)
- [ ] SpellManager.luau (серверная логика заклинаний)
- [ ] SpellbookUI (клиентское окно заклинаний)
- [ ] Spell Points (получение с боссов)
- [ ] Пассивные механики школ (Leech, Ignite)
- [ ] Тировая прогрессия (I → II → III → ULT)
- [ ] Новые типы эффектов (AoEHeal, AoEBuff, Block, Channelling, Beam)
- [ ] Интеграция с ProjectileManager (shadowbolt и т.д.)
- [ ] Слоты R, G, Z для заклинаний

---

## Сводка

| Фаза | Статус | Описание |
|---|---|---|
| Фаза 1 | ✅ Завершена | Рефакторинг архитектуры (ItemConfig, BossManager, ServantManager) |
| Фаза 2 | ✅ Завершена | Система контейнеров (сундуки, CastBar, CastManager) |
| Фаза 3 | ✅ Завершена | День/Ночь, лунные циклы, солнечный дебафф |
| Фаза 4 | ✅ Завершена | Дальний бой (Bow, снаряды, рефакторинг combat/) |
| Фаза 5 | 🔲 Не начата | Система магии (Spellbook) |