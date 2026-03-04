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
                -- DamageReduction на цели
                local dmgReduction = BuffManager.getStatModifier(target, "DamageReduction")
                local finalDamage = math.floor(attackDamage * (1 - dmgReduction))
                finalDamage = math.max(1, finalDamage)
                HealthManager.takeDamage(target, finalDamage, character)
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    attackCooldowns[player.UserId] = nil
end)