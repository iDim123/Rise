local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local HealthManager = require(script.Parent:WaitForChild("HealthManager"))

local TICK_RATE = 0.2 -- как часто обновляется AI (секунды)

-- Найти ближайшего игрока в радиусе
local function findNearestPlayer(position, range)
	local nearest = nil
	local nearestDist = range

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then continue end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end

		local dist = (rootPart.Position - position).Magnitude
		if dist < nearestDist then
			nearest = character
			nearestDist = dist
		end
	end

	return nearest, nearestDist
end

-- AI цикл для одного врага
local function updateEnemy(enemy)
	local humanoid = enemy:FindFirstChild("Humanoid")
	local rootPart = enemy:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end
	if humanoid.Health <= 0 then return end

	local data = HealthManager.getData(enemy)
	if not data or data.IsDead then return end

	local enemyType = enemy:GetAttribute("EnemyType") or "Warrior"
	local config = Config.Enemies[enemyType]
	if not config then return end

	local spawnPos = enemy:GetAttribute("SpawnPosition")
	local position = rootPart.Position

	-- Ищем игрока в радиусе агро
	local target, distance = findNearestPlayer(position, config.AggroRange)

	if target then
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if not targetRoot then return end

		if distance <= config.AttackRange then
			-- Атака
			humanoid:MoveTo(rootPart.Position) -- остановиться

			-- Поворачиваемся к цели
			local direction = (targetRoot.Position - rootPart.Position).Unit
			rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + Vector3.new(direction.X, 0, direction.Z))

			-- Проверяем кулдаун атаки
			local lastAttack = enemy:GetAttribute("LastAttack") or 0
			local now = tick()

			if now - lastAttack >= config.AttackCooldown then
				enemy:SetAttribute("LastAttack", now)
				HealthManager.takeDamage(target, config.Damage, enemy)
				print("[EnemyAI] " .. enemy.Name .. " attacked " .. target.Name)
			end
		else
			-- Преследование
			humanoid:MoveTo(targetRoot.Position)
		end
	else
		-- Нет цели — возвращаемся на точку спавна
		if spawnPos then
			local distToSpawn = (position - spawnPos).Magnitude
			if distToSpawn > 3 then
				humanoid:MoveTo(spawnPos)
			end
		end
	end
end

-- Главный цикл AI
task.spawn(function()
	while true do
		local enemiesFolder = workspace:FindFirstChild("Enemies")
		if enemiesFolder then
			for _, enemy in enemiesFolder:GetChildren() do
				task.spawn(updateEnemy, enemy)
			end
		end
		task.wait(TICK_RATE)
	end
end)