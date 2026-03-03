local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local modules = ReplicatedStorage:WaitForChild("modules")
local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local HealthManager = require(modules:WaitForChild("HealthManager"))

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

local craftItem = Instance.new("RemoteEvent")
craftItem.Name = "CraftItem"
craftItem.Parent = ReplicatedStorage

local craftQueueUpdate = Instance.new("RemoteEvent")
craftQueueUpdate.Name = "CraftQueueUpdate"
craftQueueUpdate.Parent = ReplicatedStorage

local useItem = Instance.new("RemoteEvent")
useItem.Name = "UseItem"
useItem.Parent = ReplicatedStorage

local craftingPlayers = {} 

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


-- ===== CRAFT QUEUE =====
local craftQueues = {}
local craftRunning = {}

local function sendQueueUpdate(player)
    local queue = craftQueues[player.UserId] or {}
    -- Считаем сколько каждого рецепта в очереди
    local counts = {}
    for _, recipeId in queue do
        counts[recipeId] = (counts[recipeId] or 0) + 1
    end
    craftQueueUpdate:FireClient(player, counts)
end

local function processCraftQueue(player)
    if craftRunning[player.UserId] then return end
    craftRunning[player.UserId] = true

    task.spawn(function()
        while true do
            local queue = craftQueues[player.UserId]
            if not queue or #queue == 0 then
                craftRunning[player.UserId] = nil
                sendQueueUpdate(player)
                return
            end

            local recipeId = queue[1]

            local recipe = nil
            for _, r in Config.Crafting.Recipes do
                if r.Id == recipeId then
                    recipe = r
                    break
                end
            end

            if not recipe then
                table.remove(queue, 1)
                sendQueueUpdate(player)
                continue
            end

            -- Проверяем ресурсы
            local canCraft = true
            for _, ingredient in recipe.Ingredients do
                if InventoryManager.countItem(player, ingredient.ItemId) < ingredient.Amount then
                    canCraft = false
                    break
                end
            end

            if not canCraft then
                table.remove(queue, 1)
                sendQueueUpdate(player)
                continue
            end

            -- Списываем ингредиенты
            for _, ingredient in recipe.Ingredients do
                InventoryManager.removeItemById(player, ingredient.ItemId, ingredient.Amount)
            end
            sendFullUpdate(player)
            sendQueueUpdate(player)

            -- Прогресс крафта
            local craftTime = recipe.CraftTime or 0
            if craftTime > 0 then
                local steps = 10
                local stepTime = craftTime / steps
                for i = 1, steps do
                    task.wait(stepTime)
                    craftQueueUpdate:FireClient(player, nil, recipeId, i / steps)
                end
            end

            -- Выдаём результат
            local result = recipe.Result
            InventoryManager.addItem(player, {
                Id = result.Id,
                Name = result.Name,
                Icon = result.Icon or "rbxassetid://0",
                Amount = result.Amount or 1,
                Stackable = result.Stackable or false,
                MaxStack = result.MaxStack or 1,
                Type = result.Type or "Misc",
            })

            table.remove(queue, 1)
            print("[Craft] " .. player.Name .. " crafted " .. result.Name)
            sendFullUpdate(player)
            sendQueueUpdate(player)
        end
    end)
end

-- ===== USE ITEM =====
local useCooldowns = {} -- [UserId] = { [ItemId] = tick() }

useItem.OnServerEvent:Connect(function(player, slotIndex)
    if type(slotIndex) ~= "number" then return end
    slotIndex = math.floor(slotIndex)

    local inv = InventoryManager.getInventory(player)
    if not inv then return end

    local item = inv.slots[slotIndex]
    if not item or item == false then return end
    if item.Type ~= "Consumable" then return end

    -- Получаем определение из Config
    local itemDef = Config.Items[item.Id]
    if not itemDef or not itemDef.UseEffect then return end

    local effect = itemDef.UseEffect

    -- Проверяем кулдаун
    local userId = player.UserId
    if not useCooldowns[userId] then useCooldowns[userId] = {} end

    local lastUse = useCooldowns[userId][item.Id] or 0
    local now = tick()
    if now - lastUse < (effect.Cooldown or 0) then
        return -- ещё на кулдауне
    end

    -- Применяем эффект
    if effect.Type == "Heal" then
        local character = player.Character
        if not character then return end
        HealthManager.heal(character, effect.Amount)
    end

    -- Ставим кулдаун
    useCooldowns[userId][item.Id] = now

    -- Расходуем 1 штуку
    InventoryManager.removeItem(player, slotIndex, 1)

    print("[UseItem] " .. player.Name .. " used " .. item.Name)
    sendFullUpdate(player)
end)


craftItem.OnServerEvent:Connect(function(player, recipeId)
    if type(recipeId) ~= "string" then return end

    if not craftQueues[player.UserId] then
        craftQueues[player.UserId] = {}
    end

    table.insert(craftQueues[player.UserId], recipeId)
    sendQueueUpdate(player)
    processCraftQueue(player)
end)

-- Очистка при выходе (добавь в существующий PlayerRemoving)
Players.PlayerRemoving:Connect(function(player)
    craftQueues[player.UserId] = nil
    craftRunning[player.UserId] = nil
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

    InventoryManager.addItemFromConfig(player, "blood_essence", 150)

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