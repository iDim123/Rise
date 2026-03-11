--[[
    ChestHandler.luau
    Сундуки внутри замка.

    Жизненный цикл:
      onCreate  — регистрирует контейнер в ContainerManager
      interact  — открывает ContainerUI для игрока
      onDestroy — дропает содержимое, удаляет контейнер
    
    Сериализация:
      getSerializer() → function(containerId) → { Id, Slots }
      restoreContainer(part, blockId, savedContainer) — восстановление из DataStore

    Используется: FunctionalDispatcher
    Зависимости: ContainerManager, CastleBorder, LootManager, Config
]] local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local CastleBorder = require(modules:WaitForChild("building"):WaitForChild("CastleBorder"))

-- Lazy requires
local _LootManager, _ContainerManager
local function getLootManager()
    if not _LootManager then
        _LootManager = require(modules:WaitForChild("LootManager"))
    end
    return _LootManager
end
local function getContainerManager()
    if not _ContainerManager then
        _ContainerManager = require(modules:WaitForChild("container"):WaitForChild("ContainerManager"))
    end
    return _ContainerManager
end

local ChestHandler = {}

-- chestData[blockId] = { containerId, part }
local chestData = {}

-- Обратный поиск: containerId → blockId
local containerToBlock = {}

--- Генерировать уникальный ID контейнера для замкового сундука.
local function makeContainerId()
    return "castle_chest_" .. tostring(math.floor(os.clock() * 1000)) .. "_" .. tostring(math.random(1, 99999))
end

--- Получить конфиг замкового сундука.
local function getChestConfig(typeId)
    local bt = Config.Building.BlockTypes[typeId]
    if not bt or not bt.FunctionalData then
        return {
            Slots = 12,
            InteractRange = 8
        }
    end
    return {
        Slots = bt.FunctionalData.Slots or 12,
        InteractRange = bt.FunctionalData.InteractRange or 8
    }
end

-- ═══════════════════════════════════════════════════════════
-- Жизненный цикл
-- ═══════════════════════════════════════════════════════════

--- Создать сундук при размещении блока.
--- @param part BasePart — Part сундука
--- @param typeId string — ID типа блока
--- @param blockId string — ID блока в BuildingManager
--- @param castle table — данные замка
--- @return string — containerId
function ChestHandler.onCreate(part, typeId, blockId, castle)
    local cfg = getChestConfig(typeId)
    local containerId = makeContainerId()

    -- Создаём пустые слоты
    local slots = {}
    for i = 1, cfg.Slots do
        slots[i] = false
    end

    -- Регистрируем в ContainerManager как кастомный контейнер
    local CM = getContainerManager()
    local containers = CM.getAll()

    containers[containerId] = {
        id = containerId,
        cfgId = "castle_chest",
        config = {
            Name = "Сундук",
            Slots = cfg.Slots,
            CastTime = 0,
            CastMovementMode = "CancelOnMove",
            CastCancelKey = "MMB",
            InteractRange = cfg.InteractRange,
            DespawnTime = math.huge, -- никогда не деспавнится
            Persistent = true
        },
        state = "Active",
        model = part,
        slots = slots,
        openedBy = {},
        spawnPoint = part,
        despawnTimer = nil,
        respawnTimer = nil,
        _despawnFn = function()
        end -- замковые сундуки не деспавнятся
    }

    -- Атрибуты на Part для клиентского UI
    part:SetAttribute("ContainerId", containerId)
    part:SetAttribute("ContainerType", "castle_chest")
    part:SetAttribute("ContainerEmpty", true)

    -- Трекинг
    chestData[blockId] = {
        containerId = containerId,
        part = part
    }
    containerToBlock[containerId] = blockId

    -- Обновить blockData в замке
    if castle and castle.blocks[blockId] then
        castle.blocks[blockId].containerId = containerId
    end

    print("[ChestHandler] Created chest " .. containerId .. " for block " .. blockId)
    return containerId
end

--- Взаимодействие с сундуком (F).
--- @param player Player
--- @param part BasePart
--- @param blockData table — из castle.blocks[blockId]
--- @param castle table
--- @return boolean, string?
function ChestHandler.interact(player, part, blockData, castle)
    -- Проверка прав
    local ownerId = part:GetAttribute("CastleOwnerId")
    if ownerId then
        if not CastleBorder.canInteract(player.UserId, ownerId) then
            return false, "Нет прав доступа"
        end
    end

    local containerId = blockData.containerId
    if not containerId then
        return false, "Сундук не инициализирован"
    end

    local CM = getContainerManager()
    local ok, result = CM.requestOpen(player, containerId)

    if not ok then
        return false, result
    end

    return true
end

--- Уничтожить сундук — дропнуть содержимое на землю.
--- @param part BasePart
--- @param blockId string? — если известен
function ChestHandler.onDestroy(part, blockId)
    -- Найти blockId если не передан
    if not blockId then
        for bId, data in chestData do
            if data.part == part then
                blockId = bId
                break
            end
        end
    end

    if not blockId or not chestData[blockId] then
        return
    end

    local containerId = chestData[blockId].containerId
    local CM = getContainerManager()
    local containers = CM.getAll()
    local data = containers[containerId]

    if data then
        -- Дроп содержимого
        local dropPos = part.Position
        for i, slot in data.slots do
            if slot and slot ~= false then
                getLootManager().dropItemAtPosition(dropPos, slot.ItemId, slot.Amount or 1)
            end
        end

        -- Закрыть UI для всех открывших
        for userId, _ in data.openedBy do
            local p = game:GetService("Players"):GetPlayerByUserId(userId)
            if p then
                Remotes.ContainerClosed:FireClient(p, containerId)
            end
        end

        -- Удалить из ContainerManager
        containers[containerId] = nil
    end

    -- Очистка трекинга
    containerToBlock[containerId] = nil
    chestData[blockId] = nil

    print("[ChestHandler] Destroyed chest " .. tostring(containerId) .. " for block " .. tostring(blockId))
end

-- ═══════════════════════════════════════════════════════════
-- Сериализация
-- ═══════════════════════════════════════════════════════════

--- Получить функцию-сериализатор для BuildingSerializer.
--- @return function(containerId) → table | nil
function ChestHandler.getSerializer()
    return function(containerId)
        local CM = getContainerManager()
        local containers = CM.getAll()
        local data = containers[containerId]
        if not data then
            return nil
        end

        -- Сериализуем слоты: { [strIndex] = { Id, Amount } }
        local serializedSlots = {}
        for i, slot in data.slots do
            if slot and slot ~= false then
                serializedSlots[tostring(i)] = {
                    Id = slot.ItemId,
                    Amount = slot.Amount
                }
            end
        end

        return {
            Id = containerId,
            Type = "castle_chest",
            Slots = serializedSlots
        }
    end
end

--- Восстановить сундук из DataStore.
--- @param part BasePart
--- @param typeId string
--- @param blockId string
--- @param castle table
--- @param savedContainer table — { Id, Type, Slots }
function ChestHandler.restoreContainer(part, typeId, blockId, castle, savedContainer)
    local cfg = getChestConfig(typeId)
    local containerId = savedContainer.Id or makeContainerId()

    -- Восстанавливаем слоты
    local slots = {}
    for i = 1, cfg.Slots do
        slots[i] = false
    end

    if savedContainer.Slots then
        for strIdx, slotData in savedContainer.Slots do
            local idx = tonumber(strIdx)
            if idx and idx >= 1 and idx <= cfg.Slots and slotData.Id then
                slots[idx] = {
                    ItemId = slotData.Id,
                    Amount = slotData.Amount or 1
                }
            end
        end
    end

    -- Регистрируем в ContainerManager
    local CM = getContainerManager()
    local containers = CM.getAll()

    containers[containerId] = {
        id = containerId,
        cfgId = "castle_chest",
        config = {
            Name = "Сундук",
            Slots = cfg.Slots,
            CastTime = 0,
            CastMovementMode = "CancelOnMove",
            CastCancelKey = "MMB",
            InteractRange = cfg.InteractRange,
            DespawnTime = math.huge,
            Persistent = true
        },
        state = "Active",
        model = part,
        slots = slots,
        openedBy = {},
        spawnPoint = part,
        despawnTimer = nil,
        respawnTimer = nil,
        _despawnFn = function()
        end
    }

    part:SetAttribute("ContainerId", containerId)
    part:SetAttribute("ContainerType", "castle_chest")

    -- Проверяем пустоту
    local isEmpty = true
    for _, s in slots do
        if s and s ~= false then
            isEmpty = false
            break
        end
    end
    part:SetAttribute("ContainerEmpty", isEmpty)

    chestData[blockId] = {
        containerId = containerId,
        part = part
    }
    containerToBlock[containerId] = blockId

    if castle and castle.blocks[blockId] then
        castle.blocks[blockId].containerId = containerId
    end

    print("[ChestHandler] Restored chest " .. containerId .. " for block " .. blockId .. " (" ..
              (isEmpty and "empty" or "has items") .. ")")
end

--- Дропнуть содержимое всех сундуков замка (при уничтожении Castle Heart).
--- @param castle table
function ChestHandler.dropAllLoot(castle)
    for blockId, block in castle.blocks do
        if chestData[blockId] then
            ChestHandler.onDestroy(block.part, blockId)
        end
    end
end

--- Получить containerId по blockId.
--- @param blockId string
--- @return string | nil
function ChestHandler.getContainerId(blockId)
    local data = chestData[blockId]
    return data and data.containerId or nil
end

return ChestHandler
