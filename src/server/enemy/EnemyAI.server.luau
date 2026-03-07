local EnemyStateManager = require(script.Parent:WaitForChild("EnemyStateManager"))
local EnemyBehaviors = require(script.Parent:WaitForChild("EnemyBehaviors"))
local BossBehaviors = require(script.Parent:WaitForChild("BossBehaviors"))
local BossAbilities = require(script.Parent:WaitForChild("BossAbilities"))

local TICK_RATE = 0.2

task.spawn(function()
    while true do
        local enemiesFolder = workspace:FindFirstChild("Enemies")
        if enemiesFolder then
            for _, enemy in enemiesFolder:GetChildren() do
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

                -- Route to correct behavior
                if enemy:GetAttribute("IsBoss") then
                    task.spawn(BossBehaviors.update, enemy)
                else
                    task.spawn(EnemyBehaviors.update, enemy)
                end
            end
        end
        task.wait(TICK_RATE)
    end
end)
