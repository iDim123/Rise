local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ResourceManager = require(modules:WaitForChild("ResourceManager"))

-- Ensure folder exists
local resourcesFolder = workspace:FindFirstChild("Resources")
if not resourcesFolder then
    resourcesFolder = Instance.new("Folder")
    resourcesFolder.Name = "Resources"
    resourcesFolder.Parent = workspace
end

-- Initialize all models with NodeType attribute in Resources folder
local function initResources()
    for _, node in resourcesFolder:GetChildren() do
        local nodeType = node:GetAttribute("NodeType")
        if not nodeType then continue end

        local config = Config.ResourceNodes[nodeType]
        if not config then
            warn("[ResourceSpawner] No config for: " .. nodeType)
            continue
        end

        ResourceManager.init(node, nodeType)
    end
end

initResources()
print("[ResourceSpawner] All resource nodes initialized")