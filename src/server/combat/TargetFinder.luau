local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterUtil = require(ReplicatedStorage:WaitForChild("CharacterUtil"))

local TargetFinder = {}

-- ═══════════════════════════════════════════════════════════
-- Пространственный хэш-грид
-- ═══════════════════════════════════════════════════════════
-- Разбивает мир на ячейки CELL_SIZE x CELL_SIZE.
-- Обновляется каждые GRID_UPDATE_INTERVAL секунд.
-- Запросы inRadius / inCone / sphereOverlap читают только
-- ячейки, пересекающие AABB запроса → O(K) вместо O(N).

local CELL_SIZE = 50 -- studs; подбирается под среднюю агро-дистанцию
local GRID_UPDATE_INTERVAL = 0.2 -- секунды между полными перестроениями

local grid = {} -- { ["x,z"] = { entity1, entity2, ... } }
local entityCell = {} -- { [entity] = "x,z" } для быстрого поиска прошлой ячейки
local lastGridUpdate = 0

-- ═══ Хелперы грида ═══

local function cellKey(x, z)
	local cx = math.floor(x / CELL_SIZE)
	local cz = math.floor(z / CELL_SIZE)
	return cx .. "," .. cz
end

local function cellKeyFromInts(cx, cz)
	return cx .. "," .. cz
end

--- Перестроить грид из текущего состояния мира
local function rebuildGrid()
	-- Полная очистка
	table.clear(grid)
	table.clear(entityCell)

	-- Враги
	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if enemiesFolder then
		for _, enemy in enemiesFolder:GetChildren() do
			local root = enemy:FindFirstChild("HumanoidRootPart")
			if root then
				local key = cellKey(root.Position.X, root.Position.Z)
				if not grid[key] then
					grid[key] = {}
				end
				table.insert(grid[key], enemy)
				entityCell[enemy] = key
			end
		end
	end

	-- Игроки
	for _, p in Players:GetPlayers() do
		local character = p.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local key = cellKey(root.Position.X, root.Position.Z)
				if not grid[key] then
					grid[key] = {}
				end
				table.insert(grid[key], character)
				entityCell[character] = key
			end
		end
	end

	lastGridUpdate = os.clock()
end

--- Обновить грид если прошло достаточно времени
local function ensureGridFresh()
	if os.clock() - lastGridUpdate >= GRID_UPDATE_INTERVAL then
		rebuildGrid()
	end
end

--- Получить все entity из ячеек, пересекающих AABB (minX,minZ)-(maxX,maxZ)
local function queryAABB(minX, minZ, maxX, maxZ)
	local cxMin = math.floor(minX / CELL_SIZE)
	local czMin = math.floor(minZ / CELL_SIZE)
	local cxMax = math.floor(maxX / CELL_SIZE)
	local czMax = math.floor(maxZ / CELL_SIZE)

	local candidates = {}
	for cx = cxMin, cxMax do
		for cz = czMin, czMax do
			local cell = grid[cellKeyFromInts(cx, cz)]
			if cell then
				for _, entity in cell do
					table.insert(candidates, entity)
				end
			end
		end
	end
	return candidates
end

-- ═══════════════════════════════════════════════════════════
-- Внутренние хелперы
-- ═══════════════════════════════════════════════════════════

-- Проверить что entity жив и имеет HumanoidRootPart
local function isValidTarget(entity)
	if not entity then
		return false
	end
	return CharacterUtil.isAlive(entity) and entity:FindFirstChild("HumanoidRootPart") ~= nil
end

-- Собрать всех потенциальных врагов и игроков (кроме excludeCharacter)
-- FALLBACK: вызывается только если грид не используется (raycast и т.д.)
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
	ensureGridFresh()

	local results = {}
	local radiusSq = radius * radius

	-- Запрос только ячеек, пересекающих AABB сферы
	local candidates = queryAABB(
		origin.X - radius, origin.Z - radius,
		origin.X + radius, origin.Z + radius
	)

	for _, entity in candidates do
		if entity ~= excludeCharacter and isValidTarget(entity) then
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
	ensureGridFresh()

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

	-- Конус вписан в AABB: origin ± range
	local candidates = queryAABB(
		origin.X - range, origin.Z - range,
		origin.X + range, origin.Z + range
	)

	for _, entity in candidates do
		if entity ~= excludeCharacter and isValidTarget(entity) then
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
	ensureGridFresh()

	hitList = hitList or {}
	local results = {}
	local radiusSq = radius * radius

	-- Запрос только ячеек, пересекающих AABB сферы
	local candidates = queryAABB(
		position.X - radius, position.Z - radius,
		position.X + radius, position.Z + radius
	)

	for _, entity in candidates do
		if not hitList[entity] and isValidTarget(entity) then
			local pos = getRootPosition(entity)
			if pos then
				local dx = pos.X - position.X
				local dy = pos.Y - position.Y
				local dz = pos.Z - position.Z
				if dx * dx + dy * dy + dz * dz <= radiusSq then
					table.insert(results, entity)
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

--- Принудительное обновление грида (вызывать из Main или EnemyAI)
function TargetFinder.refreshGrid()
	rebuildGrid()
end

--- Диагностика: количество ячеек и entity в гриде
function TargetFinder.getGridStats()
	local cellCount = 0
	local entityCount = 0
	for _, cell in grid do
		cellCount += 1
		entityCount += #cell
	end
	return { cells = cellCount, entities = entityCount, cellSize = CELL_SIZE }
end

return TargetFinder
