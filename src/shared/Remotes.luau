local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

-- RemoteEvents
local events = {
    "AttackRequest",
    "DamageEvent",
    "EntityDied",
    "HealEvent",
    "UpdateInventory",
    "SwapSlots",
    "EquipItem",
    "UnequipItem",
    "SetActiveWeapon",
    "CraftItem",
    "CraftQueueUpdate",
    "UseItem",
    "DrinkBloodRequest",
    "CaptureRequest",
    "CaptureResult",
    "SummonServant",
    "DismissServant",
    "SetServantMode",
    "ServantCommand",
    "RenameServant",
    "PickupLoot",
    "DropItem", 
    "EquipServantItem",
    "UnequipServantItem",
    "ToggleServantFavorite",
    "UpdateServantData",
}

-- RemoteFunctions
local functions = {
    "GetInventory",
    "GetServants",
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