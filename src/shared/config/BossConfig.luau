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
            Description = "Могущественный воин, познавший силу крови. Его удары пропитаны кровавой энергией, а его жажда крови не знает границ. Он бродит по Кровавому лесу в поисках жертв, чтобы утолить свою жажду и стать ещё сильнее.",
            Image = "rbxassetid://87767728636951",
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
            Unlocks = {{
                Type = "Recipes",
                Icon = "rbxassetid://78556678380740",
                Name = "Кровавая ковка",
                Description = "Открывает рецепты кровавых украшений.",
                Recipes = {"blood_ring", "blood_necklace"}
            }, {
                Type = "Loot",
                Icon = "rbxassetid://133649527466179",
                Name = "Малая сумка",
                Description = "Содержит различные ресурсы."
            }}
        }
    },

    -- Таймер автосмерти в Downed состоянии
    DownedTimeout = 20,

    -- Клавиши
    FinishKey = Enum.KeyCode.F,
    CaptureKey = Enum.KeyCode.T,

    -- Дистанция для Finish / Capture
    InteractRange = 8
}
