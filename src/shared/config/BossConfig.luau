return {
    Bosses = {
        BloodWarrior = {
            Name = "Кровавый Воин",
            Level = 6,
            Act = 1,
            MaxHP = 10,
            Damage = 15,
            AttackRange = 6,
            AggroRange = 30,
            AttackCooldown = 1.2,
            WalkSpeed = 14,
            RespawnTime = 10,
            EssenceRequired = 2,
            XPReward = 150,
            Location = "Кровавый лес",
            Description = "Могущественный воин, познавший силу крови. Его удары пропитаны кровавой энергией, а его жажда крови не знает границ. Он бродит по Кровавому лесу в поисках жертв, чтобы утолить свою жажду и стать ещё сильнее.",
            Image = "rbxassetid://87767728636951",
            BloodType = nil,
            BloodQuality = nil,
            CanCapture = false,
            SpellPointRewards = {{
                School = "Blood",
                Tier = 1,
                Amount = 1
            }, {
                School = "Blood",
                Tier = 2,
                Amount = 1
            }},
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
            }, {
                Type = "Spell",
                Icon = "rbxassetid://123772032226199",
                Name = "Blood Rage",
                Description = "Открывает Blood Rage (Tier I Blood)."
            }},
            Abilities = {
                BloodSlash = {
                    Name = "Кровавый удар",
                    Type = "DirectDamage",
                    Damage = 30,
                    Range = 8,
                    Cooldown = 6,
                    Priority = 1,
                    MinHP = 0,
                    Animation = nil
                },
                BloodNova = {
                    Name = "Кровавая волна",
                    Type = "AoEDamage",
                    Damage = 20,
                    Radius = 12,
                    Cooldown = 12,
                    Priority = 2,
                    MinHP = 0,
                    Animation = nil
                },
                BloodRage = {
                    Name = "Ярость крови",
                    Type = "Enrage",
                    SpeedMultiplier = 1.5,
                    DamageMultiplier = 1.3,
                    Duration = 5,
                    Cooldown = 20,
                    Priority = 3,
                    MinHP = 0.5,
                    Animation = nil
                }
            }
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
            Image = "rbxassetid://123248253802708",
            BloodType = nil,
            BloodQuality = nil,
            CanCapture = false,
            SpellPointRewards = {{
                School = "Chaos",
                Tier = 1,
                Amount = 1
            }, {
                School = "Blood",
                Tier = 2,
                Amount = 1
            }},
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
                Icon = "rbxassetid://120841469219855",
                Name = "Обработка древесины",
                Description = "Открывает рецепт обработки древесины в доски.",
                Recipes = {"wooden_plank"}
            }, {
                Type = "Spell",
                Icon = "rbxassetid://136139846768097",
                Name = "Chaos Volley",
                Description = "Открывает Chaos Volley (Tier I Chaos)."
            }},
            Abilities = {
                HeavyChop = {
                    Name = "Тяжёлый удар",
                    Type = "DirectDamage",
                    Damage = 25,
                    Range = 7,
                    Cooldown = 5,
                    Priority = 1,
                    MinHP = 0
                },
                TimberFall = {
                    Name = "Падение брёвен",
                    Type = "AoEDamage",
                    Damage = 15,
                    Radius = 10,
                    Cooldown = 15,
                    Priority = 2,
                    MinHP = 0
                }
            }
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
