local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local HealthManager = require(script.Parent:WaitForChild("HealthManager"))

local weaponsFolder = ServerStorage:WaitForChild("weapons")

local attackCooldowns = {}

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")

		local sword = weaponsFolder:WaitForChild("Sword"):Clone()
		sword.Parent = player.Backpack

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

Remotes.AttackRequest.OnServerEvent:Connect(function(player, mousePosition)
	local character = player.Character
	if not character then print("[Server] No character") return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then print("[Server] No humanoid") return end

	local now = tick()
	local lastAttack = attackCooldowns[player.UserId] or 0
	if now - lastAttack < Config.Weapons.Sword.Cooldown then print("[Server] Cooldown") return end
	attackCooldowns[player.UserId] = now

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then print("[Server] No tool equipped") return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then print("[Server] No rootPart") return end

	local attackRange = Config.Weapons.Sword.Range
	local attackDamage = Config.Weapons.Sword.Damage

	local targets = getTargets(character)

	for _, target in targets do
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