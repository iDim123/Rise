local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")
local HealthManager = require(modules:WaitForChild("HealthManager"))

print("[Server] All systems initialized")