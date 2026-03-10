--[[
    BlockHealth.luau
    Мост между строительной системой и HealthManager / TargetFinder.

    Отвечает за:
    - Инициализацию HP блока через HealthManager
    - Установку атрибутов IsStructure, BlockTypeId, CastleOwnerId на Part
    - Регистрацию блока в TargetFinder.addStaticEntity
    - Подписку на StructureDestroyed (EventBus) → уведомление BuildingManager

    НЕ отвечает за:
    - Создание/удаление Part (BuildingManager)
    - Расчёт урона (DamageCalc, HealthManager)
    - Сериализацию (BuildingSerializer)

    Используется: BuildingManager (initBlock, cleanupBlock)
    Зависимости: HealthManager, TargetFinder, EventBus, Config
]] local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local EventBus = require(modules:WaitForChild("EventBus"))

-- TargetFinder — lazy require (живёт в combat/, не в modules/)
local _TargetFinder
local function getTargetFinder()
    if not _TargetFinder then
        _TargetFinder = require(ServerScriptService:WaitForChild("combat"):WaitForChild("TargetFinder"))
    end
    return _TargetFinder
end

local BlockHealth = {}

-- Трекинг живых блоков для быстрого поиска по Part
-- managedBlocks[part] = { ownerId, typeId, blockId }
local managedBlocks = {}

-- ═══════════════════════════════════════════════════════════
-- Публичное API
-- ═══════════════════════════════════════════════════════════

--- Инициализировать HP и атрибуты для размещённого блока.
--- Вызывается из BuildingManager при создании Part (placeBlock и initPlayer).
---
--- Порядок операций:
---   1. Установить атрибуты на Part
---   2. Зарегистрировать в HealthManager
---   3. Зарегистрировать в TargetFinder (инкрементально)
---   4. Добавить в managedBlocks
---
--- @param part BasePart — созданный Part блока (уже в workspace)
--- @param blockTypeId string — ключ в Config.Building.BlockTypes
--- @param ownerId number — UserId владельца замка
--- @param blockId string — уникальный id блока в BuildingManager
function BlockHealth.initBlock(part, blockTypeId, ownerId, blockId)
    local bt = Config.Building and Config.Building.BlockTypes[blockTypeId]
    if not bt then
        warn("[BlockHealth] initBlock: unknown blockTypeId " .. tostring(blockTypeId))
        return
    end

    local maxHP = bt.HP or 100

    -- 1. Атрибуты для идентификации
    part:SetAttribute("IsStructure", true)
    part:SetAttribute("BlockTypeId", blockTypeId)
    part:SetAttribute("CastleOwnerId", ownerId)
    part:SetAttribute("BlockId", blockId)

    -- 2. HealthManager инициализация
    --    HealthManager использует IsStructure для ветвления в takeDamage/die
    HealthManager.init(part, maxHP)

    -- 3. TargetFinder — инкрементальное добавление
    --    NPC (EnemyBehaviors) смогут находить блоки через inRadius/inCone
    getTargetFinder().addStaticEntity(part)

    -- 4. Трекинг
    managedBlocks[part] = {
        ownerId = ownerId,
        typeId = blockTypeId,
        blockId = blockId
    }
end

--- Очистить блок из всех систем.
--- Вызывается из BuildingManager при ручном удалении (removeBlock).
--- НЕ вызывается при разрушении через урон — StructureDestroyed обработает.
---
--- @param part BasePart
function BlockHealth.cleanupBlock(part)
    -- TargetFinder — инкрементальное удаление
    getTargetFinder().removeStaticEntity(part)

    -- HealthManager
    HealthManager.cleanup(part)

    -- Трекинг
    managedBlocks[part] = nil
end

--- Получить данные управляемого блока.
--- @param part BasePart
--- @return table | nil — { ownerId, typeId, blockId }
function BlockHealth.getBlockData(part)
    return managedBlocks[part]
end

--- Проверить, управляется ли Part этим модулем.
--- @param part BasePart
--- @return boolean
function BlockHealth.isManaged(part)
    return managedBlocks[part] ~= nil
end

-- ═══════════════════════════════════════════════════════════
-- EventBus: StructureDestroyed
-- ═══════════════════════════════════════════════════════════
--
-- Цепочка событий при разрушении блока через урон:
--   1. HealthManager.takeDamage → HP <= 0
--   2. HealthManager.die → обнаруживает IsStructure
--   3. HealthManager.die → EventBus.fire("StructureDestroyed", entity, attacker)
--   4. BlockHealth (здесь) → ловит StructureDestroyed
--   5. BlockHealth → очищает TargetFinder, managedBlocks
--   6. BlockHealth → EventBus.fire("BlockDestroyedByDamage", ...)
--   7. BuildingManager (слушает BlockDestroyedByDamage) → удаляет из данных,
--      уничтожает Part, дропает лут сундука и т.д.
--
-- ВАЖНО: HealthManager.die для IsStructure НЕ вызывает entity:Destroy().
-- Уничтожение Part делегировано BuildingManager.

EventBus.on("StructureDestroyed", function(entity, attacker)
    local blockData = managedBlocks[entity]
    if not blockData then
        -- Не наш блок (возможно, другая система использует IsStructure)
        return
    end

    -- Очищаем из TargetFinder
    getTargetFinder().removeStaticEntity(entity)

    -- Очищаем из трекинга
    local ownerId = blockData.ownerId
    local typeId = blockData.typeId
    local blockId = blockData.blockId
    managedBlocks[entity] = nil

    -- Уведомляем BuildingManager через отдельное событие
    -- BuildingManager подпишется на BlockDestroyedByDamage
    -- и выполнит: удаление из данных, Destroy Part, дроп контейнера, sync
    EventBus.fire("BlockDestroyedByDamage", entity, attacker, ownerId, typeId, blockId)

    print("[BlockHealth] Structure destroyed: " .. typeId .. " (owner " .. tostring(ownerId) .. ")")
end)

return BlockHealth
