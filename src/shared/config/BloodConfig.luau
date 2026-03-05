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
                Color = Color3.fromRGB(120, 120, 120),
                Buffs = {},
            },
            Warrior = {
                DisplayName = "Воин",
                Color = Color3.fromRGB(200, 50, 50),
                Buffs = { DamageBonus = { Min = 0.05, Max = 0.50 } },
            },
        },
    },
}