--[[
    CraftStationHandler.luau
    Универсальный обработчик крафтовых станций (Workbench, Forge, ...).

    Отличие от StationHandler (Sawmill/Crusher):
      - Нет разделения input/output — единый контейнер (N слотов).
      - Крафт запускается игроком вручную (по клику на рецепт).
      - Ресурсы берутся сначала из контейнера, потом из инвентаря.
      - Результат помещается в контейнер (если нет места — дроп).
      - Очередь крафта привязана к станции, не к игроку.

    Используется: FunctionalDispatcher
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

local _InventoryManager
local function getInventoryManager()
    if not _InventoryManager then
        _InventoryManager = require(modules:WaitForChild("InventoryManager"))
    end
    return _InventoryManager
end

local _InventorySync
local function getInventorySync()
    if not _InventorySync then
        _InventorySync = require(modules:WaitForChild("InventorySync"))
    end
    return _InventorySync
end

local CraftStationHandler = {}

-- ═══════════════════════════════════════════════════════════
-- Состояние
-- ═══════════════════════════════════════════════════════════

-- csData[blockId] = {
--   csId: string,
--   stationType: string,  -- "Workbench", "Forge", ...
--   part: BasePart,
--   slots: { [1..N] = false | { ItemId, Amount } },
--   craftQueue: { { recipeId, elapsed, duration }, ... },
--   viewers: { [userId] = Player },
-- }
local csData = {}
local csIdToBlock = {} -- csId → blockId

-- Кэш рецептов по типу станции
local recipeCache = {} -- { ["Workbench"] = { recipe, ... } }

-- ═══════════════════════════════════════════════════════════
-- Утилиты
-- ═══════════════════════════════════════════════════════════

local function makeCsId(stationType)
    return "cs_" .. stationType:lower() .. "_" .. tostring(math.floor(os.clock() * 1000))
        .. "_" .. tostring(math.random(1, 99999))
end

local function makeEmptySlots(count)
    local slots = {}
    for i = 1, count do
        slots[i] = false
    end
    return slots
end

local function getCraftStationConfig(stationType)
    local cfg = Config.Stations
        and Config.Stations.CraftStations
        and Config.Stations.CraftStations[stationType]
    -- Фоллбэк: ищем в корне Config.CraftStations (на случай другой структуры Config.luau)
    if not cfg then
        cfg = Config.CraftStations and Config.CraftStations[stationType]
    end
    return cfg or {
        Name = stationType,
        Slots = 9,
        InteractRange = 10,
    }
end

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
    print("[CraftStationHandler] Loaded " .. #recipes .. " recipes for " .. stationType)
    return recipes
end

local function findRecipeById(stationType, recipeId)
    for _, r in getRecipesForType(stationType) do
        if r.Id == recipeId then return r end
    end
    return nil
end

-- ═══ Slot utilities ═══

local function countItemsInSlots(slots)
    local counts = {}
    for _, slot in slots do
        if slot and slot ~= false then
            counts[slot.ItemId] = (counts[slot.ItemId] or 0) + (slot.Amount or 1)
        end
    end
    return counts
end

local function removeFromSlots(slots, itemId, amount)
    local remaining = amount
    for i = #slots, 1, -1 do
        if remaining <= 0 then break end
        local slot = slots[i]
        if slot and slot ~= false and slot.ItemId == itemId then
            local take = math.min(slot.Amount, remaining)
            slot.Amount -= take
            remaining -= take
            if slot.Amount <= 0 then
                slots[i] = false
            end
        end
    end
    return remaining
end

local function addToSlots(slots, itemId, amount)
    local remaining = amount
    local itemDef = Config.Items[itemId]
    local maxStack = (itemDef and itemDef.MaxStack) or 99

    for i, slot in slots do
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

    for i, slot in slots do
        if remaining <= 0 then break end
        if not slot or slot == false then
            local add = math.min(maxStack, remaining)
            slots[i] = { ItemId = itemId, Amount = add }
            remaining -= add
        end
    end

    return remaining
end

-- ═══════════════════════════════════════════════════════════
-- Уведомления
-- ═══════════════════════════════════════════════════════════

local function buildPayload(data)
    local currentCraft = nil
    if data.craftQueue and #data.craftQueue > 0 then
        local c = data.craftQueue[1]
        currentCraft = {
            RecipeId = c.recipeId,
            Elapsed = c.elapsed,
            Duration = c.duration,
        }
    end

    local queueCounts = {}
    for _, entry in data.craftQueue do
        queueCounts[entry.recipeId] = (queueCounts[entry.recipeId] or 0) + 1
    end

    return {
        CsId = data.csId,
        StationType = data.stationType,
        Slots = data.slots,
        Crafting = currentCraft,
        QueueCounts = queueCounts,
    }
end

local function notifyViewers(data)
    local payload = buildPayload(data)
    for _, player in data.viewers do
        Remotes.CraftStationUpdate:FireClient(player, payload)
    end
end

-- ═══════════════════════════════════════════════════════════
-- Крафт-цикл (Heartbeat)
-- ═══════════════════════════════════════════════════════════

local function processCraftStation(data, dt)
    if not data.craftQueue or #data.craftQueue == 0 then return end

    local current = data.craftQueue[1]
    current.elapsed += dt

    if current.elapsed >= current.duration then
        local recipe = findRecipeById(data.stationType, current.recipeId)
        if recipe then
            local results = recipe.Results or {}
            if recipe.Result and not recipe.Results then
                results = { recipe.Result }
            end

            for _, res in results do
                local leftover = addToSlots(data.slots, res.ItemId, res.Amount or 1)
                if leftover > 0 and data.part and data.part.Parent then
                    getLootManager().dropItemAtPosition(data.part.Position, res.ItemId, leftover)
                end
            end
        end

        table.remove(data.craftQueue, 1)
        notifyViewers(data)
    end
end

local heartbeatConn = nil

local function startHeartbeat()
    if heartbeatConn then return end
    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        for _, data in csData do
            processCraftStation(data, dt)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- Жизненный цикл
-- ═══════════════════════════════════════════════════════════

function CraftStationHandler.onCreate(part, typeId, blockId, castle)
    local bt = Config.Building.BlockTypes[typeId]
    local stationType = bt and bt.FunctionalData and bt.FunctionalData.StationType
    if not stationType then
        warn("[CraftStationHandler] No StationType for " .. typeId)
        return nil
    end

    local cfg = getCraftStationConfig(stationType)
    local csId = makeCsId(stationType)

    local data = {
        csId = csId,
        stationType = stationType,
        part = part,
        slots = makeEmptySlots(cfg.Slots),
        craftQueue = {},
        viewers = {},
    }

    csData[blockId] = data
    csIdToBlock[csId] = blockId

    part:SetAttribute("CraftStationId", csId)
    part:SetAttribute("CraftStationType", stationType)
    part:SetAttribute("FunctionalType", "CraftStation")

    if castle and castle.blocks[blockId] then
        castle.blocks[blockId].csId = csId
    end

    startHeartbeat()

    print("[CraftStationHandler] Created " .. stationType .. " (" .. csId .. ") for block " .. blockId)
    return csId
end

function CraftStationHandler.interact(player, part, blockData, castle)
    local ownerId = part:GetAttribute("CastleOwnerId")
    if ownerId then
        if not CastleBorder.canInteract(player.UserId, ownerId) then
            return false, "Нет прав доступа"
        end
    end

    local csId = part:GetAttribute("CraftStationId")
    if not csId then
        return false, "Крафтовая станция не инициализирована"
    end

    local blockId = csIdToBlock[csId]
    local data = blockId and csData[blockId]
    if not data then
        return false, "Данные станции не найдены"
    end

    data.viewers[player.UserId] = player

    local recipes = getRecipesForType(data.stationType)
    local cfg = getCraftStationConfig(data.stationType)

    local currentCraft = nil
    if #data.craftQueue > 0 then
        local c = data.craftQueue[1]
        currentCraft = {
            RecipeId = c.recipeId,
            Elapsed = c.elapsed,
            Duration = c.duration,
        }
    end

    local queueCounts = {}
    for _, entry in data.craftQueue do
        queueCounts[entry.recipeId] = (queueCounts[entry.recipeId] or 0) + 1
    end

    local payload = {
        CsId = data.csId,
        StationType = data.stationType,
        StationName = cfg.Name,
        Slots = data.slots,
        Recipes = recipes,
        Crafting = currentCraft,
        QueueCounts = queueCounts,
    }

    Remotes.CraftStationOpened:FireClient(player, payload)
    return true
end

function CraftStationHandler.onDestroy(part, blockId)
    if not blockId then
        for bId, data in csData do
            if data.part == part then
                blockId = bId
                break
            end
        end
    end

    if not blockId or not csData[blockId] then return end

    local data = csData[blockId]
    local dropPos = part.Position

    -- Дропаем содержимое контейнера
    for _, slot in data.slots do
        if slot and slot ~= false then
            getLootManager().dropItemAtPosition(dropPos, slot.ItemId, slot.Amount or 1)
        end
    end

    -- Уведомляем зрителей
    for _, player in data.viewers do
        Remotes.CraftStationClosed:FireClient(player, data.csId)
    end

    csIdToBlock[data.csId] = nil
    csData[blockId] = nil

    print("[CraftStationHandler] Destroyed " .. data.stationType .. " (" .. data.csId .. ")")
end

-- ═══════════════════════════════════════════════════════════
-- Действия игрока
-- ═══════════════════════════════════════════════════════════

function CraftStationHandler.depositItem(player, csId, inventorySlotIndex)
    local blockId = csIdToBlock[csId]
    local data = blockId and csData[blockId]
    if not data then return end
    if not data.viewers[player.UserId] then return end

    local InventoryManager = getInventoryManager()
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

    for i, slot in data.slots do
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

    for i, slot in data.slots do
        if remaining <= 0 then break end
        if not slot or slot == false then
            local add = math.min(maxStack, remaining)
            data.slots[i] = { ItemId = itemId, Amount = add }
            remaining -= add
        end
    end

    local deposited = amount - remaining
    if deposited > 0 then
        InventoryManager.removeItem(player, inventorySlotIndex, deposited)
        getInventorySync().sendFullUpdate(player)
        notifyViewers(data)
    end
end

function CraftStationHandler.takeItem(player, csId, slotIndex)
    local blockId = csIdToBlock[csId]
    local data = blockId and csData[blockId]
    if not data then return end
    if not data.viewers[player.UserId] then return end

    local slot = data.slots[slotIndex]
    if not slot or slot == false then return end

    local InventoryManager = getInventoryManager()
    local added = InventoryManager.addItemFromConfig(player, slot.ItemId, slot.Amount)

    if added then
        data.slots[slotIndex] = false
        getInventorySync().sendFullUpdate(player)
        notifyViewers(data)
    end
end

function CraftStationHandler.craft(player, csId, recipeId)
    local blockId = csIdToBlock[csId]
    local data = blockId and csData[blockId]
    if not data then return end
    if not data.viewers[player.UserId] then return end

    local recipe = findRecipeById(data.stationType, recipeId)
    if not recipe then return end

    local InventoryManager = getInventoryManager()
    local slotCounts = countItemsInSlots(data.slots)

    -- Проверяем достаточность ресурсов (контейнер + инвентарь)
    for _, ing in recipe.Ingredients do
        local inSlots = slotCounts[ing.ItemId] or 0
        local inInv = InventoryManager.countItem(player, ing.ItemId)
        if inSlots + inInv < ing.Amount then
            Remotes.Notify:FireClient(player, "Недостаточно ресурсов!", "warning")
            return
        end
    end

    -- Списываем: сначала из контейнера, потом из инвентаря
    local invChanged = false
    for _, ing in recipe.Ingredients do
        local needed = ing.Amount

        -- Сколько есть в контейнере
        local inSlots = 0
        for _, slot in data.slots do
            if slot and slot ~= false and slot.ItemId == ing.ItemId then
                inSlots += slot.Amount
            end
        end

        local fromSlots = math.min(inSlots, needed)
        if fromSlots > 0 then
            removeFromSlots(data.slots, ing.ItemId, fromSlots)
            needed -= fromSlots
        end

        if needed > 0 then
            InventoryManager.removeItemById(player, ing.ItemId, needed)
            invChanged = true
        end
    end

    if invChanged then
        getInventorySync().sendFullUpdate(player)
    end

    -- Добавляем в очередь крафта станции
    table.insert(data.craftQueue, {
        recipeId = recipeId,
        elapsed = 0,
        duration = recipe.CraftTime or 0,
    })

    notifyViewers(data)
    print("[CraftStationHandler] " .. player.Name .. " queued " .. recipeId .. " on " .. data.stationType)
end

function CraftStationHandler.closeStation(player, csId)
    local blockId = csIdToBlock[csId]
    local data = blockId and csData[blockId]
    if not data then return end
    data.viewers[player.UserId] = nil
end

-- ═══════════════════════════════════════════════════════════
-- Утилиты для замка
-- ═══════════════════════════════════════════════════════════

function CraftStationHandler.dropAllLoot(castle)
    for blockId, block in castle.blocks do
        if csData[blockId] then
            CraftStationHandler.onDestroy(block.part, blockId)
        end
    end
end

function CraftStationHandler.getCsId(blockId)
    local data = csData[blockId]
    return data and data.csId or nil
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

function CraftStationHandler.getSerializer()
    return function(csId)
        local blockId = csIdToBlock[csId]
        local data = blockId and csData[blockId]
        if not data then return nil end

        return {
            Id = data.csId,
            Type = "craftstation",
            StationType = data.stationType,
            Slots = serializeSlots(data.slots),
        }
    end
end

function CraftStationHandler.restoreContainer(part, typeId, blockId, castle, savedData)
    local bt = Config.Building.BlockTypes[typeId]
    local stationType = savedData.StationType
        or (bt and bt.FunctionalData and bt.FunctionalData.StationType)
    if not stationType then
        warn("[CraftStationHandler] Cannot restore: no StationType for block " .. blockId)
        return
    end

    local cfg = getCraftStationConfig(stationType)
    local csId = savedData.Id or makeCsId(stationType)

    local slots = makeEmptySlots(cfg.Slots)
    if savedData.Slots then
        for strIdx, slotData in savedData.Slots do
            local idx = tonumber(strIdx)
            if idx and idx >= 1 and idx <= cfg.Slots and slotData.Id then
                slots[idx] = { ItemId = slotData.Id, Amount = slotData.Amount or 1 }
            end
        end
    end

    local data = {
        csId = csId,
        stationType = stationType,
        part = part,
        slots = slots,
        craftQueue = {},
        viewers = {},
    }

    csData[blockId] = data
    csIdToBlock[csId] = blockId

    part:SetAttribute("CraftStationId", csId)
    part:SetAttribute("CraftStationType", stationType)
    part:SetAttribute("FunctionalType", "CraftStation")

    if castle and castle.blocks[blockId] then
        castle.blocks[blockId].csId = csId
    end

    startHeartbeat()

    print("[CraftStationHandler] Restored " .. stationType .. " (" .. csId .. ") for block " .. blockId)
end


--- Проверить, есть ли предметы в контейнере станции или активный крафт.
--- @param blockId string
--- @return boolean
function CraftStationHandler.hasItems(blockId)
    local data = csData[blockId]
    if not data then return false end

    -- Проверяем слоты
    for _, slot in data.slots do
        if slot and slot ~= false then
            return true
        end
    end

    -- Проверяем очередь крафта
    if data.craftQueue and #data.craftQueue > 0 then
        return true
    end

    return false
end

return CraftStationHandler