
local Config = {}

Config.Player = {
	MaxHP = 200,
	RespawnTime = 5,
}

Config.Enemies = {
    Warrior = {
        MaxHP = 80,
        Damage = 10,
        AttackRange = 5,
        AggroRange = 25,
        AttackCooldown = 1.5,
        WalkSpeed = 12,
        RespawnTime = 10,
        BloodType = "Warrior",
        BloodQuality = { Min = 1, Max = 100 }, -- случайное качество при спавне
        Loot = {
            { ItemId = "blood_essence", Amount = { Min = 5, Max = 12 }, Chance = 1.0 },
        },
    },
    TrainingDummy = {
        MaxHP = 99999,
        Damage = 0,
        AttackRange = 0,
        AggroRange = 0,
        AttackCooldown = 999,
        WalkSpeed = 0,
        RespawnTime = 5,
        BloodType = "Outcast",
        BloodQuality = { Min = 1, Max = 1 },
        Loot = {},
    },
}

Config.Weapons = {
	Sword = {
		Damage = 15,
		Range = 6,
		Cooldown = 0.4,
		ComboWindow = 1.2, -- секунд на следующий клик, иначе сброс
		Combo = {
			[1] = {
				Damage = 35,
				AnimationId = "rbxassetid://70662356098178", -- твоя анимация
			},
			[2] = {
				Damage = 20,
				AnimationId = "rbxassetid://70662356098178", -- замени на другую позже
			},
			[3] = {
				Damage = 30,
				AnimationId = "rbxassetid://70662356098178", -- замени на другую позже
			},
		},
	},
}


Config.Inventory = {
    Rows = 5,
    Columns = 8,
    SlotSize = 50,
    Padding = 4,
    ActionBarRow = 1, -- первая строка = ActionBar
}

Config.Equipment = {
    Slots = {
        { Id = "Head",  Name = "Head",  Row = 1 },
        { Id = "Chest", Name = "Chest", Row = 2 },
        { Id = "Legs",  Name = "Legs",  Row = 3 },
        { Id = "Feet",  Name = "Feet",  Row = 4 },
        { Id = "Hands", Name = "Hands", Row = 5 },
    },
}

Config.ItemTypes = {
    Weapon = "Weapon",
    HeadArmor = "Head",
    ChestArmor = "Chest",
    LegsArmor = "Legs",
    FeetArmor = "Feet",
    HandsArmor = "Hands",
    Consumable = "Consumable",
    Misc = "Misc",
    Resource = "Resource",
}

Config.Blood = {
    DrainRate = 2,           -- % в минуту
    DrainTickSeconds = 1,    -- проверка каждую секунду
    DrinkThreshold = 0.2,    -- враг <20% HP
    DrinkKey = Enum.KeyCode.F,
    DrinkRange = 8,          -- дистанция для питья
    OutcastFallbackAmount = 25, -- % крови Изгоя при истощении

    Types = {
        Outcast = {
            DisplayName = "Изгой",
            Color = Color3.fromRGB(120, 120, 120),
            Buffs = {},  -- нет баффов
        },
        Warrior = {
            DisplayName = "Воин",
            Color = Color3.fromRGB(200, 50, 50),
            Buffs = {
                DamageBonus = { Min = 0.05, Max = 0.50 }, -- 5%-50%
            },
        },
    },
}

Config.Servants = {
    MaxCaptured = 10,
    MaxActive = 1,
    CaptureKey = Enum.KeyCode.T,
    CaptureRange = 8,
    CaptureTime = 3,          -- секунды каста
    CaptureThreshold = 0.3,   -- враг <30% HP
    FollowDistance = 6,        -- дистанция следования за игроком
    AttackRange = 5,
    AggroRange = 20,
    AttackCooldown = 1.2,

    Modes = {
        Aggressive = "Aggressive",
        Defensive = "Defensive",
        Passive = "Passive",
    },

    Commands = {
        AttackTarget = "AttackTarget",
        Stay = "Stay",
        Follow = "Follow",
    },
}

Config.Items = {
	blood_essence = {
		Id = "blood_essence",
		Name = "Blood Essence",
		Description = "An energy source distilled from blood. Vampires use it to control material, to unlock sealed knowledge and convert humans into obedient servants.",
		Icon = "rbxassetid://0",
		Category = "Alchemy",
		Type = "Resource",
		Stackable = true,
		MaxStack = 500,
	},
    health_potion = {
        Id = "health_potion",
        Name = "Health Potion",
        Description = "Восстанавливает 50 HP при использовании.",
        Icon = "rbxassetid://0",
        Type = "Consumable",
        Stackable = true,
        MaxStack = 20,
        UseEffect = {
            Type = "Heal",
            Amount = 50,
            Cooldown = 5,
        },
    },
}

Config.Loot = {
	DropLifetime = 300, -- секунд до исчезновения
	PickupRange = 6,    -- дистанция подбора
	PickupKey = Enum.KeyCode.F,
}

Config.Crafting = {
    Recipes = {
        {
            Id = "health_potion",
            Name = "Зелье восстановления",
            Description = "Восстанавливает 50 HP при использовании.",
            Icon = "rbxassetid://0",
            Result = {
                Id = "health_potion",
                Name = "Health Potion",
                Icon = "rbxassetid://0",
                Type = "Consumable",
                Stackable = true,
                MaxStack = 20,
                Amount = 1,
            },
            Ingredients = {
                { ItemId = "blood_essence", Amount = 10 },
            },
            CraftTime = 1,
        },  {
            Id = "health_potion_x5",
            Name = "Зелье восстановления x5",
            Description = "Крафт 5 зелий восстановления за раз.",
            Icon = "rbxassetid://0",
            Result = {
                Id = "health_potion",
                Name = "Health Potion",
                Icon = "rbxassetid://0",
                Type = "Consumable",
                Stackable = true,
                MaxStack = 20,
                Amount = 5,
            },
            Ingredients = {
                { ItemId = "blood_essence", Amount = 50 },
            },
            CraftTime = 3,
        },
    },
}

return Config