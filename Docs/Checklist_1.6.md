# Checklist v1.6

## 1. Stats Foundation
- [x] StatsConfig.luau — 20 статов с Id, Name, Description, Base, Format, Category
- [x] StatsConfig.DisplayOrder — порядок отображения в UI
- [x] StatsConfig.EquipmentStats — допустимые статы для экипировки
- [x] StatsManager.luau — recalculate (base + equipment + blood + buffs)
- [x] StatsManager.get(player, statId) — получение конкретного стата
- [x] StatsManager.getAll(player) — все статы
- [x] StatsManager.markCombat / isInCombat — трекинг боя для регена
- [x] StatsManager.tickRegen — реген HP вне боя (1% MaxHP/тик * HealthRegen)
- [x] StatsManager.cleanup — очистка при выходе игрока
- [x] Remote UpdateStats (Server → Client)
- [x] Remote GetPlayerStats (Client → Server)
- [x] Интеграция: WeaponManager — PhysicalPower, AttackSpeed, PhysCritChance, PhysCritDamage, PhysResistance
- [x] Интеграция: HealthManager — HealingReceived в heal()
- [x] Интеграция: HealthManager — HealthRegen через StatsManager.tickRegen
- [x] Интеграция: Humanoid.WalkSpeed — MoveSpeed множитель
- [x] Интеграция: Humanoid.MaxHealth — MaxHP из уровня + экипировки
- [ ] Интеграция: AbilityManager — MagicalPower, MagicCritChance, MagicCritDamage, WeaponCDSpeed, MagicCDSpeed
- [ ] Интеграция: ServantAI — FamiliarDamage множитель
- [ ] Интеграция: BloodManager — BloodDrainRate, BloodBonusPower
- [ ] Интеграция: ResourceManager — ResourceDamage, ResourceYield

## 2. Blood Tiers
- [x] BloodConfig.luau — TierThresholds (I=1, II=50, MAX=100)
- [x] BloodConfig.Types — Warrior (PhysicalPower + WeaponCDSpeed), Creature (MoveSpeed + HealingReceived)
- [x] BloodConfig.Types.*.Tiers.MAX — BoostAll множитель (1.20)
- [x] BloodManager.getStatBonuses — расчёт тировых бонусов по качеству
- [x] Интеграция со StatsManager.recalculate
- [x] Outcast — нет бонусов
- [x] Drain: BloodAmount уменьшается по DrainRate

## 3. Character Window UI
- [x] AttributesPanel.luau — таблица 20 статов
  - [x] Формат отображения: flat → число, percent → процент
  - [x] Обновление через Remotes.UpdateStats
  - [x] Тултип с Description при наведении
- [x] BloodPoolPanel.luau — тип крови, объём, качество
  - [x] Шкала качества с метками I / II / MAX
  - [x] Список активных бонусов с значениями
  - [x] Обновление через атрибуты персонажа
- [x] Табы в CharacterWindow: Equipment, Crafting, Attributes, Blood Pool

## 4. DataStore
- [x] DataService.luau — централизованное сохранение/загрузка
  - [x] DATASTORE_NAME = "RisePlayerData_v1"
  - [x] MAX_RETRIES = 3 (retry logic)
  - [x] AUTOSAVE_INTERVAL = 120 секунд
  - [x] SAVE_ENABLED флаг (toggle через F9)
  - [x] isSaveEnabled() — геттер для BindToClose
- [x] Default data template: Level, XP, Inventory, Blood, BossEssence, UnlockedTechs, Servants
- [x] DataService.load — загрузка + _applyData на все модули
- [x] DataService.save — сбор + запись с retry
- [x] DataService.collect — сбор текущего состояния из всех модулей
- [x] DataService.cleanup — очистка при выходе
- [x] Хелперы модулей:
  - [x] LevelManager._setPlayerData(player, level, xp)
  - [x] BossManager._setPlayerEssence / _getPlayerEssence
  - [x] BossManager._setPlayerTechs / _getPlayerTechs
  - [x] ServantManager._setPlayerServants
- [x] Сериализация: inventory slots, equipment, servants

## 5. PlayerLifecycle (архитектура)
- [x] PlayerLifecycle.server.luau — единый entry point
  - [x] onPlayerAdded: DataService.load → starter items → CharacterAdded
  - [x] onCharacterAdded: HealthManager.init → blood attrs → ServantManager.dismiss → StatsManager.recalculate
  - [x] onPlayerRemoving: DataService.save → cleanup всех модулей
  - [x] game:BindToClose — сохранение с проверкой isSaveEnabled
- [x] Удалены PlayerAdded/PlayerRemoving из:
  - [x] HealthManager.luau
  - [x] InventoryServer.server.luau
  - [x] BloodServer.server.luau
  - [x] BossServer.server.luau
  - [x] ServantServer.server.luau
- [x] WeaponManager — lazy init cooldown (убран PlayerAdded)

## 6. Boss System
- [x] BossConfig.luau — BloodWarrior (Lv6, Act 1), SawmillBoss (Lv14, Act 1)
  - [x] Abilities конфиг для каждого босса
  - [x] Loot таблицы
  - [x] Unlocks (рецепты + технологии)
  - [x] EssenceRequired
- [x] BossManager.luau — спавн, состояния (Alive → Downed → Dead), Essence tracking
  - [x] onBossDowned: таймер, F (Finish) / T (Capture)
  - [x] grantTech, grantEssence, XP
- [x] BossBehaviors.luau — AI поведение боссов
  - [x] Состояния: Idle, Chase, Attack, Return
  - [x] Leash (AggroRange * 3) с хилом при возврате
  - [x] Enrage множитель скорости
  - [x] Проверка IsDead на AggroTarget
  - [x] Сброс AggroTarget при смерти/выходе игрока
  - [x] Переход в RETURN когда цель не найдена
- [x] BossAbilities.luau — способности боссов (Q/E атаки)
  - [x] pickAbility — выбор по кулдауну
  - [x] execute — прямой урон и AoE
- [x] EnemyTargeting.luau — проверка IsDead при поиске цели
- [x] EnemyBehaviors.luau — проверка IsDead на AggroTarget

## 7. Boss Journal UI + MenuBar
- [x] MenuBar.luau — нижний правый угол, 40×40 иконки, тултип
- [x] BossJournal.luau — полноэкранное окно
  - [x] Хедер с кнопкой закрытия
  - [x] Табы актов (ActTabs.luau — отдельный модуль)
  - [x] Scroll-список карточек боссов
  - [x] BossCard.luau — карточка: имя, уровень, локация, описание, Essence шкала
  - [x] Иконки технологий с тултипами (BossTooltip.luau)
  - [x] Lock overlay для боссов выше уровня (+10)
  - [x] Фильтрация по выбранному акту
  - [x] Сортировка по уровню
- [x] BossJournalConstants.luau — UI константы и цветовая палитра
- [x] Remotes: GetBossData, BossFinish, BossCapture, BossFinishResult, BossCaptureResult
- [x] Обновление при UpdateLevel

## 8. Minimap
- [x] Minimap.client.luau — круглая миникарта
  - [x] Фиксированная ориентация (север = вверх)
  - [x] Вращается только иконка игрока (ромб + стрелка направления)
  - [x] Стороны света N/S/W/E — ромбы на ободке
  - [x] Точки: враги (красные), боссы (фиолетовые), другие игроки (синие), ресурсы (жёлтые)
  - [x] Зум: кнопки +/− под картой
  - [x] Зум: скролл при наведении мышью
  - [x] Dot pool (переиспользование UI элементов)
  - [x] Отступы от края экрана
  - [x] Проверка IsDead — мёртвые не отображаются
  - [x] Поддержка кастомной иконки игрока (ImageLabel с AssetId)

## 9. Система смерти
- [x] HealthManager — заморозка персонажа (WalkSpeed=0, JumpPower=0, JumpHeight=0)
- [x] HealthManager — humanoid.Health=1 (не 0, чтобы не триггерить Roblox auto-respawn)
- [x] HealthManager — humanoid.MaxHealth=math.huge (блокировка естественной смерти)
- [x] HealthManager — оружие убирается в Backpack при смерти
- [x] DeathScreen.client.luau — UI экран смерти
  - [x] Заголовок «Вы погибли»
  - [x] Таймер обратного отсчёта (от Config.Player.RespawnTime)
  - [x] Кнопка «Возродиться»
  - [x] Авто-респавн по истечении таймера
  - [x] Сброс при CharacterAdded
- [x] Remotes: PlayerDied (Server → Client), PlayerRespawn (Client → Server)
- [x] Серверная страховка: task.delay(RespawnTime + 2) auto-respawn
- [x] WeaponManager — проверка IsDead перед атакой
- [x] Время респавна передаётся с сервера (единый источник)

## 10. Debug Tools
- [x] DebugCommands.server.luau — серверные команды (только в Studio)
  - [x] F5 = save
  - [x] F6 = data (вывод Level, XP, Blood, Servants)
  - [x] F7 = +500 XP
  - [x] F8 = wipe DataStore
  - [x] F9 = toggle save on/off
- [x] DebugKeys.client.luau — клиентские хоткеи (F5–F9)
- [x] Remote: DebugCommand

## 11. Remotes
- [x] Добавлены в Remotes.luau:
  - [x] PlayerDied (событие смерти)
  - [x] PlayerRespawn (запрос респавна)
  - [x] DebugCommand (дебаг команды)
  - [x] BossFinishResult, BossCaptureResult
  - [x] UnlockTech

## 12. Прочие исправления
- [x] Баг: босс не возвращается на спавн после смерти игрока
  - [x] BossBehaviors — пропущен `target = aggroChar` в ветке AggroTarget
  - [x] BossBehaviors — добавлен переход в RETURN при target == nil
  - [x] EnemyTargeting — проверка IsDead
  - [x] EnemyBehaviors — проверка IsDead на AggroTarget
- [x] Баг: задержка при нажатии Stop в Studio (BindToClose ждал 5 сек)
  - [x] DataService.isSaveEnabled() проверка перед ожиданием
- [x] Баг: ранний респавн (humanoid.Health=0 триггерил Roblox Died)
  - [x] Заменено на Health=1 + MaxHealth=huge + IsDead атрибут
- [x] Баг: task.cancel на завершённый поток в DeathScreen
  - [x] Заменено на проверку флага isDead вместо task.cancel
- [x] Баг: тултипы показывались на заблокированных боссах
  - [x] lockOverlay.Active = true