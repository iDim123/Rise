local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local modules = ReplicatedStorage:WaitForChild("modules")
local InventoryManager = require(modules:WaitForChild("InventoryManager"))

-- Remotes
local getInventory = Instance.new("RemoteFunction")
getInventory.Name = "GetInventory"
getInventory.Parent = ReplicatedStorage

local updateInventory = Instance.new("RemoteEvent")
updateInventory.Name = "UpdateInventory"
updateInventory.Parent = ReplicatedStorage

local swapSlots = Instance.new("RemoteEvent")
swapSlots.Name = "SwapSlots"
swapSlots.Parent = ReplicatedStorage

local equipItem = Instance.new("RemoteEvent")
equipItem.Name = "EquipItem"
equipItem.Parent = ReplicatedStorage

local unequipItem = Instance.new("RemoteEvent")
unequipItem.Name = "UnequipItem"
unequipItem.Parent = ReplicatedStorage

local setActiveWeapon = Instance.new("RemoteEvent")
setActiveWeapon.Name = "SetActiveWeapon"
setActiveWeapon.Parent = ReplicatedStorage

local function sendFullUpdate(player)
    updateInventory:FireClient(player, {
        slots = InventoryManager.getSlots(player),
        equipment = InventoryManager.getEquipment(player),
        activeWeaponSlot = InventoryManager.getActiveWeaponSlot(player),
    })
end

getInventory.OnServerInvoke = function(player)
    return {
        slots = InventoryManager.getSlots(player),
        equipment = InventoryManager.getEquipment(player),
        activeWeaponSlot = InventoryManager.getActiveWeaponSlot(player),
    }
end

swapSlots.OnServerEvent:Connect(function(player, fromIndex, toIndex)
    if type(fromIndex) ~= "number" or type(toIndex) ~= "number" then return end
    fromIndex = math.floor(fromIndex)
    toIndex = math.floor(toIndex)
    if InventoryManager.swapSlots(player, fromIndex, toIndex) then
        sendFullUpdate(player)
    end
end)

equipItem.OnServerEvent:Connect(function(player, slotIndex)
    if type(slotIndex) ~= "number" then return end
    slotIndex = math.floor(slotIndex)
    if InventoryManager.equipItem(player, slotIndex) then
        sendFullUpdate(player)
    end
end)

unequipItem.OnServerEvent:Connect(function(player, equipSlotId)
    if type(equipSlotId) ~= "string" then return end
    if InventoryManager.unequipItem(player, equipSlotId) then
        sendFullUpdate(player)
    end
end)

setActiveWeapon.OnServerEvent:Connect(function(player, slotIndex)
    if type(slotIndex) ~= "number" then return end
    slotIndex = math.floor(slotIndex)
    InventoryManager.setActiveWeapon(player, slotIndex)

    -- Обновляем оружие в руке
    local character = player.Character
    if not character then return end

    -- Убираем текущее оружие
    for _, tool in character:GetChildren() do
        if tool:IsA("Tool") then tool:Destroy() end
    end
    for _, tool in player.Backpack:GetChildren() do
        if tool:IsA("Tool") then tool:Destroy() end
    end

    -- Даём новое если есть
    local inv = InventoryManager.getInventory(player)
    if inv and inv.activeWeaponSlot then
        local item = inv.slots[inv.activeWeaponSlot]
        if item and item ~= false and item.Type == Config.ItemTypes.Weapon then
            local weaponsFolder = ServerStorage:FindFirstChild("weapons")
            if weaponsFolder then
                local weaponTemplate = weaponsFolder:FindFirstChild(item.Id)
                if weaponTemplate then
                    local weapon = weaponTemplate:Clone()
                    weapon.Parent = character
                end
            end
        end
    end

    sendFullUpdate(player)
end)

Players.PlayerAdded:Connect(function(player)
    InventoryManager.create(player)

    -- Тестовые предметы
    InventoryManager.addItem(player, {
        Id = "Sword",
        Name = "Sword of Light",
        Icon = "rbxassetid://0",
        Amount = 1,
        Stackable = false,
        MaxStack = 1,
        Type = "Weapon",
    })

    InventoryManager.addItem(player, {
        Id = "health_potion",
        Name = "Health Potion",
        Icon = "rbxassetid://0",
        Amount = 5,
        Stackable = true,
        MaxStack = 20,
        Type = "Consumable",
    })

    InventoryManager.addItem(player, {
        Id = "iron_helmet",
        Name = "Iron Helmet",
        Icon = "rbxassetid://0",
        Amount = 1,
        Stackable = false,
        MaxStack = 1,
        Type = "Head",
        EquipSlot = "Head",
        Stats = { Defense = 5 },
    })
end)

Players.PlayerRemoving:Connect(function(player)
    InventoryManager.remove(player)
end)