local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local modules = ServerScriptService:WaitForChild("modules")
local combat = ServerScriptService:WaitForChild("combat")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local BuffManager = require(modules:WaitForChild("BuffManager"))
local StatsManager = require(modules:WaitForChild("StatsManager"))
local CastManager = require(modules:WaitForChild("CastManager"))
local SpellProgressManager = require(modules:WaitForChild("SpellProgressManager"))
local DamageCalc = require(combat:WaitForChild("DamageCalc"))
local TargetFinder = require(combat:WaitForChild("TargetFinder"))

-- Lazy loads
local ProjectileManager
local function getProjectileManager()
    if not ProjectileManager then
        local ok, mod = pcall(function()
            return require(combat:WaitForChild("ProjectileManager", 2))
        end)
        if ok then ProjectileManager = mod end
    end
    return ProjectileManager
end

local SpellCastManager = {}

-- ═══ State ═══
local spellCooldowns = {}   -- [userId] = { [spellId] = lastUseTime }
local spellCharges = {}     -- [userId] = { [spellId] = { charges = N, lastRecharge = tick() } }
local activeChannels = {}   -- [userId] = { spellId, task, startTime }

-- ═══ Helpers ═══

local function flatDirection(from, to)
    local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
    if dir.Magnitude < 0.001 then
        return Vector3.new(0, 0, 1)
    end
    return dir.Unit
end

local function getSpellPower(player)
    return StatsManager.get(player, "MagicalPower") or 1.0
end

local function validateCaster(player)
    local character = player.Character
    if not character then return nil, nil, nil end
    if character:GetAttribute("IsDead") then return nil, nil, nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil, nil, nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil, nil, nil end
    return character, humanoid, rootPart
end

-- ═══════════════════════════════════════════════════════════
-- Cooldown & Charges
-- ═══════════════════════════════════════════════════════════

local function isOnCooldown(player, spellConfig)
    local userId = player.UserId
    local spellId = spellConfig.Id

    -- Charge-based spells
    if spellConfig.MaxCharges then
        local chargeData = spellCharges[userId] and spellCharges[userId][spellId]
        if not chargeData then return false end
        return chargeData.charges <= 0
    end

    -- Normal cooldown
    if not spellCooldowns[userId] then return false end
    local lastUse = spellCooldowns[userId][spellId] or 0
    local cdSpeed = StatsManager.get(player, "MagicCDSpeed") or 1
    local actualCd = spellConfig.Cooldown / math.max(cdSpeed, 0.1)
    return (tick() - lastUse) < actualCd
end

local function applyCooldown(player, spellConfig)
    local userId = player.UserId
    local spellId = spellConfig.Id

    if spellConfig.MaxCharges then
        -- Charge system
        if not spellCharges[userId] then spellCharges[userId] = {} end
        local chargeData = spellCharges[userId][spellId]
        if not chargeData then
            chargeData = { charges = spellConfig.MaxCharges, lastRecharge = tick() }
            spellCharges[userId][spellId] = chargeData
        end
        chargeData.charges = math.max(0, chargeData.charges - 1)
        Remotes.SpellChargeUpdate:FireClient(player, spellId, chargeData.charges, spellConfig.MaxCharges)

        -- Start recharge if not full
        if chargeData.charges < spellConfig.MaxCharges then
            local cdSpeed = StatsManager.get(player, "MagicCDSpeed") or 1
            local rechargeTime = (spellConfig.ChargeRechargeTime or spellConfig.Cooldown) / math.max(cdSpeed, 0.1)
            Remotes.SpellCooldown:FireClient(player, spellId, rechargeTime)
        end
    else
        -- Normal cooldown
        if not spellCooldowns[userId] then spellCooldowns[userId] = {} end
        spellCooldowns[userId][spellId] = tick()
        local cdSpeed = StatsManager.get(player, "MagicCDSpeed") or 1
        local actualCd = spellConfig.Cooldown / math.max(cdSpeed, 0.1)
        Remotes.SpellCooldown:FireClient(player, spellId, actualCd)
    end
end

-- ═══════════════════════════════════════════════════════════
-- Charge recharge loop
-- ═══════════════════════════════════════════════════════════

task.spawn(function()
    while true do
        task.wait(0.5)
        for userId, spells in spellCharges do
            local player = Players:GetPlayerByUserId(userId)
            if not player then continue end
            for spellId, chargeData in spells do
                local spellConfig = Config.Spells[spellId]
                if not spellConfig or not spellConfig.MaxCharges then continue end
                if chargeData.charges >= spellConfig.MaxCharges then continue end

                local cdSpeed = StatsManager.get(player, "MagicCDSpeed") or 1
                local rechargeTime = (spellConfig.ChargeRechargeTime or spellConfig.Cooldown) / math.max(cdSpeed, 0.1)
                if (tick() - chargeData.lastRecharge) >= rechargeTime then
                    chargeData.charges = math.min(chargeData.charges + 1, spellConfig.MaxCharges)
                    chargeData.lastRecharge = tick()
                    Remotes.SpellChargeUpdate:FireClient(player, spellId, chargeData.charges, spellConfig.MaxCharges)
                    if chargeData.charges < spellConfig.MaxCharges then
                        Remotes.SpellCooldown:FireClient(player, spellId, rechargeTime)
                    end
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- Main entry: castSpell
-- ═══════════════════════════════════════════════════════════

function SpellCastManager.castSpell(player, spellId, mousePosition)
    local character, humanoid, rootPart = validateCaster(player)
    if not character then return end

    -- Check spell is equipped
    local equippedSlots = SpellProgressManager.getEquippedSlots(player)
    local isEquipped = false
    for _, equipped in equippedSlots do
        if equipped == spellId then isEquipped = true break end
    end
    if not isEquipped then return end

    local spellConfig = Config.Spells[spellId]
    if not spellConfig then return end

    -- Cooldown check
    if isOnCooldown(player, spellConfig) then return end

    -- Already channelling?
    if activeChannels[player.UserId] then return end

    -- Already casting?
    if CastManager.isActive(player) then return end

    -- Cast time
    if spellConfig.CastTime and spellConfig.CastTime > 0.05 then
        local castId = CastManager.start(player, {
            Duration = spellConfig.CastTime,
            Label = spellConfig.Name,
            MovementMode = spellConfig.CastMovementMode or "Free",
            SpeedMult = spellConfig.CastSpeedMult or 0.5,
            CancelOnStun = true,
            CancelOnDamage = false,
            OnComplete = function()
                SpellCastManager._executeSpell(player, spellConfig, mousePosition)
            end,
            OnCancel = function(_, reason)
                -- No cooldown on cancel
            end,
        })
        if not castId then return end
    else
        -- Instant cast
        SpellCastManager._executeSpell(player, spellConfig, mousePosition)
    end
end

-- ═══════════════════════════════════════════════════════════
-- Execute spell effects
-- ═══════════════════════════════════════════════════════════

function SpellCastManager._executeSpell(player, spellConfig, mousePosition)
    local character, humanoid, rootPart = validateCaster(player)
    if not character then return end

    applyCooldown(player, spellConfig)

    for _, effect in spellConfig.Effects do
        local handler = SpellCastManager._effectHandlers[effect.Type]
        if handler then
            handler(player, character, rootPart, mousePosition, effect, spellConfig)
        else
            warn("[SpellCastManager] Unknown effect type: " .. tostring(effect.Type))
        end
    end

    print("[Spell] " .. player.Name .. " cast " .. spellConfig.Name)
end

-- ═══════════════════════════════════════════════════════════
-- Effect handlers
-- ═══════════════════════════════════════════════════════════

SpellCastManager._effectHandlers = {}

-- AoEHeal: heal allies in radius
SpellCastManager._effectHandlers["AoEHeal"] = function(player, character, rootPart, mousePosition, effect, spellConfig)
    local radius = effect.Radius or 10
    local spellPower = getSpellPower(player)
    local healAmount = math.floor(spellPower * (effect.HealPercent or 0.5) * 100)

    -- Heal self
    HealthManager.heal(character, healAmount)

    -- Heal nearby players and servants
    for _, other in Players:GetPlayers() do
        if other == player then continue end
        local otherChar = other.Character
        if not otherChar then continue end
        local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
        if not otherRoot then continue end
        if (otherRoot.Position - rootPart.Position).Magnitude <= radius then
            HealthManager.heal(otherChar, healAmount)
        end
    end

    Remotes.SpellEffect:FireAllClients("AoEHeal", rootPart.Position, { Radius = radius })
end

-- AoEBuff: apply buffs to allies in radius
SpellCastManager._effectHandlers["AoEBuff"] = function(player, character, rootPart, mousePosition, effect, spellConfig)
    local radius = effect.Radius or 10

    local targets = { character }
    for _, other in Players:GetPlayers() do
        if other == player then continue end
        local otherChar = other.Character
        if not otherChar then continue end
        local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
        if not otherRoot then continue end
        if (otherRoot.Position - rootPart.Position).Magnitude <= radius then
            table.insert(targets, otherChar)
        end
    end

    for _, target in targets do
        for _, buff in effect.Buffs do
            BuffManager.applyBuff(target, buff.BuffId, buff.Duration, spellConfig.Id)
        end
    end
end

-- AoEApplyPassive: mark enemies with passive (Leech/Ignite)
SpellCastManager._effectHandlers["AoEApplyPassive"] = function(player, character, rootPart, mousePosition, effect, spellConfig)
    local radius = effect.Radius or 10
    local targets = TargetFinder.inRadius(rootPart.Position, radius, character)
    local passive = SpellProgressManager.getEffectivePassive(player, spellConfig.School)
    local duration = passive and passive.Duration or 5

    for _, target in targets do
        target:SetAttribute("Passive_" .. effect.PassiveId, true)
        target:SetAttribute("Passive_" .. effect.PassiveId .. "_Owner", player.UserId)
        target:SetAttribute("Passive_" .. effect.PassiveId .. "_Expire", tick() + duration)
    end
end

-- Projectile: single projectile
SpellCastManager._effectHandlers["Projectile"] = function(player, character, rootPart, mousePosition, effect, spellConfig)
    local pm = getProjectileManager()
    if not pm then return end

    local dir = flatDirection(rootPart.Position, mousePosition)
    local spellPower = getSpellPower(player)
    local baseDamage = math.floor(spellPower * (effect.DamageMult or 1.0) * 100)

    pm.fire({
        owner = player,
        origin = rootPart.Position + dir * 2,
        direction = dir,
        projectileId = effect.ProjectileId,
        baseDamage = baseDamage,
        damageType = spellConfig.DamageType or "Magic",
        pierceCount = effect.PierceCount,
        onHitEffects = effect.OnHitEffects,
        spellSchool = spellConfig.School,
    })
end

-- MultiProjectile: fan of projectiles
SpellCastManager._effectHandlers["MultiProjectile"] = function(player, character, rootPart, mousePosition, effect, spellConfig)
    local pm = getProjectileManager()
    if not pm then return end

    local baseDir = flatDirection(rootPart.Position, mousePosition)
    local count = effect.Count or 3
    local spreadAngle = effect.SpreadAngle or 25
    local spellPower = getSpellPower(player)
    local baseDamage = math.floor(spellPower * (effect.DamageMult or 1.0) * 100)

    local startAngle = -spreadAngle / 2
    local step = count > 1 and (spreadAngle / (count - 1)) or 0

    for i = 0, count - 1 do
        local angle = math.rad(startAngle + step * i)
        local rotatedDir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(baseDir)
        rotatedDir = Vector3.new(rotatedDir.X, 0, rotatedDir.Z).Unit

        pm.fire({
            owner = player,
            origin = rootPart.Position + rotatedDir * 2,
            direction = rotatedDir,
            projectileId = effect.ProjectileId,
            baseDamage = baseDamage,
            damageType = spellConfig.DamageType or "Magic",
            onHitEffects = effect.OnHitEffects,
            spellSchool = spellConfig.School,
        })
    end
end

-- AoEDamage (used by Block triggered effects too)
SpellCastManager._effectHandlers["AoEDamage"] = function(player, character, rootPart, mousePosition, effect, spellConfig)
    local radius = effect.Radius or 8
    local targets = TargetFinder.inRadius(rootPart.Position, radius, character)
    local spellPower = getSpellPower(player)
    local baseDamage = math.floor(spellPower * (effect.DamageMult or 1.0) * 100)

    for _, target in targets do
        local finalDamage = DamageCalc.calculate({
            player = player,
            target = target,
            baseDamage = baseDamage,
            damageType = spellConfig.DamageType or "Magic",
        })
        HealthManager.takeDamage(target, finalDamage, character)
    end

    Remotes.SpellEffect:FireAllClients("AoEDamage", rootPart.Position, { Radius = radius })
end

-- Block: absorb attacks for duration, trigger effects on block
SpellCastManager._effectHandlers["Block"] = function(player, character, rootPart, mousePosition, effect, spellConfig)
    character:SetAttribute("Blocking", true)
    character:SetAttribute("BlockMelee", effect.BlockMelee or false)
    character:SetAttribute("BlockProjectile", effect.BlockProjectile or false)

    -- Slow during block
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local baseSpeed = humanoid and humanoid.WalkSpeed or 16
    if effect.MovementMode == "Slowed" and humanoid then
        humanoid.WalkSpeed = baseSpeed * (effect.SpeedMult or 0.5)
    end

    local triggered = false
    local blockConn
    blockConn = character:GetAttributeChangedSignal("BlockTriggered"):Connect(function()
        if character:GetAttribute("BlockTriggered") and not triggered then
            triggered = true
            character:SetAttribute("BlockTriggered", false)
            -- Execute OnBlockTriggered effects
            if effect.OnBlockTriggered then
                for _, subEffect in effect.OnBlockTriggered do
                    local handler = SpellCastManager._effectHandlers[subEffect.Type]
                    if handler then
                        handler(player, character, rootPart, mousePosition, subEffect, spellConfig)
                    end
                end
            end
        end
    end)

    task.delay(effect.Duration or 1.5, function()
        character:SetAttribute("Blocking", false)
        character:SetAttribute("BlockMelee", false)
        character:SetAttribute("BlockProjectile", false)
        if humanoid then
            StatsManager.recalculate(player)
        end
        if blockConn then blockConn:Disconnect() end
    end)
end

-- FrontalBlock: directional block with reflect
SpellCastManager._effectHandlers["FrontalBlock"] = function(player, character, rootPart, mousePosition, effect, spellConfig)
    character:SetAttribute("FrontalBlock", true)
    character:SetAttribute("FrontalBlockAngle", effect.BlockAngle or 120)
    character:SetAttribute("FrontalBlockReflect", effect.ReflectPercent or 0)
    character:SetAttribute("FrontalBlockDamageAbsorbed", 0)

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if effect.MovementMode == "Slowed" and humanoid then
        local baseSpeed = humanoid.WalkSpeed
        humanoid.WalkSpeed = baseSpeed * (effect.SpeedMult or 0.4)
    end

    task.delay(effect.Duration or 2, function()
        local absorbed = character:GetAttribute("FrontalBlockDamageAbsorbed") or 0
        character:SetAttribute("FrontalBlock", false)
        character:SetAttribute("FrontalBlockAngle", nil)
        character:SetAttribute("FrontalBlockReflect", nil)
        character:SetAttribute("FrontalBlockDamageAbsorbed", nil)

        if humanoid then
            StatsManager.recalculate(player)
        end

        -- Reflect damage on expire
        if absorbed > 0 and effect.ReflectPercent and effect.ReflectPercent > 0 then
            local reflectDmg = math.floor(absorbed * effect.ReflectPercent)
            local targets = TargetFinder.inRadius(rootPart.Position, 8, character)
            for _, target in targets do
                HealthManager.takeDamage(target, reflectDmg, character)
            end
            Remotes.SpellEffect:FireAllClients("Reflect", rootPart.Position, { Damage = reflectDmg })
        end
    end)
end

-- Immaterial: invulnerability
SpellCastManager._effectHandlers["Immaterial"] = function(player, character, rootPart, mousePosition, effect, spellConfig)
    character:SetAttribute("Invulnerable", true)
    task.delay(effect.Duration or 1, function()
        character:SetAttribute("Invulnerable", false)
    end)
end

-- Beam: channelled beam (Crimson Beam)
SpellCastManager._effectHandlers["Beam"] = function(player, character, rootPart, mousePosition, effect, spellConfig)
    local userId = player.UserId
    if activeChannels[userId] then return end

    local dir = flatDirection(rootPart.Position, mousePosition)
    local duration = effect.Duration or 3
    local tickRate = effect.TickRate or 0.25
    local range = effect.Range or 30
    local width = effect.Width or 3
    local spellPower = getSpellPower(player)

    -- Slow caster
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if effect.MovementMode == "Slowed" and humanoid then
        humanoid.WalkSpeed = humanoid.WalkSpeed * (effect.SpeedMult or 0.3)
    end

    -- Notify clients
    Remotes.BeamStart:FireAllClients(userId, rootPart.Position, dir, {
        Range = range, Width = width, Duration = duration,
        TrailColor = Config.Projectiles and Config.Projectiles.shadowbolt and Config.Projectiles.shadowbolt.TrailColor,
    })

    activeChannels[userId] = { spellId = spellConfig.Id, startTime = tick() }

    local channelTask = task.spawn(function()
        local elapsed = 0
        while elapsed < duration do
            task.wait(tickRate)
            elapsed = elapsed + tickRate

            local char, hum, rp = validateCaster(player)
            if not char then break end

            -- Update direction from current mouse (client sends BeamUpdate)
            local currentDir = dir

            -- Damage enemies in beam path
            local beamEnd = rp.Position + currentDir * range
            local targets = TargetFinder.inRadius(rp.Position, range, char)
            local baseDamage = math.floor(spellPower * (effect.DamageMult or 1.0) * 100 * tickRate / duration)

            for _, target in targets do
                -- Check if target is in beam path (simple distance-to-line check)
                local targetRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")
                if targetRoot then
                    local toTarget = targetRoot.Position - rp.Position
                    local projection = toTarget:Dot(currentDir)
                    if projection > 0 and projection < range then
                        local perpDist = (toTarget - currentDir * projection).Magnitude
                        if perpDist <= width then
                            local finalDamage = DamageCalc.calculate({
                                player = player,
                                target = target,
                                baseDamage = baseDamage,
                                damageType = spellConfig.DamageType or "Magic",
                            })
                            HealthManager.takeDamage(target, finalDamage, char)

                            -- Apply passive
                            if effect.ApplyPassive then
                                target:SetAttribute("Passive_" .. effect.ApplyPassive, true)
                                target:SetAttribute("Passive_" .. effect.ApplyPassive .. "_Owner", userId)
                                local passive = SpellProgressManager.getEffectivePassive(player, spellConfig.School)
                                target:SetAttribute("Passive_" .. effect.ApplyPassive .. "_Expire", tick() + (passive and passive.Duration or 5))
                            end

                            -- Self heal per hit
                            if effect.SelfHealPerHit then
                                local selfHeal = math.floor(spellPower * effect.SelfHealPerHit * 10)
                                HealthManager.heal(char, selfHeal)
                            end
                        end
                    end
                end
            end
        end

        -- Channel ended
        activeChannels[userId] = nil
        Remotes.BeamEnd:FireAllClients(userId)
        if humanoid then
            StatsManager.recalculate(player)
        end
    end)

    activeChannels[userId].task = channelTask
end

-- ChannelledProjectile: burst of projectiles over time (Chaos Barrage)
SpellCastManager._effectHandlers["ChannelledProjectile"] = function(player, character, rootPart, mousePosition, effect, spellConfig)
    local userId = player.UserId
    if activeChannels[userId] then return end

    local pm = getProjectileManager()
    if not pm then return end

    local duration = effect.Duration or 2
    local count = effect.Count or 8
    local interval = duration / count
    local spellPower = getSpellPower(player)
    local baseDamage = math.floor(spellPower * (effect.DamageMult or 1.0) * 100)

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if effect.MovementMode == "Slowed" and humanoid then
        humanoid.WalkSpeed = humanoid.WalkSpeed * (effect.SpeedMult or 0.3)
    end

    activeChannels[userId] = { spellId = spellConfig.Id, startTime = tick() }

    local channelTask = task.spawn(function()
        for i = 1, count do
            local char, hum, rp = validateCaster(player)
            if not char then break end
            if not activeChannels[userId] then break end

            local dir = flatDirection(rp.Position, mousePosition)

            -- Apply slight spread
            local spreadAngle = effect.SpreadAngle or 5
            local angle = math.rad((math.random() - 0.5) * spreadAngle)
            local rotatedDir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(dir)
            rotatedDir = Vector3.new(rotatedDir.X, 0, rotatedDir.Z).Unit

            pm.fire({
                owner = player,
                origin = rp.Position + rotatedDir * 2,
                direction = rotatedDir,
                projectileId = effect.ProjectileId,
                baseDamage = baseDamage,
                damageType = spellConfig.DamageType or "Magic",
                onHitEffects = effect.OnHitEffects,
                spellSchool = spellConfig.School,
            })

            if i < count then
                task.wait(interval)
            end
        end

        activeChannels[userId] = nil
        if humanoid then
            StatsManager.recalculate(player)
        end
    end)

    activeChannels[userId].task = channelTask
end

-- ═══════════════════════════════════════════════════════════
-- Cancel channel (on stun/death/disconnect)
-- ═══════════════════════════════════════════════════════════

function SpellCastManager.cancelChannel(player)
    local userId = player.UserId
    local channel = activeChannels[userId]
    if not channel then return end
    if channel.task then
        pcall(task.cancel, channel.task)
    end
    activeChannels[userId] = nil
    Remotes.BeamEnd:FireAllClients(userId)
    StatsManager.recalculate(player)
end

-- ═══════════════════════════════════════════════════════════
-- Remote: CastSpell
-- ═══════════════════════════════════════════════════════════

Remotes.CastSpell.OnServerEvent:Connect(function(player, spellId, mousePosition)
    if type(spellId) ~= "string" then return end
    if typeof(mousePosition) ~= "Vector3" then return end
    SpellCastManager.castSpell(player, spellId, mousePosition)
end)

-- ═══════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════

Players.PlayerRemoving:Connect(function(player)
    SpellCastManager.cancelChannel(player)
    spellCooldowns[player.UserId] = nil
    spellCharges[player.UserId] = nil
end)

return SpellCastManager