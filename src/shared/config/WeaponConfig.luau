return {
    Weapons = {
        Sword = {
            Damage = 15,
            Range = 6,
            Cooldown = 0.4,
            ComboWindow = 1.2,
            ResourceDamage = 15,
            Combo = {
                [1] = {
                    Damage = 25,
                    AnimationId = "rbxassetid://70662356098178"
                },
                [2] = {
                    Damage = 20,
                    AnimationId = "rbxassetid://70662356098178"
                },
                [3] = {
                    Damage = 30,
                    AnimationId = "rbxassetid://110637980313006"
                }
            },
            ComboAbility = {
                Id = "sword_combo",
                Name = "Sword Combo",
                Description = "3-hit combo: slash, thrust, heavy strike.",
                Icon = "rbxassetid://119544363190700"
            },
            Abilities = {
                Q = {
                    Id = "sword_slash",
                    Name = "Широкий замах",
                    Description = "Наносит урон всем врагам перед собой.",
                    Icon = "rbxassetid://109099176664820",
                    AnimationId = "rbxassetid://110637980313006",
                    Cooldown = 8,
                    DamageType = "Physical",
                    Effects = {{
                        Type = "AoEDamage",
                        Damage = 40,
                        Radius = 8,
                        Angle = 180
                    }}
                },
                E = {
                    Id = "sword_thrust",
                    Name = "Выпад",
                    Description = "Мощный удар по одной цели с замедлением.",
                    Icon = "rbxassetid://107340020831744",
                    AnimationId = "rbxassetid://0",
                    Cooldown = 12,
                    DamageType = "Physical",
                    Effects = {{
                        Type = "DirectDamage",
                        Damage = 60
                    }, {
                        Type = "ApplyDebuff",
                        BuffId = "slow",
                        Duration = 3
                    }}
                }
            }
        },
        Axe = {
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
    }
}
