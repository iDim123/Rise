local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local InventorySync = require(modules:WaitForChild("InventorySync"))

local CraftHandler = {}

local craftQueues = {}
local craftRunning = {}

local function sendQueueUpdate(player)
    local queue = craftQueues[player.UserId] or {}
    local counts = {}
    for _, entry in queue do
        -- entry может быть string (legacy) или { recipeId, context }
        local recipeId = type(entry) == "table" and entry.recipeId or entry
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

            local entry = queue[1]
            -- Поддержка legacy (string) и нового формата ({ recipeId, context })
            local recipeId = type(entry) == "table" and entry.recipeId or entry
            local context = type(entry) == "table" and entry.context or nil

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

            -- Phase 0: проверка RequiresWorkbench
            if recipe.RequiresWorkbench then
                local hasWorkbench = context and context.hasWorkbench
                if not hasWorkbench then
                    print("[Craft] " .. player.Name .. " tried to craft " .. recipeId .. " without workbench")
                    table.remove(queue, 1)
                    sendQueueUpdate(player)
                    continue
                end
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

            local result = recipe.Result
            InventoryManager.addItemFromConfig(player, result.ItemId, result.Amount or 1)

            table.remove(queue, 1)
            print("[Craft] " .. player.Name .. " crafted " .. result.ItemId .. " x" .. (result.Amount or 1))
            InventorySync.sendFullUpdate(player)
            sendQueueUpdate(player)
        end
    end)
end

--- Запрос крафта.
--- @param player Player
--- @param recipeId string
--- @param context table? — { hasWorkbench: boolean } (Phase 0: опциональный)
function CraftHandler.onCraftItem(player, recipeId, context)
    if type(recipeId) ~= "string" then return end

    -- Find recipe
    local recipe = nil
    for _, r in Config.Crafting.Recipes do
        if r.Id == recipeId then
            recipe = r
            break
        end
    end
    if not recipe then return end

    -- Check tech requirement
    if recipe.RequiresTech then
        local BossManager = require(modules:WaitForChild("boss"):WaitForChild("BossManager"))
        if not BossManager.hasTech(player, recipe.RequiresTech) then
            print("[Craft] " .. player.Name .. " tried to craft " .. recipeId .. " without tech " .. recipe.RequiresTech)
            return
        end
    end

    -- Phase 0: ранняя проверка RequiresWorkbench (до очереди)
    if recipe.RequiresWorkbench then
        local hasWorkbench = context and context.hasWorkbench
        if not hasWorkbench then
            print("[Craft] " .. player.Name .. " tried to craft " .. recipeId .. " without workbench")
            Remotes.Notify:FireClient(player, "Требуется верстак!", "warning")
            return
        end
    end

    if not craftQueues[player.UserId] then
        craftQueues[player.UserId] = {}
    end

    -- Сохраняем context вместе с recipeId
    if context then
        table.insert(craftQueues[player.UserId], { recipeId = recipeId, context = context })
    else
        table.insert(craftQueues[player.UserId], recipeId)
    end

    sendQueueUpdate(player)
    processCraftQueue(player)
end

function CraftHandler.cleanup(player)
    craftQueues[player.UserId] = nil
    craftRunning[player.UserId] = nil
end

return CraftHandler