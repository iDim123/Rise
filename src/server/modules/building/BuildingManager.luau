--[[
    BuildingManager.luau
    Ядро строительной системы. Управляет данными замков, размещением и удалением блоков.

    Castle Heart делегирован CastleHeartManager.
    Функциональные блоки делегированы FunctionalDispatcher.

    Состояние:
      castles[ownerId] = {
          ownerId, centerPos, blocks, blockCount, folder,
          coffinPos, coffinBlockId,
          heartPart, heartBlockId, heartLevel
      }

    Используется: BuildingServer, DataService, PlayerLifecycle, Main.server
    Зависимости: Config, BuildingValidator, BuildingSerializer, CastleBorder,
                 BlockHealth, CastleHeartManager, FunctionalDispatcher,
                 InventoryManager (lazy), InventorySync (lazy),
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
local CastleHeartManager = require(script.Parent:WaitForChild("CastleHeartManager"))
local FunctionalDispatcher = require(script.Parent:WaitForChild("FunctionalDispatcher"))

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
local castles = {}

local nextBlockId = 1
local function makeBlockId()
    local id = "blk_" .. nextBlockId
    nextBlockId += 1
    return id
end

-- ═══════════════════════════════════════════════════════════
-- Приватные хелперы
-- ═══════════════════════════════════════════════════════════

local function getCastlesRoot()
    local root = workspace:FindFirstChild("Castles")
    if not root then
        root = Instance.new("Folder")
        root.Name = "Castles"
        root.Parent = workspace
    end
    return root
end

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

    if bt.IsShelter then
        part:SetAttribute("IsShelter", true)
    end

    part.Parent = folder
    return part
end

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

local function deductCost(player, typeId)
    local bt = Config.Building.BlockTypes[typeId]
    if not bt or not bt.Cost then return true end
    local invMgr = getInventoryManager()
    for _, cost in bt.Cost do
        invMgr.removeItemById(player, cost.ItemId, cost.Amount)
    end
    return true
end

local function refundCost(player, typeId)
    local refund = BuildingValidator.calcRefund(typeId)
    local invMgr = getInventoryManager()
    for _, entry in refund do
        invMgr.addItemFromConfig(player, entry.ItemId, entry.Amount)
    end
end

local function broadcastSync(castle)
    local syncData = {
        OwnerId = castle.ownerId,
        CenterPos = castle.centerPos,
        BlockCount = castle.blockCount,
        HeartLevel = castle.heartLevel,
    }
    for _, player in Players:GetPlayers() do
        Remotes.BuildingSync:FireClient(player, syncData)
    end
end

--- Каскадное уничтожение всех блоков замка (без Castle Heart).
--- Используется в destroyCastle и onHeartDestroyedByDamage.
local function destroyAllBlocks(castle)
    for blockId, block in castle.blocks do
        if block.part and block.part.Parent then
            FunctionalDispatcher.onRemove(block.part, block.typeId, blockId)
            BlockHealth.cleanupBlock(block.part)
            block.part:Destroy()
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: инициализация
-- ═══════════════════════════════════════════════════════════

function BuildingManager.init()
    getCastlesRoot()
    print("[BuildingManager] Initialized")
end

function BuildingManager.initPlayer(player, savedData)
    local ownerId = player.UserId
    if not savedData then return end

    local deserialized = BuildingSerializer.deserialize(savedData)
    if not deserialized then
        warn("[BuildingManager] Failed to deserialize castle for " .. player.Name)
        return
    end

    local heartLevel = deserialized.heartLevel or 1
    local ok, err = CastleBorder.registerClaim(
        ownerId, deserialized.centerPos, heartLevel, deserialized.permissions
    )
    if not ok then
        warn("[BuildingManager] Failed to register claim for " .. player.Name .. ": " .. (err or ""))
        return
    end

    local folder = getCastleFolder(ownerId)
    local heartBlockId = makeBlockId()
    local savedEssence = deserialized.bloodEssence or 0

    local heartModel = CastleHeartManager.createModel(deserialized.centerPos, heartLevel, folder, savedEssence)
    CastleHeartManager.initSystems(heartModel, heartLevel, ownerId, heartBlockId)

    castles[ownerId] = {
        ownerId = ownerId,
        centerPos = deserialized.centerPos,
        blocks = {},
        blockCount = 0,
        folder = folder,
        coffinPos = nil,
        coffinBlockId = nil,
        heartPart = heartModel,
        heartBlockId = heartBlockId,
        heartLevel = heartLevel,
    }
    local castle = castles[ownerId]

    -- Маппинг: serialized index → blockId (для привязки контейнеров)
    local indexToBlockId = {}

    for i, blockData in deserialized.blocks do
        if blockData and blockData ~= false then
            local blockId = makeBlockId()
            local part = createBlockPart(blockData.typeId, blockData.position, blockData.rotation, folder)

            BlockHealth.initBlock(part, blockData.typeId, ownerId, blockId)

            castle.blocks[blockId] = {
                typeId = blockData.typeId,
                position = blockData.position,
                rotation = blockData.rotation,
                size = blockData.size,
                part = part,
                containerId = nil,
            }
            castle.blockCount += 1
            indexToBlockId[i] = blockId

            local bt = Config.Building.BlockTypes[blockData.typeId]
            if bt and bt.Functional == "Coffin" then
                castle.coffinPos = blockData.position + Vector3.new(0, 1, 0)
                castle.coffinBlockId = blockId
            end

            -- FunctionalDispatcher для НЕ-сундуков (двери и т.д.)
            if not (bt and bt.Functional == "Chest") then
                FunctionalDispatcher.onPlace(part, blockData.typeId, blockId, castle)
            end
        end
    end

    -- Восстановление сундуков с данными из DataStore
    local ChestHandler = FunctionalDispatcher.getChestHandler()
    if deserialized.containers and #deserialized.containers > 0 then
        -- Сопоставляем Ref → blockId
        local containerByRef = {}
        for _, savedContainer in deserialized.containers do
            if savedContainer.Ref then
                containerByRef[savedContainer.Ref] = savedContainer
            end
        end

        for refIndex, blockId in indexToBlockId do
            local savedContainer = containerByRef[refIndex]
            local block = castle.blocks[blockId]
            if savedContainer and block then
                local bt = Config.Building.BlockTypes[block.typeId]
                if bt and bt.Functional == "Chest" then
                    ChestHandler.restoreContainer(block.part, block.typeId, blockId, castle, savedContainer)
                end
            end
        end
    end

    -- Инициализировать сундуки без сохранённых данных (новые пустые)
    for i, blockData in deserialized.blocks do
        if blockData and blockData ~= false then
            local blockId = indexToBlockId[i]
            local bt = Config.Building.BlockTypes[blockData.typeId]
            if bt and bt.Functional == "Chest" and blockId then
                local block = castle.blocks[blockId]
                if block and not block.containerId then
                    ChestHandler.onCreate(block.part, blockData.typeId, blockId, castle)
                end
            end
        end
    end

        -- Восстановление лесопилок с данными из DataStore
    local SawmillHandler = FunctionalDispatcher.getSawmillHandler()
    if deserialized.containers and #deserialized.containers > 0 then
        for refIndex, blockId in indexToBlockId do
            local block = castle.blocks[blockId]
            if not block then continue end
            local bt = Config.Building.BlockTypes[block.typeId]
            if bt and bt.Functional == "Sawmill" then
                -- Ищем savedContainer с совпадающим Ref
                for _, savedContainer in deserialized.containers do
                    if savedContainer.Ref == refIndex and savedContainer.Type == "sawmill" then
                        SawmillHandler.restoreContainer(block.part, block.typeId, blockId, castle, savedContainer)
                        break
                    end
                end
            end
        end
    end

    -- Инициализировать лесопилки без сохранённых данных (новые пустые)
    for i, blockData in deserialized.blocks do
        if blockData and blockData ~= false then
            local blockId = indexToBlockId[i]
            local bt = Config.Building.BlockTypes[blockData.typeId]
            if bt and bt.Functional == "Sawmill" and blockId then
                local block = castle.blocks[blockId]
                if block and not block.sawmillId then
                    FunctionalDispatcher.onPlace(block.part, blockData.typeId, blockId, castle)
                end
            end
        end
    end


    print("[BuildingManager] Restored castle for " .. player.Name
        .. ": " .. castle.blockCount .. " blocks, heart level " .. heartLevel)
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: Castle Heart (делегация)
-- ═══════════════════════════════════════════════════════════

function BuildingManager.placeCastleHeart(player, rawPosition)
    local ok, err = CastleHeartManager.place(player, rawPosition, castles, makeBlockId, getCastleFolder)
    if ok then
        broadcastSync(castles[player.UserId])
    end
    return ok, err
end

function BuildingManager.upgradeHeart(player)
    local castle = castles[player.UserId]
    if not castle then return false, "Нет замка" end

    local ok, err = CastleHeartManager.upgrade(player, castle)
    if ok then
        broadcastSync(castle)
    end
    return ok, err
end

function BuildingManager.updateHeartEssence(ownerId, essenceAmount)
    local castle = castles[ownerId]
    if castle then
        CastleHeartManager.updateEssence(castle, essenceAmount)
    end
end

function BuildingManager.destroyCastle(player)
    local ownerId = player.UserId
    local castle = castles[ownerId]
    if not castle then return false, "Нет замка" end

    -- Phase 2: дроп лута из всех сундуков и лесопилок
    FunctionalDispatcher.getChestHandler().dropAllLoot(castle)
    FunctionalDispatcher.getSawmillHandler().dropAllLoot(castle)

    destroyAllBlocks(castle)
    CastleHeartManager.destroyHeart(castle)

    if castle.folder and castle.folder.Parent then
        castle.folder:Destroy()
    end

    CastleBorder.removeClaim(ownerId)
    castles[ownerId] = nil

    EventBus.fire("CastleDestroyed", player)
    print("[BuildingManager] " .. player.Name .. " destroyed their castle")
    return true
end

function BuildingManager.getCastleHeartInfo(ownerId)
    local castle = castles[ownerId]
    if not castle then return nil end
    return CastleHeartManager.getInfo(castle, ownerId, countFunctional)
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: строительство блоков
-- ═══════════════════════════════════════════════════════════

function BuildingManager.placeBlock(player, blockTypeId, rawPosition, rotation)
    local actorId = player.UserId
    local bt = Config.Building.BlockTypes[blockTypeId]
    if not bt then
        return false, "Неизвестный тип блока"
    end

    local rot = BuildingValidator.normalizeRotation(rotation)
    local existingOwner = CastleBorder.getOwnerAt(rawPosition)
    local castleOwnerId

    if existingOwner then
        castleOwnerId = existingOwner
        if not CastleBorder.canBuild(actorId, castleOwnerId) then
            return false, "Нет прав на строительство"
        end
    else
        if CastleBorder.hasCastle(actorId) then
            if not CastleBorder.isWithinClaim(rawPosition, actorId) then
                return false, "За пределами вашей территории"
            end
            castleOwnerId = actorId
        else
            return false, "Сначала поставьте Сердце замка"
        end
    end

    local canPay, payErr = BuildingValidator.canAfford(player, blockTypeId)
    if not canPay then
        return false, payErr
    end

    local castle = castles[castleOwnerId]
    if not castle then
        return false, "Сначала поставьте Сердце замка"
    end
    local folder = castle.folder

    local finalPos, surfaceY, hitPart = BuildingValidator.calcPlacementPos(
        blockTypeId, rawPosition, rot, folder
    )
    if not finalPos then
        return false, "Не удалось определить позицию"
    end

    local heartCfg = Config.Building.CastleHeart
    local valid, validErr = BuildingValidator.validate({
        blockTypeId = blockTypeId,
        position = finalPos,
        rotation = rot,
        castleOwnerId = castleOwnerId,
        actorId = actorId,
        blockCount = castle.blockCount,
        maxBlocks = CastleBorder.getMaxBlocks(castleOwnerId),
        maxCoffins = CastleBorder.getMaxCoffins(castleOwnerId),
        existingBlocks = getExistingBlocksArray(castle),
        castleFolder = folder,
        hitPart = hitPart,
        coffinCount = countFunctional(castle, "Coffin"),
        heartPosition = castle.heartPart and castle.heartPart.PrimaryPart
            and castle.heartPart.PrimaryPart.Position or nil,
        heartSize = heartCfg.Size,
    })
    if not valid then
        return false, validErr
    end

    deductCost(player, blockTypeId)
    getInventorySync().sendFullUpdate(player)

    local blockId = makeBlockId()
    local size = BuildingValidator.getRotatedSize(blockTypeId, rot)
    local part = createBlockPart(blockTypeId, finalPos, rot, folder)

    BlockHealth.initBlock(part, blockTypeId, castleOwnerId, blockId)
    FunctionalDispatcher.onPlace(part, blockTypeId, blockId, castle)

    castle.blocks[blockId] = {
        typeId = blockTypeId,
        position = finalPos,
        rotation = rot,
        size = size,
        part = part,
        containerId = nil,
    }
    castle.blockCount += 1

    if bt.Functional == "Coffin" then
        castle.coffinPos = finalPos + Vector3.new(0, 1, 0)
        castle.coffinBlockId = blockId
    end

    EventBus.fire("BlockPlaced", player, blockTypeId, finalPos)
    broadcastSync(castle)

    print("[BuildingManager] " .. player.Name .. " placed " .. blockTypeId
        .. " at " .. tostring(finalPos) .. " (castle of " .. tostring(castleOwnerId) .. ")")
    return true
end

function BuildingManager.removeBlock(player, blockId)
    local actorId = player.UserId

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

    local valid, validErr = BuildingValidator.validateRemove({
        position = foundBlock.position,
        castleOwnerId = castle.ownerId,
        actorId = actorId,
    })
    if not valid then
        return false, validErr
    end

    refundCost(player, foundBlock.typeId)
    getInventorySync().sendFullUpdate(player)

    if castle.coffinBlockId == blockId then
        castle.coffinPos = nil
        castle.coffinBlockId = nil
    end

    if foundBlock.part and foundBlock.part.Parent then
        FunctionalDispatcher.onRemove(foundBlock.part, foundBlock.typeId, blockId)
        BlockHealth.cleanupBlock(foundBlock.part)
        foundBlock.part:Destroy()
    end

    castle.blocks[blockId] = nil
    castle.blockCount -= 1

    EventBus.fire("BlockRemoved", player, foundBlock.position)
    broadcastSync(castle)

    print("[BuildingManager] " .. player.Name .. " removed " .. foundBlock.typeId
        .. " at " .. tostring(foundBlock.position))
    return true
end

-- ═══════════════════════════════════════════════════════════
-- EventBus: BlockDestroyedByDamage
-- ═══════════════════════════════════════════════════════════

EventBus.on("BlockDestroyedByDamage", function(entity, attacker, ownerId, typeId, blockId)
    local castle = castles[ownerId]
    if not castle then return end

    local block = castle.blocks[blockId]
    if not block then return end

    if castle.coffinBlockId == blockId then
        castle.coffinPos = nil
        castle.coffinBlockId = nil
    end

    FunctionalDispatcher.onRemove(entity, typeId, blockId)

    if entity and entity.Parent then
        entity:Destroy()
    end

    castle.blocks[blockId] = nil
    castle.blockCount -= 1

    EventBus.fire("BlockRemoved", nil, block.position)
    broadcastSync(castle)

    print("[BuildingManager] Block destroyed by damage: " .. typeId
        .. " at " .. tostring(block.position) .. " (attacker: "
        .. (attacker and attacker.Name or "unknown") .. ")")
end)

-- ═══════════════════════════════════════════════════════════
-- Публичное API: вызывается CastleHeartManager при StructureDestroyed
-- ═══════════════════════════════════════════════════════════

function BuildingManager.onHeartDestroyedByDamage(ownerId, heartEntity, attacker)
    local castle = castles[ownerId]
    if not castle then return end

    FunctionalDispatcher.getChestHandler().dropAllLoot(castle)
    FunctionalDispatcher.getSawmillHandler().dropAllLoot(castle)

    destroyAllBlocks(castle)

    -- TargetFinder cleanup (HealthManager уже очищен в die())
    local TargetFinder = require(ServerScriptService:WaitForChild("combat"):WaitForChild("TargetFinder"))
    TargetFinder.removeStaticEntity(heartEntity)

    -- Уничтожить Model
    if castle.heartPart and castle.heartPart.Parent then
        castle.heartPart:Destroy()
    end

    if castle.folder and castle.folder.Parent then
        castle.folder:Destroy()
    end

    CastleBorder.removeClaim(ownerId)
    castles[ownerId] = nil

    EventBus.fire("CastleDestroyed", nil)
    print("[BuildingManager] Castle destroyed (heart killed) for owner " .. tostring(ownerId))
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: данные
-- ═══════════════════════════════════════════════════════════

function BuildingManager.collect(player)
    local castle = castles[player.UserId]
    if not castle then return nil end
    local claimData = CastleBorder.serializeClaim(player.UserId)
    local chestSerializer = FunctionalDispatcher.getChestHandler().getSerializer()
    local sawmillSerializer = FunctionalDispatcher.getSawmillHandler().getSerializer()

    -- Комбинированный сериализатор: пробует chest, потом sawmill
    local function combinedSerializer(containerId)
        local result = chestSerializer(containerId)
        if result then return result end
        return sawmillSerializer(containerId)
    end

    return BuildingSerializer.serialize(castle, claimData, combinedSerializer)
end

function BuildingManager.getCoffinPos(player)
    local castle = castles[player.UserId]
    return castle and castle.coffinPos or nil
end

function BuildingManager.getCastle(ownerId)
    return castles[ownerId]
end

function BuildingManager.getAllCastles()
    return castles
end

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

function BuildingManager.getAllCastlesInfo()
    local result = {}
    for ownerId, castle in castles do
        table.insert(result, {
            OwnerId = ownerId,
            CenterPos = castle.centerPos,
            BlockCount = castle.blockCount,
            HeartLevel = castle.heartLevel,
        })
    end
    return result
end

-- ═══════════════════════════════════════════════════════════
-- Очистка
-- ═══════════════════════════════════════════════════════════

function BuildingManager.cleanup(player)
    local ownerId = player.UserId
    local castle = castles[ownerId]
    if not castle then return end

    destroyAllBlocks(castle)
    CastleHeartManager.destroyHeart(castle)

    if castle.folder and castle.folder.Parent then
        castle.folder:Destroy()
    end

    CastleBorder.removeClaim(ownerId)
    castles[ownerId] = nil

    print("[BuildingManager] Cleaned up castle for " .. player.Name)
end

return BuildingManager