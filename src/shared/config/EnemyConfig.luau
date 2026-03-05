return {
    Enemies = {
        Warrior = {
            MaxHP = 120,
            Damage = 10,
            AttackRange = 5,
            AggroRange = 25,
            AttackCooldown = 1.5,
            WalkSpeed = 12,
            Level = 5,
            RespawnTime = 10,
            BloodType = "Warrior",
            BloodQuality = { Min = 1, Max = 100 },
            XPReward = 50,
            Loot = {
                { ItemId = "blood_essence", Amount = { Min = 5, Max = 12 }, Chance = 1.0 },
            },
        },
        Wolf = {
            MaxHP = 90,         
            Damage = 5,        
            AttackRange = 4,
            AggroRange = 20,
            PackRadius = 30,      -- радиус стайного агро
            AttackCooldown = 1.2,
            WalkSpeed = 16,       -- волки быстрее
            RespawnTime = 10,
            Level = 4,            -- 3-5, среднее
            XPReward = 35,
            CanCapture = false,
            BloodType = "Creature",
            BloodQuality = { Min = 1, Max = 100 },
            Loot = {
                { ItemId = "rugged_hide", Amount = { Min = 5, Max = 20 }, Chance = 1.0 },
            },
        },
        TrainingDummy = {
            MaxHP = 99999,
            Damage = 0,
            AttackRange = 0,
            AggroRange = 0,
            AttackCooldown = 999,
            WalkSpeed = 0,
            Level = 1,
            RespawnTime = 5,
            BloodType = "Outcast",
            BloodQuality = { Min = 1, Max = 1 },
            Loot = {},
            XPReward = 0,
        },
    },
}