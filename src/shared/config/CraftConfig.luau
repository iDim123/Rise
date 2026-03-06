return {
    Crafting = {
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
        }, {
            Id = "rugged_hide_helmet",
            Name = "Шлем из грубой шкуры",
            Description = "Грубый шлем из шкуры зверей. +10 HP.",
            Icon = "rbxassetid://130188795755158",
            Result = {
                ItemId = "rugged_hide_helmet",
                Amount = 1
            },
            Ingredients = {{
                ItemId = "rugged_hide",
                Amount = 100
            }},
            CraftTime = 1
        }, {
            Id = "rugged_hide_chest",
            Name = "Нагрудник из грубой шкуры",
            Description = "Прочный нагрудник из толстых шкур. +10 HP.",
            Icon = "rbxassetid://139222038886991",
            Result = {
                ItemId = "rugged_hide_chest",
                Amount = 1
            },
            Ingredients = {{
                ItemId = "rugged_hide",
                Amount = 100
            }},
            CraftTime = 1
        }, {
            Id = "rugged_hide_legs",
            Name = "Поножи из грубой шкуры",
            Description = "Поножи, сшитые из слоёв шкуры. +10 HP.",
            Icon = "rbxassetid://112291375503087",
            Result = {
                ItemId = "rugged_hide_legs",
                Amount = 1
            },
            Ingredients = {{
                ItemId = "rugged_hide",
                Amount = 100
            }},
            CraftTime = 1
        }, {
            Id = "rugged_hide_gauntlets",
            Name = "Перчатки из грубой шкуры",
            Description = "Перчатки, обмотанные жёсткой шкурой. +10 HP.",
            Icon = "rbxassetid://102807820827058",
            Result = {
                ItemId = "rugged_hide_gauntlets",
                Amount = 1
            },
            Ingredients = {{
                ItemId = "rugged_hide",
                Amount = 100
            }},
            CraftTime = 1
        }, {
            Id = "rugged_hide_boots",
            Name = "Сапоги из грубой шкуры",
            Description = "Сапоги, укреплённые шкурой зверей. +10 HP.",
            Icon = "rbxassetid://89717071091346",
            Result = {
                ItemId = "rugged_hide_boots",
                Amount = 1
            },
            Ingredients = {{
                ItemId = "rugged_hide",
                Amount = 100
            }},
            CraftTime = 1
        }, {
            Id = "blood_ring",
            Name = "Кровавое кольцо",
            Description = "Кольцо, пропитанное кровавой эссенцией. +3 Physical Power, +2 Magical Power.",
            Icon = "rbxassetid://0",
            Result = {
                ItemId = "blood_ring",
                Amount = 1
            },
            Ingredients = {{
                ItemId = "blood_essence",
                Amount = 20
            }},
            CraftTime = 5,
            RequiresTech = "BloodWarrior"
        }, {
            Id = "blood_necklace",
            Name = "Кровавое ожерелье",
            Description = "Ожерелье, наполненное силой крови. +15 MaxHP, +10% HealthRegen.",
            Icon = "rbxassetid://0",
            Result = {
                ItemId = "blood_necklace",
                Amount = 1
            },
            Ingredients = {{
                ItemId = "blood_essence",
                Amount = 20
            }},
            CraftTime = 5,
            RequiresTech = "BloodWarrior"
        }, {
            Id = "wooden_plank",
            Name = "Доска",
            Description = "Обработанная деревянная доска.",
            Icon = "rbxassetid://0", -- замени на свой ассет
            Result = {
                ItemId = "wooden_plank",
                Amount = 1
            },
            Ingredients = {{
                ItemId = "wood",
                Amount = 10
            }},
            CraftTime = 2,
            RequiresTech = "SawmillBoss"
        }}
    }
}
