local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local WeaponUtil = require(script.Parent:WaitForChild("WeaponUtil"))
local MeleeHandler = require(script.Parent:WaitForChild("MeleeHandler"))
local RangedHandler = require(script.Parent:WaitForChild("RangedHandler"))
local ProjectileManager = require(script.Parent:WaitForChild("ProjectileManager"))
local AbilityManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("AbilityManager"))

-- Phase 5: Magic system
local SpellCastManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("SpellCastManager"))
local SpellProgressManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("SpellProgressManager"))
local LeechHandler = require(ServerScriptService:WaitForChild("modules"):WaitForChild("LeechHandler"))
local IgniteHandler = require(ServerScriptService:WaitForChild("modules"):WaitForChild("IgniteHandler"))

-- ═══════════════════════════════════════════════════════════
-- Инициализация
-- ═══════════════════════════════════════════════════════════

ProjectileManager.init()
LeechHandler.init()
IgniteHandler.init()

-- ═══════════════════════════════════════════════════════════
-- Основная атака (LMB)
-- ═══════════════════════════════════════════════════════════

Remotes.AttackRequest.OnServerEvent:Connect(function(player, mousePos, comboIndex)
    if typeof(mousePos) ~= "Vector3" then
        return
    end
    local weaponConfig = WeaponUtil.getConfig(player)
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
-- Ranged: отпускание ЛКМ
-- ═══════════════════════════════════════════════════════════

Remotes.RangedRelease.OnServerEvent:Connect(function(player, mousePosition)
    if typeof(mousePosition) ~= "Vector3" then
        return
    end
    RangedHandler.onRelease(player, mousePosition)
end)

-- ═══════════════════════════════════════════════════════════
-- Способности Q / E (weapon abilities)
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
-- Заклинания R / G / Z (magic spells)
-- ═══════════════════════════════════════════════════════════

Remotes.CastSpell.OnServerEvent:Connect(function(player, spellId, mousePosition)
    if type(spellId) ~= "string" then
        return
    end
    if typeof(mousePosition) ~= "Vector3" then
        return
    end
    SpellCastManager.castSpell(player, spellId, mousePosition)
end)

-- ═══════════════════════════════════════════════════════════
-- Spellbook: learn / equip / unequip / query
-- ═══════════════════════════════════════════════════════════

Remotes.LearnSpell.OnServerEvent:Connect(function(player, spellId)
    if type(spellId) ~= "string" then
        return
    end
    local ok, reason = SpellProgressManager.learnSpell(player, spellId)
    if not ok then
        Remotes.Notify:FireClient(player, "Не удалось изучить: " .. (reason or "unknown"), "error")
    end
end)

Remotes.EquipSpell.OnServerEvent:Connect(function(player, spellId, slotKey)
    if type(spellId) ~= "string" or type(slotKey) ~= "string" then
        return
    end
    local ok, reason = SpellProgressManager.equipSpell(player, spellId, slotKey)
    if not ok then
        Remotes.Notify:FireClient(player, "Не удалось экипировать: " .. (reason or "unknown"),
            "error")
    end
end)

Remotes.UnequipSpell.OnServerEvent:Connect(function(player, slotKey)
    if type(slotKey) ~= "string" then
        return
    end
    SpellProgressManager.unequipSpell(player, slotKey)
end)

-- ═══════════════════════════════════════════════════════════
-- Beam: обновление направления луча (клиент → сервер, ~10/сек)
-- ═══════════════════════════════════════════════════════════

Remotes.BeamUpdate.OnServerEvent:Connect(function(player, mousePosition)
    if typeof(mousePosition) ~= "Vector3" then
        return
    end
    local activeChannels = SpellCastManager.getActiveChannels()
    local channel = activeChannels[player.UserId]
    if not channel then
        return
    end
    local character = player.Character
    if not character then
        return
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end
    local newDir = Vector3.new(mousePosition.X - rootPart.Position.X, 0, mousePosition.Z - rootPart.Position.Z)
    if newDir.Magnitude > 0.001 then
        channel.direction = newDir.Unit
    end
end)

Remotes.GetSpellData.OnServerInvoke = function(player)
    return SpellProgressManager._getPlayerData(player)
end

-- ═══════════════════════════════════════════════════════════
-- Cleanup при выходе
-- ═══════════════════════════════════════════════════════════

Players.PlayerRemoving:Connect(function(player)
    MeleeHandler.cleanup(player)
    RangedHandler.cleanup(player)
end)

print("[CombatManager] Initialized")
