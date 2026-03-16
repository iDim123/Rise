--[[
    SawmillHandler.luau
    Лесопилка — автоматическая крафтовая станция.

    Жизненный цикл:
      onCreate    — создаёт input/output контейнеры, запускает крафт-цикл
      interact    — открывает SawmillUI для игрока (отправляет данные по ремоту)
      onDestroy   — дропает содержимое input/output, останавливает крафт, удаляет контейнеры
    
    Сериализация:
      getSerializer() → function(containerId) → { Id, InputSlots, OutputSlots, ... }
      restoreContainer(part, blockId, castle, savedData) — восстановление из DataStore
    
    Крафт-логика:
      - RunService.Heartbeat проверяет input каждой лесопилки
      - Если input содержит ингредиенты для активного рецепта → запускает крафт
      - Рецепты обрабатываются в порядке конфига
      - Каждый рецепт имеет toggle (вкл/выкл), по умолчанию все включены
      - Множественный output: Results[] — массив { ItemId, Amount }
      - Прогресс крафта отправляется клиентам через SawmillCraftProgress
      - При завершении: забирает ингредиенты из input, кладёт результаты в output
      - Если output полный — крафт приостанавливается

    Многопользовательский доступ: да, несколько игроков могут открыть одну лесопилку.

    Используется: FunctionalDispatcher
    Зависимости: ContainerManager, CastleBorder, LootManager, Config, Remotes
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

local SawmillHandler = {}

-- ═══════════════════════════════════════════════════════════
-- Конфигурация
-- ═══════════════════════════════════════════════════════════

local INPUT_SLOTS = 8
local OUTPUT_SLOTS = 8
local INTERACT_RANGE = 10

-- ═══════════════════════════════════════════════════════════
-- Состояние
-- ═══════════════════════════════════════════════════════════

-- sawmillData[blockId] = {
--   sawmillId: string,
--   part: BasePart,
--   inputSlots: { [1..8] = false | { ItemId, Amount } },
--   outputSlots: { [1..8] = false | { ItemId, Amount } },
--   recipeToggles: { [recipeId] = bool },  -- true = active
--   crafting: { recipeId, elapsed, duration } | nil,
--   viewers: { [userId] = Player },
--   originalColor: Color3,
-- }
local sawmillData = {}

-- Обратный поиск: sawmillId → blockId
local sawmillIdToBlock = {}

-- Рецепты лесопилки (кэшируются при init)
local sawmillRecipes = {}

-- ═══════════════════════════════════════════════════════════
-- Утилиты
-- ═══════════════════════════════════════════════════════════

local function makeSawmillId()
    return "sawmill_" .. tostring(math.floor(os.clock() * 1000)) .. "_" .. tostring(math.random(1, 99999))
end

--- Создать пустые слоты
local function makeEmptySlots(count)
    local slots = {}
    for i = 1, count do
        slots[i] = false
    end
    return slots
end

--- Подсчитать количество каждого предмета в слотах
local function countItems(slots)
    local counts = {}
    for _, slot in slots do
        if slot and slot ~= false then
            counts[slot.ItemId] = (counts[slot.ItemId] or 0) + (slot.Amount or 1)
        end
    end
    return counts
end

--- Проверить, хватает ли ингредиентов в input
local function hasIngredients(inputCounts, recipe)
    for _, ing in recipe.Ingredients do
        if (inputCounts[ing.ItemId] or 0) < ing.Amount then
            return false
        end
    end
    return true
end

--- Забрать ингредиенты из input слотов (мутирует slots)
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

--- Попробовать добавить предмет в output слоты.
--- Возвращает true если ВСЕ результаты помещаются, false иначе.
--- НЕ мутирует слоты — только проверка.
local function canFitResults(slots, recipe)
    -- Создаём копию слотов для симуляции
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

        -- Сначала доливаем в существующие стаки
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

        -- Затем используем пустые слоты
        for i, slot in simSlots do
            if toPlace <= 0 then break end
            if not slot or slot == false then
                local add = math.min(maxStack, toPlace)
                simSlots[i] = { ItemId = res.ItemId, Amount = add }
                toPlace -= add
            end
        end

        if toPlace > 0 then
            return false -- не помещается
        end
    end
    return true
end

--- Добавить результаты крафта в output слоты (мутирует slots)
local function placeResults(slots, recipe)
    local results = recipe.Results or {}
    if recipe.Result and not recipe.Results then
        results = { recipe.Result }
    end

    for _, res in results do
        local toPlace = res.Amount
        local itemDef = Config.Items[res.ItemId]
        local maxStack = (itemDef and itemDef.MaxStack) or 99

        -- Доливаем в существующие стаки
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

        -- Пустые слоты
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

--- Отправить обновление всем просматривающим
local function notifyViewers(data)
    local payload = {
        SawmillId = data.sawmillId,
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
        Remotes.SawmillUpdate:FireClient(player, payload)
    end
end

--- Установить цвет крафта на модели
local function setCraftingColor(data, isCrafting)
    if not data.part or not data.part.Parent then return end
    if isCrafting then
        data.part.Color = Color3.fromRGB(180, 140, 60) -- жёлто-золотой
    else
        data.part.Color = data.originalColor
    end
end

-- ═══════════════════════════════════════════════════════════
-- Инициализация рецептов
-- ═══════════════════════════════════════════════════════════

local function loadRecipes()
    sawmillRecipes = {}
    local allRecipes = Config.Crafting and Config.Crafting.Recipes or {}
    for _, recipe in allRecipes do
        if recipe.Station == "Sawmill" then
            table.insert(sawmillRecipes, recipe)
        end
    end
    print("[SawmillHandler] Loaded " .. #sawmillRecipes .. " sawmill recipes")
end

-- ═══════════════════════════════════════════════════════════
-- Крафт-цикл (Heartbeat)
-- ═══════════════════════════════════════════════════════════

local function processSawmill(data, dt)
    -- Если уже крафтим — продолжаем
    if data.crafting then
        data.crafting.elapsed += dt

        if data.crafting.elapsed >= data.crafting.duration then
            -- Крафт завершён
            local recipe = nil
            for _, r in sawmillRecipes do
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

    -- Ищем следующий рецепт для крафта
    local inputCounts = countItems(data.inputSlots)

    for _, recipe in sawmillRecipes do
        -- Проверяем toggle
        if data.recipeToggles[recipe.Id] == false then
            continue
        end

        -- Проверяем ингредиенты
        if not hasIngredients(inputCounts, recipe) then
            continue
        end

        -- Проверяем место в output
        if not canFitResults(data.outputSlots, recipe) then
            continue
        end

        -- Запускаем крафт!
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

-- Подключаем Heartbeat
local heartbeatConn = nil

local function startHeartbeat()
    if heartbeatConn then return end

    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        for _, data in sawmillData do
            processSawmill(data, dt)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- Жизненный цикл
-- ═══════════════════════════════════════════════════════════

--- Создать лесопилку при размещении блока.
function SawmillHandler.onCreate(part, typeId, blockId, castle)
    if #sawmillRecipes == 0 then
        loadRecipes()
    end

    local sawmillId = makeSawmillId()

    -- Дефолтные toggles: все рецепты включены
    local toggles = {}
    for _, recipe in sawmillRecipes do
        toggles[recipe.Id] = true
    end

    local bt = Config.Building.BlockTypes[typeId]
    local origColor = bt and bt.Color or Color3.fromRGB(130, 85, 40)

    local data = {
        sawmillId = sawmillId,
        part = part,
        inputSlots = makeEmptySlots(INPUT_SLOTS),
        outputSlots = makeEmptySlots(OUTPUT_SLOTS),
        recipeToggles = toggles,
        crafting = nil,
        viewers = {},
        originalColor = origColor,
    }

    sawmillData[blockId] = data
    sawmillIdToBlock[sawmillId] = blockId

    -- Атрибуты на Part для клиентского UI
    part:SetAttribute("SawmillId", sawmillId)
    part:SetAttribute("FunctionalType", "Sawmill")

    -- Обновить blockData в замке
    if castle and castle.blocks[blockId] then
        castle.blocks[blockId].sawmillId = sawmillId
    end

    startHeartbeat()

    print("[SawmillHandler] Created sawmill " .. sawmillId .. " for block " .. blockId)
    return sawmillId
end

--- Взаимодействие с лесопилкой (F).
function SawmillHandler.interact(player, part, blockData, castle)
    -- Проверка прав
    local ownerId = part:GetAttribute("CastleOwnerId")
    if ownerId then
        if not CastleBorder.canInteract(player.UserId, ownerId) then
            return false, "Нет прав доступа"
        end
    end

    local sawmillId = part:GetAttribute("SawmillId")
    if not sawmillId then
        return false, "Лесопилка не инициализирована"
    end

    -- Найти данные
    local blockId = sawmillIdToBlock[sawmillId]
    local data = blockId and sawmillData[blockId]
    if not data then
        return false, "Данные лесопилки не найдены"
    end

    -- Добавить viewer
    data.viewers[player.UserId] = player

    -- Отправить полные данные клиенту
    local payload = {
        SawmillId = data.sawmillId,
        InputSlots = data.inputSlots,
        OutputSlots = data.outputSlots,
        RecipeToggles = data.recipeToggles,
        Recipes = sawmillRecipes,
        Crafting = data.crafting and {
            RecipeId = data.crafting.recipeId,
            Elapsed = data.crafting.elapsed,
            Duration = data.crafting.duration,
        } or nil,
    }

    Remotes.SawmillOpened:FireClient(player, payload)
    return true
end

--- Уничтожить лесопилку — дропнуть содержимое.
function SawmillHandler.onDestroy(part, blockId)
    -- Найти blockId если не передан
    if not blockId then
        for bId, data in sawmillData do
            if data.part == part then
                blockId = bId
                break
            end
        end
    end

    if not blockId or not sawmillData[blockId] then
        return
    end

    local data = sawmillData[blockId]
    local dropPos = part.Position

    -- Дроп input
    for _, slot in data.inputSlots do
        if slot and slot ~= false then
            getLootManager().dropItemAtPosition(dropPos, slot.ItemId, slot.Amount or 1)
        end
    end

    -- Дроп output
    for _, slot in data.outputSlots do
        if slot and slot ~= false then
            getLootManager().dropItemAtPosition(dropPos, slot.ItemId, slot.Amount or 1)
        end
    end

    -- Закрыть UI для всех viewers
    for userId, player in data.viewers do
        Remotes.SawmillClosed:FireClient(player, data.sawmillId)
    end

    -- Очистка
    sawmillIdToBlock[data.sawmillId] = nil
    sawmillData[blockId] = nil

    print("[SawmillHandler] Destroyed sawmill " .. tostring(data.sawmillId) .. " for block " .. tostring(blockId))
end

-- ═══════════════════════════════════════════════════════════
-- Действия игрока (вызываются через Remotes)
-- ═══════════════════════════════════════════════════════════

--- Игрок кладёт предмет из инвентаря в input лесопилки.
function SawmillHandler.depositToInput(player, sawmillId, inventorySlotIndex)
    local blockId = sawmillIdToBlock[sawmillId]
    local data = blockId and sawmillData[blockId]
    if not data then return end

    -- Проверяем viewer
    if not data.viewers[player.UserId] then return end

    local InventoryManager = require(modules:WaitForChild("InventoryManager"))
    local inv = InventoryManager.getInventory(player)
    if not inv or not inv.slots then return end

    local invSlot = inv.slots[inventorySlotIndex]
    if not invSlot or invSlot == false then return end

    local itemId = invSlot.Id or invSlot.ItemId
    local amount = invSlot.Amount or 1
    if not itemId then return end

    -- Проверяем, есть ли место в input
    local itemDef = Config.Items[itemId]
    local maxStack = (itemDef and itemDef.MaxStack) or 99
    local remaining = amount

    -- Пробуем доложить в существующие стаки
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

    -- Пустые слоты
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
        InventoryManager.removeItemBySlot(player, inventorySlotIndex, deposited)
        local InventorySync = require(modules:WaitForChild("InventorySync"))
        InventorySync.sendFullUpdate(player)
        notifyViewers(data)
    end
end

--- Игрок забирает предмет из output лесопилки.
function SawmillHandler.takeFromOutput(player, sawmillId, slotIndex)
    local blockId = sawmillIdToBlock[sawmillId]
    local data = blockId and sawmillData[blockId]
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

--- Забрать ВСЁ из output.
function SawmillHandler.takeAllOutput(player, sawmillId)
    local blockId = sawmillIdToBlock[sawmillId]
    local data = blockId and sawmillData[blockId]
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

--- Переключить рецепт вкл/выкл.
function SawmillHandler.toggleRecipe(player, sawmillId, recipeId)
    local blockId = sawmillIdToBlock[sawmillId]
    local data = blockId and sawmillData[blockId]
    if not data then return end

    if not data.viewers[player.UserId] then return end

    local current = data.recipeToggles[recipeId]
    if current == nil then return end -- неизвестный рецепт

    data.recipeToggles[recipeId] = not current

    -- Если выключили активный крафт — отменяем и возвращаем ингредиенты
    if data.crafting and data.crafting.recipeId == recipeId and not data.recipeToggles[recipeId] then
        -- Возврат ингредиентов
        local recipe = nil
        for _, r in sawmillRecipes do
            if r.Id == recipeId then
                recipe = r
                break
            end
        end
        if recipe then
            placeResults(data.inputSlots, { Results = recipe.Ingredients }) -- "Results" трюк для reuse
        end
        data.crafting = nil
        setCraftingColor(data, false)
    end

    notifyViewers(data)
end

--- Игрок закрывает UI лесопилки.
function SawmillHandler.closeSawmill(player, sawmillId)
    local blockId = sawmillIdToBlock[sawmillId]
    local data = blockId and sawmillData[blockId]
    if not data then return end

    data.viewers[player.UserId] = nil
end

-- ═══════════════════════════════════════════════════════════
-- Сериализация
-- ═══════════════════════════════════════════════════════════

--- Сериализовать слоты (input или output).
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

--- Получить функцию-сериализатор для BuildingSerializer.
function SawmillHandler.getSerializer()
    return function(sawmillId)
        local blockId = sawmillIdToBlock[sawmillId]
        local data = blockId and sawmillData[blockId]
        if not data then return nil end

        return {
            Id = data.sawmillId,
            Type = "sawmill",
            InputSlots = serializeSlots(data.inputSlots),
            OutputSlots = serializeSlots(data.outputSlots),
            RecipeToggles = data.recipeToggles,
        }
    end
end

--- Восстановить лесопилку из DataStore.
function SawmillHandler.restoreContainer(part, typeId, blockId, castle, savedData)
    if #sawmillRecipes == 0 then
        loadRecipes()
    end

    local sawmillId = savedData.Id or makeSawmillId()

    -- Восстановить input слоты
    local inputSlots = makeEmptySlots(INPUT_SLOTS)
    if savedData.InputSlots then
        for strIdx, slotData in savedData.InputSlots do
            local idx = tonumber(strIdx)
            if idx and idx >= 1 and idx <= INPUT_SLOTS and slotData.Id then
                inputSlots[idx] = {
                    ItemId = slotData.Id,
                    Amount = slotData.Amount or 1,
                }
            end
        end
    end

    -- Восстановить output слоты
    local outputSlots = makeEmptySlots(OUTPUT_SLOTS)
    if savedData.OutputSlots then
        for strIdx, slotData in savedData.OutputSlots do
            local idx = tonumber(strIdx)
            if idx and idx >= 1 and idx <= OUTPUT_SLOTS and slotData.Id then
                outputSlots[idx] = {
                    ItemId = slotData.Id,
                    Amount = slotData.Amount or 1,
                }
            end
        end
    end

    -- Восстановить toggles
    local toggles = {}
    for _, recipe in sawmillRecipes do
        toggles[recipe.Id] = true -- default on
    end
    if savedData.RecipeToggles then
        for recipeId, val in savedData.RecipeToggles do
            if toggles[recipeId] ~= nil then
                toggles[recipeId] = val
            end
        end
    end

    local bt = Config.Building.BlockTypes[typeId]
    local origColor = bt and bt.Color or Color3.fromRGB(130, 85, 40)

    local data = {
        sawmillId = sawmillId,
        part = part,
        inputSlots = inputSlots,
        outputSlots = outputSlots,
        recipeToggles = toggles,
        crafting = nil,
        viewers = {},
        originalColor = origColor,
    }

    sawmillData[blockId] = data
    sawmillIdToBlock[sawmillId] = blockId

    part:SetAttribute("SawmillId", sawmillId)
    part:SetAttribute("FunctionalType", "Sawmill")

    if castle and castle.blocks[blockId] then
        castle.blocks[blockId].sawmillId = sawmillId
    end

    startHeartbeat()

    print("[SawmillHandler] Restored sawmill " .. sawmillId .. " for block " .. blockId)
end

--- Дропнуть содержимое всех лесопилок замка (при уничтожении Castle Heart).
function SawmillHandler.dropAllLoot(castle)
    for blockId, block in castle.blocks do
        if sawmillData[blockId] then
            SawmillHandler.onDestroy(block.part, blockId)
        end
    end
end

--- Получить sawmillId по blockId.
function SawmillHandler.getSawmillId(blockId)
    local data = sawmillData[blockId]
    return data and data.sawmillId or nil
end

return SawmillHandler