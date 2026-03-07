return {
    debug_buff_potion = {
        Name = "Debug Buff Potion",
        Description = "Test potion: +30% damage, -40% speed for 20s.",
        Icon = "rbxassetid://0",
        Type = "Consumable",
        ItemLevel = 0,
        Stackable = true,
        MaxStack = 20,
        UseEffect = {
            Type = "ApplyBuffs",
            Cooldown = 1,
            Buffs = {{
                BuffId = "damage_boost",
                Duration = 200
            }, {
                BuffId = "slow",
                Duration = 20
            }}
        }
    },
    debug_servant_egg = {
        Name = "Debug Servant Egg",
        Description = "Use to add a random servant. Debug item.",
        Icon = "rbxassetid://0",
        Type = "Consumable",
        ItemLevel = 0,
        Stackable = true,
        MaxStack = 99,
        UseEffect = {
            Type = "AddServant",
            Cooldown = 1
        }
    },
    health_potion = {
        Name = "Health Potion",
        Description = "Восстанавливает 50 HP при использовании.",
        Icon = "rbxassetid://111762549286435",
        Type = "Consumable",
        ItemLevel = 0,
        Stackable = true,
        MaxStack = 20,
        UseEffect = {
            Type = "Heal",
            Amount = 50,
            Cooldown = 5
        }
    },
    blood_vial_warrior = {
        Name = "Колба крови воина",
        Description = "Колба с кровью воина. Выпейте, чтобы сменить тип крови.",
        Icon = "rbxassetid://115847672921380",
        Type = "Consumable",
        ItemLevel = 0,
        Stackable = true,
        MaxStack = 30,
        UseEffect = {
            Type = "DrinkBloodVial",
            Cooldown = 1,
            BloodType = "Warrior",
            BloodQuality = 50
        }
    },
    blood_vial_creature = {
        Name = "Колба крови существа",
        Description = "Колба с кровью существа. Выпейте, чтобы сменить тип крови.",
        Icon = "rbxassetid://115847672921380",
        Type = "Consumable",
        ItemLevel = 0,
        Stackable = true,
        MaxStack = 30,
        UseEffect = {
            Type = "DrinkBloodVial",
            Cooldown = 1,
            BloodType = "Creature",
            BloodQuality = 100
        }
    }
}
