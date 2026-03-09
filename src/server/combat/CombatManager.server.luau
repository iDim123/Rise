local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local WeaponUtil = require(script.Parent:WaitForChild("WeaponUtil"))
local MeleeHandler = require(script.Parent:WaitForChild("MeleeHandler"))
local RangedHandler = require(script.Parent:WaitForChild("RangedHandler"))
local ProjectileManager = require(script.Parent:WaitForChild("ProjectileManager"))
local AbilityManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("AbilityManager"))

-- ═══════════════════════════════════════════════════════════
-- Инициализация
-- ═══════════════════════════════════════════════════════════

ProjectileManager.init()

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

    if WeaponUtil.isRanged(weaponConfig) then
        RangedHandler.attack(player, mousePos, weaponConfig)
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

    RangedHandler.onRelease(player, mousePosition)
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
    RangedHandler.cleanup(player)
end)

print("[CombatManager] Initialized")
