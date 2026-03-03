local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local modules = ReplicatedStorage:WaitForChild("modules")
local EnemySpawner = require(modules:WaitForChild("EnemySpawner"))

-- Создаём папку для живых врагов (если EnemySpawner не успел)
if not workspace:FindFirstChild("Enemies") then
    local folder = Instance.new("Folder")
    folder.Name = "Enemies"
    folder.Parent = workspace
end

local enemiesStorage = ServerStorage:WaitForChild("enemies")

local function initEnemies()
    for _, template in enemiesStorage:GetChildren() do
        local enemyType = template:GetAttribute("EnemyType")
        if not enemyType then continue end

        local spawnPos = template:GetAttribute("SpawnPosition")
        if not spawnPos then continue end

        local config = Config.Enemies[enemyType]
        if not config then
            warn("[EnemyManager] Skipping " .. template.Name .. ": no config for " .. enemyType)
            continue
        end

        EnemySpawner.spawn(enemyType, spawnPos)
    end
end

initEnemies()