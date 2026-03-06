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
        },
        SawmillBoss = {
            Name = "Глава лесопилки",
            Level = 14,
            Act = 1,
            MaxHP = 80,
            Damage = 10,
            AttackRange = 5,
            AggroRange = 25,
            AttackCooldown = 1.4,
            WalkSpeed = 12,
            RespawnTime = 10,
            EssenceRequired = 2,
            XPReward = 100,
            Location = "Лесопилка",
            Description = "Жестокий надсмотрщик, управляющий старой лесопилкой. Знает секреты обработки древесины.",
            Image = "rbxassetid://123248253802708", -- замени на свой ассет
            BloodType = nil,
            BloodQuality = nil,
            CanCapture = false,

            Loot = {{
                ItemId = "wood",
                Amount = {
                    Min = 20,
                    Max = 40
                },
                Chance = 1.0
            }},

            Unlocks = {{
                Type = "Recipes",
                Icon = "rbxassetid://120841469219855", -- иконка досок
                Name = "Обработка древесины",
                Description = "Открывает рецепт обработки древесины в доски.",
                Recipes = {"wooden_plank"}
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
