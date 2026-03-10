local Players = game:GetService("Players")
local EnemyStateManager = require(script.Parent:WaitForChild("EnemyStateManager"))
local EnemyBehaviors = require(script.Parent:WaitForChild("EnemyBehaviors"))
local BossBehaviors = require(script.Parent:WaitForChild("BossBehaviors"))
local BossAbilities = require(script.Parent:WaitForChild("BossAbilities"))

local TICK_RATE = 0.2
local ACTIVATION_RANGE = 100 -- studs: only run AI for enemies near players
local BATCH_SIZE = 20 -- max enemies processed per frame in a tick

-- Check if any player is within range of the enemy
local function isNearAnyPlayer(enemy, range)
    local rootPart = enemy:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return false
    end
    local pos = rootPart.Position
    local rangeSq = range * range
    for _, player in Players:GetPlayers() do
        local character = player.Character
        if character then
            local pRoot = character:FindFirstChild("HumanoidRootPart")
            if pRoot then
                local delta = pRoot.Position - pos
                if delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z <= rangeSq then
                    return true
                end
            end
        end
    end
    return false
end

task.spawn(function()
    while true do
        local enemiesFolder = workspace:FindFirstChild("Enemies")
        if enemiesFolder then
            local enemies = enemiesFolder:GetChildren()
            local processed = 0

            for _, enemy in enemies do
                -- Track newly-appeared enemies
                if not EnemyStateManager.get(enemy).Tracked then
                    EnemyStateManager.get(enemy).Tracked = true

                    -- Init boss abilities
                    if enemy:GetAttribute("IsBoss") then
                        BossAbilities.init(enemy)
                    end

                    enemy.Destroying:Connect(function()
                        BossAbilities.cleanup(enemy)
                        EnemyStateManager.remove(enemy)
                    end)
                end

                -- Only update AI for enemies near players (activation range)
                if isNearAnyPlayer(enemy, ACTIVATION_RANGE) then
                    -- Route to correct behavior
                    if enemy:GetAttribute("IsBoss") then
                        task.spawn(BossBehaviors.update, enemy)
                    else
                        task.spawn(EnemyBehaviors.update, enemy)
                    end

                    processed += 1
                    -- Yield between batches to spread CPU load
                    if processed >= BATCH_SIZE then
                        processed = 0
                        task.wait()
                    end
                end
            end
        end
        task.wait(TICK_RATE)
    end
end)
