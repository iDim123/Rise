local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local BloodManager = require(modules:WaitForChild("BloodManager"))
local HealthManager = require(modules:WaitForChild("HealthManager"))

BloodManager.setHealthManager(HealthManager)

Remotes.DrinkBloodRequest.OnServerEvent:Connect(function(player)
    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return end

    local bestEnemy = nil
    local bestDistance = Config.Blood.DrinkRange + 1

    for _, enemy in enemiesFolder:GetChildren() do
        local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
        if not enemyRoot then continue end

        local currentHP = enemy:GetAttribute("CurrentHP")
        local maxHP = enemy:GetAttribute("MaxHP")
        if not currentHP or not maxHP or maxHP == 0 then continue end

        if currentHP / maxHP <= Config.Blood.DrinkThreshold then
            local dist = (enemyRoot.Position - rootPart.Position).Magnitude
            if dist < bestDistance then
                bestDistance = dist
                bestEnemy = enemy
            end
        end
    end

    if bestEnemy then
        BloodManager.drinkBlood(player, bestEnemy)
        -- Recalc stats (blood changed)
        local StatsManager = require(modules:WaitForChild("StatsManager"))
        StatsManager.recalculate(player)
    end
end)

local lastTick = tick()
RunService.Heartbeat:Connect(function()
    local now = tick()
    local dt = now - lastTick
    lastTick = now

    for _, player in Players:GetPlayers() do
        local oldType = player.Character and player.Character:GetAttribute("BloodType")
        BloodManager.tick(player, dt)
        local newType = player.Character and player.Character:GetAttribute("BloodType")
        if oldType ~= newType then
            local StatsManager = require(modules:WaitForChild("StatsManager"))
            StatsManager.recalculate(player)
        end
    end
end)