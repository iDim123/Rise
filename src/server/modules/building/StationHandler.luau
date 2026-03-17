--[[
    StationHandler.luau
    Универсальный обработчик перерабатывающих станций (Sawmill, Crusher, ...).

    Жизненный цикл:
      onCreate    — создаёт input/output, запускает крафт-цикл
      interact    — открывает StationUI для игрока
      onDestroy   — дропает содержимое, останавливает крафт
    
    Станция определяется по StationType из FunctionalData.
    Рецепты фильтруются по полю Station в CraftConfig.

    Используется: FunctionalDispatcher
    Зависимости: StationConfig, CastleBorder, LootManager, Config, Remotes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local CastleBorder = require(modules:WaitForChild("building"):WaitForChild("CastleBorder"))

-- Lazy requires
local _LootManager
local function getLootManager()
    if not _LootManager then
        _LootManager = require(modules:WaitForChild("LootManager"))
    end
    return _LootManager
end

local StationHandler = {}

-- ═══════════════════════════════════════════════════════════
-- Состояние
-- ═══════════════════════════════════════════════════════════

-- stationData[blockId] = {
--   stationId: string,
--   stationType: string ("Sawmill", "Crusher", ...),
--   part: BasePart,
--   inputSlots: { [1..N] = false | { ItemId, Amount } },
--   outputSlots: { [1..N] = false | { ItemId, Amount } },
--   recipeToggles: { [recipeId] = bool },
--   crafting: { recipeId, elapsed, duration } | nil,
--   viewers: { [userId] = Player },
--   originalColor: Color3,
-- }
local stationData = {}

-- Обратный поиск: stationId → blockId
local stationIdToBlock = {}

-- Кэш рецептов по StationType: { ["Sawmill"] = { recipe, ... }, ... }
local recipeCache = {}

-- ═══════════════════════════════════════════════════════════
-- Утилиты
-- ═══════════════════════════════════════════════════════════

local function makeStationId(stationType)
    return "station_" .. stationType:lower() .. "_" .. tostring(math.floor(os.clock() * 1000)) .. "_" .. tostring(math.random(1, 99999))
end

local function makeEmptySlots(count)
    local slots = {}
    for i = 1, count do
        slots[i] = false
    end
    return slots
end

local function getStationConfig(stationType)
    return Config.Stations and Config.Stations[stationType] or {
        Name = stationType,
        InputSlots = 8,
        OutputSlots = 8,
        InteractRange = 10,
        CraftingColor = Color3.fromRGB(180, 140, 60),
    }
end

--- Загрузить рецепты для конкретного типа станции
local function getRecipesForType(stationType)
    if recipeCache[stationType] then
        return recipeCache[stationType]
    end

    local recipes = {}
    local allRecipes = Config.Crafting and Config.Crafting.Recipes or {}
    for _, recipe in allRecipes do
        if recipe.Station == stationType then
            table.insert(recipes, recipe)
        end
    end

    recipeCache[stationType] = recipes
    print("[StationHandler] Loaded " .. #recipes .. " recipes for " .. stationType)
    return recipes
end

local function countItems(slots)
    local counts = {}
    for _, slot in slots do
        if slot and slot ~= false then
            counts[slot.ItemId] = (counts[slot.ItemId] or 0) + (slot.Amount or 1)
        end
    end
    return counts
end

local function hasIngredients(inputCounts, recipe)
    for _, ing in recipe.Ingredients do
        if (inputCounts[ing.ItemId] or 0) < ing.Amount then
            return false
        end
    end
    return true
end

local function consumeIngredients(slots, recipe)
    for _, ing in recipe.Ingredients do
        local remaining = ing.Amount
        for i = #slots, 1, -1 do
            if remaining <= 0 then break end
            local slot = slots[i]
            if slot and slot ~= false and slot.ItemId == ing.ItemId then
                local take = math.min(slot.Amount, remaining)
                slot.Amount -= take
                remaining -= take
                if slot.Amount <= 0 then
                    slots[i] = false
                end
            end
        end
    end
end

local function canFitResults(slots, recipe)
    local simSlots = {}
    for i, slot in slots do
        if slot and slot ~= false then
            simSlots[i] = { ItemId = slot.ItemId, Amount = slot.Amount }
        else
            simSlots[i] = false
        end
    end

    local results = recipe.Results or {}
    if recipe.Result and not recipe.Results then
        results = { recipe.Result }
    end

    for _, res in results do
        local toPlace = res.Amount
        local itemDef = Config.Items[res.ItemId]
        local maxStack = (itemDef and itemDef.MaxStack) or 99

        for i, slot in simSlots do
            if toPlace <= 0 then break end
            if slot and slot ~= false and slot.ItemId == res.ItemId then
                local canAdd = maxStack - slot.Amount
                if canAdd > 0 then
                    local add = math.min(canAdd, toPlace)
                    slot.Amount += add
                    toPlace -= add
                end
            end
        end

        for i, slot in simSlots do
            if toPlace <= 0 then break end
            if not slot or slot == false then
                local add = math.min(maxStack, toPlace)
                simSlots[i] = { ItemId = res.ItemId, Amount = add }
                toPlace -= add
            end
        end

        if toPlace > 0 then
            return false
        end
    end
    return true
end

local function placeResults(slots, recipe)
    local results = recipe.Results or {}
    if recipe.Result and not recipe.Results then
        results = { recipe.Result }
    end

    for _, res in results do
        local toPlace = res.Amount
        local itemDef = Config.Items[res.ItemId]
        local maxStack = (itemDef and itemDef.MaxStack) or 99

        for i, slot in slots do
            if toPlace <= 0 then break end
            if slot and slot ~= false and slot.ItemId == res.ItemId then
                local canAdd = maxStack - slot.Amount
                if canAdd > 0 then
                    local add = math.min(canAdd, toPlace)
                    slot.Amount += add
                    toPlace -= add
                end
            end
        end

        for i, slot in slots do
            if toPlace <= 0 then break end
            if not slot or slot == false then
                local add = math.min(maxStack, toPlace)
                slots[i] = { ItemId = res.ItemId, Amount = add }
                toPlace -= add
            end
        end
    end
end

local function notifyViewers(data)
    local payload = {
        StationId = data.stationId,
        StationType = data.stationType,
        InputSlots = data.inputSlots,
        OutputSlots = data.outputSlots,
        RecipeToggles = data.recipeToggles,
        Crafting = data.crafting and {
            RecipeId = data.crafting.recipeId,
            Elapsed = data.crafting.elapsed,
            Duration = data.crafting.duration,
        } or nil,
    }
    for _, player in data.viewers do
        Remotes.StationUpdate:FireClient(player, payload)
    end
end

local function setCraftingColor(data, isCrafting)
    if not data.part or not data.part.Parent then return end
    local cfg = getStationConfig(data.stationType)
    if isCrafting then
        data.part.Color = cfg.CraftingColor
    else
        data.part.Color = data.originalColor
    end
end

-- ═══════════════════════════════════════════════════════════
-- Крафт-цикл (Heartbeat)
-- ═══════════════════════════════════════════════════════════

local function processStation(data, dt)
    if data.crafting then
        data.crafting.elapsed += dt

        if data.crafting.elapsed >= data.crafting.duration then
            local recipes = getRecipesForType(data.stationType)
            local recipe = nil
            for _, r in recipes do
                if r.Id == data.crafting.recipeId then
                    recipe = r
                    break
                end
            end

            if recipe then
                placeResults(data.outputSlots, recipe)
            end

            data.crafting = nil
            setCraftingColor(data, false)
            notifyViewers(data)
        end

        return
    end

    local recipes = getRecipesForType(data.stationType)
    local inputCounts = countItems(data.inputSlots)

    for _, recipe in recipes do
        if data.recipeToggles[recipe.Id] == false then
            continue
        end
        if not hasIngredients(inputCounts, recipe) then
            continue
        end
        if not canFitResults(data.outputSlots, recipe) then
            continue
        end

        consumeIngredients(data.inputSlots, recipe)

        data.crafting = {
            recipeId = recipe.Id,
            elapsed = 0,
            duration = recipe.CraftTime or 2,
        }

        setCraftingColor(data, true)
        notifyViewers(data)
        return
    end
end

local heartbeatConn = nil

local function startHeartbeat()
    if heartbeatConn then return end
    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        for _, data in stationData do
            processStation(data, dt)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- Жизненный цикл
-- ═══════════════════════════════════════════════════════════

function StationHandler.onCreate(part, typeId, blockId, castle)
    local bt = Config.Building.BlockTypes[typeId]
    local stationType = bt and bt.FunctionalData and bt.FunctionalData.StationType
    if not stationType then
        warn("[StationHandler] No StationType for " .. typeId)
        return nil
    end

    local cfg = getStationConfig(stationType)
    local recipes = getRecipesForType(stationType)
    local stationId = makeStationId(stationType)

    local toggles = {}
    for _, recipe in recipes do
        toggles[recipe.Id] = true
    end

    local data = {
        stationId = stationId,
        stationType = stationType,
        part = part,
        inputSlots = makeEmptySlots(cfg.InputSlots),
        outputSlots = makeEmptySlots(cfg.OutputSlots),
        recipeToggles = toggles,
        crafting = nil,
        viewers = {},
        originalColor = bt.Color or Color3.fromRGB(128, 128, 128),
    }

    stationData[blockId] = data
    stationIdToBlock[stationId] = blockId

    part:SetAttribute("StationId", stationId)
    part:SetAttribute("StationType", stationType)
    part:SetAttribute("FunctionalType", "Station")

    if castle and castle.blocks[blockId] then
        castle.blocks[blockId].stationId = stationId
    end

    startHeartbeat()

    print("[StationHandler] Created " .. stationType .. " station " .. stationId .. " for block " .. blockId)
    return stationId
end

function StationHandler.interact(player, part, blockData, castle)
    local ownerId = part:GetAttribute("CastleOwnerId")
    if ownerId then
        if not CastleBorder.canInteract(player.UserId, ownerId) then
            return false, "Нет прав доступа"
        end
    end

    local stationId = part:GetAttribute("StationId")
    if not stationId then
        return false, "Станция не инициализирована"
    end

    local blockId = stationIdToBlock[stationId]
    local data = blockId and stationData[blockId]
    if not data then
        return false, "Данные станции не найдены"
    end

    data.viewers[player.UserId] = player

    local recipes = getRecipesForType(data.stationType)
    local cfg = getStationConfig(data.stationType)

    local payload = {
        StationId = data.stationId,
        StationType = data.stationType,
        StationName = cfg.Name,
        InputSlots = data.inputSlots,
        OutputSlots = data.outputSlots,
        RecipeToggles = data.recipeToggles,
        Recipes = recipes,
        Crafting = data.crafting and {
            RecipeId = data.crafting.recipeId,
            Elapsed = data.crafting.elapsed,
            Duration = data.crafting.duration,
        } or nil,
    }

    Remotes.StationOpened:FireClient(player, payload)
    return true
end

function StationHandler.onDestroy(part, blockId)
    if not blockId then
        for bId, data in stationData do
            if data.part == part then
                blockId = bId
                break
            end
        end
    end

    if not blockId or not stationData[blockId] then
        return
    end

    local data = stationData[blockId]
    local dropPos = part.Position

    for _, slot in data.inputSlots do
        if slot and slot ~= false then
            getLootManager().dropItemAtPosition(dropPos, slot.ItemId, slot.Amount or 1)
        end
    end

    for _, slot in data.outputSlots do
        if slot and slot ~= false then
            getLootManager().dropItemAtPosition(dropPos, slot.ItemId, slot.Amount or 1)
        end
    end

    for userId, player in data.viewers do
        Remotes.StationClosed:FireClient(player, data.stationId)
    end

    stationIdToBlock[data.stationId] = nil
    stationData[blockId] = nil

    print("[StationHandler] Destroyed " .. data.stationType .. " station " .. data.stationId .. " for block " .. blockId)
end

-- ═══════════════════════════════════════════════════════════
-- Действия игрока
-- ═══════════════════════════════════════════════════════════

function StationHandler.depositToInput(player, stationId, inventorySlotIndex)
    local blockId = stationIdToBlock[stationId]
    local data = blockId and stationData[blockId]
    if not data then return end
    if not data.viewers[player.UserId] then return end

    local InventoryManager = require(modules:WaitForChild("InventoryManager"))
    local inv = InventoryManager.getInventory(player)
    if not inv or not inv.slots then return end

    local invSlot = inv.slots[inventorySlotIndex]
    if not invSlot or invSlot == false then return end

    local itemId = invSlot.Id or invSlot.ItemId
    local amount = invSlot.Amount or 1
    if not itemId then return end

    local itemDef = Config.Items[itemId]
    local maxStack = (itemDef and itemDef.MaxStack) or 99
    local remaining = amount

    for i, slot in data.inputSlots do
        if remaining <= 0 then break end
        if slot and slot ~= false and slot.ItemId == itemId then
            local canAdd = maxStack - slot.Amount
            if canAdd > 0 then
                local add = math.min(canAdd, remaining)
                slot.Amount += add
                remaining -= add
            end
        end
    end

    for i, slot in data.inputSlots do
        if remaining <= 0 then break end
        if not slot or slot == false then
            local add = math.min(maxStack, remaining)
            data.inputSlots[i] = { ItemId = itemId, Amount = add }
            remaining -= add
        end
    end

    local deposited = amount - remaining
    if deposited > 0 then
        InventoryManager.removeItem(player, inventorySlotIndex, deposited)
        local InventorySync = require(modules:WaitForChild("InventorySync"))
        InventorySync.sendFullUpdate(player)
        notifyViewers(data)
    end
end

function StationHandler.takeFromOutput(player, stationId, slotIndex)
    local blockId = stationIdToBlock[stationId]
    local data = blockId and stationData[blockId]
    if not data then return end
    if not data.viewers[player.UserId] then return end

    local slot = data.outputSlots[slotIndex]
    if not slot or slot == false then return end

    local InventoryManager = require(modules:WaitForChild("InventoryManager"))
    local added = InventoryManager.addItemFromConfig(player, slot.ItemId, slot.Amount)

    if added then
        data.outputSlots[slotIndex] = false
        local InventorySync = require(modules:WaitForChild("InventorySync"))
        InventorySync.sendFullUpdate(player)
        notifyViewers(data)
    end
end

function StationHandler.takeFromInput(player, stationId, slotIndex)
    local blockId = stationIdToBlock[stationId]
    local data = blockId and stationData[blockId]
    if not data then return end
    if not data.viewers[player.UserId] then return end

    local slot = data.inputSlots[slotIndex]
    if not slot or slot == false then return end

    local InventoryManager = require(modules:WaitForChild("InventoryManager"))
    local added = InventoryManager.addItemFromConfig(player, slot.ItemId, slot.Amount)

    if added then
        data.inputSlots[slotIndex] = false
        local InventorySync = require(modules:WaitForChild("InventorySync"))
        InventorySync.sendFullUpdate(player)
        notifyViewers(data)
    end
end

function StationHandler.takeFromInput(player, stationId, slotIndex)
    local blockId = stationIdToBlock[stationId]
    local data = blockId and stationData[blockId]
    if not data then return end
    if not data.viewers[player.UserId] then return end

    local slot = data.inputSlots[slotIndex]
    if not slot or slot == false then return end

    local InventoryManager = require(modules:WaitForChild("InventoryManager"))
    local added = InventoryManager.addItemFromConfig(player, slot.ItemId, slot.Amount)

    if added then
        data.inputSlots[slotIndex] = false
        local InventorySync = require(modules:WaitForChild("InventorySync"))
        InventorySync.sendFullUpdate(player)
        notifyViewers(data)
    end
end

function StationHandler.takeAllOutput(player, stationId)
    local blockId = stationIdToBlock[stationId]
    local data = blockId and stationData[blockId]
    if not data then return end
    if not data.viewers[player.UserId] then return end

    local InventoryManager = require(modules:WaitForChild("InventoryManager"))
    local InventorySync = require(modules:WaitForChild("InventorySync"))
    local anyTaken = false

    for i, slot in data.outputSlots do
        if slot and slot ~= false then
            local added = InventoryManager.addItemFromConfig(player, slot.ItemId, slot.Amount)
            if added then
                data.outputSlots[i] = false
                anyTaken = true
            end
        end
    end

    if anyTaken then
        InventorySync.sendFullUpdate(player)
        notifyViewers(data)
    end
end

function StationHandler.toggleRecipe(player, stationId, recipeId)
    local blockId = stationIdToBlock[stationId]
    local data = blockId and stationData[blockId]
    if not data then return end
    if not data.viewers[player.UserId] then return end

    local current = data.recipeToggles[recipeId]
    if current == nil then return end

    data.recipeToggles[recipeId] = not current

    if data.crafting and data.crafting.recipeId == recipeId and not data.recipeToggles[recipeId] then
        local recipes = getRecipesForType(data.stationType)
        local recipe = nil
        for _, r in recipes do
            if r.Id == recipeId then recipe = r; break end
        end
        if recipe then
            -- Возвращаем ингредиенты в input
            for _, ing in recipe.Ingredients do
                local toPlace = ing.Amount
                local itemDef = Config.Items[ing.ItemId]
                local maxStack = (itemDef and itemDef.MaxStack) or 99
                for i, slot in data.inputSlots do
                    if toPlace <= 0 then break end
                    if slot and slot ~= false and slot.ItemId == ing.ItemId then
                        local canAdd = maxStack - slot.Amount
                        if canAdd > 0 then
                            local add = math.min(canAdd, toPlace)
                            slot.Amount += add
                            toPlace -= add
                        end
                    end
                end
                for i, slot in data.inputSlots do
                    if toPlace <= 0 then break end
                    if not slot or slot == false then
                        local add = math.min(maxStack, toPlace)
                        data.inputSlots[i] = { ItemId = ing.ItemId, Amount = add }
                        toPlace -= add
                    end
                end
            end
        end
        data.crafting = nil
        setCraftingColor(data, false)
    end

    notifyViewers(data)
end

function StationHandler.closeStation(player, stationId)
    local blockId = stationIdToBlock[stationId]
    local data = blockId and stationData[blockId]
    if not data then return end
    data.viewers[player.UserId] = nil
end

-- ═══════════════════════════════════════════════════════════
-- Сериализация
-- ═══════════════════════════════════════════════════════════

local function serializeSlots(slots)
    local result = {}
    for i, slot in slots do
        if slot and slot ~= false then
            result[tostring(i)] = {
                Id = slot.ItemId,
                Amount = slot.Amount,
            }
        end
    end
    return result
end

function StationHandler.getSerializer()
    return function(stationId)
        local blockId = stationIdToBlock[stationId]
        local data = blockId and stationData[blockId]
        if not data then return nil end

        return {
            Id = data.stationId,
            Type = "station",
            StationType = data.stationType,
            InputSlots = serializeSlots(data.inputSlots),
            OutputSlots = serializeSlots(data.outputSlots),
            RecipeToggles = data.recipeToggles,
        }
    end
end

function StationHandler.restoreContainer(part, typeId, blockId, castle, savedData)
    local bt = Config.Building.BlockTypes[typeId]
    local stationType = savedData.StationType
        or (bt and bt.FunctionalData and bt.FunctionalData.StationType)
    if not stationType then
        warn("[StationHandler] Cannot restore: no StationType for block " .. blockId)
        return
    end

    local cfg = getStationConfig(stationType)
    local recipes = getRecipesForType(stationType)
    local stationId = savedData.Id or makeStationId(stationType)

    local inputSlots = makeEmptySlots(cfg.InputSlots)
    if savedData.InputSlots then
        for strIdx, slotData in savedData.InputSlots do
            local idx = tonumber(strIdx)
            if idx and idx >= 1 and idx <= cfg.InputSlots and slotData.Id then
                inputSlots[idx] = { ItemId = slotData.Id, Amount = slotData.Amount or 1 }
            end
        end
    end

    local outputSlots = makeEmptySlots(cfg.OutputSlots)
    if savedData.OutputSlots then
        for strIdx, slotData in savedData.OutputSlots do
            local idx = tonumber(strIdx)
            if idx and idx >= 1 and idx <= cfg.OutputSlots and slotData.Id then
                outputSlots[idx] = { ItemId = slotData.Id, Amount = slotData.Amount or 1 }
            end
        end
    end

    local toggles = {}
    for _, recipe in recipes do
        toggles[recipe.Id] = true
    end
    if savedData.RecipeToggles then
        for recipeId, val in savedData.RecipeToggles do
            if toggles[recipeId] ~= nil then
                toggles[recipeId] = val
            end
        end
    end

    local data = {
        stationId = stationId,
        stationType = stationType,
        part = part,
        inputSlots = inputSlots,
        outputSlots = outputSlots,
        recipeToggles = toggles,
        crafting = nil,
        viewers = {},
        originalColor = bt and bt.Color or Color3.fromRGB(128, 128, 128),
    }

    stationData[blockId] = data
    stationIdToBlock[stationId] = blockId

    part:SetAttribute("StationId", stationId)
    part:SetAttribute("StationType", stationType)
    part:SetAttribute("FunctionalType", "Station")

    if castle and castle.blocks[blockId] then
        castle.blocks[blockId].stationId = stationId
    end

    startHeartbeat()

    print("[StationHandler] Restored " .. stationType .. " station " .. stationId .. " for block " .. blockId)
end

function StationHandler.dropAllLoot(castle)
    for blockId, block in castle.blocks do
        if stationData[blockId] then
            StationHandler.onDestroy(block.part, blockId)
        end
    end
end

function StationHandler.getStationId(blockId)
    local data = stationData[blockId]
    return data and data.stationId or nil
end

return StationHandler