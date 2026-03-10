--[[
    CastleBorder.luau
    Управление территориями замков и кооперативными правами доступа.

    Каждый замок имеет Castle Heart с уровнем (1-3).
    Уровень определяет: ClaimRadius, MaxBlocks, MaxCoffins, HP сердца.
    Территории не могут пересекаться.

    Зависимости: Config (Building.CastleHeart, Building.DefaultPermissions)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local CastleBorder = {}

-- ═══════════════════════════════════════════════════════════
-- Состояние
-- ═══════════════════════════════════════════════════════════
-- claims[ownerId] = {
--     ownerId      = number,
--     center       = Vector3,
--     heartLevel   = number (1-3),
--     permissions  = {
--         AllowCoopBuild, AllowCoopRemove, AllowCoopInteract,
--         AllowedPlayers = { [userId] = true },
--     },
-- }
local claims = {}

-- ═══════════════════════════════════════════════════════════
-- Приватные хелперы
-- ═══════════════════════════════════════════════════════════

local function getHeartConfig()
    return Config.Building and Config.Building.CastleHeart or {}
end

local function getLevelData(level)
    local heart = getHeartConfig()
    return heart.Levels and heart.Levels[level] or nil
end

local function getRadiusForLevel(level)
    local data = getLevelData(level)
    return data and data.ClaimRadius or 48
end

local function getDefaultPermissions()
    local defaults = Config.Building and Config.Building.DefaultPermissions or {}
    return {
        AllowCoopBuild    = defaults.AllowCoopBuild or false,
        AllowCoopRemove   = defaults.AllowCoopRemove or false,
        AllowCoopInteract = if defaults.AllowCoopInteract ~= nil then defaults.AllowCoopInteract else true,
        AllowedPlayers    = {},
    }
end

local function horizontalDistance(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function hasPermission(claim, actorId, permissionKey)
    if actorId == claim.ownerId then
        return true
    end

    local perms = claim.permissions
    if not perms[permissionKey] then
        return false
    end

    local allowedList = perms.AllowedPlayers
    if not allowedList or not next(allowedList) then
        return true
    end

    return allowedList[actorId] == true
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: регистрация и удаление
-- ═══════════════════════════════════════════════════════════

--- Зарегистрировать территорию замка.
--- @param ownerId number
--- @param centerPos Vector3
--- @param heartLevel number? — уровень сердца (default 1)
--- @param savedPermissions table? — из DataStore
--- @return boolean, string?
function CastleBorder.registerClaim(ownerId, centerPos, heartLevel, savedPermissions)
    if claims[ownerId] then
        return false, "Player already has a castle"
    end

    heartLevel = heartLevel or 1
    local radius = getRadiusForLevel(heartLevel)

    -- Проверка пересечения — учитываем максимальный возможный радиус обоих замков
    -- (чтобы апгрейд не вызвал пересечение в будущем — используем текущие радиусы)
    for existingOwnerId, existingClaim in claims do
        local existingRadius = getRadiusForLevel(existingClaim.heartLevel)
        local dist = horizontalDistance(centerPos, existingClaim.center)
        if dist < radius + existingRadius then
            return false, "Territory overlaps with castle of player " .. tostring(existingOwnerId)
        end
    end

    local permissions
    if savedPermissions then
        permissions = {
            AllowCoopBuild    = if savedPermissions.AllowCoopBuild ~= nil then savedPermissions.AllowCoopBuild else false,
            AllowCoopRemove   = if savedPermissions.AllowCoopRemove ~= nil then savedPermissions.AllowCoopRemove else false,
            AllowCoopInteract = if savedPermissions.AllowCoopInteract ~= nil then savedPermissions.AllowCoopInteract else true,
            AllowedPlayers    = {},
        }
        if savedPermissions.AllowedPlayers then
            for _, id in savedPermissions.AllowedPlayers do
                permissions.AllowedPlayers[id] = true
            end
        end
    else
        permissions = getDefaultPermissions()
    end

    claims[ownerId] = {
        ownerId     = ownerId,
        center      = centerPos,
        heartLevel  = heartLevel,
        permissions = permissions,
    }

    print("[CastleBorder] Registered claim for " .. tostring(ownerId)
        .. " at " .. tostring(centerPos) .. " (level " .. heartLevel .. ")")
    return true
end

function CastleBorder.removeClaim(ownerId)
    if claims[ownerId] then
        print("[CastleBorder] Removed claim for " .. tostring(ownerId))
        claims[ownerId] = nil
    end
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: Castle Heart уровень
-- ═══════════════════════════════════════════════════════════

--- Получить текущий уровень сердца.
--- @param ownerId number
--- @return number
function CastleBorder.getHeartLevel(ownerId)
    local claim = claims[ownerId]
    return claim and claim.heartLevel or 0
end

--- Установить уровень сердца (после улучшения).
--- Обновляет radius. Проверка пересечений НЕ делается здесь —
--- валидация в BuildingManager.upgradeHeart перед вызовом.
--- @param ownerId number
--- @param newLevel number
--- @return boolean
function CastleBorder.setHeartLevel(ownerId, newLevel)
    local claim = claims[ownerId]
    if not claim then return false end

    local maxLevel = getHeartConfig().MaxLevel or 3
    if newLevel < 1 or newLevel > maxLevel then return false end

    claim.heartLevel = newLevel
    print("[CastleBorder] Heart level set to " .. newLevel .. " for " .. tostring(ownerId))
    return true
end

--- Проверить, не вызовет ли апгрейд пересечение территорий.
--- @param ownerId number
--- @param newLevel number
--- @return boolean, string?
function CastleBorder.canUpgrade(ownerId, newLevel)
    local claim = claims[ownerId]
    if not claim then return false, "No castle" end

    local newRadius = getRadiusForLevel(newLevel)

    for existingOwnerId, existingClaim in claims do
        if existingOwnerId ~= ownerId then
            local existingRadius = getRadiusForLevel(existingClaim.heartLevel)
            local dist = horizontalDistance(claim.center, existingClaim.center)
            if dist < newRadius + existingRadius then
                return false, "Upgrade would overlap with castle of " .. tostring(existingOwnerId)
            end
        end
    end

    return true
end

--- Получить MaxBlocks для текущего уровня.
--- @param ownerId number
--- @return number
function CastleBorder.getMaxBlocks(ownerId)
    local claim = claims[ownerId]
    if not claim then return 0 end
    local data = getLevelData(claim.heartLevel)
    return data and data.MaxBlocks or 200
end

--- Получить MaxCoffins для текущего уровня.
--- @param ownerId number
--- @return number
function CastleBorder.getMaxCoffins(ownerId)
    local claim = claims[ownerId]
    if not claim then return 0 end
    local data = getLevelData(claim.heartLevel)
    return data and data.MaxCoffins or 1
end

--- Получить HP сердца для текущего уровня.
--- @param ownerId number
--- @return number
function CastleBorder.getHeartHP(ownerId)
    local claim = claims[ownerId]
    if not claim then return 0 end
    local data = getLevelData(claim.heartLevel)
    return data and data.HP or 1000
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: запросы территории
-- ═══════════════════════════════════════════════════════════

function CastleBorder.getClaim(ownerId)
    return claims[ownerId]
end

function CastleBorder.getOwnerAt(position)
    for ownerId, claim in claims do
        local radius = getRadiusForLevel(claim.heartLevel)
        if horizontalDistance(position, claim.center) <= radius then
            return ownerId
        end
    end
    return nil
end

function CastleBorder.isWithinClaim(position, ownerId)
    local claim = claims[ownerId]
    if not claim then return false end
    local radius = getRadiusForLevel(claim.heartLevel)
    return horizontalDistance(position, claim.center) <= radius
end

function CastleBorder.isWithinAnyClaim(position)
    return CastleBorder.getOwnerAt(position) ~= nil
end

function CastleBorder.hasCastle(ownerId)
    return claims[ownerId] ~= nil
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: проверки прав
-- ═══════════════════════════════════════════════════════════

function CastleBorder.canBuild(actorId, ownerId)
    local claim = claims[ownerId]
    if not claim then return false end
    return hasPermission(claim, actorId, "AllowCoopBuild")
end

function CastleBorder.canRemove(actorId, ownerId)
    local claim = claims[ownerId]
    if not claim then return false end
    return hasPermission(claim, actorId, "AllowCoopRemove")
end

function CastleBorder.canInteract(actorId, ownerId)
    local claim = claims[ownerId]
    if not claim then return false end
    return hasPermission(claim, actorId, "AllowCoopInteract")
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API: управление правами
-- ═══════════════════════════════════════════════════════════

function CastleBorder.setPermission(ownerId, permissionKey, value)
    local claim = claims[ownerId]
    if not claim then return false end

    if permissionKey ~= "AllowCoopBuild"
        and permissionKey ~= "AllowCoopRemove"
        and permissionKey ~= "AllowCoopInteract" then
        return false
    end

    claim.permissions[permissionKey] = (value == true)
    return true
end

function CastleBorder.addAlly(ownerId, allyId)
    local claim = claims[ownerId]
    if not claim then return false end
    if allyId == ownerId then return false end
    claim.permissions.AllowedPlayers[allyId] = true
    return true
end

function CastleBorder.removeAlly(ownerId, allyId)
    local claim = claims[ownerId]
    if not claim then return false end
    claim.permissions.AllowedPlayers[allyId] = nil
    return true
end

function CastleBorder.getAllies(ownerId)
    local claim = claims[ownerId]
    if not claim then return {} end
    local result = {}
    for allyId, _ in claim.permissions.AllowedPlayers do
        table.insert(result, allyId)
    end
    return result
end

-- ═══════════════════════════════════════════════════════════
-- Сериализация
-- ═══════════════════════════════════════════════════════════

--- Собрать данные claim для DataStore.
--- Включает heartLevel и permissions.
--- @param ownerId number
--- @return table | nil
function CastleBorder.serializeClaim(ownerId)
    local claim = claims[ownerId]
    if not claim then return nil end

    return {
        HeartLevel        = claim.heartLevel,
        AllowCoopBuild    = claim.permissions.AllowCoopBuild,
        AllowCoopRemove   = claim.permissions.AllowCoopRemove,
        AllowCoopInteract = claim.permissions.AllowCoopInteract,
        AllowedPlayers    = CastleBorder.getAllies(ownerId),
    }
end

-- ═══════════════════════════════════════════════════════════
-- Очистка
-- ═══════════════════════════════════════════════════════════

function CastleBorder.reset()
    table.clear(claims)
end

function CastleBorder.getAllClaims()
    return claims
end

return CastleBorder