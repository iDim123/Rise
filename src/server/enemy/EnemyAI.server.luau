local EnemyStateManager = require(script.Parent:WaitForChild("EnemyStateManager"))
local EnemyBehaviors = require(script.Parent:WaitForChild("EnemyBehaviors"))

local TICK_RATE = 0.2

task.spawn(function()
	while true do
		local enemiesFolder = workspace:FindFirstChild("Enemies")
		if enemiesFolder then
			for _, enemy in enemiesFolder:GetChildren() do
				if not EnemyStateManager.get(enemy).Tracked then
					EnemyStateManager.get(enemy).Tracked = true
					enemy.Destroying:Connect(function()
						EnemyStateManager.remove(enemy)
					end)
				end
				task.spawn(EnemyBehaviors.update, enemy)
			end
		end
		task.wait(TICK_RATE)
	end
end)