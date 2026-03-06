return {
    Blood = {
        DrainRate = 2,
        DrainTickSeconds = 1,
        DrinkThreshold = 0.2,
        DrinkKey = Enum.KeyCode.F,
        DrinkRange = 8,
        OutcastFallbackAmount = 25,

        TierThresholds = {
            I = 1,
            II = 50,
            MAX = 100
        },

        Types = {
            Outcast = {
                DisplayName = "Изгой",
                Icon = "rbxassetid://122168979244567",
                Color = Color3.fromRGB(120, 120, 120),
                Tiers = {}
            },
            Warrior = {
                DisplayName = "Воин",
                Icon = "rbxassetid://72937285531599",
                Color = Color3.fromRGB(200, 50, 50),
                Tiers = {
                    I = {
                        Stat = "PhysicalPower",
                        Min = 0.10,
                        Max = 0.20,
                        QualityRange = {1, 100},
                        Description = "Увеличивает физическую силу на %s%%"
                    },
                    II = {
                        Stat = "WeaponCDSpeed",
                        Min = 0.10,
                        Max = 0.20,
                        QualityRange = {50, 100},
                        Description = "Увеличивает скорость перезарядки оружия на %s%%"
                    },
                    MAX = {
                        Type = "BoostAll",
                        Multiplier = 1.20,
                        Description = "Усиливает все бонусы крови на 20%"
                    }
                }
            },
            Creature = {
                DisplayName = "Животное",
                Icon = "rbxassetid://121693018205086",
                Color = Color3.fromRGB(100, 180, 80),
                Tiers = {
                    I = {
                        Stat = "MoveSpeed",
                        Min = 0.10,
                        Max = 0.20,
                        QualityRange = {1, 100},
                        Description = "Увеличивает скорость передвижения на %s%%"
                    },
                    II = {
                        Stat = "HealingReceived",
                        Min = 0.12,
                        Max = 0.24,
                        QualityRange = {50, 100},
                        Description = "Увеличивает получаемое исцеление на %s%%"
                    },
                    MAX = {
                        Type = "BoostAll",
                        Multiplier = 1.20,
                        Description = "Усиливает все бонусы крови на 20%"
                    }
                }
            }
        }
    }
}
