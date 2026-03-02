
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
}

Config.Weapons = {
	Sword = {
		Damage = 15,
		Range = 6,
		Cooldown = 0.8,
	},
}

return Config