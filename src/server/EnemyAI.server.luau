local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local HealthManager = require(script.Parent:WaitForChild("HealthManager"))

local TICK_RATE = 0.2

-- Состояния AI
local STATE_IDLE = "Idle"
local STATE_PATROL = "Patrol"
local STATE_CHASE = "Chase"
local STATE_ATTACK = "Attack"
local STATE_RETURN = "Return"

-- Хранилище состояний врагов
local enemyStates = {}

local function getEnemyState(enemy)
	if not enemyStates[enemy] then
		enemyStates[enemy] = {
			State = STATE_IDLE,
			PatrolTarget = nil,
			IdleTimer = 0,
			LastAttack = 0,
		}
	end
	return enemyStates[enemy]
end

-- Случайная точка патруля вокруг спавна
local function getRandomPatrolPoint(spawnPos, radius)
	local angle = math.random() * math.pi * 2
	local dist = math.random() * radius
	return Vector3.new(
		spawnPos.X + math.cos(angle) * dist,
		spawnPos.Y,
		spawnPos.Z + math.sin(angle) * dist
	)
end

-- Найти ближайшего живого игрока в радиусе
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
	if not spawnPos then return end

	local position = rootPart.Position
	local state = getEnemyState(enemy)

	-- Расстояние до точки спавна
	local distToSpawn = (position - spawnPos).Magnitude

	-- Ищем игрока
	local target, distToTarget = findNearestPlayer(position, config.AggroRange)

	-- Если слишком далеко от спавна — возвращаемся
	local maxChaseRange = config.AggroRange * 2
	if distToSpawn > maxChaseRange then
		state.State = STATE_RETURN
		target = nil
	end

	-- === СОСТОЯНИЯ ===

	if target then
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if not targetRoot then return end

		if distToTarget <= config.AttackRange then
			-- АТАКА
			state.State = STATE_ATTACK
			humanoid:MoveTo(rootPart.Position) -- остановиться

			-- Повернуться к цели
			local dir = (targetRoot.Position - rootPart.Position).Unit
			rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + Vector3.new(dir.X, 0, dir.Z))

			-- Проверяем кулдаун
			local now = tick()
			if now - state.LastAttack >= config.AttackCooldown then
				state.LastAttack = now
				HealthManager.takeDamage(target, config.Damage, enemy)
			end
		else
			-- ПРЕСЛЕДОВАНИЕ
			state.State = STATE_CHASE
			humanoid.WalkSpeed = config.WalkSpeed * 1.2 -- чуть быстрее при погоне
			humanoid:MoveTo(targetRoot.Position)
		end

	elseif state.State == STATE_RETURN then
		-- ВОЗВРАТ на точку спавна
		humanoid.WalkSpeed = config.WalkSpeed
		humanoid:MoveTo(spawnPos)

		if distToSpawn < 3 then
			state.State = STATE_IDLE
			state.IdleTimer = tick()
		end

	elseif state.State == STATE_IDLE then
		-- ПОКОЙ — стоим на месте, через пару секунд идём патрулировать
		humanoid.WalkSpeed = 0

		if tick() - state.IdleTimer > math.random(2, 5) then
			state.State = STATE_PATROL
			local patrolRadius = config.AggroRange * 0.4
			state.PatrolTarget = getRandomPatrolPoint(spawnPos, patrolRadius)
		end

	elseif state.State == STATE_PATROL then
		-- ПАТРУЛЬ — идём к случайной точке
		humanoid.WalkSpeed = config.WalkSpeed * 0.5 -- медленнее при патруле

		if state.PatrolTarget then
			humanoid:MoveTo(state.PatrolTarget)

			local distToPatrol = (position - state.PatrolTarget).Magnitude
			if distToPatrol < 3 then
				state.State = STATE_IDLE
				state.IdleTimer = tick()
			end
		else
			state.State = STATE_IDLE
			state.IdleTimer = tick()
		end

	else
		-- По умолчанию — idle
		state.State = STATE_IDLE
		state.IdleTimer = tick()
	end
end

-- Очистка при уничтожении врага
local function onEnemyRemoved(enemy)
	enemyStates[enemy] = nil
end

-- Главный цикл AI
task.spawn(function()
	while true do
		local enemiesFolder = workspace:FindFirstChild("Enemies")
		if enemiesFolder then
			-- Подписка на удаление
			for _, enemy in enemiesFolder:GetChildren() do
				if not enemyStates[enemy] then
					enemy.Destroying:Connect(function()
						onEnemyRemoved(enemy)
					end)
				end
				task.spawn(updateEnemy, enemy)
			end
		end
		task.wait(TICK_RATE)
	end
end)