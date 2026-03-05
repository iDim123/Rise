return {
    Blood = {
        DrainRate = 2,
        DrainTickSeconds = 1,
        DrinkThreshold = 0.2,
        DrinkKey = Enum.KeyCode.F,
        DrinkRange = 8,
        OutcastFallbackAmount = 25,
        Types = {
            Outcast = {
                DisplayName = "Изгой",
                Icon = "rbxassetid://122168979244567",
                Color = Color3.fromRGB(120, 120, 120),
                Buffs = {},
            },
            Warrior = {
                DisplayName = "Воин",
                Icon = "rbxassetid://72937285531599",
                Color = Color3.fromRGB(200, 50, 50),
                Buffs = { DamageBonus = { Min = 0.05, Max = 0.50 } },
            },
            Creature = {
                DisplayName = "Животное",
                Icon = "rbxassetid://121693018205086",
                Color = Color3.fromRGB(100, 180, 80),
                Buffs = {
                    SpeedBonus = { Min = 0.02, Max = 0.20 },
                },
            },
        },
    },
}