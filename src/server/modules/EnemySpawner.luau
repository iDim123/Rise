local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local modules = ReplicatedStorage:WaitForChild("modules")

local EnemySpawner = {}

function EnemySpawner.spawn(enemyType, spawnPosition)
    local config = Config.Enemies[enemyType]
    if not config then
        warn("[EnemySpawner] No config for: " .. tostring(enemyType))
        return nil
    end

    local enemiesStorage = ServerStorage:FindFirstChild("enemies")
    if not enemiesStorage then
        warn("[EnemySpawner] No enemies folder in ServerStorage")
        return nil
    end

    local template = enemiesStorage:FindFirstChild(enemyType)
    if not template then
        warn("[EnemySpawner] No template for: " .. enemyType)
        return nil
    end

    local activeEnemies = workspace:FindFirstChild("Enemies")
    if not activeEnemies then
        activeEnemies = Instance.new("Folder")
        activeEnemies.Name = "Enemies"
        activeEnemies.Parent = workspace
        return nil
    end

    local enemy = template:Clone()
    enemy.Parent = activeEnemies

    local rootPart = enemy:FindFirstChild("HumanoidRootPart")
    if rootPart then
        rootPart.Anchored = false
        rootPart.CFrame = CFrame.new(spawnPosition)
    end

    local humanoid = enemy:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = config.WalkSpeed
    end

    enemy:SetAttribute("EnemyType", enemyType)
    enemy:SetAttribute("SpawnPosition", spawnPosition)

    -- HP
    local HealthManager = require(modules:WaitForChild("HealthManager"))
    HealthManager.init(enemy, config.MaxHP)

    -- Blood
    local bloodType = config.BloodType or "Outcast"
    local bqRange = config.BloodQuality or { Min = 1, Max = 1 }
    enemy:SetAttribute("BloodType", bloodType)
    enemy:SetAttribute("BloodQuality", math.random(bqRange.Min, bqRange.Max))

    print("[EnemySpawner] Spawned: " .. enemyType .. " at " .. tostring(spawnPosition))
    return enemy
end

function EnemySpawner.respawn(enemyType, spawnPosition)
    local config = Config.Enemies[enemyType]
    if not config then return end

    task.delay(config.RespawnTime, function()
        EnemySpawner.spawn(enemyType, spawnPosition)
    end)
end

return EnemySpawner