local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local BuffManager = require(modules:WaitForChild("BuffManager"))

local BossAbilities = {}

-- Cooldown tracking: [entity][abilityId] = lastUseTime
local cooldowns = {}

function BossAbilities.init(entity)
    cooldowns[entity] = {}
end

function BossAbilities.cleanup(entity)
    cooldowns[entity] = nil
end

-- Pick best ability to use based on priority, cooldown, HP threshold
function BossAbilities.pickAbility(entity, bossConfig, target)
    if not bossConfig.Abilities then return nil end

    local hpData = HealthManager.getData(entity)
    if not hpData then return nil end
    local hpPercent = hpData.CurrentHP / math.max(hpData.MaxHP, 1)

    local rootPart = entity:FindFirstChild("HumanoidRootPart")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    if not rootPart or not targetRoot then return nil end
    local dist = (targetRoot.Position - rootPart.Position).Magnitude

    local now = tick()
    if not cooldowns[entity] then cooldowns[entity] = {} end

    -- Collect available abilities
    local available = {}
    for abilityId, ability in bossConfig.Abilities do
        local lastUse = cooldowns[entity][abilityId] or 0
        local ready = (now - lastUse) >= ability.Cooldown

        -- HP threshold: MinHP means "use when HP% <= MinHP" (0 = always)
        local hpOk = true
        if ability.MinHP and ability.MinHP > 0 then
            hpOk = hpPercent <= ability.MinHP
        end

        -- Range check for direct damage
        local rangeOk = true
        if ability.Type == "DirectDamage" then
            rangeOk = dist <= (ability.Range or bossConfig.AttackRange or 6)
        end

        if ready and hpOk and rangeOk then
            table.insert(available, { id = abilityId, ability = ability })
        end
    end

    if #available == 0 then return nil end

    -- Sort by priority (highest first)
    table.sort(available, function(a, b)
        return (a.ability.Priority or 0) > (b.ability.Priority or 0)
    end)

    return available[1].id, available[1].ability
end

-- Execute ability
function BossAbilities.execute(entity, abilityId, ability, bossConfig, target)
    if not cooldowns[entity] then cooldowns[entity] = {} end
    cooldowns[entity][abilityId] = tick()

    local rootPart = entity:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    if ability.Type == "DirectDamage" then
        local targetRoot = target:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end

        local dist = (targetRoot.Position - rootPart.Position).Magnitude
        if dist > (ability.Range or bossConfig.AttackRange or 6) then return end

        -- Face target
        local dir = (targetRoot.Position - rootPart.Position).Unit
        rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + Vector3.new(dir.X, 0, dir.Z))

        local damage = ability.Damage or bossConfig.Damage
        HealthManager.takeDamage(target, damage, entity)

        print("[BossAI] " .. (bossConfig.Name or "Boss") .. " used " .. ability.Name .. " → " .. damage .. " dmg")

    elseif ability.Type == "AoEDamage" then
        local radius = ability.Radius or 10
        local damage = ability.Damage or bossConfig.Damage

        -- Hit all players in radius
        for _, player in Players:GetPlayers() do
            local char = player.Character
            if not char then continue end
            local charRoot = char:FindFirstChild("HumanoidRootPart")
            local charHum = char:FindFirstChildOfClass("Humanoid")
            if not charRoot or not charHum or charHum.Health <= 0 then continue end

            if (charRoot.Position - rootPart.Position).Magnitude <= radius then
                HealthManager.takeDamage(char, damage, entity)
            end
        end

        -- Hit servants in radius
        local servantsFolder = workspace:FindFirstChild("Servants")
        if servantsFolder then
            for _, servant in servantsFolder:GetChildren() do
                local sRoot = servant:FindFirstChild("HumanoidRootPart")
                local sHum = servant:FindFirstChildOfClass("Humanoid")
                if sRoot and sHum and sHum.Health > 0 then
                    if (sRoot.Position - rootPart.Position).Magnitude <= radius then
                        HealthManager.takeDamage(servant, damage, entity)
                    end
                end
            end
        end

        print("[BossAI] " .. (bossConfig.Name or "Boss") .. " used " .. ability.Name .. " (AoE r=" .. radius .. ")")

    elseif ability.Type == "Enrage" then
        -- Temporary speed + damage boost
        local humanoid = entity:FindFirstChild("Humanoid")
        if humanoid then
            local baseSpeed = bossConfig.WalkSpeed or 14
            humanoid.WalkSpeed = baseSpeed * (ability.SpeedMultiplier or 1.5)
        end

        -- Store enrage data on entity
        entity:SetAttribute("BossEnraged", true)
        entity:SetAttribute("BossDamageMultiplier", ability.DamageMultiplier or 1.3)

        print("[BossAI] " .. (bossConfig.Name or "Boss") .. " ENRAGED for " .. (ability.Duration or 5) .. "s")

        -- Remove after duration
        task.delay(ability.Duration or 5, function()
            if not entity or not entity.Parent then return end
            entity:SetAttribute("BossEnraged", false)
            entity:SetAttribute("BossDamageMultiplier", 1)
            local hum = entity:FindFirstChild("Humanoid")
            if hum then
                hum.WalkSpeed = bossConfig.WalkSpeed or 14
            end
            print("[BossAI] " .. (bossConfig.Name or "Boss") .. " enrage ended")
        end)
    end
end

return BossAbilities