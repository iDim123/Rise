--[[
	WorldManager — оркестратор генерации мира.
	
	Phase 0: заглушка (Manual = skip). ✅
	Phase 1: seed → terrain generation → WorldReady. ✅
	Phase 2: биомы, spawn points (будущее).
	Phase 3: persistence (будущее).
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local modules = ServerScriptService:WaitForChild("modules")
local worldModules = modules:WaitForChild("world")

local WorldSeed = require(worldModules:WaitForChild("WorldSeed"))
local TerrainGenerator = require(worldModules:WaitForChild("TerrainGenerator"))
local ChunkSystem = require(worldModules:WaitForChild("ChunkSystem"))

local WorldManager = {}

-- Внутреннее состояние
local state = {
	mode = "Manual",
	seed = 0,
	initialized = false,
	generating = false,
	generationTime = 0,
}

-- ═══════════════════════════════════════════════════════════
-- Основное API
-- ═══════════════════════════════════════════════════════════

--[[
	Инициализация мира при старте сервера.
	Вызывается из Main.server.luau.
	
	В режиме Manual — ничего не делает.
	В режиме Generated/Hybrid — генерирует мир из seed.
]]
function WorldManager.init()
	state.mode = Config.World and Config.World.Mode or "Manual"

	if state.mode == "Manual" then
		print("[WorldManager] Mode = Manual — skipping world generation")
		state.initialized = true
		return true
	end

	-- Generated / Hybrid — генерируем мир
	local seed = WorldSeed.generateRandom()
	local success = WorldManager.generate(seed)
	return success
end

--[[
	Генерирует мир из указанного seed.
	Может вызываться из debug-команды /worldgen.
	
	Возвращает true при успехе.
]]
function WorldManager.generate(seed: number): boolean
	if state.generating then
		warn("[WorldManager] Generation already in progress")
		return false
	end

	state.generating = true
	local startTime = os.clock()

	print(string.format("[WorldManager] Starting world generation (seed: %d, mode: %s)", seed, state.mode))

	-- 1. Установить seed
	WorldSeed.setSeed(seed)
	state.seed = seed

	-- 2. Очистить предыдущий terrain
	TerrainGenerator.clearTerrain()

	-- 3. Инициализировать чанки
	ChunkSystem.init()

	-- 4. Генерация terrain
	local totalChunks, totalTime = ChunkSystem.generateAll(function(current, total, elapsed)
		-- Прогресс callback (будущее: отправка на клиент для loading screen)
		if current % 16 == 0 or current == total then
			print(string.format("[WorldManager] Progress: %d/%d chunks (%.1fs)", current, total, elapsed))
		end
	end)

	-- 5. Готово
	state.generationTime = os.clock() - startTime
	state.generating = false
	state.initialized = true

	print(string.format(
		"[WorldManager] World ready! Seed: %d | %d chunks | %.1f seconds",
		seed, totalChunks, state.generationTime
	))

	-- Phase 2: здесь будет EventBus.fire("WorldReady", seed, biomeMap)

	return true
end

--[[
	Очищает сгенерированный мир.
	Для debug-команды /worldclear.
]]
function WorldManager.clear()
	TerrainGenerator.clearTerrain()
	ChunkSystem.reset()
	state.seed = 0
	state.generationTime = 0
	state.initialized = state.mode == "Manual"
	print("[WorldManager] World cleared")
end

-- ═══════════════════════════════════════════════════════════
-- Геттеры
-- ═══════════════════════════════════════════════════════════

function WorldManager.getMode(): string
	return state.mode
end

function WorldManager.getSeed(): number
	return state.seed
end

function WorldManager.isReady(): boolean
	return state.initialized
end

function WorldManager.isGenerating(): boolean
	return state.generating
end

--[[
	Информация о мире для debug-команд.
]]
function WorldManager.getInfo(): string
	local worldCfg = Config.World or {}
	local mapSize = worldCfg.MapSize or 1024
	local chunkSize = worldCfg.ChunkSize or 64
	local chunksPerSide = math.ceil(mapSize / chunkSize)
	local total = chunksPerSide * chunksPerSide
	local generated = ChunkSystem.getGeneratedCount()

	return string.format(
		"Mode: %s | Seed: %d | Ready: %s | Map: %dx%d | Chunks: %d/%d | GenTime: %.1fs",
		state.mode,
		state.seed,
		tostring(state.initialized),
		mapSize, mapSize,
		generated, total,
		state.generationTime
	)
end

--[[
	Проверяет, что все папки шаблонов доступны в ServerStorage.
]]
function WorldManager.validateTemplates(): (number, number, string)
	local paths = Config.World and Config.World.TemplatePaths or {}
	local found = 0
	local missing = 0
	local details = {}

	for key, folderName in paths do
		local folder = ServerStorage:FindFirstChild(folderName)
		if folder then
			local count = #folder:GetChildren()
			found = found + 1
			table.insert(details, string.format("  %s/ — %d items", folderName, count))
		else
			missing = missing + 1
			table.insert(details, string.format("  %s/ — MISSING", folderName))
		end
	end

	return found, missing, table.concat(details, "\n")
end

return WorldManager
