return {
    Type = "Melee",
    Damage = 20,
    Range = 5,
    Cooldown = 0.6,
    ComboWindow = 1.0,
    ResourceDamage = 12,
    Combo = {
        [1] = {
            Damage = 30,
            AnimationId = "rbxassetid://131735837276755"
        },
        [2] = {
            Damage = 25,
            AnimationId = "rbxassetid://131735837276755"
        },
        [3] = {
            Damage = 40,
            AnimationId = "rbxassetid://131735837276755"
        }
    },
    ComboAbility = {
        Id = "axe_combo",
        Name = "Axe Combo",
        Description = "3-hit combo: chop, swing, overhead slam.",
        Icon = "rbxassetid://127853105217094"
    },
    Abilities = {
        Q = {
            Id = "axe_frenzy",
            Name = "Бешенство",
            Description = "Увеличивает урон на 30% на 5 секунд.",
            Icon = "rbxassetid://110176616320571",
            AnimationId = "rbxassetid://0",
            Cooldown = 10,
            DamageType = "Physical",
            Effects = {{
                Type = "ApplyBuff",
                BuffId = "damage_boost",
                Duration = 5
            }}
        },
        E = {
            Id = "axe_whirlwind",
            Name = "Вихрь",
            Description = "AoE урон вокруг с замедлением.",
            Icon = "rbxassetid://107340020831744",
            AnimationId = "rbxassetid://0",
            Cooldown = 14,
            DamageType = "Physical",
            Effects = {{
                Type = "AoEDamage",
                Damage = 35,
                Radius = 10,
                Angle = 360
            }, {
                Type = "ApplyDebuff",
                BuffId = "slow",
                Duration = 3
            }}
        }
    }
}
