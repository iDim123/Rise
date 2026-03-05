return {
    Enemies = {
        Warrior = {
            MaxHP = 120,
            Damage = 10,
            AttackRange = 5,
            AggroRange = 25,
            AttackCooldown = 1.5,
            WalkSpeed = 12,
            RespawnTime = 10,
            BloodType = "Warrior",
            BloodQuality = { Min = 1, Max = 100 },
            Loot = {
                { ItemId = "blood_essence", Amount = { Min = 5, Max = 12 }, Chance = 1.0 },
            },
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
            BloodQuality = { Min = 1, Max = 1 },
            Loot = {},
        },
    },
}