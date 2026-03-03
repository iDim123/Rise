local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryManager = require(script.Parent:WaitForChild("InventoryManager"))

-- RemoteFunctions / RemoteEvents
local getInventory = Instance.new("RemoteFunction")
getInventory.Name = "GetInventory"
getInventory.Parent = ReplicatedStorage

local updateInventory = Instance.new("RemoteEvent")
updateInventory.Name = "UpdateInventory"
updateInventory.Parent = ReplicatedStorage

local swapSlots = Instance.new("RemoteEvent")
swapSlots.Name = "SwapSlots"
swapSlots.Parent = ReplicatedStorage

-- Клиент запрашивает инвентарь
getInventory.OnServerInvoke = function(player)
    return InventoryManager.getSlots(player)
end

-- Клиент просит поменять слоты местами (drag & drop)
swapSlots.OnServerEvent:Connect(function(player, fromIndex, toIndex)
    if type(fromIndex) ~= "number" or type(toIndex) ~= "number" then return end
    fromIndex = math.floor(fromIndex)
    toIndex = math.floor(toIndex)

    if InventoryManager.swapSlots(player, fromIndex, toIndex) then
        updateInventory:FireClient(player, InventoryManager.getSlots(player))
    end
end)

-- При входе создаём инвентарь и даём тестовый предмет
Players.PlayerAdded:Connect(function(player)
    InventoryManager.create(player)

    -- Тестовый предмет
    InventoryManager.addItem(player, {
        Id = "sword_of_light",
        Name = "Sword of Light",
        Icon = "rbxassetid://0", -- заменить на реальный ID иконки
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
end)

Players.PlayerRemoving:Connect(function(player)
    InventoryManager.remove(player)
end)