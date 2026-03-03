local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local modules = ReplicatedStorage:WaitForChild("modules")
local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local InventorySync = require(modules:WaitForChild("InventorySync"))

local CraftHandler = {}

local craftQueues = {}
local craftRunning = {}

local function sendQueueUpdate(player)
    local queue = craftQueues[player.UserId] or {}
    local counts = {}
    for _, recipeId in queue do
        counts[recipeId] = (counts[recipeId] or 0) + 1
    end
    Remotes.CraftQueueUpdate:FireClient(player, counts)
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
            InventorySync.sendFullUpdate(player)
            sendQueueUpdate(player)

            -- Прогресс крафта
            local craftTime = recipe.CraftTime or 0
            if craftTime > 0 then
                local steps = 10
                local stepTime = craftTime / steps
                for i = 1, steps do
                    task.wait(stepTime)
                    Remotes.CraftQueueUpdate:FireClient(player, nil, recipeId, i / steps)
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
            InventorySync.sendFullUpdate(player)
            sendQueueUpdate(player)
        end
    end)
end

function CraftHandler.onCraftItem(player, recipeId)
    if type(recipeId) ~= "string" then return end

    if not craftQueues[player.UserId] then
        craftQueues[player.UserId] = {}
    end

    table.insert(craftQueues[player.UserId], recipeId)
    sendQueueUpdate(player)
    processCraftQueue(player)
end

function CraftHandler.cleanup(player)
    craftQueues[player.UserId] = nil
    craftRunning[player.UserId] = nil
end

return CraftHandler