return {
    Type = "Ranged",
    Damage = 18,
    Range = 60, -- максимальная дистанция снаряда
    Cooldown = 0.3, -- между выстрелами
    CastTime = 0.8, -- натяжение тетивы
    ProjectileId = "arrow", -- ключ из ProjectileConfig
    ResourceDamage = 0, -- лук не бьёт ресурсы
    CastMovementMode = "Slowed",
    CastSpeedMult = 0.5,
    Combo = {
        [1] = {
            Damage = 18,
            AnimationId = "rbxassetid://0" -- TODO: анимация выстрела
        }
    },
    ComboAbility = {
        Id = "bow_shot",
        Name = "Bow Shot",
        Description = "Charged arrow shot.",
        Icon = "rbxassetid://114549612188882"
    },
    Abilities = {
        Q = {
            Id = "power_shot",
            Name = "Мощный выстрел",
            Description = "Пробивающая стрела, наносит повышенный урон.",
            Icon = "rbxassetid://114549612188882",
            AnimationId = "rbxassetid://0",
            Cooldown = 2,
            DamageType = "Physical",
            Effects = {{
                Type = "Projectile",
                ProjectileId = "power_arrow",
                Damage = 50,
                PierceCount = 2
            }}
        },
        E = {
            Id = "arrow_rain",
            Name = "Дождь стрел",
            Description = "AoE: стрелы падают в указанную область.",
            Icon = "rbxassetid://114549612188882",
            AnimationId = "rbxassetid://0",
            Cooldown = 3,
            DamageType = "Physical",
            Effects = {{
                Type = "AoEProjectile",
                ProjectileId = "rain_arrow",
                Damage = 25,
                Radius = 12,
                Count = 8,
                SpawnHeight = 40
            }}
        }
    }
}
