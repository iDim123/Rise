local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}

local configFolder = ReplicatedStorage:WaitForChild("config")
for _, module in configFolder:GetChildren() do
    if module:IsA("ModuleScript") then
        local data = require(module)
        for key, value in data do
            Config[key] = value
        end
    end
end

return Config
