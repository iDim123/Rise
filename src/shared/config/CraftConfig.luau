return {
    Crafting = {
        Recipes = {
            {
                Id = "health_potion",
                Name = "Зелье восстановления",
                Description = "Восстанавливает 50 HP при использовании.",
                Icon = "rbxassetid://111762549286435",
                Result = { ItemId = "health_potion", Amount = 1 },
                Ingredients = { { ItemId = "blood_essence", Amount = 10 } },
                CraftTime = 1,
            },
            {
                Id = "health_potion_x5",
                Name = "Зелье восстановления x5",
                Description = "Крафт 5 зелий восстановления за раз.",
                Icon = "rbxassetid://111762549286435",
                Result = { ItemId = "health_potion", Amount = 5 },
                Ingredients = { { ItemId = "blood_essence", Amount = 50 } },
                CraftTime = 3,
            },
        },
    },
}