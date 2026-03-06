return {
    Bosses = {
        BloodWarrior = {
            Name = "Кровавый Воин",
            Level = 6,
            Act = 1,
            MaxHP = 100,
            Damage = 15,
            AttackRange = 6,
            AggroRange = 30,
            AttackCooldown = 1.2,
            WalkSpeed = 14,
            RespawnTime = 10,
            EssenceRequired = 2, -- сколько раз убить для захвата
            XPReward = 150,
            Location = "Кровавый лес",
            Description = "Могущественный воин, познавший силу крови.",
            Image = "rbxassetid://0",
            BloodType = nil, -- нет типа крови, нельзя пить
            BloodQuality = nil,
            CanCapture = false, -- нельзя обычным захватом

            Loot = {{
                ItemId = "blood_essence",
                Amount = {
                    Min = 10,
                    Max = 20
                },
                Chance = 1.0
            }},

            Unlocks = {
                Type = "Recipes",
                Icon = "rbxassetid://0",
                TooltipTitle = "Кровавая ковка",
                Recipes = {"blood_ring", "blood_necklace"}
            }
        }
    },

    -- Таймер автосмерти в Downed состоянии
    DownedTimeout = 10,

    -- Клавиши
    FinishKey = Enum.KeyCode.F,
    CaptureKey = Enum.KeyCode.T,

    -- Дистанция для Finish / Capture
    InteractRange = 8
}
