local Players = game:GetService("Players")

local TargetFinder = {}

-- ═══════════════════════════════════════════════════════════
-- Внутренние хелперы
-- ═══════════════════════════════════════════════════════════

-- Проверить что entity жив и имеет HumanoidRootPart
local function isValidTarget(entity)
    if not entity then
        return false
    end
    if entity:GetAttribute("IsDead") then
        return false
    end

    local humanoid = entity:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    local rootPart = entity:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return false
    end

    return true
end

-- Собрать всех потенциальных врагов и игроков (кроме excludeCharacter)
local function collectAllTargets(excludeCharacter)
    local targets = {}

    -- Враги
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, enemy in enemiesFolder:GetChildren() do
            if enemy ~= excludeCharacter and isValidTarget(enemy) then
                table.insert(targets, enemy)
            end
        end
    end

    -- Другие игроки
    for _, p in Players:GetPlayers() do
        local character = p.Character
        if character and character ~= excludeCharacter and isValidTarget(character) then
            table.insert(targets, character)
        end
    end

    return targets
end

-- Получить позицию HumanoidRootPart
local function getRootPosition(entity)
    local rootPart = entity:FindFirstChild("HumanoidRootPart")
    return rootPart and rootPart.Position or nil
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API
-- ═══════════════════════════════════════════════════════════

--- Все живые цели в радиусе от точки
--- @param origin Vector3
--- @param radius number
--- @param excludeCharacter Model? — персонаж, которого исключить
--- @return { Model, ... }
function TargetFinder.inRadius(origin, radius, excludeCharacter)
    local results = {}
    local radiusSq = radius * radius

    for _, entity in collectAllTargets(excludeCharacter) do
        local pos = getRootPosition(entity)
        if pos then
            local dx = pos.X - origin.X
            local dy = pos.Y - origin.Y
            local dz = pos.Z - origin.Z
            if dx * dx + dy * dy + dz * dz <= radiusSq then
                table.insert(results, entity)
            end
        end
    end

    return results
end

--- Цели в конусе перед атакующим (для melee / directed)
--- Возвращает массив { {entity, distance}, ... } отсортированный по distance
--- @param origin Vector3
--- @param direction Vector3 (unit) — направление атаки
--- @param range number — максимальная дистанция
--- @param dotThreshold number? — порог dot product (default 0.3)
--- @param excludeCharacter Model?
--- @return { {entity: Model, distance: number}, ... }
function TargetFinder.inCone(origin, direction, range, dotThreshold, excludeCharacter)
    dotThreshold = dotThreshold or 0.3
    local results = {}
    local rangeSq = range * range

    -- Нормализуем направление в горизонтальной плоскости
    local flatDir = Vector3.new(direction.X, 0, direction.Z)
    local magSq = flatDir.X * flatDir.X + flatDir.Z * flatDir.Z
    if magSq < 0.001 then
        return results
    end
    flatDir = flatDir.Unit

    for _, entity in collectAllTargets(excludeCharacter) do
        local pos = getRootPosition(entity)
        if pos then
            local offset = pos - origin
            local distSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z

            if distSq <= rangeSq then
                local flatOffset = Vector3.new(offset.X, 0, offset.Z)
                local flatMag = flatOffset.Magnitude
                if flatMag > 0.001 then
                    local dot = flatDir:Dot(flatOffset.Unit)
                    if dot > dotThreshold then
                        table.insert(results, {
                            entity = entity,
                            distance = math.sqrt(distSq)
                        })
                    end
                end
            end
        end
    end

    -- Сортировка по дистанции (ближайшие первыми)
    table.sort(results, function(a, b)
        return a.distance < b.distance
    end)

    return results
end

--- Ближайшая цель в конусе (для single-target способностей)
--- @return Model | nil
function TargetFinder.closestInCone(origin, direction, range, dotThreshold, excludeCharacter)
    local results = TargetFinder.inCone(origin, direction, range, dotThreshold, excludeCharacter)
    if #results > 0 then
        return results[1].entity
    end
    return nil
end

--- Все цели в сфере заданного радиуса (для снарядов)
--- Исключает уже задетые цели из hitList
--- @param position Vector3 — текущая позиция снаряда
--- @param radius number — HitRadius снаряда
--- @param hitList { [Model]: true }? — уже задетые (для pierce)
--- @return { Model, ... } — новые попадания
function TargetFinder.sphereOverlap(position, radius, hitList)
    hitList = hitList or {}
    local results = {}
    local radiusSq = radius * radius

    -- Враги
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, enemy in enemiesFolder:GetChildren() do
            if not hitList[enemy] and isValidTarget(enemy) then
                local pos = getRootPosition(enemy)
                if pos then
                    local dx = pos.X - position.X
                    local dy = pos.Y - position.Y
                    local dz = pos.Z - position.Z
                    if dx * dx + dy * dy + dz * dz <= radiusSq then
                        table.insert(results, enemy)
                    end
                end
            end
        end
    end

    -- Игроки
    for _, p in Players:GetPlayers() do
        local character = p.Character
        if character and not hitList[character] and isValidTarget(character) then
            local pos = getRootPosition(character)
            if pos then
                local dx = pos.X - position.X
                local dy = pos.Y - position.Y
                local dz = pos.Z - position.Z
                if dx * dx + dy * dy + dz * dz <= radiusSq then
                    table.insert(results, character)
                end
            end
        end
    end

    return results
end

--- Raycast (для лучевых способностей, если потребуется)
--- @param origin Vector3
--- @param direction Vector3 (unit)
--- @param maxDist number
--- @param excludeList { Instance, ... }?
--- @return Model | nil, Vector3 | nil (hitPosition)
function TargetFinder.raycast(origin, direction, maxDist, excludeList)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = excludeList or {}

    local result = workspace:Raycast(origin, direction * maxDist, rayParams)
    if result and result.Instance then
        -- Найти модель-владельца (враг или персонаж)
        local hit = result.Instance
        local entity = hit:FindFirstAncestorOfClass("Model")
        if entity and isValidTarget(entity) then
            return entity, result.Position
        end
        -- Попали в стену/пол — вернуть nil entity, но позицию
        return nil, result.Position
    end

    return nil, nil
end

return TargetFinder
