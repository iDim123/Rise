local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local ResourceManager
local StatsManager

local ResourceHit = {}

-- ═══════════════════════════════════════════════════════════
-- Ленивая загрузка
-- ═══════════════════════════════════════════════════════════

local function getResourceManager()
    if not ResourceManager then
        ResourceManager = require(
            ServerScriptService:WaitForChild("modules"):WaitForChild("ResourceManager")
        )
    end
    return ResourceManager
end

local function getStatsManager()
    if not StatsManager then
        StatsManager = require(
            ServerScriptService:WaitForChild("modules"):WaitForChild("StatsManager")
        )
    end
    return StatsManager
end

-- ═══════════════════════════════════════════════════════════
-- Внутренние хелперы
-- ═══════════════════════════════════════════════════════════

-- Рассчитать финальный урон по ресурсу с учётом стата
local function calcResourceDamage(player, weaponConfig)
    local baseDamage = weaponConfig.ResourceDamage or 0
    if baseDamage <= 0 then return 0 end

    local resDmgMod = getStatsManager().get(player, "ResourceDamage")
    return math.max(1, math.floor(baseDamage * resDmgMod))
end

-- Найти ближайшую дистанцию от rootPart до любой BasePart ноды (горизонтально)
local function getHorizontalDistance(rootPart, node)
    local closestDist = math.huge
    local parts = {}

    if node:IsA("BasePart") then
        table.insert(parts, node)
    else
        for _, desc in node:GetDescendants() do
            if desc:IsA("BasePart") then
                table.insert(parts, desc)
            end
        end
    end

    local closestPart = nil
    for _, part in parts do
        local dx = rootPart.Position.X - part.Position.X
        local dz = rootPart.Position.Z - part.Position.Z
        local hDist = math.sqrt(dx * dx + dz * dz)
        if hDist < closestDist then
            closestDist = hDist
            closestPart = part
        end
    end

    return closestDist, closestPart
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API
-- ═══════════════════════════════════════════════════════════

--- Ударить ресурсные ноды в конусе (для melee атак)
--- Логика из оригинального WeaponManager: range+2, dot > 0.3, первая нода
--- @param player Player
--- @param rootPart BasePart — HumanoidRootPart атакующего
--- @param mouseDirection Vector3 (unit) — горизонтальное направление атаки
--- @param weaponConfig table
function ResourceHit.hitInCone(player, rootPart, mouseDirection, weaponConfig)
    local damage = calcResourceDamage(player, weaponConfig)
    if damage <= 0 then return end

    local resourcesFolder = workspace:FindFirstChild("Resources")
    if not resourcesFolder then return end

    local range = (weaponConfig.Range or 6) + 2
    local flatDir = Vector3.new(mouseDirection.X, 0, mouseDirection.Z)
    if flatDir.Magnitude < 0.001 then return end
    flatDir = flatDir.Unit

    for _, node in resourcesFolder:GetChildren() do
        if not node:GetAttribute("NodeType") then continue end

        local dist, closestPart = getHorizontalDistance(rootPart, node)
        if not closestPart then continue end

        if dist <= range then
            local toNode = closestPart.Position - rootPart.Position
            local flatToNode = Vector3.new(toNode.X, 0, toNode.Z)
            if flatToNode.Magnitude > 0.001 then
                local dot = flatDir:Dot(flatToNode.Unit)
                if dot > 0.3 then
                    getResourceManager().hit(player, node, damage)
                    break -- оригинал бьёт только первую ноду в конусе
                end
            end
        end
    end
end

--- Ударить ноды в радиусе (для AoE способностей)
--- Логика из оригинального AbilityManager._hitResourceNodes
--- @param player Player
--- @param rootPart BasePart
--- @param radius number
--- @param weaponConfig table
function ResourceHit.hitInRadius(player, rootPart, radius, weaponConfig)
    local damage = calcResourceDamage(player, weaponConfig)
    if damage <= 0 then return end

    local resourcesFolder = workspace:FindFirstChild("Resources")
    if not resourcesFolder then return end

    for _, node in resourcesFolder:GetChildren() do
        if not node:GetAttribute("NodeType") then continue end

        local dist = getHorizontalDistance(rootPart, node)
        if dist <= radius then
            getResourceManager().hit(player, node, damage)
        end
    end
end

return ResourceHit