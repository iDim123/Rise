local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local BloodManager = require(modules:WaitForChild("BloodManager"))

local weaponsFolder = ServerStorage:WaitForChild("weapons")

local attackCooldowns = {}

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        character:WaitForChild("Humanoid")
        attackCooldowns[player.UserId] = 0
    end)
end)

local function getTargets(attacker)
	local targets = {}

	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if not enemiesFolder then return targets end

	for _, enemy in enemiesFolder:GetChildren() do
		if enemy:FindFirstChild("Humanoid") and enemy:FindFirstChild("HumanoidRootPart") then
			table.insert(targets, enemy)
		end
	end

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character ~= attacker then
			if character:FindFirstChild("Humanoid") and character:FindFirstChild("HumanoidRootPart") then
				table.insert(targets, character)
			end
		end
	end

	return targets
end

Remotes.AttackRequest.OnServerEvent:Connect(function(player, mousePosition, comboIndex)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local now = tick()
	local lastAttack = attackCooldowns[player.UserId] or 0
	if now - lastAttack < Config.Weapons.Sword.Cooldown then return end
	attackCooldowns[player.UserId] = now

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Получаем урон из комбо
	local comboConfig = Config.Weapons.Sword.Combo
	comboIndex = math.clamp(comboIndex or 1, 1, #comboConfig)
	local attackDamage = comboConfig[comboIndex].Damage
	local attackRange = Config.Weapons.Sword.Range

	local buffs = BloodManager.getBuffs(player)
	if buffs.DamageBonus then
		attackDamage = attackDamage * (1 + buffs.DamageBonus)
		attackDamage = math.floor(attackDamage)
	end
		

	for _, target in getTargets(character) do
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if not targetRoot then continue end

		local distance = (targetRoot.Position - rootPart.Position).Magnitude

		if distance <= attackRange then
			local directionToTarget = (targetRoot.Position - rootPart.Position).Unit
			local attackDirection = (mousePosition - rootPart.Position).Unit
			attackDirection = Vector3.new(attackDirection.X, 0, attackDirection.Z).Unit

			local dot = directionToTarget:Dot(attackDirection)
			if dot > 0.3 then
				HealthManager.takeDamage(target, attackDamage, character)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	attackCooldowns[player.UserId] = nil
end)