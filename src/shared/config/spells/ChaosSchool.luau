return {
    School = {
        Id = "Chaos",
        Name = "Chaos Magic",
        Description = "Магия хаоса. Разрушительная сила огня и пустоты, взрывы и поджоги.",
        Icon = "rbxassetid://0",
        PassiveName = "Ignite",
        PassiveDescription = "Поджигает врагов хаос-пламенем: 50% магического урона за 5с. При смерти цели с Ignite — взрыв 50% магического урона.",
        Passive = {
            DotPercent = 0.50,
            DotDuration = 5,
            ExplosionDamagePercent = 0.50,
            ExplosionRadius = 1,
            ChainIgnite = true
        },
        TierBonuses = {
            [1] = {
                Description = "Ignite урон +25%",
                Override = {
                    DotPercent = 0.625
                }
            },
            [2] = {
                Description = "Ignite радиус взрыва +50%",
                Override = {
                    ExplosionRadius = 1.5
                }
            },
            [3] = {
                Description = "Ignite взрыв гарантированно накладывает Ignite",
                Override = {
                    ChainIgnite = true,
                    ChainIgniteGuaranteed = true
                }
            }
        },
        UltTierBonus = {
            Description = "Ignite DoT тикает на 30% быстрее",
            Override = {
                DotDuration = 3.5
            }
        }
    },

    Spells = {
        chaos_volley = {
            Id = "chaos_volley",
            Name = "Chaos Volley",
            Description = "Выпускает 2 хаос-болта последовательно, каждый наносит 125% маг. урона и накладывает Ignite.",
            Icon = "rbxassetid://131199963182182",
            School = "Chaos",
            Class = "Basic",
            Tier = 1,
            UnlockCost = 1,
            Tags = {"Channelling", "Projectile", "CanCrit"},
            CastTime = 0.6,
            CastMovementMode = "Slowed",
            CastSpeedMult = 0.6,
            Cooldown = 8,
            DamageType = "Magic",
            CanCrit = true,
            Effects = {{
                Type = "MultiProjectile",
                ProjectileId = "chaos_bolt",
                Count = 2,
                Interval = 0.3,
                DamageMult = 1.25,
                FollowCursor = true,
                OnHitEffects = {{
                    Type = "ApplyPassive",
                    PassiveId = "Ignite"
                }}
            }}
        },

        void = {
            Id = "void",
            Name = "Void",
            Description = "Призывает сферу, взрывающуюся в указанной точке: 80% маг. урона, Ignite, притягивает врагов к центру. 2 заряда.",
            Icon = "rbxassetid://125296267295316",
            School = "Chaos",
            Class = "Basic",
            Tier = 2,
            UnlockCost = 1,
            Tags = {"TargetArea", "CanCrit"},
            CastTime = 0.4,
            CastMovementMode = "Free",
            Cooldown = 9,
            MaxCharges = 2,
            ChargeRechargeTime = 9,
            DamageType = "Magic",
            CanCrit = true,
            Effects = {{
                Type = "TargetAreaProjectile",
                ProjectileId = "void_orb",
                Speed = 60,
                DamageMult = 0.80,
                ExplosionRadius = 6,
                OnHitEffects = {{
                    Type = "ApplyPassive",
                    PassiveId = "Ignite"
                }, {
                    Type = "Pull",
                    Duration = 0.5,
                    Force = 40
                }}
            }}
        },

        chaos_barrier = {
            Id = "chaos_barrier",
            Name = "Chaos Barrier",
            Description = "Блокирует ближние и дальние атаки спереди 2с. Отражает атаки обратно в атакующего. Каждый следующий отражённый снаряд наносит на 30% меньше урона.",
            Icon = "rbxassetid://93290240085992",
            School = "Chaos",
            Class = "Basic",
            Tier = 3,
            UnlockCost = 1,
            Tags = {"Defensive", "Channelling", "Projectile", "CannotCrit"},
            CastTime = 0.1,
            CastMovementMode = "Slowed",
            CastSpeedMult = 0.5,
            Cooldown = 11,
            DamageType = "Magic",
            CanCrit = false,
            Effects = {{
                Type = "FrontalBlock",
                Duration = 2,
                BlockAngle = 120,
                BlockMelee = true,
                BlockProjectile = true,
                MovementMode = "Slowed",
                SpeedMult = 0.5,
                ReflectProjectiles = true,
                ReflectDamageDecay = 0.30
            }}
        },

        chaos_barrage = {
            Id = "chaos_barrage",
            Name = "Chaos Barrage",
            Description = "Выпускает 4 хаос-снаряда: 200% маг. урона при прямом попадании, 100% по области. Ignite.",
            Icon = "rbxassetid://77146590571159",
            School = "Chaos",
            Class = "Ultimate",
            Tier = 1,
            UnlockCost = 1,
            Tags = {"Channelling", "CannotCrit"},
            CastTime = 1.0,
            CastMovementMode = "Slowed",
            CastSpeedMult = 0.4,
            Cooldown = 120,
            DamageType = "Magic",
            CanCrit = false,
            Effects = {{
                Type = "MultiProjectile",
                ProjectileId = "chaos_barrage_bolt",
                Count = 4,
                Interval = 0.4,
                FollowCursor = true,
                DirectHitDamageMult = 2.0,
                SplashDamageMult = 1.0,
                SplashRadius = 5,
                OnHitEffects = {{
                    Type = "ApplyPassive",
                    PassiveId = "Ignite"
                }}
            }}
        }
    }
}
