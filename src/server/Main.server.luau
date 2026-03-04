local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

-- Загружаем модули чтобы зарегистрировать подписки на EventBus
require(modules:WaitForChild("HealthManager"))
require(modules:WaitForChild("LootManager"))
require(modules:WaitForChild("EnemySpawner"))

print("[Server] All systems initialized")