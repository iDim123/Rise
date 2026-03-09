local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local WeaponUtil = require(script.Parent:WaitForChild("WeaponUtil"))
local MeleeHandler = require(script.Parent:WaitForChild("MeleeHandler"))

-- RangedHandler и ProjectileManager загрузим лениво —
-- они ещё не созданы на этом этапе рефакторинга.
-- После Шага 10-11 заменим на прямой require.
local RangedHandler
local ProjectileManager

local function getRangedHandler()
    if not RangedHandler then
        local ok, mod = pcall(function()
            return require(script.Parent:WaitForChild("RangedHandler", 2))
        end)
        if ok then
            RangedHandler = mod
        end
    end
    return RangedHandler
end

local function getProjectileManager()
    if not ProjectileManager then
        local ok, mod = pcall(function()
            return require(script.Parent:WaitForChild("ProjectileManager", 2))
        end)
        if ok then
            ProjectileManager = mod
        end
    end
    return ProjectileManager
end

-- AbilityManager остаётся в modules/
local AbilityManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("AbilityManager"))

-- ═══════════════════════════════════════════════════════════
-- Инициализация
-- ═══════════════════════════════════════════════════════════

-- ProjectileManager.init() будет вызван при первом ranged-запросе,
-- или явно после создания модуля (Шаг 10).
-- Пока что пытаемся инициализировать если модуль существует.
local pm = getProjectileManager()
if pm and pm.init then
    pm.init()
end

-- ═══════════════════════════════════════════════════════════
-- Основная атака (LMB)
-- ═══════════════════════════════════════════════════════════

Remotes.AttackRequest.OnServerEvent:Connect(function(player, mousePos, comboIndex)
    if typeof(mousePos) ~= "Vector3" then
        return
    end

    local weaponConfig, weaponItem = WeaponUtil.getConfig(player)
    if not weaponConfig then
        return
    end

    local wType = WeaponUtil.getType(weaponConfig)

    if wType == "Ranged" then
        local rh = getRangedHandler()
        if rh then
            rh.attack(player, mousePos, weaponConfig)
        end
    else
        MeleeHandler.attack(player, mousePos, comboIndex, weaponConfig)
    end
end)

-- ═══════════════════════════════════════════════════════════
-- Ranged: финальная mousePosition после каста (LMB up)
-- ═══════════════════════════════════════════════════════════

Remotes.RangedRelease.OnServerEvent:Connect(function(player, mousePosition)
    if typeof(mousePosition) ~= "Vector3" then
        return
    end

    local rh = getRangedHandler()
    if rh then
        rh.onRelease(player, mousePosition)
    end
end)

-- ═══════════════════════════════════════════════════════════
-- Способности Q / E
-- ═══════════════════════════════════════════════════════════

Remotes.UseAbility.OnServerEvent:Connect(function(player, key, mousePosition)
    if type(key) ~= "string" then
        return
    end
    if typeof(mousePosition) ~= "Vector3" then
        return
    end

    AbilityManager.useAbility(player, key, mousePosition)
end)

-- ═══════════════════════════════════════════════════════════
-- Cleanup при выходе
-- ═══════════════════════════════════════════════════════════

Players.PlayerRemoving:Connect(function(player)
    MeleeHandler.cleanup(player)

    local rh = getRangedHandler()
    if rh then
        rh.cleanup(player)
    end
end)

print("[CombatManager] Initialized")
