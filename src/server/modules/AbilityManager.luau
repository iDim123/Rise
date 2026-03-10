local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local BuffManager = require(modules:WaitForChild("BuffManager"))
local StatsManager = require(modules:WaitForChild("StatsManager"))

-- Боевые модули из combat/
local combat = ServerScriptService:WaitForChild("combat")
local WeaponUtil = require(combat:WaitForChild("WeaponUtil"))
local DamageCalc = require(combat:WaitForChild("DamageCalc"))
local TargetFinder = require(combat:WaitForChild("TargetFinder"))
local ResourceHit = require(combat:WaitForChild("ResourceHit"))

-- ProjectileManager — ленивая загрузка (создаётся в Шаге 10)
local ProjectileManager
local function getProjectileManager()
    if not ProjectileManager then
        local ok, mod = pcall(function()
            return require(combat:WaitForChild("ProjectileManager", 2))
        end)
        if ok then
            ProjectileManager = mod
        end
    end
    return ProjectileManager
end

local AbilityManager = {}
local abilityCooldowns = {} -- [userId] = { [abilityId] = lastUseTime }

local function flatDirection(from, to)
    local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
    if dir.Magnitude < 0.001 then
        return Vector3.new(0, 0, 1)
    end
    return dir.Unit
end

-- ═══════════════════════════════════════════════════════════
-- Основная точка входа
-- ═══════════════════════════════════════════════════════════

function AbilityManager.useAbility(player, key, mousePosition)
    if type(key) ~= "string" then
        return
    end
    if key ~= "Q" and key ~= "E" then
        return
    end

    local character = player.Character
    if not character then
        return
    end
    if character:GetAttribute("IsDead") then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    local weaponConfig = WeaponUtil.getConfig(player)
    if not weaponConfig then
        return
    end

    local ability = weaponConfig.Abilities and weaponConfig.Abilities[key]
    if not ability then
        return
    end

    -- ── Cooldown с учётом CD speed стата ──────────────────
    local userId = player.UserId
    if not abilityCooldowns[userId] then
        abilityCooldowns[userId] = {}
    end
    local lastUse = abilityCooldowns[userId][ability.Id] or 0
    local now = os.clock()

    local cdSpeed
    if ability.DamageType == "Magic" then
        cdSpeed = StatsManager.get(player, "MagicCDSpeed")
    else
        cdSpeed = StatsManager.get(player, "WeaponCDSpeed")
    end
    local actualCooldown = ability.Cooldown / math.max(cdSpeed, 0.1)
    if now - lastUse < actualCooldown then
        return
    end

    -- ── Применение эффектов ───────────────────────────────
    for _, effect in ability.Effects do
        if effect.Type == "DirectDamage" then
            AbilityManager._directDamage(player, character, rootPart, mousePosition, effect, weaponConfig)
            ResourceHit.hitInRadius(player, rootPart, weaponConfig.Range or 6, weaponConfig)

        elseif effect.Type == "AoEDamage" then
            AbilityManager._aoeDamage(player, character, rootPart, effect)
            ResourceHit.hitInRadius(player, rootPart, effect.Radius or 8, weaponConfig)

        elseif effect.Type == "ApplyBuff" then
            BuffManager.applyBuff(character, effect.BuffId, effect.Duration, ability.Id)

        elseif effect.Type == "ApplyDebuff" then
            AbilityManager._applyDebuffToTargets(character, rootPart, effect, weaponConfig)

        elseif effect.Type == "Projectile" then
            AbilityManager._fireProjectile(player, character, rootPart, mousePosition, effect, ability)

        elseif effect.Type == "AoEProjectile" then
            AbilityManager._fireAoEProjectile(player, rootPart, mousePosition, effect, ability)
        end
    end

    abilityCooldowns[userId][ability.Id] = now
    Remotes.AbilityCooldown:FireClient(player, key, actualCooldown)

    print("[Ability] " .. player.Name .. " used " .. ability.Name .. " (" .. key .. ")")
end

-- ═══════════════════════════════════════════════════════════
-- DirectDamage — ближайшая цель в конусе
-- ═══════════════════════════════════════════════════════════

function AbilityManager._directDamage(player, character, rootPart, mousePosition, effect, weaponConfig)
    local range = weaponConfig.Range or 6
    local direction = flatDirection(rootPart.Position, mousePosition)

    local target = TargetFinder.closestInCone(rootPart.Position, direction, range, 0.3, character)

    if target then
        local finalDamage = DamageCalc.calculate({
            player = player,
            target = target,
            baseDamage = effect.Damage,
            damageType = effect.DamageType or "Physical"
        })
        HealthManager.takeDamage(target, finalDamage, character)
    end
end

-- ═══════════════════════════════════════════════════════════
-- AoEDamage — все цели в радиусе
-- ═══════════════════════════════════════════════════════════

function AbilityManager._aoeDamage(player, character, rootPart, effect)
    local radius = effect.Radius or 8
    local targets = TargetFinder.inRadius(rootPart.Position, radius, character)

    for _, target in targets do
        local finalDamage = DamageCalc.calculate({
            player = player,
            target = target,
            baseDamage = effect.Damage,
            damageType = effect.DamageType or "Physical"
        })
        HealthManager.takeDamage(target, finalDamage, character)
    end
end

-- ═══════════════════════════════════════════════════════════
-- ApplyDebuff — все цели в радиусе
-- ═══════════════════════════════════════════════════════════

function AbilityManager._applyDebuffToTargets(character, rootPart, effect, weaponConfig)
    local range = effect.Radius or weaponConfig.Range or 6
    local targets = TargetFinder.inRadius(rootPart.Position, range, character)

    for _, target in targets do
        BuffManager.applyBuff(target, effect.BuffId, effect.Duration, "ability")
    end
end

-- ═══════════════════════════════════════════════════════════
-- Projectile — одиночный снаряд (Q лука: Мощный выстрел)
-- ═══════════════════════════════════════════════════════════

function AbilityManager._fireProjectile(player, character, rootPart, mousePosition, effect, ability)
    local pm = getProjectileManager()
    if not pm then
        warn("[AbilityManager] ProjectileManager not available")
        return
    end

    local dir = flatDirection(rootPart.Position, mousePosition)

    pm.fire({
        owner = player,
        origin = rootPart.Position + dir * 2,
        direction = dir,
        projectileId = effect.ProjectileId,
        baseDamage = effect.Damage,
        damageType = ability.DamageType or "Physical",
        pierceCount = effect.PierceCount
    })
end

-- ═══════════════════════════════════════════════════════════
-- AoEProjectile — дождь снарядов (E лука: Дождь стрел)
-- ═══════════════════════════════════════════════════════════

function AbilityManager._fireAoEProjectile(player, rootPart, mousePosition, effect, ability)
    local pm = getProjectileManager()
    if not pm then
        warn("[AbilityManager] ProjectileManager not available")
        return
    end

    local count = effect.Count or 8
    local radius = effect.Radius or 12
    local spawnHeight = effect.SpawnHeight or 40

    -- mousePosition = центр области на земле
    local centerGround = Vector3.new(mousePosition.X, rootPart.Position.Y, mousePosition.Z)

    for i = 1, count do
        local offsetX = (math.random() - 0.5) * 2 * radius
        local offsetZ = (math.random() - 0.5) * 2 * radius
        local spawnPos = centerGround + Vector3.new(offsetX, spawnHeight, offsetZ)

        -- Небольшой временной разброс для визуального эффекта
        task.defer(function()
            task.wait(math.random() * 0.3)
            pm.fire({
                owner = player,
                origin = spawnPos,
                direction = Vector3.new(0, -1, 0),
                projectileId = effect.ProjectileId,
                baseDamage = effect.Damage,
                damageType = ability.DamageType or "Physical"
            })
        end)
    end
end

-- ═══════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════

Players.PlayerRemoving:Connect(function(player)
    abilityCooldowns[player.UserId] = nil
end)

return AbilityManager
