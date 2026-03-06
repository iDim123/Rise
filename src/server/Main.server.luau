local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local modules = ServerScriptService:WaitForChild("modules")
local StatsManager = require(modules:WaitForChild("StatsManager"))

require(modules:WaitForChild("HealthManager"))
require(modules:WaitForChild("LootManager"))
require(modules:WaitForChild("EnemySpawner"))
require(modules:WaitForChild("LevelManager"))
local BuffManager = require(modules:WaitForChild("BuffManager"))

local buffTickAccumulator = 0
local BUFF_TICK_RATE = 1

RunService.Heartbeat:Connect(function(dt)
    buffTickAccumulator = buffTickAccumulator + dt
    if buffTickAccumulator >= BUFF_TICK_RATE then
        buffTickAccumulator = 0
        BuffManager.tick()
    end
end)

-- HealthRegen: tick every 1 second
task.spawn(function()
    while true do
        task.wait(1)
        StatsManager.tickRegen()
    end
end)

print("[Server] All systems initialized")
