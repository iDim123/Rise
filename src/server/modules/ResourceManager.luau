local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local InventorySync = require(modules:WaitForChild("InventorySync"))

local ResourceManager = {}
local nodeData = {} -- [node instance] = { nodeType, currentHP, maxHP, resourceId, spawnPosition, spawnCFrame }
local respawning = {} -- [node instance] = true (prevents double respawn)

function ResourceManager.init(node, nodeType)
    local config = Config.ResourceNodes[nodeType]
    if not config then
        warn("[ResourceManager] Unknown node type: " .. tostring(nodeType))
        return
    end

    node:SetAttribute("NodeType", nodeType)
    node:SetAttribute("CurrentHP", config.MaxHP)
    node:SetAttribute("MaxHP", config.MaxHP)

    nodeData[node] = {
        nodeType = nodeType,
        currentHP = config.MaxHP,
        maxHP = config.MaxHP,
        resourceId = config.ResourceId,
        spawnPosition = node:GetPivot().Position,
        spawnCFrame = node:GetPivot(),
    }

    print("[ResourceManager] Initialized " .. nodeType .. " at " .. tostring(node:GetPivot().Position))
end

function ResourceManager.hit(player, node, damage)
    local data = nodeData[node]
    if not data then print("[Resource] No data for node") return false end
    if data.currentHP <= 0 then print("[Resource] Node already dead") return false end

    -- Validate distance (horizontal only, using nearest part)
    local character = player.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local closestDist = math.huge
    local parts = {}
    if node:IsA("BasePart") then
        table.insert(parts, node)
    else
        for _, desc in node:GetDescendants() do
            if desc:IsA("BasePart") then table.insert(parts, desc) end
        end
    end
    for _, part in parts do
        local dx = rootPart.Position.X - part.Position.X
        local dz = rootPart.Position.Z - part.Position.Z
        local hDist = math.sqrt(dx * dx + dz * dz)
        if hDist < closestDist then closestDist = hDist end
    end

    if closestDist > 15 then
        print("[Resource] Too far:", closestDist)
        return false
    end

    -- Apply damage
    local actualDamage = math.min(damage, data.currentHP)
    data.currentHP = data.currentHP - actualDamage
    node:SetAttribute("CurrentHP", data.currentHP)

    -- Calculate resources gained
    local config = Config.ResourceNodes[data.nodeType]
    local resourceAmount = math.floor(actualDamage * (config.ResourcePerHit or 1))
    if resourceAmount < 1 then resourceAmount = 1 end

    -- Give resources to player
    local added = InventoryManager.addItemFromConfig(player, data.resourceId, resourceAmount)
    if added then
        InventorySync.sendFullUpdate(player)
        Remotes.ResourceGathered:FireClient(player, node, data.resourceId, resourceAmount)
        print("[Resource] " .. player.Name .. " gathered " .. resourceAmount .. "x " .. data.resourceId)
    else
        print("[Resource] Failed to add item to inventory")
    end

    -- Check if node is destroyed
    if data.currentHP <= 0 then
        ResourceManager._destroyNode(node, data)
    end

    return true
end

function ResourceManager._destroyNode(node, data)
    if respawning[node] then return end
    respawning[node] = true

    local nodeType = data.nodeType
    local spawnCFrame = data.spawnCFrame
    local config = Config.ResourceNodes[nodeType]

    -- Hide the node (make transparent and non-collidable)
    for _, part in node:GetDescendants() do
        if part:IsA("BasePart") then
            part.Transparency = 1
            part.CanCollide = false
        end
    end

    -- Schedule respawn
    task.delay(config.RespawnTime, function()
        ResourceManager._respawnNode(node, nodeType, spawnCFrame)
    end)
end

function ResourceManager._respawnNode(node, nodeType, spawnCFrame)
    local config = Config.ResourceNodes[nodeType]
    if not config then return end

    if not node or not node.Parent then
        respawning[node] = nil
        nodeData[node] = nil
        return
    end

    -- Restore visibility but disable collision initially
    for _, part in node:GetDescendants() do
        if part:IsA("BasePart") then
            part.Transparency = 0
            part.CanCollide = false
        end
    end

    -- Reset HP
    node:SetAttribute("CurrentHP", config.MaxHP)
    node:SetAttribute("MaxHP", config.MaxHP)

    nodeData[node] = {
        nodeType = nodeType,
        currentHP = config.MaxHP,
        maxHP = config.MaxHP,
        resourceId = config.ResourceId,
        spawnPosition = spawnCFrame.Position,
        spawnCFrame = spawnCFrame,
    }

    respawning[node] = nil

    -- Wait until no players are inside, then enable collision
    task.spawn(function()
        while true do
            local anyInside = false
            for _, p in Players:GetPlayers() do
                if p.Character then
                    local root = p.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local dx = root.Position.X - spawnCFrame.Position.X
                        local dz = root.Position.Z - spawnCFrame.Position.Z
                        local hDist = math.sqrt(dx * dx + dz * dz)
                        if hDist < 8 then
                            anyInside = true
                            break
                        end
                    end
                end
            end

            if not anyInside then
                for _, part in node:GetDescendants() do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
                break
            end

            task.wait(0.5)
        end
    end)
end

function ResourceManager.getNodeData(node)
    return nodeData[node]
end

function ResourceManager.isResourceNode(node)
    return nodeData[node] ~= nil
end

function ResourceManager.cleanup(node)
    nodeData[node] = nil
    respawning[node] = nil
end

return ResourceManager