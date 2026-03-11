local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

-- RemoteEvents
local events = { -- === Existing ===
"AttackRequest", "DamageEvent", "EntityDied", "HealEvent", "UpdateInventory", "SwapSlots", "EquipItem", "UnequipItem",
"SetActiveWeapon", "CraftItem", "CraftQueueUpdate", "UseItem", "DrinkBloodRequest", "CaptureRequest", "CaptureResult",
"SummonServant", "DismissServant", "SetServantMode", "ServantCommand", "RenameServant", "PickupLoot", "DropItem",
"EquipServantItem", "UnequipServantItem", "ToggleServantFavorite", "UpdateServantData", "UpdateBuffs", "UseAbility",
"AbilityCooldown", "ResourceGathered", "UpdateLevel", "UpdateServantLevel", "UpdateStats", "BossFinish", "BossCapture",
"BossFinishResult", "BossCaptureResult", "UnlockTech", "Notify", "DebugCommand", "PlayerDied", "ContainerOpen",
"ContainerClose", "ContainerTakeItem", "ContainerTakeAll", "ContainerSort", "ContainerOpened", "ContainerUpdate",
"ContainerClosed", "CastStart", "CastCancel", "CastCancelRequest", "DayNightSync", "PlayerRespawn", "RangedRelease",
"ProjectileFired", "ProjectileHit", "ProjectileRemoved", "CastSpell", "LearnSpell", "EquipSpell", "UnequipSpell",
"SpellCooldown", "SpellChargeUpdate", "BeamStart", "BeamUpdate", "BeamEnd", "SpellEffect", "UpdateSpellData",
"SpellAim", "StructureDamageEvent", "PlaceCastleHeart", "UpgradeCastleHeart", "DestroyCastle", "CastleHeartInfo",
"PlaceBlock", "RemoveBlock", "BuildingSync", "SetBuildPermission", "AddBuildAlly", "RemoveBuildAlly", "InteractBlock"}

-- RemoteFunctions
local functions = { -- === Existing ===
"GetInventory", "GetServants", "GetPlayerStats", "GetBossData", "GetSpellData", -- === Phase 1: Building ===
"GetBuildings", -- Client → Server: returns blocks array
"GetCastleHeartInfo" -- Client → Server: returns heartInfo table
}

if RunService:IsServer() then
    for _, name in events do
        local remote = ReplicatedStorage:FindFirstChild(name)
        if not remote then
            remote = Instance.new("RemoteEvent")
            remote.Name = name
            remote.Parent = ReplicatedStorage
        end
        Remotes[name] = remote
    end

    for _, name in functions do
        local remote = ReplicatedStorage:FindFirstChild(name)
        if not remote then
            remote = Instance.new("RemoteFunction")
            remote.Name = name
            remote.Parent = ReplicatedStorage
        end
        Remotes[name] = remote
    end
else
    for _, name in events do
        Remotes[name] = ReplicatedStorage:WaitForChild(name)
    end

    for _, name in functions do
        Remotes[name] = ReplicatedStorage:WaitForChild(name)
    end
end

return Remotes
