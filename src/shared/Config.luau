local Config = {}

Config.Player = {
    MaxHP = 200,
    RespawnTime = 5
}

Config.Enemies = {
    Warrior = {
        MaxHP = 120,
        Damage = 10,
        AttackRange = 5,
        AggroRange = 25,
        AttackCooldown = 1.5,
        WalkSpeed = 12,
        RespawnTime = 10,
        BloodType = "Warrior",
        BloodQuality = {
            Min = 1,
            Max = 100
        }, -- случайное качество при спавне
        Loot = {{
            ItemId = "blood_essence",
            Amount = {
                Min = 5,
                Max = 12
            },
            Chance = 1.0
        }}
    },
    TrainingDummy = {
        MaxHP = 99999,
        Damage = 0,
        AttackRange = 0,
        AggroRange = 0,
        AttackCooldown = 999,
        WalkSpeed = 0,
        RespawnTime = 5,
        BloodType = "Outcast",
        BloodQuality = {
            Min = 1,
            Max = 1
        },
        Loot = {}
    }
}

Config.Weapons = {
    Sword = {
        Damage = 15,
        Range = 6,
        Cooldown = 0.4,
        ComboWindow = 1.2,
        ResourceDamage = 15,
        Combo = {
            [1] = { Damage = 25, AnimationId = "rbxassetid://70662356098178" },
            [2] = { Damage = 20, AnimationId = "rbxassetid://70662356098178" },
            [3] = { Damage = 30, AnimationId = "rbxassetid://70662356098178" },
        },
        ComboAbility = {
            Id = "sword_combo",
            Name = "Sword Combo",
            Description = "3-hit combo: slash, thrust, heavy strike.",
            Icon = "rbxassetid://119544363190700",
        },
        Abilities = {
            Q = {
                Id = "sword_slash",
                Name = "Широкий замах",
                Description = "Наносит урон всем врагам перед собой.",
                Icon = "rbxassetid://109099176664820",
                AnimationId = "rbxassetid://0",
                Cooldown = 8,
                Effects = {
                    { Type = "AoEDamage", Damage = 40, Radius = 8, Angle = 180 },
                },
            },
            E = {
                Id = "sword_thrust",
                Name = "Выпад",
                Description = "Мощный удар по одной цели с замедлением.",
                Icon = "rbxassetid://107340020831744",
                AnimationId = "rbxassetid://0",
                Cooldown = 12,
                Effects = {
                    { Type = "DirectDamage", Damage = 60 },
                    { Type = "ApplyDebuff", BuffId = "slow", Duration = 3 },
                },
            },
        },
    },
    Axe = {
        Damage = 20,
        Range = 5,
        Cooldown = 0.6,
        ComboWindow = 1.0,
        ResourceDamage = 12,
        Combo = {
            [1] = { Damage = 30, AnimationId = "rbxassetid://131735837276755" },
            [2] = { Damage = 25, AnimationId = "rbxassetid://131735837276755" },
            [3] = { Damage = 40, AnimationId = "rbxassetid://131735837276755" },
        },
        ComboAbility = {
            Id = "axe_combo",
            Name = "Axe Combo",
            Description = "3-hit combo: chop, swing, overhead slam.",
            Icon = "rbxassetid://127853105217094",
        },
        Abilities = {
            Q = {
                Id = "axe_frenzy",
                Name = "Бешенство",
                Description = "Увеличивает урон на 30% на 5 секунд.",
                Icon = "rbxassetid://110176616320571",
                AnimationId = "rbxassetid://0",
                Cooldown = 10,
                Effects = {
                    { Type = "ApplyBuff", BuffId = "damage_boost", Duration = 5 },
                },
            },
            E = {
                Id = "axe_whirlwind",
                Name = "Вихрь",
                Description = "AoE урон вокруг с замедлением.",
                Icon = "rbxassetid://107340020831744",
                AnimationId = "rbxassetid://0",
                Cooldown = 14,
                Effects = {
                    { Type = "AoEDamage", Damage = 35, Radius = 10, Angle = 360 },
                    { Type = "ApplyDebuff", BuffId = "slow", Duration = 3 },
                },
            },
        },
    },
}

Config.Inventory = {
    Rows = 5,
    Columns = 8,
    SlotSize = 50,
    Padding = 4,
    ActionBarRow = 1 -- первая строка = ActionBar
}

Config.Equipment = {
    Slots = {{
        Id = "Head",
        Name = "Head",
        Row = 1
    }, {
        Id = "Chest",
        Name = "Chest",
        Row = 2
    }, {
        Id = "Legs",
        Name = "Legs",
        Row = 3
    }, {
        Id = "Feet",
        Name = "Feet",
        Row = 4
    }, {
        Id = "Hands",
        Name = "Hands",
        Row = 5
    }}
}

Config.ItemTypes = {
    Weapon = "Weapon",
    HeadArmor = "Head",
    ChestArmor = "Chest",
    LegsArmor = "Legs",
    FeetArmor = "Feet",
    HandsArmor = "Hands",
    Amulet = "Amulet",
    Ring = "Ring",
    Consumable = "Consumable",
    Misc = "Misc",
    Resource = "Resource"
}

Config.Blood = {
    DrainRate = 2, -- % в минуту
    DrainTickSeconds = 1, -- проверка каждую секунду
    DrinkThreshold = 0.2, -- враг <20% HP
    DrinkKey = Enum.KeyCode.F,
    DrinkRange = 8, -- дистанция для питья
    OutcastFallbackAmount = 25, -- % крови Изгоя при истощении

    Types = {
        Outcast = {
            DisplayName = "Изгой",
            Color = Color3.fromRGB(120, 120, 120),
            Buffs = {} -- нет баффов
        },
        Warrior = {
            DisplayName = "Воин",
            Color = Color3.fromRGB(200, 50, 50),
            Buffs = {
                DamageBonus = {
                    Min = 0.05,
                    Max = 0.50
                } -- 5%-50%
            }
        }
    }
}

Config.Servants = {
    MaxCaptured = 10,
    MaxActive = 1,
    CaptureKey = Enum.KeyCode.T,
    CaptureRange = 8,
    CaptureTime = 0,
    CaptureThreshold = 1,
    FollowDistance = 6,
    AttackRange = 5,
    AggroRange = 20,
    AttackCooldown = 1.2,
    PowerBase = 100,

    EquipmentSlots = {
        { Id = "Head",    Name = "Head",    Row = 1, Col = 1 },
        { Id = "Chest",   Name = "Chest",   Row = 2, Col = 1 },
        { Id = "Legs",    Name = "Legs",    Row = 3, Col = 1 },
        { Id = "Feet",    Name = "Feet",    Row = 4, Col = 1 },
        { Id = "Hands",   Name = "Hands",   Row = 5, Col = 1 },
        { Id = "Amulet",  Name = "Amulet",  Row = 1, Col = 2 },
        { Id = "Ring1",   Name = "Ring 1",  Row = 2, Col = 2 },
        { Id = "Ring2",   Name = "Ring 2",  Row = 3, Col = 2 },
    },

    Modes = {
        Aggressive = "Aggressive",
        Defensive = "Defensive",
        Passive = "Passive"
    },

    Commands = {
        AttackTarget = "AttackTarget",
        Stay = "Stay",
        Follow = "Follow"
    }
}

Config.Items = {
    debug_buff_potion = {
        Id = "debug_buff_potion",
        Name = "Debug Buff Potion",
        Description = "Test potion: +30% damage, -40% speed for 20s.",
        Icon = "rbxassetid://0",
        Type = "Consumable",
        ItemLevel = 0,
        Stackable = true,
        MaxStack = 20,
        UseEffect = {
            Type = "ApplyBuffs",
            Cooldown = 1,
            Buffs = {
                { BuffId = "damage_boost", Duration = 200 },
                { BuffId = "slow", Duration = 20 },
            },
        },
    },
    debug_servant_egg = {
        Id = "debug_servant_egg",
        Name = "Debug Servant Egg",
        Description = "Use to add a random servant. Debug item.",
        Icon = "rbxassetid://0",
        Type = "Consumable",
        ItemLevel = 0,
        Stackable = true,
        MaxStack = 99,
        UseEffect = {
            Type = "AddServant",
            Cooldown = 1
        }
    },
    blood_essence = {
        Id = "blood_essence",
        Name = "Blood Essence",
        Description = "An energy source distilled from blood.",
        Icon = "rbxassetid://114549612188882",
        Category = "Alchemy",
        Type = "Resource",
        ItemLevel = 0,
        Stackable = true,
        MaxStack = 500
    },
    health_potion = {
        Id = "health_potion",
        Name = "Health Potion",
        Description = "Восстанавливает 50 HP при использовании.",
        Icon = "rbxassetid://111762549286435",
        Type = "Consumable",
        ItemLevel = 0,
        Stackable = true,
        MaxStack = 20,
        UseEffect = {
            Type = "Heal",
            Amount = 50,
            Cooldown = 5
        }
    },
    Sword = {
        Id = "Sword",
        Name = "Sword of Light",
        Description = "A shining blade.",
        Icon = "rbxassetid://119544363190700",
        Type = "Weapon",
        ItemLevel = 10,
        Stackable = false,
        MaxStack = 1
    },
    Axe = {
        Id = "Axe",
        Name = "Iron Axe",
        Description = "A sturdy one-handed axe.",
        Icon = "rbxassetid://127853105217094",
        Type = "Weapon",
        ItemLevel = 8,
        Stackable = false,
        MaxStack = 1,
    },
    iron_helmet = {
        Id = "iron_helmet",
        Name = "Iron Helmet",
        Description = "Basic head protection.",
        Icon = "rbxassetid://130188795755158",
        Type = "Head",
        EquipSlot = "Head",
        ItemLevel = 5,
        Stackable = false,
        MaxStack = 1,
        Stats = {
            Defense = 5
        }
    },
    wood = {
        Id = "wood",
        Name = "Wood",
        Description = "Raw wood harvested from trees.",
        Icon = "rbxassetid://120841469219855",
        Type = "Resource",
        ItemLevel = 0,
        Stackable = true,
        MaxStack = 99,
    },
    stone = {
        Id = "stone",
        Name = "Stone",
        Description = "Raw stone mined from rocks.",
        Icon = "rbxassetid://73029786735287",
        Type = "Resource",
        ItemLevel = 0,
        Stackable = true,
        MaxStack = 99,
    },
}

Config.Loot = {
    DropLifetime = 300, -- секунд до исчезновения
    PickupRange = 6, -- дистанция подбора
    PickupKey = Enum.KeyCode.F
}

Config.Crafting = {
    Recipes = {{
        Id = "health_potion",
        Name = "Зелье восстановления",
        Description = "Восстанавливает 50 HP при использовании.",
        Icon = "rbxassetid://111762549286435",
        Result = {
            ItemId = "health_potion",
            Amount = 1
        },
        Ingredients = {{
            ItemId = "blood_essence",
            Amount = 10
        }},
        CraftTime = 1
    }, {
        Id = "health_potion_x5",
        Name = "Зелье восстановления x5",
        Description = "Крафт 5 зелий восстановления за раз.",
        Icon = "rbxassetid://111762549286435",
        Result = {
            ItemId = "health_potion",
            Amount = 5
        },
        Ingredients = {{
            ItemId = "blood_essence",
            Amount = 50
        }},
        CraftTime = 3
    }}
}

Config.Buffs = {
    damage_boost = {
        Id = "damage_boost",
        Name = "Усиление урона",
        Description = "+30% к урону на время действия.",
        Icon = "rbxassetid://110176616320571",
        Type = "Buff",
        Stat = "DamageBonus",
        Value = 0.30,
        Stackable = false,
    },
    slow = {
        Id = "slow",
        Name = "Замедление",
        Description = "-40% скорости передвижения.",
        Icon = "rbxassetid://110176616320571",
        Type = "Debuff",
        Stat = "Slow",
        Value = 0.40,
        Stackable = false,
    },
    damage_reduction = {
        Id = "damage_reduction",
        Name = "Укрепление",
        Description = "-20% получаемого урона.",
        Icon = "rbxassetid://110176616320571",
        Type = "Buff",
        Stat = "DamageReduction",
        Value = 0.20,
        Stackable = false,
    },
    speed_boost = {
        Id = "speed_boost",
        Name = "Ускорение",
        Description = "+25% скорости передвижения.",
        Icon = "rbxassetid://110176616320571",
        Type = "Buff",
        Stat = "SpeedBonus",
        Value = 0.25,
        Stackable = false,
    },
}

Config.ResourceNodes = {
    Tree = {
        MaxHP = 50,
        ResourceId = "wood",
        ResourcePerHit = 1, -- multiplier: resourceDamage * this = amount
        RespawnTime = 5,
        Model = "Tree",
    },
    Rock = {
        MaxHP = 80,
        ResourceId = "stone",
        ResourcePerHit = 1,
        RespawnTime = 45,
        Model = "Rock",
    },
}

return Config
