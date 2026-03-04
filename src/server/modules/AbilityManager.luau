local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local BuffManager = require(modules:WaitForChild("BuffManager"))
local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local ResourceManager = require(modules:WaitForChild("ResourceManager"))

local AbilityManager = {}
local abilityCooldowns = {} -- [userId] = { [abilityId] = lastUseTime }

function AbilityManager.getWeaponConfig(player)
    local inv = InventoryManager.getInventory(player)
    if not inv then return nil end
    local slot = inv.slots[inv.activeWeaponSlot]
    if not slot or slot == false then return nil end
    return Config.Weapons[slot.Id]
end

function AbilityManager.useAbility(player, key, mousePosition)
    if type(key) ~= "string" then return end
    if key ~= "Q" and key ~= "E" then return end

    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    -- Get weapon and ability config
    local weaponConfig = AbilityManager.getWeaponConfig(player)
    if not weaponConfig then return end
    local ability = weaponConfig.Abilities and weaponConfig.Abilities[key]
    if not ability then return end

    -- Check cooldown
    local userId = player.UserId
    if not abilityCooldowns[userId] then abilityCooldowns[userId] = {} end
    local lastUse = abilityCooldowns[userId][ability.Id] or 0
    local now = tick()
    if now - lastUse < ability.Cooldown then return end

    -- Apply effects
    for _, effect in ability.Effects do
        if effect.Type == "DirectDamage" then
            AbilityManager._directDamage(character, rootPart, mousePosition, effect, weaponConfig)
            AbilityManager._hitResourceNodes(character, rootPart, effect, weaponConfig)
        elseif effect.Type == "AoEDamage" then
            AbilityManager._aoeDamage(character, rootPart, effect)
            AbilityManager._hitResourceNodes(character, rootPart, effect, weaponConfig)
        elseif effect.Type == "ApplyBuff" then
            BuffManager.applyBuff(character, effect.BuffId, effect.Duration, ability.Id)

        elseif effect.Type == "ApplyDebuff" then
            AbilityManager._applyDebuffToTargets(character, rootPart, mousePosition, effect, weaponConfig)
        end
    end

    -- Start cooldown
    abilityCooldowns[userId][ability.Id] = now
    Remotes.AbilityCooldown:FireClient(player, key, ability.Cooldown)

    print("[Ability] " .. player.Name .. " used " .. ability.Name .. " (" .. key .. ")")
end

function AbilityManager._getEnemiesInRadius(position, radius)
    local targets = {}
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, enemy in enemiesFolder:GetChildren() do
            local eRoot = enemy:FindFirstChild("HumanoidRootPart")
            local eHum = enemy:FindFirstChildOfClass("Humanoid")
            if eRoot and eHum and eHum.Health > 0 then
                if (eRoot.Position - position).Magnitude <= radius then
                    table.insert(targets, enemy)
                end
            end
        end
    end
    return targets
end

function AbilityManager._getPlayersInRadius(attacker, position, radius)
    local targets = {}
    for _, p in Players:GetPlayers() do
        if p.Character and p.Character ~= attacker then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                if (root.Position - position).Magnitude <= radius then
                    table.insert(targets, p.Character)
                end
            end
        end
    end
    return targets
end

function AbilityManager._directDamage(character, rootPart, mousePosition, effect, weaponConfig)
    local range = weaponConfig.Range or 6
    local direction = (mousePosition - rootPart.Position).Unit
    local targets = {}

    -- Collect enemies
    for _, enemy in AbilityManager._getEnemiesInRadius(rootPart.Position, range) do
        local eRoot = enemy:FindFirstChild("HumanoidRootPart")
        if eRoot then
            local toTarget = (eRoot.Position - rootPart.Position).Unit
            if direction:Dot(toTarget) > 0.3 then
                table.insert(targets, enemy)
            end
        end
    end

    -- Collect players
    for _, target in AbilityManager._getPlayersInRadius(character, rootPart.Position, range) do
        local tRoot = target:FindFirstChild("HumanoidRootPart")
        if tRoot then
            local toTarget = (tRoot.Position - rootPart.Position).Unit
            if direction:Dot(toTarget) > 0.3 then
                table.insert(targets, target)
            end
        end
    end

    -- Apply damage to first target (single target)
    if #targets > 0 then
        local closest = nil
        local closestDist = math.huge
        for _, t in targets do
            local tRoot = t:FindFirstChild("HumanoidRootPart")
            if tRoot then
                local dist = (tRoot.Position - rootPart.Position).Magnitude
                if dist < closestDist then
                    closest = t
                    closestDist = dist
                end
            end
        end
        if closest then
            HealthManager.takeDamage(closest, effect.Damage, character)
        end
    end
end

function AbilityManager._aoeDamage(character, rootPart, effect)
    local radius = effect.Radius or 8
    local targets = AbilityManager._getEnemiesInRadius(rootPart.Position, radius)
    for _, target in AbilityManager._getPlayersInRadius(character, rootPart.Position, radius) do
        table.insert(targets, target)
    end

    for _, target in targets do
        HealthManager.takeDamage(target, effect.Damage, character)
    end
end

function AbilityManager._applyDebuffToTargets(character, rootPart, mousePosition, effect, weaponConfig)
    local range = effect.Radius or weaponConfig.Range or 6
    local targets = AbilityManager._getEnemiesInRadius(rootPart.Position, range)
    for _, target in AbilityManager._getPlayersInRadius(character, rootPart.Position, range) do
        table.insert(targets, target)
    end

    for _, target in targets do
        BuffManager.applyBuff(target, effect.BuffId, effect.Duration, "ability")
    end
end

function AbilityManager._hitResourceNodes(character, rootPart, effect, weaponConfig)
    local resourcesFolder = workspace:FindFirstChild("Resources")
    if not resourcesFolder then return end

    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    local resourceDamage = weaponConfig.ResourceDamage or 0
    if resourceDamage <= 0 then return end

    local radius = effect.Radius or weaponConfig.Range or 8

    for _, node in resourcesFolder:GetChildren() do
        if not node:GetAttribute("NodeType") then continue end

        local closestDist = math.huge
        local parts = {}
        if node:IsA("BasePart") then
            table.insert(parts, node)
        else
            for _, desc in node:GetDescendants() do
                if desc:IsA("BasePart") then table.insert(parts, desc) end
            end
        end

        for _, part in parts do
            local dx = rootPart.Position.X - part.Position.X
            local dz = rootPart.Position.Z - part.Position.Z
            local hDist = math.sqrt(dx * dx + dz * dz)
            if hDist < closestDist then closestDist = hDist end
        end

        if closestDist <= radius then
            ResourceManager.hit(player, node, resourceDamage)
        end
    end
end

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
    abilityCooldowns[player.UserId] = nil
end)

return AbilityManager