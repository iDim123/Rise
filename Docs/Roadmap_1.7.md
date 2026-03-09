# Roadmap v1.7


Фаза 5 — Система магии (Magic / Spellbook System)
Концепция
Магия — отдельная система, не привязанная к оружию. Заклинания открываются через Spell Points, получаемые с боссов (только первое убийство). Каждая школа магии имеет пассивную механику (Leech для Blood, Ignite для Chaos), тировую прогрессию (I → II → III → ULT) и пассивные бонусы за закрытие полного тира. Заклинания экипируются в слоты R, G (обычные) и Z (только ультимативные) через окно Spellbook. Нельзя использовать два одинаковых заклинания одновременно.

5.1 — SpellConfig (конфигурация заклинаний)
Copy-- src/shared/config/SpellConfig.luau

Config.MagicSchools = {
    Blood = {
        Name = "Blood Magic",
        Description = "Магия крови. Контроль жизненной силы врагов...",
        Icon = "rbxassetid://0",
        PassiveName = "Leech",
        PassiveDescription = "Физические атаки восстанавливают 10% урона по целям с Leech. При смерти цели с Leech — лечение 3% от максимального HP.",
        Passive = {
            HealOnHitPercent = 0.10,
            HealOnKillPercent = 0.03,
            Duration = 5,               -- длительность дебаффа Leech
        },
        -- Бонусы за закрытие полных тиров
        TierBonuses = {
            [1] = { Description = "Leech heal on hit: 10% → 12%",   Override = { HealOnHitPercent = 0.12 } },
            [2] = { Description = "Leech heal on kill: 3% → 5%",    Override = { HealOnKillPercent = 0.05 } },
            [3] = { Description = "Leech замедляет врагов на 10%",  Extra = { SlowPercent = 0.10, SlowDuration = 2 } },
        },
        UltTierBonus = { Description = "Leech также снижает урон врага на 5%", Extra = { DamageReduction = 0.05 } },
    },
    Chaos = {
        Name = "Chaos Magic",
        Description = "Магия хаоса. Разрушительная сила огня и пустоты...",
        Icon = "rbxassetid://0",
        PassiveName = "Ignite",
        PassiveDescription = "Поджигает врагов хаос-пламенем: 50% магического урона за 5с. При смерти цели с Ignite — взрыв 50% магического урона.",
        Passive = {
            DotPercent = 0.50,           -- % от spell power за полную длительность
            DotDuration = 5,
            ExplosionDamagePercent = 0.50,
            ExplosionRadius = 1,         -- studs
            ChainIgnite = true,          -- взрыв может наложить Ignite на других
        },
        TierBonuses = {
            [1] = { Description = "Ignite урон +25%",              Override = { DotPercent = 0.625 } },
            [2] = { Description = "Ignite радиус взрыва +50%",     Override = { ExplosionRadius = 1.5 } },
            [3] = { Description = "Ignite взрыв гарантированно накладывает Ignite", Override = { ChainIgnite = true, ChainIgniteGuaranteed = true } },
        },
        UltTierBonus = { Description = "Ignite DoT тикает на 30% быстрее", Override = { DotDuration = 3.5 } },
    },
}

Config.Spells = {
    -- ═══════════ BLOOD SCHOOL ═══════════
    blood_rage = {
        Id = "blood_rage",
        Name = "Blood Rage",
        Description = "Лечит ближайших союзников на 65% spell power и накладывает ускорение: +10% скорости, +25% скорости атаки на 3с. Накладывает Leech на ближайших врагов.",
        Icon = "rbxassetid://0",
        School = "Blood",
        Class = "Basic",                -- "Basic" или "Ultimate"
        Tier = 1,
        UnlockCost = 1,                 -- 1 Spell Point Tier 1
        Tags = { "Area", "Buff" },
        CastTime = 0.1,
        CastMovementMode = "Free",
        Cooldown = 10,
        DamageType = "Magic",
        CanCrit = false,
        Effects = {
            {
                Type = "AoEHeal",
                Radius = 10,
                HealPercent = 0.65,      -- % от spell power
                TargetFilter = "Allies", -- игроки + серванты
            },
            {
                Type = "AoEBuff",
                Radius = 10,
                TargetFilter = "Allies",
                Buffs = {
                    { BuffId = "blood_rage_speed", Stat = "MoveSpeed", Value = 0.10, Duration = 3, Fading = true },
                    { BuffId = "blood_rage_atkspd", Stat = "AttackSpeed", Value = 0.25, Duration = 3, Fading = true },
                },
            },
            {
                Type = "AoEApplyPassive",
                Radius = 10,
                TargetFilter = "Enemies",
                PassiveId = "Leech",
            },
        },
    },

    shadowbolt = {
        Id = "shadowbolt",
        Name = "Shadowbolt",
        Description = "Выпускает снаряд, наносящий 200% магического урона и накладывающий Leech.",
        Icon = "rbxassetid://0",
        School = "Blood",
        Class = "Basic",
        Tier = 2,
        UnlockCost = 1,
        Tags = { "Projectile", "CanCrit" },
        CastTime = 1.0,
        CastMovementMode = "Locked",
        Cooldown = 8,
        DamageType = "Magic",
        CanCrit = true,
        Effects = {
            {
                Type = "Projectile",
                ProjectileId = "shadowbolt",
                DamageMult = 2.0,
                OnHitEffects = {
                    { Type = "ApplyPassive", PassiveId = "Leech" },
                },
            },
        },
    },

    blood_rite = {
        Id = "blood_rite",
        Name = "Blood Rite",
        Description = "Блокирует ближние и дальние атаки 1.5с. При блоке — кровавая нова: отталкивает врагов, 60% маг. урона, Leech. Неуязвимость 1.2с при срабатывании.",
        Icon = "rbxassetid://0",
        School = "Blood",
        Class = "Basic",
        Tier = 3,
        UnlockCost = 1,
        Tags = { "Counter", "Area", "CannotCrit" },
        CastTime = 0.1,
        CastMovementMode = "Slowed",
        CastSpeedMult = 0.5,
        Cooldown = 10,
        DamageType = "Magic",
        CanCrit = false,
        Effects = {
            {
                Type = "Block",
                Duration = 1.5,
                BlockMelee = true,
                BlockProjectile = true,
                MovementMode = "Slowed",
                SpeedMult = 0.5,
                OnBlockTriggered = {
                    {
                        Type = "AoEDamage",
                        DamageMult = 0.60,
                        Radius = 8,
                        Knockback = true,
                        KnockbackForce = 30,
                    },
                    {
                        Type = "AoEApplyPassive",
                        Radius = 8,
                        TargetFilter = "Enemies",
                        PassiveId = "Leech",
                    },
                    {
                        Type = "Immaterial",
                        Duration = 1.2,    -- неуязвимость, нельзя таргетировать
                        CanPassThroughEnemies = false,
                    },
                },
            },
        },
    },

    crimson_beam = {
        Id = "crimson_beam",
        Name = "Crimson Beam",
        Description = "Канал луча энергии: 275% маг. урона + Leech на врагах, лечение союзников 200% spell power/сек, до 3с. Каждая задетая цель лечит кастера на 75% spell power.",
        Icon = "rbxassetid://0",
        School = "Blood",
        Class = "Ultimate",
        Tier = 1,                        -- ULT Tier 1 (отдельная шкала)
        UnlockCost = 1,                  -- 1 Ultimate Point
        Tags = { "Channelling", "Beam", "CannotCrit" },
        CastTime = 0.4,
        CastMovementMode = "Slowed",
        CastSpeedMult = 0.3,
        Cooldown = 120,
        DamageType = "Magic",
        CanCrit = false,
        Effects = {
            {
                Type = "Beam",
                Duration = 3,
                TickRate = 0.2,          -- проверка попаданий каждые 0.2с
                Width = 3,               -- studs ширина луча
                Length = 25,             -- studs длина луча
                FollowCursor = true,     -- луч следует за курсором
                DamageMult = 2.75,       -- за полную длительность
                ChannelMovementMode = "Slowed",
                ChannelSpeedMult = 0.3,
                OnHitEnemy = {
                    { Type = "ApplyPassive", PassiveId = "Leech" },
                    { Type = "HealCaster", HealPercent = 0.75 }, -- % spell power
                },
                OnHitAlly = {
                    { Type = "Heal", HealPercent = 2.00 }, -- % spell power / сек
                },
            },
        },
    },

    -- ═══════════ CHAOS SCHOOL ═══════════
    chaos_volley = {
        Id = "chaos_volley",
        Name = "Chaos Volley",
        Description = "Выпускает 2 хаос-болта последовательно, каждый наносит 125% маг. урона и накладывает Ignite.",
        Icon = "rbxassetid://0",
        School = "Chaos",
        Class = "Basic",
        Tier = 1,
        UnlockCost = 1,
        Tags = { "Channelling", "Projectile", "CanCrit" },
        CastTime = 0.6,
        CastMovementMode = "Slowed",
        CastSpeedMult = 0.6,
        Cooldown = 8,
        DamageType = "Magic",
        CanCrit = true,
        Effects = {
            {
                Type = "MultiProjectile",
                ProjectileId = "chaos_bolt",
                Count = 2,
                Interval = 0.3,           -- секунд между болтами
                DamageMult = 1.25,
                FollowCursor = true,       -- каждый болт летит к текущей позиции курсора
                OnHitEffects = {
                    { Type = "ApplyPassive", PassiveId = "Ignite" },
                },
            },
        },
    },

    void = {
        Id = "void",
        Name = "Void",
        Description = "Призывает сферу, взрывающуюся в указанной точке: 80% маг. урона, Ignite, притягивает врагов к центру.",
        Icon = "rbxassetid://0",
        School = "Chaos",
        Class = "Basic",
        Tier = 2,
        UnlockCost = 1,
        Tags = { "TargetArea", "CanCrit" },
        CastTime = 0.4,
        CastMovementMode = "Free",
        Cooldown = 9,
        Charges = 2,                      -- 2 заряда
        ChargeRechargeTime = 9,           -- каждый заряд восстанавливается независимо
        DamageType = "Magic",
        CanCrit = true,
        Effects = {
            {
                Type = "TargetAreaProjectile",
                ProjectileId = "void_orb",
                Speed = 60,
                DamageMult = 0.80,
                ExplosionRadius = 6,
                OnHitEffects = {
                    { Type = "ApplyPassive", PassiveId = "Ignite" },
                    { Type = "Pull", Duration = 0.5, Force = 40 }, -- притягивание к центру
                },
            },
        },
    },

    chaos_barrier = {
        Id = "chaos_barrier",
        Name = "Chaos Barrier",
        Description = "Блокирует ближние и дальние атаки спереди 2с. Отражает атаки обратно в атакующего. Каждый следующий отражённый снаряд наносит на 30% меньше урона.",
        Icon = "rbxassetid://0",
        School = "Chaos",
        Class = "Basic",
        Tier = 3,
        UnlockCost = 1,
        Tags = { "Defensive", "Channelling", "Projectile", "CannotCrit" },
        CastTime = 0.1,
        CastMovementMode = "Slowed",
        CastSpeedMult = 0.5,
        Cooldown = 11,
        DamageType = "Magic",
        CanCrit = false,
        Effects = {
            {
                Type = "FrontBlock",
                Duration = 2,
                BlockAngle = 120,          -- градусов перед персонажем
                BlockMelee = true,
                BlockProjectile = true,
                MovementMode = "Slowed",
                SpeedMult = 0.5,
                ReflectProjectiles = true,
                ReflectDamageDecay = 0.30, -- -30% за каждое отражение
            },
        },
    },

    chaos_barrage = {
        Id = "chaos_barrage",
        Name = "Chaos Barrage",
        Description = "Выпускает 4 хаос-снаряда: 200% маг. урона при прямом попадании, 100% по области. Ignite.",
        Icon = "rbxassetid://0",
        School = "Chaos",
        Class = "Ultimate",
        Tier = 1,
        UnlockCost = 1,
        Tags = { "Channelling", "CannotCrit" },
        CastTime = 1.0,
        CastMovementMode = "Slowed",
        CastSpeedMult = 0.4,
        Cooldown = 120,
        DamageType = "Magic",
        CanCrit = false,
        Effects = {
            {
                Type = "MultiProjectile",
                ProjectileId = "chaos_barrage_bolt",
                Count = 4,
                Interval = 0.4,
                FollowCursor = true,
                DirectHitDamageMult = 2.0,
                SplashDamageMult = 1.0,
                SplashRadius = 5,
                OnHitEffects = {
                    { Type = "ApplyPassive", PassiveId = "Ignite" },
                },
            },
        },
    },
}
Copy
5.2 — SpellPointConfig (награды с боссов)
Copy-- Дополнение к src/shared/config/BossConfig.luau
BloodWarrior = {
    -- ... существующие поля ...
    SpellPointRewards = {
        { School = "Blood", Tier = 1, Amount = 1 },
    },
},
SawmillBoss = {
    -- ... существующие поля ...
    SpellPointRewards = {
        { School = "Chaos", Tier = 1, Amount = 1 },
        { School = "Blood", Tier = 2, Amount = 1 },
    },
},
-- Будущие боссы могут давать несколько разных поинтов
-- включая Ultimate Points:
-- { School = "Blood", Tier = "Ultimate", Amount = 1 },
5.3 — Spell Points и прогрессия (SpellProgressManager)
Путь: src/server/modules/SpellProgressManager.luau

Хранит и управляет:

Доступные (неиспользованные) Spell Points по школам и тирам: { Blood = { [1] = 2, [2] = 0, [3] = 0, Ultimate = 0 }, Chaos = { ... } }
Список изученных заклинаний: { "blood_rage", "chaos_volley", ... }
Экипированные заклинания: { R = "blood_rage", G = "chaos_volley", Z = nil }
Закрытые тиры (все заклинания тира изучены): автоматически рассчитывается
API:

addSpellPoints(player, school, tier, amount) — добавить поинты (вызывается при убийстве босса)
getSpellPoints(player, school, tier) → number
canLearnSpell(player, spellId) → boolean (есть ли поинт нужного тира)
learnSpell(player, spellId) → boolean (тратит поинт, добавляет в список)
isSpellLearned(player, spellId) → boolean
equipSpell(player, spellId, slot) → boolean (R/G/Z, проверка дубликатов и класса)
unequipSpell(player, slot) → boolean
getEquippedSpells(player) → { R, G, Z }
getLearnedSpells(player) → list
isTierComplete(player, school, tier) → boolean
getTierBonuses(player, school) → active bonuses list
getPassiveStats(player, school) → passive values with tier bonus overrides
getProgressData(player) → full data for UI
save(player) / load(player, data) — сериализация для DataService
5.4 — SpellCastManager (серверный модуль — исполнение заклинаний)
Путь: src/server/modules/SpellCastManager.luau

Обрабатывает кастование и эффекты заклинаний. Вызывается когда игрок нажимает R/G/Z.

API:

castSpell(player, slot, mousePosition) — основная функция
Проверяет: заклинание экипировано, кулдаун, заряды, персонаж жив, не в другом касте
Запускает CastBar с параметрами заклинания (CastTime, CastMovementMode, CastSpeedMult)
По завершении каста — исполняет Effects по типам
Обработчики типов эффектов:

Projectile / MultiProjectile → вызывает ProjectileManager.fire() (из фазы 4)
Beam → создаёт серверный луч, обновляет направление по данным клиента (BeamUpdate remote, ~10 раз/сек), тикает урон/хил по TickRate
AoEDamage → урон в радиусе
AoEHeal → лечение союзников (игроки + серванты) в радиусе
AoEBuff → баффы союзникам через BuffManager
AoEApplyPassive → наложение Leech/Ignite на врагов в радиусе
Block / FrontBlock → состояние блока с таймером, при атаке → триггер OnBlockTriggered
TargetAreaProjectile → снаряд летит к точке курсора, взрывается при достижении
Immaterial → неуязвимость, не таргетируемый
Pull → LinearVelocity к центру на Duration
HealCaster → лечение кастера
Channelling-логика:

Для Beam, MultiProjectile с Interval — заклинание продолжает действовать после каста
Серверный таймер управляет длительностью канала
CastMovementMode применяется на весь канал (не только каст)
5.5 — Пассивные механики (LeechHandler, IgniteHandler)
Путь: src/server/modules/spell/LeechHandler.luau

Слушает HealthManager.takeDamage — если на цели есть Leech и атакующий — игрок с физ. атакой → лечение
Слушает EventBus.EntityDying — если на умершей цели Leech → лечение 3% maxHP кастеру
Учитывает TierBonuses текущего игрока (повышенные % если тиры закрыты)
Путь: src/server/modules/spell/IgniteHandler.luau

Управляет DoT: тик урона каждую секунду в течение DotDuration
При смерти цели с Ignite → взрыв (ExplosionRadius, ExplosionDamagePercent)
ChainIgnite: взрыв накладывает Ignite на задетых врагов
Учитывает TierBonuses
5.6 — Charges-система (для Void и будущих заклинаний)
В SpellCastManager:

Заклинания с Charges > 1 хранят массив таймеров зарядов
При использовании — тратится 1 заряд, запускается отдельный таймер ChargeRechargeTime
Каждый заряд восстанавливается независимо
Если все заряды на КД — заклинание недоступно
UI показывает количество доступных зарядов; если 0 — время до ближайшего восстановления
5.7 — DataService интеграция
Дополнение к шаблону данных в DataService:

Copy-- В defaultData:
Magic = {
    SpellPoints = {
        Blood = { [1] = 0, [2] = 0, [3] = 0, Ultimate = 0 },
        Chaos = { [1] = 0, [2] = 0, [3] = 0, Ultimate = 0 },
    },
    LearnedSpells = {},              -- { "blood_rage", "chaos_volley" }
    EquippedSpells = {               -- слоты R, G, Z
        R = nil,
        G = nil,
        Z = nil,
    },
    ClaimedBossRewards = {},         -- { "BloodWarrior" = true } — защита от повторного получения
},
5.8 — UI: Spellbook Window
Модульная структура (по аналогии с BossJournal):

src/client/ui/spellbook/
├── SpellbookInit.client.luau        -- точка входа, создаёт окно
├── SpellbookWindow.luau             -- основной контейнер (полная высота экрана)
├── SpellbookConstants.luau          -- цвета, размеры, отступы
├── SchoolTabs.luau                  -- табы Blood / Chaos вверху
├── SchoolInfoPanel.luau             -- левая панель: название, описание, пассивка школы
├── TierProgressBar.luau             -- шкала тиров I → II → III → ULT с заполнением
├── SpellGrid.luau                   -- центральная сетка: ряды по тирам, иконки заклинаний
├── SpellSlot.luau                   -- одна ячейка заклинания (иконка, замок, доступность)
├── SpellDetailPanel.luau            -- правая панель: детали выбранного заклинания
├── CurrentSpellsBar.luau            -- нижняя зона: слоты R, G, Z (зеркало AbilitiesBar)
├── SpellDragManager.luau            -- drag & drop из SpellGrid в CurrentSpellsBar
└── SpellLearnOverlay.luau           -- оверлей зажатия ЛКМ 2с для изучения (прогресс-бар)
Окно открывается через MenuBar (иконка "Spellbook") или горячей клавишей. Заголовок окна содержит табы: Map, Bosses, Spellbook (подчёркнут когда активен).

SchoolTabs: Blood | Chaos — переключают содержимое. Добавление новой школы = новый таб.

SchoolInfoPanel (левая часть): описание школы, пассивная механика (Leech / Ignite) с текстом, пассивные бонусы за закрытые тиры (с галочкой если закрыт).

TierProgressBar: горизонтальная шкала с секциями I, II, III, ULT. Каждая секция заполняется пропорционально количеству изученных заклинаний в тире. Полностью заполненная секция подсвечивается.

SpellGrid: ряды тиров. Каждый ряд содержит иконки заклинаний. Неизученные — затемнены с замком (но кликабельны для просмотра описания). Доступные для изучения (есть поинт) — подсвечены рамкой. Изученные — полная яркость.

SpellDetailPanel (правая часть): появляется при клике на заклинание. Показывает: иконку, название, тип (Projectile, Area и т.д.), Cast Time, Cooldown, Charges (если есть), полное описание. Для неизученных — показывает "Требуется: Blood Spell Point Tier 2". Для доступных к изучению — подсказка "Зажмите ЛКМ для изучения".

SpellLearnOverlay: при зажатии ЛКМ на доступном заклинании — круговой прогресс 2 секунды. По завершении — анимация изучения, заклинание разблокируется, тратится Spell Point.

CurrentSpellsBar (низ окна): три слота R, G, Z. Не меняются при переключении школ. Зеркало AbilitiesBar. Drag & drop из SpellGrid сюда. Правый клик — убрать заклинание из слота. Z принимает только Ultimate.

SpellDragManager: перетаскивание изученных заклинаний из сетки в слоты R/G/Z. Валидация: не дублировать, Ultimate только в Z, Basic только в R/G. При успешном drop — отправляет EquipSpell remote серверу.

5.9 — Обновление AbilitiesBar
Текущие слоты: LMB, Q, E, Space. Новые слоты: LMB, Q, E, Space, R, G, Z, X.

LMB — атака оружием (как сейчас)
Q, E — способности оружия (как сейчас)
Space — Dash (будущее: заклинания-дэши)
R — заклинание магии (Basic)
G — заклинание магии (Basic)
Z — заклинание магии (Ultimate only)
X — зарезервировано для классового спелла
Обновить src/client/ui/abilities/AbilitiesBar.luau — добавить 4 новых слота. Для R/G/Z — иконка из экипированного заклинания, кулдаун-оверлей, отображение зарядов.

5.10 — Remotes
Remote	Направление	Назначение
CastSpell	Client → Server	Использовать заклинание (slot: R/G/Z, mousePosition)
LearnSpell	Client → Server	Изучить заклинание (spellId)
EquipSpell	Client → Server	Экипировать заклинание (spellId, slot)
UnequipSpell	Client → Server	Снять заклинание (slot)
SpellCooldown	Server → Client	Кулдаун заклинания (slot, cooldownTime)
SpellChargeUpdate	Server → Client	Обновление зарядов (slot, charges, rechargeTimes)
BeamUpdate	Client → Server	Позиция курсора для Beam (mousePosition, ~10/сек)
BeamVisual	Server → Client	Визуализация луча (casterId, origin, direction, width, length)
SpellEffect	Server → Client	VFX заклинания (spellId, position, targets)
GetSpellProgress	RemoteFunction	Запрос полных данных прогресса магии
SpellProgressUpdate	Server → Client	Обновление прогресса (после изучения/получения поинтов)
5.11 — ProjectileConfig дополнения (для заклинаний)
Copy-- Дополнение к ProjectileConfig.luau
shadowbolt = {
    Name = "Shadowbolt",
    Speed = 90,
    MaxRange = 50,
    HitboxRadius = 2,
    Pierce = 0,
    Model = "shadowbolt_projectile",
    TrailEnabled = true,
    TrailColor = Color3.fromRGB(139, 0, 0),
},
chaos_bolt = {
    Name = "Chaos Bolt",
    Speed = 100,
    MaxRange = 45,
    HitboxRadius = 1.5,
    Pierce = 0,
    Model = "chaos_bolt_projectile",
    TrailEnabled = true,
    TrailColor = Color3.fromRGB(180, 50, 255),
},
void_orb = {
    Name = "Void Orb",
    Speed = 60,
    MaxRange = 40,
    HitboxRadius = 2,
    Pierce = 0,
    Model = "void_orb_projectile",
    DestinationBased = true,     -- летит к точке, не бесконечно
},
chaos_barrage_bolt = {
    Name = "Chaos Barrage Bolt",
    Speed = 80,
    MaxRange = 50,
    HitboxRadius = 2.5,
    Pierce = 0,
    Model = "chaos_barrage_projectile",
    SplashRadius = 5,
    TrailEnabled = true,
    TrailColor = Color3.fromRGB(200, 30, 200),
},
Copy
5.12 — Файловая структура
Действие	Путь	Описание
NEW	src/shared/config/SpellConfig.luau	Школы магии, пассивки, тир-бонусы, все заклинания
NEW	src/server/modules/SpellProgressManager.luau	Spell Points, изучение, экипировка, прогресс
NEW	src/server/modules/SpellCastManager.luau	Кастование, исполнение эффектов, channelling, charges
NEW	src/server/modules/spell/LeechHandler.luau	Пассивка Blood: heal on hit, heal on kill
NEW	src/server/modules/spell/IgniteHandler.luau	Пассивка Chaos: DoT, explosion, chain
NEW	src/client/ui/spellbook/SpellbookInit.client.luau	Точка входа UI
NEW	src/client/ui/spellbook/SpellbookWindow.luau	Основной контейнер
NEW	src/client/ui/spellbook/SpellbookConstants.luau	UI константы
NEW	src/client/ui/spellbook/SchoolTabs.luau	Табы школ
NEW	src/client/ui/spellbook/SchoolInfoPanel.luau	Левая панель — описание школы
NEW	src/client/ui/spellbook/TierProgressBar.luau	Шкала прогресса тиров
NEW	src/client/ui/spellbook/SpellGrid.luau	Сетка заклинаний по тирам
NEW	src/client/ui/spellbook/SpellSlot.luau	Ячейка одного заклинания
NEW	src/client/ui/spellbook/SpellDetailPanel.luau	Правая панель — детали
NEW	src/client/ui/spellbook/CurrentSpellsBar.luau	Нижние слоты R, G, Z
NEW	src/client/ui/spellbook/SpellDragManager.luau	Drag & drop
NEW	src/client/ui/spellbook/SpellLearnOverlay.luau	Оверлей изучения (2с зажатие)
UPDATE	src/shared/config/BossConfig.luau	+ SpellPointRewards для каждого босса
UPDATE	src/shared/config/ProjectileConfig.luau	+ shadowbolt, chaos_bolt, void_orb и т.д.
UPDATE	src/server/modules/boss/BossInteraction.luau	+ начисление Spell Points при первом убийстве
UPDATE	src/server/modules/DataService.luau	+ Magic в defaultData и сериализация
UPDATE	src/server/modules/HealthManager.luau	+ хуки для Leech/Ignite проверок
UPDATE	src/client/ui/abilities/AbilitiesBar.luau	+ слоты R, G, Z, X
UPDATE	src/client/ui/MenuBar.luau	+ иконка Spellbook
UPDATE	src/shared/Remotes.luau	+ все новые remotes
ASSETS	ServerStorage/projectiles/	+ модели shadowbolt, chaos_bolt, void_orb и т.д.
Ключевые принципы
Server-authoritative: все расчёты урона, хила, эффектов — на сервере. Клиент только визуализация и ввод.
Единая система снарядов: заклинания-проджектайлы используют ProjectileManager.fire() из фазы 4.
CastBar интеграция: каждое заклинание настраивает CastMovementMode индивидуально.
Модульный UI: 12 файлов Spellbook — каждый компонент отдельно, легко расширять.
Масштабируемость: добавление новой школы = записи в SpellConfig + новый таб в UI. Добавление заклинания = запись в Config.Spells.
Пассивки как отдельные handler-модули: LeechHandler и IgniteHandler подключаются к EventBus и HealthManager, не загрязняя основной код.
