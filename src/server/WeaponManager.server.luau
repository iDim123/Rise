local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local weaponsFolder = ServerStorage:WaitForChild("weapons")

-- Хранилище кулдаунов атак
local attackCooldowns = {}

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")

		-- Выдаём меч
		local sword = weaponsFolder:WaitForChild("SwordOfLight"):Clone()
		sword.Parent = player.Backpack

		-- Сбрасываем кулдаун
		attackCooldowns[player.UserId] = 0
	end)
end)

-- Обработка атаки
Remotes.AttackRequest.OnServerEvent:Connect(function(player, mousePosition)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- Проверка кулдауна
	local now = tick()
	local lastAttack = attackCooldowns[player.UserId] or 0
	if now - lastAttack < Config.Weapons.Sword.Cooldown then return end
	attackCooldowns[player.UserId] = now

	-- Проверяем что меч экипирован
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Серверный хитбокс: ищем врагов в радиусе атаки
	local attackRange = Config.Weapons.Sword.Range
	local attackDamage = Config.Weapons.Sword.Damage

	for _, target in workspace:GetChildren() do
		if target == character then continue end
		if not target:FindFirstChild("Humanoid") then continue end
		if not target:FindFirstChild("HumanoidRootPart") then continue end

		local distance = (target.HumanoidRootPart.Position - rootPart.Position).Magnitude

		if distance <= attackRange then
			-- Проверяем что цель перед игроком (в направлении мыши)
			local directionToTarget = (target.HumanoidRootPart.Position - rootPart.Position).Unit
			local attackDirection = (mousePosition - rootPart.Position).Unit
			attackDirection = Vector3.new(attackDirection.X, 0, attackDirection.Z).Unit

			local dot = directionToTarget:Dot(attackDirection)
			if dot > 0.3 then -- цель примерно в направлении атаки
				-- Загружаем HealthManager и наносим урон
				local HealthManager = require(script.Parent:WaitForChild("HealthManager"))
				HealthManager.takeDamage(target, attackDamage, character)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	attackCooldowns[player.UserId] = nil
end)