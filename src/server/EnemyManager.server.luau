local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local HealthManager = require(script.Parent:WaitForChild("HealthManager"))

local enemiesFolder = ServerStorage:WaitForChild("enemies")

-- Папка для живых врагов в Workspace
local activeEnemies = Instance.new("Folder")
activeEnemies.Name = "Enemies"
activeEnemies.Parent = workspace

-- Спавн одного врага
local function spawnEnemy(template, spawnPosition)
	local enemy = template:Clone()
	enemy.Parent = activeEnemies

	-- Перемещаем на точку спавна
	local rootPart = enemy:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.Anchored = false
		rootPart.CFrame = CFrame.new(spawnPosition)
	end

	local humanoid = enemy:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.Enemies.Warrior.WalkSpeed
	end

	-- Сохраняем данные
	enemy:SetAttribute("EnemyType", "Warrior")
	enemy:SetAttribute("SpawnPosition", spawnPosition)

	-- Инициализируем HP
	HealthManager.init(enemy, Config.Enemies.Warrior.MaxHP)

	print("[EnemyManager] Spawned: " .. enemy.Name .. " at " .. tostring(spawnPosition))

	return enemy
end

-- Респавн врага после смерти
local function onEnemyDied(enemyType, spawnPosition)
	local config = Config.Enemies[enemyType]
	if not config then return end

	task.delay(config.RespawnTime, function()
		local template = enemiesFolder:FindFirstChild(enemyType)
		if template then
			spawnEnemy(template, spawnPosition)
		end
	end)
end

-- Начальный спавн всех врагов
local function initEnemies()
	for _, template in enemiesFolder:GetChildren() do
		local spawnPos = template:GetAttribute("SpawnPosition")
		if spawnPos then
			spawnEnemy(template, spawnPos)
		end
	end
end

initEnemies()

return {
	spawnEnemy = spawnEnemy,
	onEnemyDied = onEnemyDied,
}