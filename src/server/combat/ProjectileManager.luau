local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local DamageCalc = require(script.Parent:WaitForChild("DamageCalc"))
local TargetFinder = require(script.Parent:WaitForChild("TargetFinder"))

local HealthManager
local StatsManager

local ProjectileManager = {}

local function getHealthManager()
    if not HealthManager then
        HealthManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("HealthManager"))
    end
    return HealthManager
end

local function getStatsManager()
    if not StatsManager then
        StatsManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("StatsManager"))
    end
    return StatsManager
end

local MAX_PROJECTILES = 50
local nextId = 0

local activeProjectiles = {}
local heartbeatConn = nil
local initialized = false

local function generateId()
    nextId = nextId + 1
    return nextId
end

local function getProjectileConfig(projectileId)
    return Config.Projectiles and Config.Projectiles[projectileId]
end

local function countActive()
    local count = 0
    for _ in activeProjectiles do
        count = count + 1
    end
    return count
end

local function removeOldest()
    local oldestId = nil
    local oldestTime = math.huge

    for id, proj in activeProjectiles do
        if proj.spawnTime < oldestTime then
            oldestTime = proj.spawnTime
            oldestId = id
        end
    end

    if oldestId then
        ProjectileManager._remove(oldestId)
    end
end

function ProjectileManager._remove(id)
    local proj = activeProjectiles[id]
    if not proj then
        return
    end

    activeProjectiles[id] = nil
    Remotes.ProjectileRemoved:FireAllClients(id)
end

function ProjectileManager._processHit(proj, target)
    local ownerCharacter = proj.owner and proj.owner.Character
    if target == ownerCharacter then
        return false
    end

    local finalDamage, isCrit = DamageCalc.calculate({
        player = proj.owner,
        target = target,
        baseDamage = proj.baseDamage,
        damageType = proj.damageType
    })

    getHealthManager().takeDamage(target, finalDamage, ownerCharacter)
    getStatsManager().markCombat(target)

    proj.hitList[target] = true

    -- ═══ OnHit Effects ═══
    if proj.onHitEffects then
        for _, onHit in proj.onHitEffects do
            if onHit.Type == "ApplyPassive" then
                local passiveId = onHit.PassiveId
                target:SetAttribute("Passive_" .. passiveId, true)
                target:SetAttribute("Passive_" .. passiveId .. "_Owner", proj.owner.UserId)
                target:SetAttribute("Passive_" .. passiveId .. "_Expire", os.clock() + (onHit.Duration or 5))
                print("[ProjectileManager] Applied passive", passiveId, "to", target.Name)

            elseif onHit.Type == "HealCaster" then
                local healAmount = 0
                if onHit.DrainPercent then
                    -- % от нанесённого урона (LifeDrain механика)
                    healAmount = math.floor(finalDamage * onHit.DrainPercent)
                elseif onHit.HealPercent then
                    -- % от spell power (прямой хил)
                    local sm = getStatsManager()
                    local spellPower = sm.get(proj.owner, "MagicalPower") or 1.0
                    healAmount = math.floor(spellPower * onHit.HealPercent * 100)
                end
                if healAmount > 0 and proj.owner and proj.owner.Character then
                    getHealthManager().heal(proj.owner.Character, healAmount)
                    print("[ProjectileManager] HealCaster healed", proj.owner.Name, "for", healAmount)
                end
            end
        end
    end

    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    local hitPos = targetRoot and targetRoot.Position or proj.position
    Remotes.ProjectileHit:FireAllClients(proj.id, hitPos, isCrit)

    proj.pierceLeft = proj.pierceLeft - 1

    return true
end

function ProjectileManager._tickProjectile(proj, dt)
    proj.elapsed = proj.elapsed + dt

    proj.velocityY = proj.velocityY - proj.gravity * dt

    local velocity = proj.direction * proj.speed + Vector3.new(0, proj.velocityY, 0)
    local displacement = velocity * dt
    local newPos = proj.position + displacement

    local horizDisp = Vector3.new(displacement.X, 0, displacement.Z)
    proj.distanceTraveled = proj.distanceTraveled + horizDisp.Magnitude

    proj.position = newPos

    local hits = TargetFinder.sphereOverlap(newPos, proj.hitRadius, proj.hitList)

    for _, target in hits do
        local didHit = ProjectileManager._processHit(proj, target)

        if didHit and proj.pierceLeft < 0 then
            return true
        end
    end

    if proj.gravity > 0 then
        local rayResult = workspace:Raycast(proj.position, Vector3.new(0, -1, 0), RaycastParams.new())
        if rayResult and (proj.position.Y - rayResult.Position.Y) < 0.5 then
            return true
        end
    end

    if proj.distanceTraveled > proj.maxDistance then
        return true
    end

    if proj.elapsed > proj.lifetime then
        return true
    end

    return false
end

function ProjectileManager._update(dt)
    local toRemove = {}

    for id, proj in activeProjectiles do
        local shouldRemove = ProjectileManager._tickProjectile(proj, dt)
        if shouldRemove then
            table.insert(toRemove, id)
        end
    end

    for _, id in toRemove do
        ProjectileManager._remove(id)
    end
end

function ProjectileManager.fire(params)
    local projConfig = getProjectileConfig(params.projectileId)
    if not projConfig then
        warn("[ProjectileManager] Unknown projectile: " .. tostring(params.projectileId))
        return nil
    end

    if countActive() >= MAX_PROJECTILES then
        removeOldest()
    end

    local id = generateId()

    local direction = params.direction
    if direction.Magnitude > 0.001 then
        direction = direction.Unit
    else
        direction = Vector3.new(0, 0, -1)
    end

    local pierceCount = params.pierceCount or projConfig.PierceCount or 0

    local proj = {
        id = id,
        owner = params.owner,
        position = params.origin,
        direction = direction,
        speed = projConfig.Speed,
        gravity = projConfig.Gravity or 0,
        maxDistance = projConfig.MaxDistance,
        hitRadius = projConfig.HitRadius or 2,
        lifetime = projConfig.Lifetime or 3,
        baseDamage = params.baseDamage,
        damageType = params.damageType or "Physical",
        pierceLeft = pierceCount,
        distanceTraveled = 0,
        elapsed = 0,
        velocityY = 0,
        spawnTime = os.clock(),
        hitList = {},
        onHitEffects = params.onHitEffects,
        spellSchool = params.spellSchool
    }

    activeProjectiles[id] = proj

    Remotes.ProjectileFired:FireAllClients({
        id = id,
        origin = params.origin,
        direction = direction,
        projectileId = params.projectileId,
        speed = projConfig.Speed,
        gravity = projConfig.Gravity or 0
    })

    return id
end

function ProjectileManager.init()
    if initialized then
        return
    end
    initialized = true

    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        ProjectileManager._update(dt)
    end)

    print("[ProjectileManager] Initialized")
end

return ProjectileManager
