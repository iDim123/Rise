return {
    School = {
        Id = "Blood",
        Name = "Blood Magic",
        Description = "Магия крови. Контроль жизненной силы врагов, исцеление союзников и поглощение энергии.",
        Icon = "rbxassetid://0",
        PassiveName = "Leech",
        PassiveDescription = "Физические атаки восстанавливают 10% урона по целям с Leech. При смерти цели с Leech — лечение 3% от максимального HP.",
        Passive = {
            HealOnHitPercent = 0.10,
            HealOnKillPercent = 0.03,
            Duration = 5
        },
        TierBonuses = {
            [1] = {
                Description = "Leech heal on hit: 10% → 12%",
                Override = {
                    HealOnHitPercent = 0.12
                }
            },
            [2] = {
                Description = "Leech heal on kill: 3% → 5%",
                Override = {
                    HealOnKillPercent = 0.05
                }
            },
            [3] = {
                Description = "Leech замедляет врагов на 10%",
                Extra = {
                    SlowPercent = 0.10,
                    SlowDuration = 2
                }
            }
        },
        UltTierBonus = {
            Description = "Leech также снижает урон врага на 5%",
            Extra = {
                DamageReduction = 0.05
            }
        }
    },

    Spells = {
        blood_rage = {
            Id = "blood_rage",
            Name = "Blood Rage",
            Description = "Лечит ближайших союзников на 65% spell power и накладывает ускорение: +10% скорости, +25% скорости атаки на 3с. Накладывает Leech на ближайших врагов.",
            Icon = "rbxassetid://110916345415796",
            School = "Blood",
            Class = "Basic",
            Tier = 1,
            UnlockCost = 1,
            Tags = {"Area", "Buff"},
            CastTime = 0.1,
            CastMovementMode = "Free",
            Cooldown = 10,
            DamageType = "Magic",
            CanCrit = false,
            Effects = {{
                Type = "AoEHeal",
                Radius = 10,
                HealPercent = 0.65,
                TargetFilter = "Allies"
            }, {
                Type = "AoEBuff",
                Radius = 10,
                TargetFilter = "Allies",
                Buffs = {{
                    BuffId = "blood_rage_speed",
                    Stat = "MoveSpeed",
                    Value = 0.10,
                    Duration = 3,
                    Fading = true
                }, {
                    BuffId = "blood_rage_atkspd",
                    Stat = "AttackSpeed",
                    Value = 0.25,
                    Duration = 3,
                    Fading = true
                }}
            }, {
                Type = "AoEApplyPassive",
                Radius = 10,
                TargetFilter = "Enemies",
                PassiveId = "Leech"
            }}
        },

        sanguine_coil = {
            Id = "sanguine_coil",
            Name = "Sanguine Coil",
            Description = "Выпускает снаряд, наносящий 80% магического урона, высасывает 30% нанесённого урона в здоровье и накладывает Leech. 3 заряда.",
            Icon = "rbxassetid://111528193416142",
            School = "Blood",
            Class = "Basic",
            Tier = 1,
            UnlockCost = 1,
            Tags = {"Projectile", "CanCrit", "Charges"},
            CastTime = 0.4,
            CastMovementMode = "Free",
            Cooldown = 6,
            MaxCharges = 3,
            ChargeRechargeTime = 6,
            DamageType = "Magic",
            CanCrit = true,
            Effects = {{
                Type = "Projectile",
                ProjectileId = "sanguine_coil",
                DamageMult = 0.80,
                OnHitEffects = {{
                    Type = "HealCaster",
                    DrainPercent = 0.30
                }, {
                    Type = "ApplyPassive",
                    PassiveId = "Leech"
                }}
            }}
        },

        shadowbolt = {
            Id = "shadowbolt",
            Name = "Shadowbolt",
            Description = "Выпускает снаряд, наносящий 200% магического урона и накладывающий Leech.",
            Icon = "rbxassetid://72344478850928",
            School = "Blood",
            Class = "Basic",
            Tier = 2,
            UnlockCost = 1,
            Tags = {"Projectile", "CanCrit"},
            CastTime = 1.0,
            CastMovementMode = "Locked",
            Cooldown = 8,
            DamageType = "Magic",
            CanCrit = true,
            Effects = {{
                Type = "Projectile",
                ProjectileId = "shadowbolt",
                DamageMult = 2.0,
                OnHitEffects = {{
                    Type = "ApplyPassive",
                    PassiveId = "Leech"
                }}
            }}
        },

        blood_rite = {
            Id = "blood_rite",
            Name = "Blood Rite",
            Description = "Блокирует атаки 1.5с. При блоке — кровавая нова: отталкивает врагов, 60% маг. урона, Leech. Неуязвимость 1.2с.",
            Icon = "rbxassetid://127320493562909",
            School = "Blood",
            Class = "Basic",
            Tier = 3,
            UnlockCost = 1,
            Tags = {"Counter", "Area", "CannotCrit"},
            CastTime = 0.1,
            CastMovementMode = "Slowed",
            CastSpeedMult = 0.5,
            Cooldown = 10,
            DamageType = "Magic",
            CanCrit = false,
            Effects = {{
                Type = "Block",
                Duration = 1.5,
                BlockMelee = true,
                BlockProjectile = true,
                MovementMode = "Slowed",
                SpeedMult = 0.5,
                OnBlockTriggered = {{
                    Type = "AoEDamage",
                    DamageMult = 0.60,
                    Radius = 8,
                    Knockback = true,
                    KnockbackForce = 30
                }, {
                    Type = "AoEApplyPassive",
                    Radius = 8,
                    TargetFilter = "Enemies",
                    PassiveId = "Leech"
                }, {
                    Type = "Immaterial",
                    Duration = 1.2,
                    CanPassThroughEnemies = false
                }}
            }}
        },

        crimson_beam = {
            Id = "crimson_beam",
            Name = "Crimson Beam",
            Description = "Канал луча энергии: 275% маг. урона + Leech на врагах, лечение союзников 200% spell power/сек, до 3с.",
            Icon = "rbxassetid://98962426416389",
            School = "Blood",
            Class = "Ultimate",
            Tier = 1,
            UnlockCost = 1,
            Tags = {"Channelling", "Beam", "CannotCrit"},
            CastTime = 0.4,
            CastMovementMode = "Slowed",
            CastSpeedMult = 0.3,
            Cooldown = 25,
            DamageType = "Magic",
            CanCrit = false,
            Effects = {{
                Type = "Beam",
                Duration = 3,
                TickRate = 0.25,
                Range = 30,
                Width = 3,
                DamageMult = 2.75,
                HealAllyMult = 2.0,
                SelfHealPerHit = 0.75,
                ApplyPassive = "Leech",
                MovementMode = "Slowed",
                SpeedMult = 0.3
            }}
        }
    }
}
