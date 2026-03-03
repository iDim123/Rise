local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local HealthManager = require(script.Parent:WaitForChild("HealthManager"))

local enemiesFolder = ServerStorage:WaitForChild("enemies")

-- Папка для живых врагов в Workspace
local activeEnemies = Instance.new("Folder")
activeEnemies.Name = "Enemies"
activeEnemies.Parent = workspace

-- Спавн одного врага
local function spawnEnemy(template, spawnPosition)
	local enemyType = template:GetAttribute("EnemyType")
	if not enemyType then return nil end

	local config = Config.Enemies[enemyType]
	if not config then
		warn("[EnemyManager] No config for enemy type: " .. enemyType)
		return nil
	end

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
		humanoid.WalkSpeed = config.WalkSpeed
	end

	-- Сохраняем данные
	enemy:SetAttribute("EnemyType", enemyType)
	enemy:SetAttribute("SpawnPosition", spawnPosition)

	-- Инициализируем HP
	HealthManager.init(enemy, config.MaxHP)

 -- Кровь врага
    local bloodType = config.BloodType or "Outcast"
    local bloodQualityRange = config.BloodQuality or { Min = 1, Max = 1 }
    local bloodQuality = math.random(bloodQualityRange.Min, bloodQualityRange.Max)
    enemy:SetAttribute("BloodType", bloodType)
    enemy:SetAttribute("BloodQuality", bloodQuality)

    print("[EnemyManager] Spawned: " .. enemyType .. " at " .. tostring(spawnPosition)
        .. " | Blood: " .. bloodType .. " " .. bloodQuality .. "%")

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
		local enemyType = template:GetAttribute("EnemyType")
		if not enemyType then continue end

		local spawnPos = template:GetAttribute("SpawnPosition")
		if not spawnPos then continue end

		local config = Config.Enemies[enemyType]
		if not config then
			warn("[EnemyManager] Skipping " .. template.Name .. ": no config for type " .. enemyType)
			continue
		end

		spawnEnemy(template, spawnPos)
	end
end

initEnemies()

return {
	spawnEnemy = spawnEnemy,
	onEnemyDied = onEnemyDied,
}