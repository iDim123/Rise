
local Config = {}

Config.Player = {
	MaxHP = 100,
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
				Damage = 15,
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
    Rows = 2,
    Columns = 6,
    SlotSize = 60,  -- пиксели
    Padding = 4,
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

return Config