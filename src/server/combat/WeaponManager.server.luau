local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local BloodManager = require(modules:WaitForChild("BloodManager"))
local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local BuffManager = require(modules:WaitForChild("BuffManager"))
local ResourceManager = require(modules:WaitForChild("ResourceManager"))

local weaponsFolder = ServerStorage:WaitForChild("weapons")

local attackCooldowns = {}

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        character:WaitForChild("Humanoid")
        attackCooldowns[player.UserId] = 0
    end)
end)

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

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    -- Определяем оружие динамически
    local weaponConfig, weaponItem = getWeaponConfig(player)
    if not weaponConfig then return end

    -- Кулдаун
    local now = tick()
    local lastAttack = attackCooldowns[player.UserId] or 0
    if now - lastAttack < weaponConfig.Cooldown then return end
    attackCooldowns[player.UserId] = now

    -- Комбо и урон
    local comboConfig = weaponConfig.Combo
    comboIndex = math.clamp(comboIndex or 1, 1, #comboConfig)
    local attackDamage = comboConfig[comboIndex].Damage
    local attackRange = weaponConfig.Range

    -- Бафф крови
 	local buffs = BloodManager.getBuffs(player)
    if buffs.DamageBonus then
        attackDamage = attackDamage * (1 + buffs.DamageBonus)
    end

    -- Баффы от BuffManager
    local dmgBonus = BuffManager.getStatModifier(character, "DamageBonus")
    if dmgBonus > 0 then
        attackDamage = attackDamage * (1 + dmgBonus)
    end

    -- Округляем после всех бонусов
    attackDamage = math.floor(attackDamage)

 	local mouseDirection = (mousePosition - rootPart.Position).Unit
    mouseDirection = Vector3.new(mouseDirection.X, 0, mouseDirection.Z).Unit

    for _, target in getTargets(character) do
        local targetRoot = target:FindFirstChild("HumanoidRootPart")
        if not targetRoot then continue end

        local distance = (targetRoot.Position - rootPart.Position).Magnitude

        if distance <= attackRange then
            local directionToTarget = (targetRoot.Position - rootPart.Position).Unit
            local dot = directionToTarget:Dot(mouseDirection)
            if dot > 0.3 then
                -- DamageReduction на цели
                local dmgReduction = BuffManager.getStatModifier(target, "DamageReduction")
                local finalDamage = math.floor(attackDamage * (1 - dmgReduction))
                finalDamage = math.max(1, finalDamage)
                HealthManager.takeDamage(target, finalDamage, character)
            end
        end
    end

	-- ═══ Resource node hit ═══
    local resourceDamage = weaponConfig.ResourceDamage or 0
    if resourceDamage > 0 then
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
                    -- Horizontal distance only (ignore Y)
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

Players.PlayerRemoving:Connect(function(player)
    attackCooldowns[player.UserId] = nil
end)

Remotes.UseAbility.OnServerEvent:Connect(function(player, key, mousePosition)
    AbilityManager.useAbility(player, key, mousePosition)
end)