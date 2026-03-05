local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local EnemySpawner = require(modules:WaitForChild("EnemySpawner"))

-- Создаём папку для живых врагов
if not workspace:FindFirstChild("Enemies") then
    local folder = Instance.new("Folder")
    folder.Name = "Enemies"
    folder.Parent = workspace
end

local function initFromSpawnPoints()
    local spawnPoints = workspace:FindFirstChild("SpawnPoints")
    if not spawnPoints then
        warn("[EnemyManager] No SpawnPoints folder in Workspace")
        return
    end

    for _, point in spawnPoints:GetChildren() do
        local enemyType = point:GetAttribute("EnemyType")
        if not enemyType then continue end

        local config = Config.Enemies[enemyType]
        if not config then
            warn("[EnemyManager] No config for: " .. enemyType)
            continue
        end

        local spawnPos = point.Position
        local level = point:GetAttribute("Level")

        EnemySpawner.spawn(enemyType, spawnPos, level)
    end
end

initFromSpawnPoints()