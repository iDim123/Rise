local ReplicatedStorage = game:GetService("ReplicatedStorage")
local modules = ReplicatedStorage:WaitForChild("modules")

local HealthManager = require(modules:WaitForChild("HealthManager"))

print("[Server] All systems initialized")