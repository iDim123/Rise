local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local ResourceManager = require(modules:WaitForChild("ResourceManager"))
local AbilityManager = require(modules:WaitForChild("AbilityManager"))
local LevelManager = require(modules:WaitForChild("LevelManager"))
local StatsManager = require(modules:WaitForChild("StatsManager"))
local weaponsFolder = ServerStorage:WaitForChild("weapons")

local attackCooldowns = {}

local function getWeaponConfig(player)
	local inv = InventoryManager.getInventory(player)
	if not inv or not inv.activeWeaponSlot then return nil, nil end

	local weaponItem = inv.slots[inv.activeWeaponSlot]
	if not weaponItem or weaponItem == false then return nil, nil end

	local weaponConfig = Config.Weapons[weaponItem.Id]
	if not weaponConfig then return nil, nil end

	return weaponConfig, weaponItem
end

local function getTargets(attacker)
	local targets = {}

	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if enemiesFolder then
		for _, enemy in enemiesFolder:GetChildren() do
			if enemy:FindFirstChild("Humanoid") and enemy:FindFirstChild("HumanoidRootPart") then
				table.insert(targets, enemy)
			end
		end
	end

	for _, p in Players:GetPlayers() do
		local character = p.Character
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

    if character:GetAttribute("IsDead") then return end 

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local weaponConfig, weaponItem = getWeaponConfig(player)
    if not weaponConfig then return end

    -- Single cooldown check
    local now = tick()
    local lastAttack = attackCooldowns[player.UserId] or 0
    local attackSpeed = StatsManager.get(player, "AttackSpeed")
    local actualCooldown = weaponConfig.Cooldown / math.max(attackSpeed, 0.1)
    if now - lastAttack < actualCooldown then return end
    attackCooldowns[player.UserId] = now

	-- ═══ Комбо и базовый урон ═══
	local comboConfig = weaponConfig.Combo
	comboIndex = math.clamp(comboIndex or 1, 1, #comboConfig)
	local baseDamage = comboConfig[comboIndex].Damage
	local attackRange = weaponConfig.Range

	-- ═══ Physical Power scaling (base = 10) ═══
	local physPower = StatsManager.get(player, "PhysicalPower")
	local attackDamage = baseDamage * (physPower / 10)

	-- ═══ Крит ═══
	local critChance = StatsManager.get(player, "PhysCritChance")
	local critDamage = StatsManager.get(player, "PhysCritDamage")
	local isCrit = math.random() < critChance

	if isCrit then
		attackDamage = attackDamage * critDamage
	end

	-- ═══ Направление атаки ═══
	local mouseDirection = (mousePosition - rootPart.Position).Unit
	mouseDirection = Vector3.new(mouseDirection.X, 0, mouseDirection.Z).Unit

	-- ═══ Поиск целей ═══
	for _, target in getTargets(character) do
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if not targetRoot then continue end

		local distance = (targetRoot.Position - rootPart.Position).Magnitude

		if distance <= attackRange then
			local directionToTarget = (targetRoot.Position - rootPart.Position).Unit
			local dot = directionToTarget:Dot(mouseDirection)

			if dot > 0.3 then
				-- Level damage modifier
				local playerLevel = LevelManager.getPlayerLevel(player)
				local targetLevel = target:GetAttribute("Level") or target:GetAttribute("EnemyLevel") or playerLevel
				local dmgMod = LevelManager.getDamageModifier(playerLevel, targetLevel)
				local modifiedDamage = attackDamage * (1 + dmgMod)

				-- Physical Resistance цели
				local targetResist = target:GetAttribute("PhysResistance") or 0
				local finalDamage = math.max(1, math.floor(modifiedDamage * (1 - targetResist / 100)))

				HealthManager.takeDamage(target, finalDamage, character)

				-- Mark combat for regen timer
				StatsManager.markCombat(target)
			end
		end
	end

	-- ═══ Resource node hit ═══
	local resourceDamage = weaponConfig.ResourceDamage or 0
	if resourceDamage > 0 then
		-- ResourceDamage stat modifier
		local resDmgMod = StatsManager.get(player, "ResourceDamage")
		resourceDamage = math.max(1, math.floor(resourceDamage * resDmgMod))

		local resourcesFolder = workspace:FindFirstChild("Resources")
		if resourcesFolder then
			for _, node in resourcesFolder:GetChildren() do
				if not node:GetAttribute("NodeType") then continue end

				-- Find nearest BasePart for distance check
				local closestPart = nil
				local closestDist = math.huge
				local parts = {}
				if node:IsA("BasePart") then
					table.insert(parts, node)
				else
					for _, desc in node:GetDescendants() do
						if desc:IsA("BasePart") then
							table.insert(parts, desc)
						end
					end
				end

				for _, part in parts do
					local partPos = part.Position
					local dx = rootPart.Position.X - partPos.X
					local dz = rootPart.Position.Z - partPos.Z
					local hDist = math.sqrt(dx * dx + dz * dz)
					if hDist < closestDist then
						closestDist = hDist
						closestPart = part
					end
				end

				if closestPart and closestDist <= weaponConfig.Range + 2 then
					local toNode = (closestPart.Position - rootPart.Position)
					toNode = Vector3.new(toNode.X, 0, toNode.Z).Unit
					local dot = mouseDirection:Dot(toNode)
					if dot > 0.3 then
						ResourceManager.hit(player, node, resourceDamage)
						break
					end
				end
			end
		end
	end
end)

Remotes.UseAbility.OnServerEvent:Connect(function(player, key, mousePosition)
	AbilityManager.useAbility(player, key, mousePosition)
end)