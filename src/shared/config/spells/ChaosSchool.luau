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
            Description = "Выпускает 3 хаос-снаряда веером, каждый наносит 80% маг. урона и поджигает.",
            Icon = "rbxassetid://0",
            School = "Chaos",
            Class = "Basic",
            Tier = 1,
            UnlockCost = 1,
            Tags = {"Projectile", "CanCrit"},
            CastTime = 0.6,
            CastMovementMode = "Slowed",
            CastSpeedMult = 0.5,
            Cooldown = 6,
            DamageType = "Magic",
            CanCrit = true,
            Effects = {{
                Type = "MultiProjectile",
                ProjectileId = "chaos_bolt",
                Count = 3,
                SpreadAngle = 25,
                DamageMult = 0.80,
                OnHitEffects = {{
                    Type = "ApplyPassive",
                    PassiveId = "Ignite"
                }}
            }}
        },

        void = {
            Id = "void",
            Name = "Void",
            Description = "Выпускает снаряд в область курсора, наносящий 150% маг. урона. 2 заряда.",
            Icon = "rbxassetid://0",
            School = "Chaos",
            Class = "Basic",
            Tier = 2,
            UnlockCost = 1,
            Tags = {"Projectile", "Charges", "CanCrit"},
            CastTime = 0.3,
            CastMovementMode = "Free",
            Cooldown = 4,
            MaxCharges = 2,
            ChargeRechargeTime = 4,
            DamageType = "Magic",
            CanCrit = true,
            Effects = {{
                Type = "Projectile",
                ProjectileId = "void_bolt",
                DamageMult = 1.50,
                OnHitEffects = {{
                    Type = "ApplyPassive",
                    PassiveId = "Ignite"
                }}
            }}
        },

        chaos_barrier = {
            Id = "chaos_barrier",
            Name = "Chaos Barrier",
            Description = "Фронтальный барьер на 2с. Блокирует снаряды и атаки спереди. При разрушении — отражает 40% заблокированного урона.",
            Icon = "rbxassetid://0",
            School = "Chaos",
            Class = "Basic",
            Tier = 3,
            UnlockCost = 1,
            Tags = {"Counter", "CannotCrit"},
            CastTime = 0.1,
            CastMovementMode = "Slowed",
            CastSpeedMult = 0.4,
            Cooldown = 14,
            DamageType = "Magic",
            CanCrit = false,
            Effects = {{
                Type = "FrontalBlock",
                Duration = 2,
                BlockAngle = 120,
                ReflectPercent = 0.40,
                MovementMode = "Slowed",
                SpeedMult = 0.4
            }}
        },

        chaos_barrage = {
            Id = "chaos_barrage",
            Name = "Chaos Barrage",
            Description = "Канал: поток хаос-снарядов в направлении курсора. 8 снарядов за 2с, каждый 100% маг. урона + Ignite.",
            Icon = "rbxassetid://0",
            School = "Chaos",
            Class = "Ultimate",
            Tier = 1,
            UnlockCost = 1,
            Tags = {"Channelling", "Projectile", "CanCrit"},
            CastTime = 0.3,
            CastMovementMode = "Slowed",
            CastSpeedMult = 0.3,
            Cooldown = 20,
            DamageType = "Magic",
            CanCrit = true,
            Effects = {{
                Type = "ChannelledProjectile",
                Duration = 2,
                ProjectileId = "chaos_bolt",
                Count = 8,
                DamageMult = 1.0,
                SpreadAngle = 5,
                MovementMode = "Slowed",
                SpeedMult = 0.3,
                OnHitEffects = {{
                    Type = "ApplyPassive",
                    PassiveId = "Ignite"
                }}
            }}
        }
    }
}
