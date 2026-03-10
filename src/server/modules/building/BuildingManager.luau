--[[
    BuildingManager.luau
    Ядро строительной системы. Управляет данными замков, размещением и удалением блоков.

    Состояние:
      castles[ownerId] = {
          ownerId, centerPos, blocks, blockCount, folder,
          coffinPos, coffinBlockId
      }

    Используется: BuildingServer, DataService, PlayerLifecycle, Main.server
    Зависимости: Config, BuildingValidator, BuildingSerializer, CastleBorder,
                 BlockHealth, InventoryManager (lazy), InventorySync (lazy),
                 EventBus, Remotes
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local EventBus = require(modules:WaitForChild("EventBus"))

local BuildingValidator = require(script.Parent:WaitForChild("BuildingValidator"))
local BuildingSerializer = require(script.Parent:WaitForChild("BuildingSerializer"))
local CastleBorder = require(script.Parent:WaitForChild("CastleBorder"))
local BlockHealth = require(script.Parent:WaitForChild("BlockHealth"))

-- Lazy requires
local _InventoryManager, _InventorySync
local function getInventoryManager()
    if not _InventoryManager then
        _InventoryManager = require(modules:WaitForChild("InventoryManager"))
    end
    return _InventoryManager
end
local function getInventorySync()
    if not _InventorySync then
        _InventorySync = require(modules:WaitForChild("InventorySync"))
    end
    return _InventorySync
end

local BuildingManager = {}

-- ═══════════════════════════════════════════════════════════
-- Состояние
-- ═══════════════════════════════════════════════════════════
-- castles[ownerId] = {
--     ownerId    = number,
--     centerPos  = Vector3,
--     blocks     = { [blockId] = {
--         typeId: string,
--         position: Vector3,
--         rotation: number,
--         size: Vector3,
--         part: BasePart,
--         containerId: string? (Phase 2),
--     }},
--     blockCount = number,
--     folder     = Folder (workspace.Castles.<PlayerName>),
--     coffinPos  = Vector3 | nil,
--     coffinBlockId = string | nil,
-- }
local castles = {}

-- Генератор blockId
local nextBlockId = 1
local function makeBlockId()
    local id = "blk_" .. nextBlockId
    nextBlockId += 1
    return id
end

-- ═══════════════════════════════════════════════════════════
-- Приватные хелперы
-- ═══════════════════════════════════════════════════════════

--- Получить или создать корневую папку workspace.Castles
local function getCastlesRoot()
    local root = workspace:FindFirstChild("Castles")
    if not root then
        root = Instance.new("Folder")
        root.Name = "Castles"
        root.Parent = workspace
    end
    return root
end

--- Получить или создать папку замка конкретного игрока
--- @param ownerId number
--- @return Folder
local function getCastleFolder(ownerId)
    local root = getCastlesRoot()
    local folderName = "Castle_" .. tostring(ownerId)
    local folder = root:FindFirstChild(folderName)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = folderName
        folder.Parent = root
    end
    return folder
end

--- Создать Part блока в мире
--- @param typeId string
--- @param position Vector3
--- @param rotation number
--- @param folder Folder
--- @return BasePart
local function createBlockPart(typeId, position, rotation, folder)
    local bt = Config.Building.BlockTypes[typeId]
    local size = bt.Size
    if rotation == 90 or rotation == 270 then
        size = Vector3.new(size.Z, size.Y, size.X)
    end

    local part = Instance.new("Part")
    part.Name = "Block_" .. typeId
    part.Size = size
    part.Material = bt.Material or Enum.Material.SmoothPlastic
    part.Color = bt.Color or Color3.fromRGB(128, 128, 128)
    part.Anchored = true
    part.CanCollide = true
    part.Position = position
    part.Orientation = Vector3.new(0, rotation, 0)

    -- Shelter атрибут для DayNightManager raycast
    if bt.IsShelter then
        part:SetAttribute("IsShelter", true)
    end

    part.Parent = folder
    return part
end

--- Собрать массив { position, size } из всех блоков замка (для коллизии)
--- @param castle table
--- @return table
local function getExistingBlocksArray(castle)
    local result = {}
    for _, block in castle.blocks do
        table.insert(result, {
            position = block.position,
            size = block.size,
        })
    end
    return result
end

--- Подсчитать функциональные блоки определённого типа
--- @param castle table
--- @param funcType string — "Coffin", "Chest" и т.д.
--- @return number
local function countFunctional(castle, funcType)
    local count = 0
    for _, block in castle.blocks do
        local bt = Config.Building.BlockTypes[block.typeId]
        if bt and bt.Functional == funcType then
            count += 1
        end
    end
    return count
end

--- Списать стоимость блока из инвентаря
--- @param player Player
--- @param typeId string
--- @return boolean
local function deductCost(player, typeId)
    local bt = Config.Building.BlockTypes[typeId]
    if not bt or not bt.Cost then return true end

    local invMgr = getInventoryManager()
    for _, cost in bt.Cost do
        invMgr.removeItemById(player, cost.ItemId, cost.Amount)
    end
    return true
end

--- Вернуть ресурсы при удалении
--- @param player Player
--- @param typeId string
local function refundCost(player, typeId)
    local refund = BuildingValidator.calcRefund(typeId)
    local invMgr = getInventoryManager()
    for _, entry in refund do
        invMgr.addItemFromConfig(player, entry.ItemId, entry.Amount)
    end
end

--- Отправить синхронизацию всем игрокам
--- @param castle table
local function broadcastSync(castle)
    local syncData = {
        OwnerId = castle.ownerId,
        CenterPos = castle.centerPos,
        BlockCount = castle.blockCount,
    }

    for _, player in Players:GetPlayers() do
        Remotes.BuildingSync:FireClient(player, syncData)
    end
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: инициализация
-- ═══════════════════════════════════════════════════════════

--- Инициализация модуля. Вызывается из Main.server.luau.
function BuildingManager.init()
    getCastlesRoot()
    print("[BuildingManager] Initialized")
end

--- Инициализировать данные замка для игрока (загрузка из DataStore).
--- Синхронное восстановление всех блоков — НЕТ task.wait внутри цикла.
--- 500 блоков ≈ 10-50мс — один кадр, приемлемо.
---
--- @param player Player
--- @param savedData table | nil — из DataService (BuildingSerializer format)
function BuildingManager.initPlayer(player, savedData)
    local ownerId = player.UserId

    if not savedData then
        -- Нет замка — ничего не делаем
        return
    end

    local deserialized = BuildingSerializer.deserialize(savedData)
    if not deserialized then
        warn("[BuildingManager] Failed to deserialize castle for " .. player.Name)
        return
    end

    -- Регистрируем территорию
    local ok, err = CastleBorder.registerClaim(ownerId, deserialized.centerPos, deserialized.permissions)
    if not ok then
        warn("[BuildingManager] Failed to register claim for " .. player.Name .. ": " .. (err or ""))
        return
    end

    -- Создаём папку
    local folder = getCastleFolder(ownerId)

    -- Инициализируем данные замка
    castles[ownerId] = {
        ownerId = ownerId,
        centerPos = deserialized.centerPos,
        blocks = {},
        blockCount = 0,
        folder = folder,
        coffinPos = nil,
        coffinBlockId = nil,
    }
    local castle = castles[ownerId]

    -- Синхронное восстановление блоков
    -- deserialized.blocks может содержать false (skipped blocks)
    for i, blockData in deserialized.blocks do
        if blockData and blockData ~= false then
            local blockId = makeBlockId()
            local part = createBlockPart(blockData.typeId, blockData.position, blockData.rotation, folder)

            -- BlockHealth: HP + TargetFinder
            BlockHealth.initBlock(part, blockData.typeId, ownerId, blockId)

            castle.blocks[blockId] = {
                typeId = blockData.typeId,
                position = blockData.position,
                rotation = blockData.rotation,
                size = blockData.size,
                part = part,
                containerId = nil, -- Phase 2: восстанавливается ниже
            }
            castle.blockCount += 1

            -- Coffin tracking
            local bt = Config.Building.BlockTypes[blockData.typeId]
            if bt and bt.Functional == "Coffin" then
                castle.coffinPos = blockData.position + Vector3.new(0, 1, 0)
                castle.coffinBlockId = blockId
            end
        end
    end

    -- Phase 2: восстановление контейнеров
    -- (заглушка — будет реализовано в Phase 2)
    -- for _, cData in deserialized.containers do
    --     local blockIndex = cData.Ref
    --     local block = deserialized.blocks[blockIndex]
    --     if block then ... end
    -- end

    print("[BuildingManager] Restored castle for " .. player.Name
        .. ": " .. castle.blockCount .. " blocks")
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: строительство
-- ═══════════════════════════════════════════════════════════

--- Разместить Castle Heart — первый шаг основания замка.
--- Может быть вызвано ТОЛЬКО владельцем. Создаёт claim, папку, Part.
--- @param player Player
--- @param rawPosition Vector3
--- @return boolean, string?
function BuildingManager.placeCastleHeart(player, rawPosition)
    local ownerId = player.UserId

    -- Проверка: у игрока уже есть замок
    if CastleBorder.hasCastle(ownerId) then
        return false, "У вас уже есть замок"
    end

    -- Проверка: лимит замков
    local castleCount = 0
    for _ in castles do castleCount += 1 end
    if castleCount >= Config.Building.MaxCastlesPerWorld then
        return false, "Достигнут лимит замков на сервере"
    end

    -- Snap позиции
    local snapped = BuildingValidator.snapPosition(rawPosition)

    -- Raycast для определения surfaceY
    local heartCfg = Config.Building.CastleHeart
    local surfaceY = 0
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate then
        local rayOrigin = Vector3.new(snapped.X, 50, snapped.Z)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { baseplate }
        local result = workspace:Raycast(rayOrigin, Vector3.new(0, -100, 0), params)
        if result then
            surfaceY = result.Position.Y
        end
    end

    local finalPos = Vector3.new(snapped.X, surfaceY + heartCfg.Size.Y / 2, snapped.Z)

    -- Регистрируем территорию (уровень 1)
    local ok, err = CastleBorder.registerClaim(ownerId, finalPos, 1)
    if not ok then
        return false, err
    end

    -- Создаём папку
    local folder = getCastleFolder(ownerId)

    -- Создаём Part
    local part = Instance.new("Part")
    part.Name = "CastleHeart"
    part.Size = heartCfg.Size
    part.Material = heartCfg.Material
    part.Color = heartCfg.Color
    part.Anchored = true
    part.CanCollide = true
    part.Position = finalPos
    part.Parent = folder

    -- Атрибуты — Castle Heart использует IsStructure но с доп. маркером
    part:SetAttribute("IsStructure", true)
    part:SetAttribute("IsCastleHeart", true)
    part:SetAttribute("CastleOwnerId", ownerId)
    part:SetAttribute("HeartLevel", 1)

    local blockId = makeBlockId()
    part:SetAttribute("BlockId", blockId)

    -- HP из уровня
    local levelData = heartCfg.Levels[1]
    HealthManager.init(part, levelData.HP)

    -- TargetFinder
    getTargetFinder().addStaticEntity(part)

    -- Данные замка
    castles[ownerId] = {
        ownerId = ownerId,
        centerPos = finalPos,
        blocks = {},
        blockCount = 0,
        folder = folder,
        coffinPos = nil,
        coffinBlockId = nil,
        heartPart = part,
        heartBlockId = blockId,
        heartLevel = 1,
    }

    EventBus.fire("CastleHeartPlaced", player, finalPos)
    broadcastSync(castles[ownerId])

    print("[BuildingManager] " .. player.Name .. " placed Castle Heart at " .. tostring(finalPos))
    return true
end

--- Улучшить Castle Heart до следующего уровня.
--- @param player Player
--- @return boolean, string?
function BuildingManager.upgradeHeart(player)
    local ownerId = player.UserId
    local castle = castles[ownerId]
    if not castle then return false, "Нет замка" end

    local heartCfg = Config.Building.CastleHeart
    local currentLevel = castle.heartLevel
    local nextLevel = currentLevel + 1

    if nextLevel > heartCfg.MaxLevel then
        return false, "Максимальный уровень"
    end

    -- Проверка: не вызовет ли апгрейд пересечение территорий
    local canUp, upErr = CastleBorder.canUpgrade(ownerId, nextLevel)
    if not canUp then
        return false, upErr
    end

    -- Проверка и списание ресурсов
    local levelData = heartCfg.Levels[nextLevel]
    if levelData.UpgradeCost then
        local invMgr = getInventoryManager()
        for _, cost in levelData.UpgradeCost do
            if invMgr.countItem(player, cost.ItemId) < cost.Amount then
                return false, "Не хватает " .. cost.ItemId
            end
        end
        for _, cost in levelData.UpgradeCost do
            invMgr.removeItemById(player, cost.ItemId, cost.Amount)
        end
        getInventorySync().sendFullUpdate(player)
    end

    -- Обновляем уровень
    castle.heartLevel = nextLevel
    CastleBorder.setHeartLevel(ownerId, nextLevel)

    -- Обновляем HP сердца
    if castle.heartPart and castle.heartPart.Parent then
        HealthManager.setMaxHP(castle.heartPart, levelData.HP)
        castle.heartPart:SetAttribute("HeartLevel", nextLevel)
    end

    broadcastSync(castle)

    print("[BuildingManager] " .. player.Name .. " upgraded Castle Heart to level " .. nextLevel)
    return true
end

--- Уничтожить весь замок (только владелец).
--- Весь лут из сундуков выпадает на землю.
--- @param player Player
--- @return boolean, string?
function BuildingManager.destroyCastle(player)
    local ownerId = player.UserId
    local castle = castles[ownerId]
    if not castle then return false, "Нет замка" end

    -- Phase 2: дроп содержимого всех сундуков
    -- for blockId, block in castle.blocks do
    --     if block.containerId then
    --         local container = ContainerManager.getContainer(block.containerId)
    --         if container then
    --             for i = 1, container.slotCount do
    --                 local slot = container.slots[i]
    --                 if slot and slot ~= false then
    --                     LootManager.dropItemAtPosition(block.position, slot.Id, slot.Amount)
    --                 end
    --             end
    --             ContainerManager.removeContainer(block.containerId)
    --         end
    --     end
    -- end

    -- Очистить все блоки
    for blockId, block in castle.blocks do
        if block.part and block.part.Parent then
            BlockHealth.cleanupBlock(block.part)
            block.part:Destroy()
        end
    end

    -- Очистить Castle Heart
    if castle.heartPart and castle.heartPart.Parent then
        getTargetFinder().removeStaticEntity(castle.heartPart)
        HealthManager.cleanup(castle.heartPart)
        castle.heartPart:Destroy()
    end

    -- Удалить папку
    if castle.folder and castle.folder.Parent then
        castle.folder:Destroy()
    end

    -- Удалить claim
    CastleBorder.removeClaim(ownerId)

    -- Удалить данные
    castles[ownerId] = nil

    EventBus.fire("CastleDestroyed", player)

    print("[BuildingManager] " .. player.Name .. " destroyed their castle")
    return true
end

--- Разместить блок.
--- @param player Player — кто строит (может быть не владелец при кооперативе)
--- @param blockTypeId string
--- @param rawPosition Vector3 — позиция от клиента (будет привязана к сетке)
--- @param rotation number — градусы (будет нормализован)
--- @return boolean, string?
function BuildingManager.placeBlock(player, blockTypeId, rawPosition, rotation)
    
    local actorId = player.UserId
    local bt = Config.Building.BlockTypes[blockTypeId]
    if not bt then
        return false, "Неизвестный тип блока"
    end

    -- 1. Определить замок
    local rot = BuildingValidator.normalizeRotation(rotation)
    local existingOwner = CastleBorder.getOwnerAt(rawPosition)
    local castleOwnerId

    if existingOwner then
        -- Позиция внутри существующей территории → кооператив
        castleOwnerId = existingOwner
        if not CastleBorder.canBuild(actorId, castleOwnerId) then
            return false, "Нет прав на строительство"
        end
    else
        -- Позиция вне территорий
        if CastleBorder.hasCastle(actorId) then
            -- У игрока есть замок — проверяем что позиция в его радиусе
            if not CastleBorder.isWithinClaim(rawPosition, actorId) then
                return false, "За пределами вашей территории"
            end
            castleOwnerId = actorId
        else
            -- Нет замка — создаём новый (только для фундамента)
            if bt.PlacementRule ~= "Ground" then
                return false, "Первый блок должен быть фундаментом"
            end
            castleOwnerId = actorId
        end
    end

    -- 2. Проверка ресурсов
    local canPay, payErr = BuildingValidator.canAfford(player, blockTypeId)
    if not canPay then
        return false, payErr
    end

    -- 3. Получить или создать замок
    local castle = castles[castleOwnerId]
    local folder

    if not castle then
        -- Новый замок — регистрируем территорию
        local snapped = BuildingValidator.snapPosition(rawPosition)
        local ok, claimErr = CastleBorder.registerClaim(castleOwnerId, snapped)
        if not ok then
            return false, claimErr
        end

        folder = getCastleFolder(castleOwnerId)
        castle = {
            ownerId = castleOwnerId,
            centerPos = snapped,
            blocks = {},
            blockCount = 0,
            folder = folder,
            coffinPos = nil,
            coffinBlockId = nil,
        }
        castles[castleOwnerId] = castle
    else
        folder = castle.folder
    end

    -- 4. Рассчитать позицию (snap + raycast)
    local finalPos, surfaceY, hitPart = BuildingValidator.calcPlacementPos(
        blockTypeId, rawPosition, rot, folder
    )
    if not finalPos then
        return false, "Не удалось определить позицию"
    end

    -- 5. Полная валидация
    local valid, validErr = BuildingValidator.validate({
        blockTypeId = blockTypeId,
        position = finalPos,
        rotation = rot,
        castleOwnerId = castleOwnerId,
        actorId = actorId,
        blockCount = castle.blockCount,
        existingBlocks = getExistingBlocksArray(castle),
        castleFolder = folder,
        hitPart = hitPart,
        coffinCount = countFunctional(castle, "Coffin"),
    })
    if not valid then
        return false, validErr
    end

    -- 6. Списать ресурсы
    deductCost(player, blockTypeId)
    getInventorySync().sendFullUpdate(player)

    -- 7. Создать Part
    local blockId = makeBlockId()
    local size = BuildingValidator.getRotatedSize(blockTypeId, rot)
    local part = createBlockPart(blockTypeId, finalPos, rot, folder)

    -- 8. BlockHealth: HP + TargetFinder
    BlockHealth.initBlock(part, blockTypeId, castleOwnerId, blockId)

    -- 9. Сохранить в данных замка
    castle.blocks[blockId] = {
        typeId = blockTypeId,
        position = finalPos,
        rotation = rot,
        size = size,
        part = part,
        containerId = nil,
    }
    castle.blockCount += 1

    -- 10. Coffin tracking
    if bt.Functional == "Coffin" then
        castle.coffinPos = finalPos + Vector3.new(0, 1, 0)
        castle.coffinBlockId = blockId
    end

    -- 11. EventBus + sync
    EventBus.fire("BlockPlaced", player, blockTypeId, finalPos)
    broadcastSync(castle)

    print("[BuildingManager] " .. player.Name .. " placed " .. blockTypeId
        .. " at " .. tostring(finalPos) .. " (castle of " .. tostring(castleOwnerId) .. ")")
    return true
end

--- Удалить блок вручную (с возвратом ресурсов).
--- @param player Player
--- @param blockId string
--- @return boolean, string?
function BuildingManager.removeBlock(player, blockId)
    local actorId = player.UserId

    -- Найти замок и блок
    local castle, foundBlock
    for ownerId, c in castles do
        if c.blocks[blockId] then
            castle = c
            foundBlock = c.blocks[blockId]
            break
        end
    end

    if not castle or not foundBlock then
        return false, "Блок не найден"
    end

    -- Проверка прав
    local valid, validErr = BuildingValidator.validateRemove({
        position = foundBlock.position,
        castleOwnerId = castle.ownerId,
        actorId = actorId,
    })
    if not valid then
        return false, validErr
    end

    -- Возврат ресурсов (строителю, не владельцу)
    refundCost(player, foundBlock.typeId)
    getInventorySync().sendFullUpdate(player)

    -- Coffin cleanup
    if castle.coffinBlockId == blockId then
        castle.coffinPos = nil
        castle.coffinBlockId = nil
    end

    -- Phase 2: контейнер cleanup
    -- if foundBlock.containerId then
    --     ContainerManager...
    -- end

    -- Очистка из BlockHealth (TargetFinder + HealthManager)
    if foundBlock.part and foundBlock.part.Parent then
        BlockHealth.cleanupBlock(foundBlock.part)
        foundBlock.part:Destroy()
    end

    -- Удаление из данных
    castle.blocks[blockId] = nil
    castle.blockCount -= 1

    -- EventBus + sync
    EventBus.fire("BlockRemoved", player, foundBlock.position)
    broadcastSync(castle)

    print("[BuildingManager] " .. player.Name .. " removed " .. foundBlock.typeId
        .. " at " .. tostring(foundBlock.position))
    return true
end

-- ═══════════════════════════════════════════════════════════
-- EventBus: BlockDestroyedByDamage (от BlockHealth)
-- ═══════════════════════════════════════════════════════════

EventBus.on("BlockDestroyedByDamage", function(entity, attacker, ownerId, typeId, blockId)
    local castle = castles[ownerId]
    if not castle then return end

    local block = castle.blocks[blockId]
    if not block then return end

    -- Coffin cleanup
    if castle.coffinBlockId == blockId then
        castle.coffinPos = nil
        castle.coffinBlockId = nil
    end

    -- Phase 2: дроп содержимого сундука
    -- if block.containerId then
    --     local LootManager = require(modules:WaitForChild("LootManager"))
    --     ... dropItemAtPosition ...
    --     ContainerManager.removeContainer(block.containerId)
    -- end

    -- Уничтожить Part
    if entity and entity.Parent then
        entity:Destroy()
    end

    -- Удаление из данных
    castle.blocks[blockId] = nil
    castle.blockCount -= 1

    -- Sync (без возврата ресурсов — NPC разрушил)
    EventBus.fire("BlockRemoved", nil, block.position)
    broadcastSync(castle)

    print("[BuildingManager] Block destroyed by damage: " .. typeId
        .. " at " .. tostring(block.position) .. " (attacker: "
        .. (attacker and attacker.Name or "unknown") .. ")")
end)

-- ═══════════════════════════════════════════════════════════
-- Публичное API: данные
-- ═══════════════════════════════════════════════════════════

--- Собрать данные замка для DataStore.
--- @param player Player
--- @return table | nil
function BuildingManager.collect(player)
    local castle = castles[player.UserId]
    if not castle then return nil end

    local permissions = CastleBorder.serializePermissions(player.UserId)

    -- Phase 2: containerSerializer
    local containerSerializer = nil
    -- containerSerializer = function(containerId)
    --     return ContainerManager.serializeContainer(containerId)
    -- end

    return BuildingSerializer.serialize(castle, permissions, containerSerializer)
end

--- Получить позицию гроба (для респавна).
--- @param player Player
--- @return Vector3 | nil
function BuildingManager.getCoffinPos(player)
    local castle = castles[player.UserId]
    if not castle then return nil end
    return castle.coffinPos
end

--- Получить данные замка.
--- @param ownerId number
--- @return table | nil
function BuildingManager.getCastle(ownerId)
    return castles[ownerId]
end

--- Получить все блоки замка (для GetBuildings RemoteFunction).
--- @param ownerId number
--- @return table
function BuildingManager.getBlocksForClient(ownerId)
    local castle = castles[ownerId]
    if not castle then return {} end

    local result = {}
    for blockId, block in castle.blocks do
        table.insert(result, {
            BlockId = blockId,
            TypeId = block.typeId,
            Position = block.position,
            Rotation = block.rotation,
            CurrentHP = block.part and block.part:GetAttribute("CurrentHP") or 0,
            MaxHP = block.part and block.part:GetAttribute("MaxHP") or 0,
        })
    end
    return result
end

--- Получить все замки (для миникарты и т.д.).
--- @return table — { { OwnerId, CenterPos, BlockCount } }
function BuildingManager.getAllCastlesInfo()
    local result = {}
    for ownerId, castle in castles do
        table.insert(result, {
            OwnerId = ownerId,
            CenterPos = castle.centerPos,
            BlockCount = castle.blockCount,
        })
    end
    return result
end

-- ═══════════════════════════════════════════════════════════
-- Очистка
-- ═══════════════════════════════════════════════════════════

--- Очистить замок игрока при выходе.
--- Part'ы остаются в мире (замки видны другим игрокам).
--- Данные и claim сохраняются до следующей загрузки.
---
--- ВНИМАНИЕ: в текущей реализации замки удаляются при выходе владельца.
--- Для persist-между-сессиями нужно сохранять castle в памяти
--- до перезагрузки сервера. Это поведение v1.9.
---
--- @param player Player
function BuildingManager.cleanup(player)
    local ownerId = player.UserId
    local castle = castles[ownerId]
    if not castle then return end

    -- Очистить BlockHealth для всех блоков
    for blockId, block in castle.blocks do
        if block.part and block.part.Parent then
            BlockHealth.cleanupBlock(block.part)
            block.part:Destroy()
        end
    end

    -- Удалить папку
    if castle.folder and castle.folder.Parent then
        castle.folder:Destroy()
    end

    -- Удалить claim
    CastleBorder.removeClaim(ownerId)

    -- Удалить данные
    castles[ownerId] = nil

    print("[BuildingManager] Cleaned up castle for " .. player.Name)
end

return BuildingManager