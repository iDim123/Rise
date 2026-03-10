--[[
    BuildingManager.luau
    Ядро строительной системы. Управляет данными замков, размещением и удалением блоков.
    Castle Heart — центральный элемент замка, первый блок. Без него замок не существует.

    Состояние:
      castles[ownerId] = {
          ownerId, centerPos, blocks, blockCount, folder,
          coffinPos, coffinBlockId,
          heartPart, heartBlockId, heartLevel
      }

    Используется: BuildingServer, DataService, PlayerLifecycle, Main.server
    Зависимости: Config, BuildingValidator, BuildingSerializer, CastleBorder,
                 BlockHealth, InventoryManager (lazy), InventorySync (lazy),
                 EventBus, Remotes, HealthManager
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local EventBus = require(modules:WaitForChild("EventBus"))
local HealthManager = require(modules:WaitForChild("HealthManager"))

local BuildingValidator = require(script.Parent:WaitForChild("BuildingValidator"))
local BuildingSerializer = require(script.Parent:WaitForChild("BuildingSerializer"))
local CastleBorder = require(script.Parent:WaitForChild("CastleBorder"))
local BlockHealth = require(script.Parent:WaitForChild("BlockHealth"))

-- Lazy requires
local _InventoryManager, _InventorySync, _TargetFinder
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
local function getTargetFinder()
    if not _TargetFinder then
        _TargetFinder = require(ServerScriptService:WaitForChild("combat"):WaitForChild("TargetFinder"))
    end
    return _TargetFinder
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
    part.Orientation = Vector3.new(0, rotation, 0)

    if bt.IsShelter then
        part:SetAttribute("IsShelter", true)
    end

    part.Parent = folder
    return part
end

--- Создать Part для Castle Heart
local function createHeartPart(position, level, folder)
    local heartCfg = Config.Building.CastleHeart

    local part = Instance.new("Part")
    part.Name = "CastleHeart"
    part.Size = heartCfg.Size
    part.Material = heartCfg.Material
    part.Color = heartCfg.Color
    part.Anchored = true
    part.CanCollide = true
    part.Position = position
    part.Parent = folder

    return part
end

--- Инициализировать атрибуты и системы для Castle Heart part.
--- Регистрирует в HealthManager и TargetFinder напрямую (не через BlockHealth),
--- потому что Castle Heart имеет особую логику уничтожения.
local function initHeartSystems(part, level, ownerId, blockId)
    local heartCfg = Config.Building.CastleHeart
    local levelData = heartCfg.Levels[level]

    -- Атрибуты
    part:SetAttribute("IsStructure", true)
    part:SetAttribute("IsCastleHeart", true)
    part:SetAttribute("CastleOwnerId", ownerId)
    part:SetAttribute("HeartLevel", level)
    part:SetAttribute("BlockId", blockId)

    -- HealthManager
    HealthManager.init(part, levelData.HP)

    -- TargetFinder
    getTargetFinder().addStaticEntity(part)
end

--- Очистить системы Castle Heart part
local function cleanupHeartSystems(part)
    getTargetFinder().removeStaticEntity(part)
    HealthManager.cleanup(part)
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

-- ═══════════════════════════════════════════════════════════
-- Публичное API: инициализация
-- ═══════════════════════════════════════════════════════════

function BuildingManager.init()
    getCastlesRoot()
    print("[BuildingManager] Initialized")
end

function BuildingManager.initPlayer(player, savedData)
    local ownerId = player.UserId

    if not savedData then
        return
    end

    local deserialized = BuildingSerializer.deserialize(savedData)
    if not deserialized then
        warn("[BuildingManager] Failed to deserialize castle for " .. player.Name)
        return
    end

    -- FIX: передаём heartLevel и permissions как отдельные аргументы
    local heartLevel = deserialized.heartLevel or 1
    local ok, err = CastleBorder.registerClaim(
        ownerId,
        deserialized.centerPos,
        heartLevel,
        deserialized.permissions
    )
    if not ok then
        warn("[BuildingManager] Failed to register claim for " .. player.Name .. ": " .. (err or ""))
        return
    end

    local folder = getCastleFolder(ownerId)

    -- FIX: создаём Castle Heart part при загрузке
    local heartBlockId = makeBlockId()
    local heartPart = createHeartPart(deserialized.centerPos, heartLevel, folder)
    initHeartSystems(heartPart, heartLevel, ownerId, heartBlockId)

    castles[ownerId] = {
        ownerId = ownerId,
        centerPos = deserialized.centerPos,
        blocks = {},
        blockCount = 0,
        folder = folder,
        coffinPos = nil,
        coffinBlockId = nil,
        heartPart = heartPart,
        heartBlockId = heartBlockId,
        heartLevel = heartLevel,
    }
    local castle = castles[ownerId]

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

            local bt = Config.Building.BlockTypes[blockData.typeId]
            if bt and bt.Functional == "Coffin" then
                castle.coffinPos = blockData.position + Vector3.new(0, 1, 0)
                castle.coffinBlockId = blockId
            end
        end
    end

    print("[BuildingManager] Restored castle for " .. player.Name
        .. ": " .. castle.blockCount .. " blocks, heart level " .. heartLevel)
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: Castle Heart
-- ═══════════════════════════════════════════════════════════

function BuildingManager.placeCastleHeart(player, rawPosition)
    local ownerId = player.UserId

    if CastleBorder.hasCastle(ownerId) then
        return false, "У вас уже есть замок"
    end

    local castleCount = 0
    for _ in castles do castleCount += 1 end
    if castleCount >= Config.Building.MaxCastlesPerWorld then
        return false, "Достигнут лимит замков на сервере"
    end

    local snapped = BuildingValidator.snapPosition(rawPosition)

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

    -- Проверка пересечения с чужими территориями
    local ok, err = CastleBorder.registerClaim(ownerId, finalPos, 1)
    if not ok then
        return false, err
    end

    local folder = getCastleFolder(ownerId)

    -- Создаём Part
    local heartBlockId = makeBlockId()
    local part = createHeartPart(finalPos, 1, folder)
    initHeartSystems(part, 1, ownerId, heartBlockId)

    castles[ownerId] = {
        ownerId = ownerId,
        centerPos = finalPos,
        blocks = {},
        blockCount = 0,
        folder = folder,
        coffinPos = nil,
        coffinBlockId = nil,
        heartPart = part,
        heartBlockId = heartBlockId,
        heartLevel = 1,
    }

    EventBus.fire("CastleHeartPlaced", player, finalPos)
    broadcastSync(castles[ownerId])

    print("[BuildingManager] " .. player.Name .. " placed Castle Heart at " .. tostring(finalPos))
    return true
end

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

    local canUp, upErr = CastleBorder.canUpgrade(ownerId, nextLevel)
    if not canUp then
        return false, upErr
    end

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

    castle.heartLevel = nextLevel
    CastleBorder.setHeartLevel(ownerId, nextLevel)

    if castle.heartPart and castle.heartPart.Parent then
        HealthManager.setMaxHP(castle.heartPart, levelData.HP)
        castle.heartPart:SetAttribute("HeartLevel", nextLevel)
    end

    broadcastSync(castle)

    print("[BuildingManager] " .. player.Name .. " upgraded Castle Heart to level " .. nextLevel)
    return true
end

--- Уничтожить весь замок. ТОЛЬКО владелец.
--- Весь лут из сундуков → на землю.
function BuildingManager.destroyCastle(player)
    local ownerId = player.UserId
    local castle = castles[ownerId]
    if not castle then return false, "Нет замка" end

    -- Phase 2: дроп лута из сундуков
    -- for blockId, block in castle.blocks do
    --     if block.containerId then ... end
    -- end

    -- Уничтожаем все блоки
    for blockId, block in castle.blocks do
        if block.part and block.part.Parent then
            BlockHealth.cleanupBlock(block.part)
            block.part:Destroy()
        end
    end

    -- Уничтожаем Castle Heart
    if castle.heartPart and castle.heartPart.Parent then
        cleanupHeartSystems(castle.heartPart)
        castle.heartPart:Destroy()
    end

    if castle.folder and castle.folder.Parent then
        castle.folder:Destroy()
    end

    CastleBorder.removeClaim(ownerId)
    castles[ownerId] = nil

    EventBus.fire("CastleDestroyed", player)

    print("[BuildingManager] " .. player.Name .. " destroyed their castle")
    return true
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

    -- 1. Определить замок — ТРЕБУЕТСЯ Castle Heart
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
            -- FIX: без Castle Heart строить нельзя
            return false, "Сначала поставьте Сердце замка"
        end
    end

    -- 2. Проверка ресурсов
    local canPay, payErr = BuildingValidator.canAfford(player, blockTypeId)
    if not canPay then
        return false, payErr
    end

    -- 3. Получить замок (должен уже существовать после placeCastleHeart)
    local castle = castles[castleOwnerId]
    if not castle then
        return false, "Сначала поставьте Сердце замка"
    end
    local folder = castle.folder

    -- 4. Рассчитать позицию
    local finalPos, surfaceY, hitPart = BuildingValidator.calcPlacementPos(
        blockTypeId, rawPosition, rot, folder
    )
    if not finalPos then
        return false, "Не удалось определить позицию"
    end

    -- 5. Полная валидация (FIX: передаём maxBlocks, maxCoffins, heartPosition, heartSize)
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
        heartPosition = castle.heartPart and castle.heartPart.Position or nil,
        heartSize = heartCfg.Size,
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

    -- 8. BlockHealth
    BlockHealth.initBlock(part, blockTypeId, castleOwnerId, blockId)

    -- 9. Данные замка
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
-- EventBus: BlockDestroyedByDamage (от BlockHealth — обычные блоки)
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
-- EventBus: StructureDestroyed — перехват Castle Heart
-- Castle Heart НЕ проходит через BlockHealth, поэтому
-- StructureDestroyed для него обрабатывается здесь.
-- Уничтожение Castle Heart через урон ЗАПРЕЩЕНО
-- (только владелец через destroyCastle).
-- ═══════════════════════════════════════════════════════════

EventBus.on("StructureDestroyed", function(entity, attacker)
    if not entity or not entity:GetAttribute("IsCastleHeart") then
        return -- обычный блок — обрабатывается BlockHealth
    end

    -- Castle Heart уничтожен через урон → каскадное уничтожение замка
    local ownerId = entity:GetAttribute("CastleOwnerId")
    local castle = castles[ownerId]
    if not castle then return end

    print("[BuildingManager] Castle Heart destroyed by damage! Owner: " .. tostring(ownerId))

    -- Уничтожаем все блоки замка
    for blockId, block in castle.blocks do
        if block.part and block.part.Parent then
            BlockHealth.cleanupBlock(block.part)
            block.part:Destroy()
        end
    end

    -- Castle Heart part: очищаем из TargetFinder (healthData уже очищен HealthManager.die)
    if entity and entity.Parent then
        getTargetFinder().removeStaticEntity(entity)
        entity:Destroy()
    end

    if castle.folder and castle.folder.Parent then
        castle.folder:Destroy()
    end

    CastleBorder.removeClaim(ownerId)
    castles[ownerId] = nil

    EventBus.fire("CastleDestroyed", nil) -- nil = не по команде игрока

    print("[BuildingManager] Castle destroyed (heart killed) for owner " .. tostring(ownerId))
end)

-- ═══════════════════════════════════════════════════════════
-- Публичное API: данные
-- ═══════════════════════════════════════════════════════════

function BuildingManager.collect(player)
    local castle = castles[player.UserId]
    if not castle then return nil end

    -- FIX: serializeClaim (не serializePermissions) + включает HeartLevel
    local claimData = CastleBorder.serializeClaim(player.UserId)

    local containerSerializer = nil

    return BuildingSerializer.serialize(castle, claimData, containerSerializer)
end

function BuildingManager.getCoffinPos(player)
    local castle = castles[player.UserId]
    if not castle then return nil end
    return castle.coffinPos
end

function BuildingManager.getCastle(ownerId)
    return castles[ownerId]
end

--- Получить информацию о Castle Heart (для клиентского UI).
function BuildingManager.getCastleHeartInfo(ownerId)
    local castle = castles[ownerId]
    if not castle then return nil end

    local heartCfg = Config.Building.CastleHeart
    local levelData = heartCfg.Levels[castle.heartLevel]

    local currentHP = 0
    local maxHP = levelData and levelData.HP or 1000
    if castle.heartPart and castle.heartPart.Parent then
        currentHP = castle.heartPart:GetAttribute("CurrentHP") or maxHP
    end

    return {
        HeartLevel = castle.heartLevel,
        MaxLevel = heartCfg.MaxLevel,
        CurrentHP = currentHP,
        MaxHP = maxHP,
        BlockCount = castle.blockCount,
        MaxBlocks = levelData and levelData.MaxBlocks or 200,
        CoffinCount = countFunctional(castle, "Coffin"),
        MaxCoffins = levelData and levelData.MaxCoffins or 1,
        CenterPos = castle.centerPos,
        ClaimRadius = levelData and levelData.ClaimRadius or 48,
        UpgradeCost = castle.heartLevel < heartCfg.MaxLevel
            and heartCfg.Levels[castle.heartLevel + 1].UpgradeCost
            or nil,
        Allies = CastleBorder.getAllies(ownerId),
        Permissions = {
            AllowCoopBuild = CastleBorder.canBuild(0, ownerId) or false,
            AllowCoopRemove = CastleBorder.canRemove(0, ownerId) or false,
            AllowCoopInteract = CastleBorder.canInteract(0, ownerId) or false,
        },
    }
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

    for blockId, block in castle.blocks do
        if block.part and block.part.Parent then
            BlockHealth.cleanupBlock(block.part)
            block.part:Destroy()
        end
    end

    -- Castle Heart cleanup
    if castle.heartPart and castle.heartPart.Parent then
        cleanupHeartSystems(castle.heartPart)
        castle.heartPart:Destroy()
    end

    if castle.folder and castle.folder.Parent then
        castle.folder:Destroy()
    end

    CastleBorder.removeClaim(ownerId)
    castles[ownerId] = nil

    print("[BuildingManager] Cleaned up castle for " .. player.Name)
end

return BuildingManager