--[[
	WorldManager — оркестратор генерации мира.
	
	Phase 0: заглушка. В Mode = "Manual" ничего не делает.
	Phase 1: будет вызывать TerrainGenerator, ChunkSystem.
	Phase 2: будет вызывать BiomeMap, SpawnPointGenerator.
	Phase 3: будет вызывать WorldSaveManager.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local WorldManager = {}

-- Внутреннее состояние
local state = {
	mode = "Manual",
	seed = 0,
	initialized = false,
}

--[[
	Инициализация мира.
	Вызывается из Main.server.luau при старте сервера.
	В режиме Manual — просто логирует и выходит.
]]
function WorldManager.init()
	state.mode = Config.World and Config.World.Mode or "Manual"

	if state.mode == "Manual" then
		print("[WorldManager] Mode = Manual — skipping world generation")
		state.initialized = true
		return true
	end

	-- Phase 1+: здесь будет генерация
	print("[WorldManager] Mode =", state.mode, "— world generation not yet implemented (Phase 1)")
	state.initialized = true
	return true
end

--[[
	Возвращает текущий режим мира.
]]
function WorldManager.getMode(): string
	return state.mode
end

--[[
	Возвращает seed мира (0 = не сгенерирован).
]]
function WorldManager.getSeed(): number
	return state.seed
end

--[[
	Проверяет, инициализирован ли мир.
]]
function WorldManager.isReady(): boolean
	return state.initialized
end

--[[
	Возвращает информацию о мире для debug-команд.
]]
function WorldManager.getInfo(): string
	local chunksX = math.ceil((Config.World and Config.World.MapSize or 1024) / (Config.World and Config.World.ChunkSize or 64))
	local totalChunks = chunksX * chunksX

	return string.format(
		"Mode: %s | Seed: %d | Ready: %s | Map: %dx%d studs | Chunks: %dx%d (%d total)",
		state.mode,
		state.seed,
		tostring(state.initialized),
		Config.World and Config.World.MapSize or 0,
		Config.World and Config.World.MapSize or 0,
		chunksX, chunksX,
		totalChunks
	)
end

--[[
	Проверяет, что все папки шаблонов доступны в ServerStorage.
	Возвращает список найденных и отсутствующих папок.
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
