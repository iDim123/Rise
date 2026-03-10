--[[
    BuildingValidator.luau
    Чистые функции валидации размещения блоков.

    Все функции не имеют побочных эффектов (не создают Part, не модифицируют состояние).
    Получают данные через параметры, возвращают boolean + причину отказа.

    Используется: BuildingManager.placeBlock, BuildingPlacer (клиентская превалидация — частично)

    Зависимости: Config (Building)
]] local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local BuildingValidator = {}

-- ═══════════════════════════════════════════════════════════
-- Приватные хелперы
-- ═══════════════════════════════════════════════════════════

local function getBuildingConfig()
    return Config.Building
end

--- Привязать координату к сетке.
--- @param value number
--- @param gridSize number
--- @return number
local function snapToGrid(value, gridSize)
    return math.round(value / gridSize) * gridSize
end

--- Привязать позицию к сетке (XZ). Y не привязывается — определяется PlacementRule.
--- @param position Vector3
--- @return Vector3
local function snapPositionXZ(position)
    local gridSize = getBuildingConfig().GridSize
    return Vector3.new(snapToGrid(position.X, gridSize), position.Y, snapToGrid(position.Z, gridSize))
end

--- Нормализовать rotation к шагу 90°.
--- @param rotation number — градусы
--- @return number — 0, 90, 180 или 270
local function normalizeRotation(rotation)
    local r = math.round(rotation / 90) * 90
    return r % 360
end

--- Получить реальный Size блока с учётом поворота.
--- При повороте на 90° или 270° — X и Z меняются местами.
--- @param baseSize Vector3
--- @param rotation number — нормализованный (0/90/180/270)
--- @return Vector3
local function getRotatedSize(baseSize, rotation)
    if rotation == 90 or rotation == 270 then
        return Vector3.new(baseSize.Z, baseSize.Y, baseSize.X)
    end
    return baseSize
end

--- Рассчитать позицию центра блока для размещения.
--- X, Z — привязаны к сетке.
--- Y — зависит от PlacementRule и высоты блока.
--- @param snappedXZ Vector3 — позиция с привязанными X, Z
--- @param blockSize Vector3 — размер блока (с учётом поворота)
--- @param surfaceY number — Y-координата поверхности, на которую ставится блок
--- @return Vector3
local function calcPlacementPosition(snappedXZ, blockSize, surfaceY)
    return Vector3.new(snappedXZ.X, surfaceY + blockSize.Y / 2, snappedXZ.Z)
end

--- Создать AABB (axis-aligned bounding box) из центра и размера.
--- @param center Vector3
--- @param size Vector3
--- @return Vector3, Vector3 — min, max
local function makeAABB(center, size)
    local half = size / 2
    return center - half, center + half
end

--- Проверить пересечение двух AABB.
--- @param minA Vector3
--- @param maxA Vector3
--- @param minB Vector3
--- @param maxB Vector3
--- @return boolean
local function aabbOverlap(minA, maxA, minB, maxB)
    -- Небольшой допуск чтобы соседние блоки не считались пересекающимися
    local EPSILON = 0.05
    return minA.X < maxB.X - EPSILON and maxA.X > minB.X + EPSILON and minA.Y < maxB.Y - EPSILON and maxA.Y > minB.Y +
               EPSILON and minA.Z < maxB.Z - EPSILON and maxA.Z > minB.Z + EPSILON
end

--- Категория блока по его конфигу.
--- @param blockTypeId string
--- @return string | nil
local function getBlockCategory(blockTypeId)
    local bt = getBuildingConfig().BlockTypes[blockTypeId]
    return bt and bt.Category or nil
end

-- ═══════════════════════════════════════════════════════════
-- PlacementRule Raycast
-- ═══════════════════════════════════════════════════════════

--- Выполнить Raycast вниз из центра позиции блока, чтобы определить
--- на что ставится блок (Terrain, Baseplate, другой блок, ничего).
--- @param position Vector3 — предполагаемый центр нового блока
--- @param blockSize Vector3 — размер нового блока (с поворотом)
--- @param castleFolder Folder — папка workspace.Castles.<Owner>
--- @return Instance | nil — объект под блоком
--- @return Vector3 | nil — точка попадания
--- @return number | nil — Y верхней поверхности объекта под блоком
local function raycastDown(position, blockSize, castleFolder)
    local rayOrigin = Vector3.new(position.X, position.Y + 500, position.Z)
    local rayDirection = Vector3.new(0, -1000, 0)

    -- FIX: Exclude вместо Include — чтобы Terrain попадал в raycast.
    -- Исключаем только персонажей игроков.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local excludeList = {}
    for _, plr in game:GetService("Players"):GetPlayers() do
        if plr.Character then
            table.insert(excludeList, plr.Character)
        end
    end
    params.FilterDescendantsInstances = excludeList

    local result = workspace:Raycast(rayOrigin, rayDirection, params)
    if result and result.Instance then
        return result.Instance, result.Position, result.Position.Y
    end

    return nil, nil, nil
end

--- Определить, допустим ли объект под блоком для данного PlacementRule.
--- @param rule string — PlacementRule нового блока
--- @param hitPart Instance | nil — на что попал Raycast
--- @return boolean, string?
local function validateSurface(rule, hitPart)
    if rule == "Ground" then
        if not hitPart then
            return false, "Нет поверхности"
        end
        if hitPart.Name == "Baseplate" then
            return true
        end
        if hitPart:IsA("Terrain") then
            return true
        end
        return false, "Фундамент можно ставить только на землю"
    end

    if rule == "OnFoundation" then
        if not hitPart then
            return false, "Нет опоры"
        end
        if not hitPart:GetAttribute("IsStructure") then
            return false, "Нужен фундамент"
        end
        local typeId = hitPart:GetAttribute("BlockTypeId")
        if typeId then
            local category = getBlockCategory(typeId)
            if category == "Foundation" then
                return true
            end
        end
        return false, "Нужен фундамент"
    end

    if rule == "OnWall" then
        if not hitPart then
            return false, "Нет опоры"
        end
        if not hitPart:GetAttribute("IsStructure") then
            return false, "Нужна стена или колонна"
        end
        local typeId = hitPart:GetAttribute("BlockTypeId")
        if typeId then
            local category = getBlockCategory(typeId)
            if category == "Wall" then
                return true
            end
        end
        return false, "Нужна стена или колонна"
    end

    if rule == "Any" then
        return true
    end

    return false, "Неизвестное PlacementRule: " .. tostring(rule)
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API
-- ═══════════════════════════════════════════════════════════

--- Привязать позицию к сетке (только XZ).
--- Используется клиентом для ghost-preview и сервером для валидации.
--- @param position Vector3
--- @return Vector3
function BuildingValidator.snapPosition(position)
    return snapPositionXZ(position)
end

--- Нормализовать поворот.
--- @param rotation number
--- @return number
function BuildingValidator.normalizeRotation(rotation)
    return normalizeRotation(rotation)
end

--- Получить размер блока с учётом поворота.
--- @param blockTypeId string
--- @param rotation number
--- @return Vector3 | nil
function BuildingValidator.getRotatedSize(blockTypeId, rotation)
    local bt = getBuildingConfig().BlockTypes[blockTypeId]
    if not bt then
        return nil
    end
    return getRotatedSize(bt.Size, normalizeRotation(rotation))
end

--- Найти ближайший край фундамента для размещения стены.
--- Стена привязывается к одной из четырёх сторон фундамента.
--- @param wallSnapped Vector3 — snap-позиция курсора (XZ)
--- @param wallSize Vector3 — размер стены (с поворотом)
--- @param hitPart Instance — фундамент, на который ставим
--- @return Vector3 — скорректированная позиция центра стены
--- @return number — surfaceY (верхняя грань фундамента)
local function snapWallToEdge(wallSnapped, wallSize, hitPart, rotation)
    local foundationPos = hitPart.Position
    local foundationSize = hitPart.Size

    local surfaceY = foundationPos.Y + foundationSize.Y / 2

    -- Определяем ближайший край фундамента
    -- Стена толщиной 1 (Size.Z при rotation=0, Size.X при rotation=90)
    -- Смещаем к краю фундамента по направлению перпендикулярному стене

    local wallX = wallSnapped.X
    local wallZ = wallSnapped.Z
    local fX = foundationPos.X
    local fZ = foundationPos.Z
    local halfFX = foundationSize.X / 2
    local halfFZ = foundationSize.Z / 2

    if rotation == 0 or rotation == 180 then
        -- Стена идёт вдоль X, толщина по Z
        -- Привязываем Z к ближнему краю фундамента
        local northEdge = fZ - halfFZ -- ближний край
        local southEdge = fZ + halfFZ -- дальний край
        local distNorth = math.abs(wallZ - northEdge)
        local distSouth = math.abs(wallZ - southEdge)

        if distNorth <= distSouth then
            wallZ = northEdge
        else
            wallZ = southEdge
        end
        -- X привязываем к центру фундамента
        wallX = fX
    else
        -- rotation == 90 или 270
        -- Стена идёт вдоль Z, толщина по X
        local westEdge = fX - halfFX
        local eastEdge = fX + halfFX
        local distWest = math.abs(wallX - westEdge)
        local distEast = math.abs(wallX - eastEdge)

        if distWest <= distEast then
            wallX = westEdge
        else
            wallX = eastEdge
        end
        -- Z привязываем к центру фундамента
        wallZ = fZ
    end

    local finalPos = Vector3.new(wallX, surfaceY + wallSize.Y / 2, wallZ)
    return finalPos, surfaceY
end

--- Рассчитать финальную позицию размещения блока.
function BuildingValidator.calcPlacementPos(blockTypeId, rawPosition, rotation, castleFolder)
    local bt = getBuildingConfig().BlockTypes[blockTypeId]
    if not bt then
        return nil
    end

    local rot = normalizeRotation(rotation)
    local size = getRotatedSize(bt.Size, rot)
    local snapped = snapPositionXZ(rawPosition)

    local hitPart, hitPos, surfaceY = raycastDown(snapped, size, castleFolder)

    if not surfaceY then
        surfaceY = 0
    end

    -- Стены и функциональные блоки на фундаменте: привязка к краю
    if bt.PlacementRule == "OnFoundation" and hitPart and hitPart:GetAttribute("IsStructure") then
        local hitTypeId = hitPart:GetAttribute("BlockTypeId")
        local hitCategory = hitTypeId and getBlockCategory(hitTypeId)

        if hitCategory == "Foundation" and bt.Category == "Wall" then
            -- Стена → snap к краю фундамента
            local edgePos, edgeSurfaceY = snapWallToEdge(snapped, size, hitPart, rot)
            return edgePos, edgeSurfaceY, hitPart
        end
    end

    -- Стандартное размещение (фундамент на земле, крыша на стене и т.д.)
    local finalPos = calcPlacementPosition(snapped, size, surfaceY)
    return finalPos, surfaceY, hitPart
end

--- Полная валидация размещения блока.
--- @param params table:
---   blockTypeId: string,
---   position: Vector3 — уже привязанная к сетке (после calcPlacementPos)
---   rotation: number — нормализованный
---   castleOwnerId: number — владелец замка
---   actorId: number — кто строит
---   blockCount: number — текущее количество блоков в замке
---   existingBlocks: { { position: Vector3, size: Vector3 } } — все блоки замка
---   castleFolder: Folder — папка замка
---   hitPart: Instance | nil — результат Raycast (из calcPlacementPos)
---   coffinCount: number? — количество гробов (для MaxPerCastle)
--- @return boolean, string?
function BuildingValidator.validate(params)
    local cfg = getBuildingConfig()
    local bt = cfg.BlockTypes[params.blockTypeId]

    -- 1. Тип блока существует
    if not bt then
        return false, "Неизвестный тип блока"
    end

    -- 2. Лимит блоков (FIX: из params, не из глобального конфига)
    local maxBlocks = params.maxBlocks or 200
    if params.blockCount >= maxBlocks then
        return false, "Достигнут лимит блоков (" .. maxBlocks .. ")"
    end

    -- 3. Поворот
    local rot = normalizeRotation(params.rotation)
    if not bt.CanRotate and rot ~= 0 then
        return false, "Этот блок нельзя поворачивать"
    end

    -- 4. PlacementRule
    local surfaceOk, surfaceErr = validateSurface(bt.PlacementRule, params.hitPart)
    if not surfaceOk then
        return false, surfaceErr
    end

    -- 5. Позиция внутри территории замка
    local CastleBorder = require(script.Parent:WaitForChild("CastleBorder"))
    if not CastleBorder.isWithinClaim(params.position, params.castleOwnerId) then
        return false, "За пределами территории замка"
    end

    -- 6. Коллизия с существующими блоками
    local size = getRotatedSize(bt.Size, rot)
    local minA, maxA = makeAABB(params.position, size)

    for _, block in params.existingBlocks do
        local minB, maxB = makeAABB(block.position, block.size)
        if aabbOverlap(minA, maxA, minB, maxB) then
            return false, "Пересечение с другим блоком"
        end
    end

    -- 7. FIX: Коллизия с Castle Heart
    if params.heartPosition and params.heartSize then
        local minH, maxH = makeAABB(params.heartPosition, params.heartSize)
        if aabbOverlap(minA, maxA, minH, maxH) then
            return false, "Пересечение с Сердцем замка"
        end
    end

    -- 8. FIX: Лимит гробов (из уровня Castle Heart, через params)
    if bt.Functional == "Coffin" then
        local maxCoffins = params.maxCoffins or 1
        local currentCoffins = params.coffinCount or 0
        if currentCoffins >= maxCoffins then
            return false, "Максимум " .. maxCoffins .. " гроб(ов) на замок"
        end
    end

    return true
end

--- Валидация удаления блока.
--- @param params table:
---   position: Vector3,
---   castleOwnerId: number,
---   actorId: number,
--- @return boolean, string?
function BuildingValidator.validateRemove(params)
    local CastleBorder = require(script.Parent:WaitForChild("CastleBorder"))

    -- Позиция внутри территории
    if not CastleBorder.isWithinClaim(params.position, params.castleOwnerId) then
        return false, "За пределами территории замка"
    end

    -- Права на удаление
    if not CastleBorder.canRemove(params.actorId, params.castleOwnerId) then
        return false, "Нет прав на удаление"
    end

    return true
end

--- Проверить стоимость блока: есть ли ресурсы в инвентаре.
--- Чистая проверка — не списывает ресурсы.
--- @param player Player
--- @param blockTypeId string
--- @return boolean, string?
function BuildingValidator.canAfford(player, blockTypeId)
    local bt = getBuildingConfig().BlockTypes[blockTypeId]
    if not bt then
        return false, "Неизвестный тип блока"
    end
    if not bt.Cost then
        return true
    end

    local InventoryManager = require(game:GetService("ServerScriptService"):WaitForChild("modules"):WaitForChild(
        "InventoryManager"))

    for _, cost in bt.Cost do
        local have = InventoryManager.countItem(player, cost.ItemId)
        if have < cost.Amount then
            return false, "Не хватает " .. cost.ItemId .. " (нужно " .. cost.Amount .. ", есть " ..
                have .. ")"
        end
    end

    return true
end

--- Рассчитать возврат ресурсов при удалении.
--- @param blockTypeId string
--- @return { { ItemId: string, Amount: number } }
function BuildingValidator.calcRefund(blockTypeId)
    local cfg = getBuildingConfig()
    local bt = cfg.BlockTypes[blockTypeId]
    if not bt or not bt.Cost then
        return {}
    end

    local refund = {}
    local rate = cfg.RemoveRefundRate or 0.5

    for _, cost in bt.Cost do
        local refundAmount = math.floor(cost.Amount * rate)
        if refundAmount > 0 then
            table.insert(refund, {
                ItemId = cost.ItemId,
                Amount = refundAmount
            })
        end
    end

    return refund
end

return BuildingValidator
