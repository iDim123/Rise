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

## Фаза 5 — Система магии ✅

### 5.1 — SpellConfig (конфигурация заклинаний)

- [x] SpellConfig.luau — коллектор, собирает модули из `config/spells/`
- [x] BloodSchool.luau — школа Blood: описание, пассивка Leech, TierBonuses, UltTierBonus
- [x] ChaosSchool.luau — школа Chaos: описание, пассивка Ignite, TierBonuses, UltTierBonus
- [x] SpellSlots: R (Basic), G (Basic), Z (Ultimate)
- [x] Заклинания Blood: blood_rage (T1), sanguine_coil (T1, charges), shadowbolt (T2), blood_rite (T3), crimson_beam (ULT)
- [x] Заклинания Chaos: chaos_volley (T1), void (T2, charges), chaos_barrier (T3), chaos_barrage (ULT)

### 5.2 — BossConfig (награды Spell Points)

- [x] BossConfig.luau: SpellPointRewards (массив) для каждого босса
- [x] BossInteraction.luau: цикл по SpellPointRewards, обратная совместимость с SpellPointReward
- [x] BloodWarrior: Blood T1 × 1
- [x] SawmillBoss: Chaos T1 × 1, Blood T2 × 1

### 5.3 — SpellProgressManager

- [x] SpellProgressManager.luau — Spell Points, изучение, экипировка, прогресс
- [x] addSpellPoints(player, school, tier, amount)
- [x] canLearnSpell / learnSpell — проверка и трата поинтов
- [x] equipSpell / unequipSpell — слоты R, G, Z с валидацией
- [x] isTierComplete / getTierBonuses / getEffectivePassive — тировая прогрессия
- [x] getProgressData — полные данные для UI
- [x] Тиры независимы — можно изучать в любой последовательности
- [x] pointsKey: "ULT" для Ultimate, строка тира для обычных

### 5.4 — SpellCastManager

- [x] SpellCastManager.luau — кастование, исполнение эффектов, channelling, charges
- [x] castSpell(player, slot, mousePosition) — проверки cooldown, charges, IsDead, каст
- [x] Динамическая загрузка обработчиков из `modules/spellEffects/`
- [x] Charges-система (независимое восстановление, SpellChargeUpdate remote)
- [x] SpellAim — позиция курсора обновляется во время каста, используется при завершении

### 5.5 — Обработчики эффектов заклинаний (spellEffects/)

- [x] ProjectileEffect.luau — одиночный снаряд
- [x] MultiProjectileEffect.luau — последовательные снаряды (chaos_volley, chaos_barrage)
- [x] ChannelledProjectileEffect.luau — каналируемые снаряды
- [x] TargetAreaProjectileEffect.luau — снаряд в точку (void)
- [x] AoEDamageEffect.luau — урон в радиусе
- [x] AoEHealEffect.luau — лечение союзников
- [x] AoEBuffEffect.luau — баффы союзникам
- [x] AoEApplyPassiveEffect.luau — наложение Leech/Ignite
- [x] BeamEffect.luau — каналируемый луч (crimson_beam), мутабельное направление
- [x] BlockEffect.luau — полный блок (blood_rite)
- [x] FrontalBlockEffect.luau — фронтальный блок (chaos_barrier)
- [x] ImmaterialEffect.luau — неуязвимость
- [x] HealCasterEffect.luau — лечение кастера
- [x] PullEffect.luau — притягивание к центру

### 5.6 — Пассивные механики

- [x] LeechHandler.luau — Blood пассивка: heal on hit, heal on kill, учёт TierBonuses
- [x] IgniteHandler.luau — Chaos пассивка: DoT, explosion, chain ignite, учёт TierBonuses

### 5.7 — DataService интеграция

- [x] DataService.luau: Magic в defaultData (SpellPoints, LearnedSpells, EquippedSpells, ClaimedBossRewards)
- [x] SpellProgressManager: save/load интеграция

### 5.8 — Spellbook UI

- [x] SpellbookPage.luau — страница внутри JournalWindow (не отдельное окно)
- [x] SpellbookConstants.luau — цвета, размеры, отступы
- [x] SchoolTabs.luau — табы Blood / Chaos
- [x] SchoolInfoPanel.luau — описание школы, пассивка, тир-бонусы
- [x] TierProgressBar.luau — шкала прогресса тиров I → II → III → ULT
- [x] SpellGrid.luau — сетка заклинаний по тирам
- [x] SpellCard.luau — ячейка заклинания (иконка, замок, подсветка)
- [x] SpellDetailPanel.luau — координатор правой панели (делегирует Builder/Learn/Equip)
- [x] SpellDetailBuilder.luau — UI-конструкция (иконка, название, описание, теги)
- [x] SpellDetailLearn.luau — кнопка изучения, проверка поинтов
- [x] SpellDetailEquip.luau — кнопки экипировки в слоты, hover состояния
- [x] SpellSlotBar.luau — слоты R, G, Z в нижней части окна
- [x] Fix: изучение/экипировка не сбрасывает выбранное заклинание
- [x] Fix: иконки растянуты на всю ширину
- [x] Fix: hover цвета корректны (BTN_NORMAL/HOVER/EQUIPPED/EQUIPPED_HOVER)
- [ ] ~~SpellDragManager~~ — отменено
- [ ] ~~SpellLearnOverlay~~ — отменено

### 5.9 — AbilitiesBar (слоты R, G, Z)

- [x] AbilitiesBar.client.luau — обновлён, секционная архитектура
- [x] AbilitiesConstants.luau — константы стилей
- [x] SlotFactory.luau — фабрика слотов
- [x] MouseUtil.luau — getMouseWorldPosition
- [x] WeaponSection.luau — LMB, Q, E, Space (оружейные слоты)
- [x] SpellSection.luau — R, G (Basic заклинания)
- [x] UltimateSection.luau — Z (Ultimate заклинания)
- [x] ClassSection.luau — X (зарезервирован)
- [x] SpellAimSender.luau — отправка позиции курсора во время каста
- [x] Интеграция SpellAimSender в SpellSection и UltimateSection

### 5.10 — Remotes

- [x] CastSpell (Client → Server)
- [x] LearnSpell (Client → Server)
- [x] EquipSpell (Client → Server)
- [x] UnequipSpell (Client → Server)
- [x] SpellCooldown (Server → Client)
- [x] SpellChargeUpdate (Server → Client)
- [x] BeamStart (Server → Client)
- [x] BeamUpdate (Client → Server)
- [x] BeamEnd (Server → Client)
- [x] SpellEffect (Server → Client)
- [x] UpdateSpellData (Server → Client)
- [x] GetSpellData (RemoteFunction)
- [x] SpellAim (Client → Server)

### 5.11 — ProjectileConfig дополнения

- [x] ProjectileConfig.luau: shadowbolt, chaos_bolt, void_orb, chaos_barrage_bolt

### 5.12 — Beam система

- [x] BeamEffect.luau — серверный луч с мутабельным направлением, ally heal
- [x] BeamVisual.client.luau — клиентская визуализация (Neon Part + PointLight)
- [x] CombatManager.server.luau — обработчик BeamUpdate remote

### 5.13 — Spell VFX

- [x] SpellVFX.client.luau — клиентские визуальные эффекты
- [x] Обработчики: AoEDamage, AoEHeal, AoEBuff, AoEPassive, AreaExplosion, Reflect, BlockStart, FrontalBlockStart, BlockTriggered, Immaterial
- [x] Цветовые палитры для Blood и Chaos школ
- [x] SpellEffect broadcast из всех серверных эффектов (включая School)

### 5.14 — Прицеливание в конце каста

- [x] SpellAim remote — клиент отправляет позицию курсора каждые 50мс
- [x] SpellCastManager — lastMousePosition, используется при завершении каста
- [x] SpellAimSender.luau — клиентский модуль start/stop

### 5.15 — Journal / Spellbook интеграция

- [x] JournalWindow.luau — общее окно с табами (Bosses, Spellbook)
- [x] JournalInit.client.luau — точка входа
- [x] JournalConstants.luau — общие константы журнала

### Debug команды (магия)

- [x] /spellpoint School Tier Amount — добавить spell points (поддерживает ULT)

---

## Сводка

| Фаза | Статус | Описание |
|---|---|---|
| Фаза 1 | ✅ Завершена | Рефакторинг архитектуры (ItemConfig, BossManager, ServantManager) |
| Фаза 2 | ✅ Завершена | Система контейнеров (сундуки, CastBar, CastManager) |
| Фаза 3 | ✅ Завершена | День/Ночь, лунные циклы, солнечный дебафф |
| Фаза 4 | ✅ Завершена | Дальний бой (Bow, снаряды, рефакторинг combat/) |
| Фаза 5 | ✅ Завершена | Система магии (Spellbook, заклинания, пассивки, VFX, beam) |