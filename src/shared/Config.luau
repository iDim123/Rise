
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
	},
	TrainingDummy = {
        MaxHP = 99999,
        Damage = 0,
        AttackRange = 0,
        AggroRange = 0,       -- 0 = никогда не агрится
        AttackCooldown = 999,
        WalkSpeed = 0,
        RespawnTime = 5,
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

return Config