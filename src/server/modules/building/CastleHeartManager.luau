--[[
    CastleHeartManager.luau
    Управление Castle Heart: создание модели, визуал (сфера/пьедестал/платформа),
    размещение, апгрейд, уничтожение, эссенция, получение info для UI.

    Не хранит castles таблицу — получает/обновляет через BuildingManager API.

    Используется: BuildingManager, BuildingServer
    Зависимости: Config, BuildingValidator, CastleBorder, HealthManager,
                 InventoryManager (lazy), InventorySync (lazy),
                 TargetFinder (lazy), EventBus, Remotes
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

-- Lazy require BuildingManager (для доступа к castles и broadcastSync)
local _BuildingManager
local function getBuildingManager()
    if not _BuildingManager then
        _BuildingManager = require(script.Parent:WaitForChild("BuildingManager"))
    end
    return _BuildingManager
end

local CastleHeartManager = {}

-- ═══════════════════════════════════════════════════════════
-- Приватные хелперы: визуал
-- ═══════════════════════════════════════════════════════════

--- Рассчитать параметры сферы по количеству эссенции.
local function calcOrbParams(essenceAmount)
    local vis = Config.Building.CastleHeart.Visual
    local orb = vis.Orb
    local maxEssence = vis.MaxEssenceCapacity

    local t = math.clamp((essenceAmount or 0) / maxEssence, 0, 1)

    local diameter = orb.MinDiameter + (orb.MaxDiameter - orb.MinDiameter) * t
    local color = orb.EmptyColor:Lerp(orb.FullColor, t)
    local brightness = orb.Light.MinBrightness + (orb.Light.MaxBrightness - orb.Light.MinBrightness) * t
    local lightRange = orb.Light.MinRange + (orb.Light.MaxRange - orb.Light.MinRange) * t

    return diameter, color, brightness, lightRange
end

--- Создать Model для Castle Heart (платформа + пьедестал + сфера + PointLight).
--- @param position Vector3
--- @param level number
--- @param folder Folder
--- @param essenceAmount number?
--- @return Model
function CastleHeartManager.createModel(position, level, folder, essenceAmount)
    local heartCfg = Config.Building.CastleHeart
    local vis = heartCfg.Visual
    essenceAmount = essenceAmount or 0

    local model = Instance.new("Model")
    model.Name = "CastleHeart"

    -- Platform
    local platform = Instance.new("Part")
    platform.Name = "Platform"
    platform.Size = vis.Platform.Size
    platform.Material = vis.Platform.Material
    platform.Color = vis.Platform.Color
    platform.Anchored = true
    platform.CanCollide = true
    platform.Position = position
    platform.Parent = model

    model.PrimaryPart = platform

    -- Pedestal
    local pedestal = Instance.new("Part")
    pedestal.Name = "Pedestal"
    pedestal.Shape = Enum.PartType.Cylinder
    pedestal.Size = Vector3.new(vis.Pedestal.Height, vis.Pedestal.Diameter, vis.Pedestal.Diameter)
    pedestal.Material = vis.Pedestal.Material
    pedestal.Color = vis.Pedestal.Color
    pedestal.Anchored = true
    pedestal.CanCollide = true
    pedestal.Orientation = Vector3.new(0, 0, 90)
    pedestal.Position = platform.Position + Vector3.new(0, vis.Platform.Size.Y / 2 + vis.Pedestal.Height / 2, 0)
    pedestal.Parent = model

    -- Orb
    local diameter, orbColor, brightness, lightRange = calcOrbParams(essenceAmount)

    local orb = Instance.new("Part")
    orb.Name = "Orb"
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(diameter, diameter, diameter)
    orb.Material = vis.Orb.Material
    orb.Color = orbColor
    orb.Anchored = true
    orb.CanCollide = false
    orb.Position = pedestal.Position + Vector3.new(0, vis.Pedestal.Height / 2 + diameter / 2, 0)
    orb.Parent = model

    -- PointLight
    local light = Instance.new("PointLight")
    light.Name = "OrbLight"
    light.Color = vis.Orb.Light.Color
    light.Brightness = brightness
    light.Range = lightRange
    light.Shadows = true
    light.Parent = orb

    model:SetAttribute("BloodEssence", essenceAmount)
    model.Parent = folder

    return model
end

--- Инициализировать атрибуты, HealthManager, TargetFinder для Castle Heart.
--- @param heartModel Model
--- @param level number
--- @param ownerId number
--- @param blockId string
function CastleHeartManager.initSystems(heartModel, level, ownerId, blockId)
    local heartCfg = Config.Building.CastleHeart
    local levelData = heartCfg.Levels[level]
    local primaryPart = heartModel.PrimaryPart

    -- Атрибуты на Model
    heartModel:SetAttribute("IsStructure", true)
    heartModel:SetAttribute("IsCastleHeart", true)
    heartModel:SetAttribute("CastleOwnerId", ownerId)
    heartModel:SetAttribute("HeartLevel", level)
    heartModel:SetAttribute("BlockId", blockId)

    -- Атрибуты на PrimaryPart
    primaryPart:SetAttribute("IsStructure", true)
    primaryPart:SetAttribute("IsCastleHeart", true)
    primaryPart:SetAttribute("CastleOwnerId", ownerId)

    HealthManager.init(primaryPart, levelData.HP)
    getTargetFinder().addStaticEntity(primaryPart)
end

--- Очистить HealthManager и TargetFinder для Castle Heart.
--- @param heartModel Model
function CastleHeartManager.cleanupSystems(heartModel)
    local primaryPart = heartModel.PrimaryPart
    if primaryPart then
        getTargetFinder().removeStaticEntity(primaryPart)
        HealthManager.cleanup(primaryPart)
    end
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: эссенция
-- ═══════════════════════════════════════════════════════════

--- Обновить визуал сферы по количеству эссенции.
--- @param castle table — данные замка
--- @param essenceAmount number
function CastleHeartManager.updateEssence(castle, essenceAmount)
    if not castle or not castle.heartPart then return end

    local heartModel = castle.heartPart
    heartModel:SetAttribute("BloodEssence", essenceAmount or 0)

    local orb = heartModel:FindFirstChild("Orb")
    if not orb then return end

    local diameter, orbColor, brightness, lightRange = calcOrbParams(essenceAmount)

    orb.Size = Vector3.new(diameter, diameter, diameter)
    orb.Color = orbColor

    local pedestal = heartModel:FindFirstChild("Pedestal")
    if pedestal then
        local vis = Config.Building.CastleHeart.Visual
        orb.Position = pedestal.Position + Vector3.new(0, vis.Pedestal.Height / 2 + diameter / 2, 0)
    end

    local light = orb:FindFirstChild("OrbLight")
    if light then
        light.Brightness = brightness
        light.Range = lightRange
    end
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: размещение
-- ═══════════════════════════════════════════════════════════

--- Разместить Castle Heart. Создаёт замок.
--- @param player Player
--- @param rawPosition Vector3
--- @param castles table — ссылка на таблицу castles из BuildingManager
--- @param makeBlockId function — генератор blockId
--- @param getCastleFolder function(ownerId) → Folder
--- @return boolean, string?
function CastleHeartManager.place(player, rawPosition, castles, makeBlockId, getCastleFolder)
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

    local vis = Config.Building.CastleHeart.Visual
    local platformH = vis.Platform.Size.Y

    -- Raycast
    local surfaceY = 0
    local rayOrigin = Vector3.new(snapped.X, 500, snapped.Z)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excludeList = {}
    local castlesFolder = workspace:FindFirstChild("Castles")
    if castlesFolder then
        table.insert(excludeList, castlesFolder)
    end
    if player.Character then
        table.insert(excludeList, player.Character)
    end
    params.FilterDescendantsInstances = excludeList

    local result = workspace:Raycast(rayOrigin, Vector3.new(0, -1000, 0), params)
    if result then
        surfaceY = result.Position.Y
    end

    local finalPos = Vector3.new(snapped.X, surfaceY + platformH / 2, snapped.Z)

    local ok, err = CastleBorder.registerClaim(ownerId, finalPos, 1)
    if not ok then
        return false, err
    end

    local folder = getCastleFolder(ownerId)
    local heartBlockId = makeBlockId()
    local heartModel = CastleHeartManager.createModel(finalPos, 1, folder)
    CastleHeartManager.initSystems(heartModel, 1, ownerId, heartBlockId)

    castles[ownerId] = {
        ownerId = ownerId,
        centerPos = finalPos,
        blocks = {},
        blockCount = 0,
        folder = folder,
        coffinPos = nil,
        coffinBlockId = nil,
        heartPart = heartModel,
        heartBlockId = heartBlockId,
        heartLevel = 1,
    }

    EventBus.fire("CastleHeartPlaced", player, finalPos)

    print("[CastleHeartManager] " .. player.Name .. " placed Castle Heart at " .. tostring(finalPos))
    return true
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: апгрейд
-- ═══════════════════════════════════════════════════════════

--- Улучшить Castle Heart.
--- @param player Player
--- @param castle table
--- @return boolean, string?
function CastleHeartManager.upgrade(player, castle)
    local ownerId = player.UserId
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

    if castle.heartPart then
        castle.heartPart:SetAttribute("HeartLevel", nextLevel)
        local primaryPart = castle.heartPart.PrimaryPart
        if primaryPart then
            HealthManager.setMaxHP(primaryPart, levelData.HP)
        end
    end

    print("[CastleHeartManager] " .. player.Name .. " upgraded to level " .. nextLevel)
    return true
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: уничтожение
-- ═══════════════════════════════════════════════════════════

--- Уничтожить Castle Heart Model и очистить системы.
--- НЕ уничтожает блоки — это делает BuildingManager.
--- @param castle table
function CastleHeartManager.destroyHeart(castle)
    if castle.heartPart then
        CastleHeartManager.cleanupSystems(castle.heartPart)
        if castle.heartPart.Parent then
            castle.heartPart:Destroy()
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: info для UI
-- ═══════════════════════════════════════════════════════════

--- Собрать данные Castle Heart для клиентского UI.
--- @param castle table
--- @param ownerId number
--- @param countFunctionalFn function(castle, type) → number
--- @return table
function CastleHeartManager.getInfo(castle, ownerId, countFunctionalFn)
    local heartCfg = Config.Building.CastleHeart
    local levelData = heartCfg.Levels[castle.heartLevel]

    local currentHP = 0
    local maxHP = levelData and levelData.HP or 1000
    if castle.heartPart and castle.heartPart.PrimaryPart then
        currentHP = castle.heartPart.PrimaryPart:GetAttribute("CurrentHP") or maxHP
    end

    return {
        HeartLevel = castle.heartLevel,
        MaxLevel = heartCfg.MaxLevel,
        CurrentHP = currentHP,
        MaxHP = maxHP,
        BlockCount = castle.blockCount,
        MaxBlocks = levelData and levelData.MaxBlocks or 200,
        CoffinCount = countFunctionalFn(castle, "Coffin"),
        MaxCoffins = levelData and levelData.MaxCoffins or 1,
        CenterPos = castle.centerPos,
        ClaimRadius = levelData and levelData.ClaimRadius or 48,
        BloodEssence = castle.heartPart and castle.heartPart:GetAttribute("BloodEssence") or 0,
        MaxEssenceCapacity = heartCfg.Visual.MaxEssenceCapacity,
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

-- ═══════════════════════════════════════════════════════════
-- EventBus: StructureDestroyed — перехват Castle Heart
-- ═══════════════════════════════════════════════════════════

EventBus.on("StructureDestroyed", function(entity, attacker)
    if not entity or not entity:GetAttribute("IsCastleHeart") then
        return
    end

    local ownerId = entity:GetAttribute("CastleOwnerId")

    -- Делегируем каскадное уничтожение BuildingManager
    local BM = getBuildingManager()
    local castle = BM.getCastle(ownerId)
    if not castle then return end

    print("[CastleHeartManager] Castle Heart destroyed by damage! Owner: " .. tostring(ownerId))

    -- Каскадно уничтожаем блоки через BuildingManager
    BM.onHeartDestroyedByDamage(ownerId, entity, attacker)
end)

return CastleHeartManager