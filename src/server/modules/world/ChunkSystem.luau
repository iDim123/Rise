--[[
	ChunkSystem — разбиение мира на чанки и потоковая генерация.
	
	Карта MapSize×MapSize делится на чанки ChunkSize×ChunkSize.
	Генерация идёт чанк за чанком с task.wait() между ними,
	чтобы не зависать и дать Roblox обработать очередь рендеринга.
	
	Callback onProgress вызывается после каждого чанка для UI.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")
local worldModules = modules:WaitForChild("world")
local TerrainGenerator = require(worldModules:WaitForChild("TerrainGenerator"))

local ChunkSystem = {}

-- Состояние чанков
local chunks = {}     -- [chunkKey] = { x, z, generated }
local chunksX = 0     -- количество чанков по X
local chunksZ = 0     -- количество чанков по Z
local totalChunks = 0

--[[
	Инициализирует сетку чанков на основе конфига.
]]
function ChunkSystem.init()
	local worldCfg = Config.World
	chunksX = math.ceil(worldCfg.MapSize / worldCfg.ChunkSize)
	chunksZ = chunksX  -- квадратная карта
	totalChunks = chunksX * chunksZ
	chunks = {}

	for cx = 0, chunksX - 1 do
		for cz = 0, chunksZ - 1 do
			local key = cx .. "_" .. cz
			chunks[key] = {
				x = cx,
				z = cz,
				generated = false,
			}
		end
	end

	print(string.format("[ChunkSystem] Grid: %dx%d = %d chunks (%d studs each)",
		chunksX, chunksZ, totalChunks, worldCfg.ChunkSize))
end

--[[
	Генерирует все чанки последовательно.
	
	onProgress(current, total, elapsed) — callback для прогресса.
	Возвращает: totalGenerated, totalTime.
]]
function ChunkSystem.generateAll(onProgress: ((number, number, number) -> ())?): (number, number)
	local startTime = os.clock()
	local generated = 0
	local worldCfg = Config.World
	local logTiming = worldCfg.Debug and worldCfg.Debug.LogChunkTiming

	-- Спиральный порядок от центра (для лучшего визуального результата)
	local order = ChunkSystem._buildSpiralOrder()

	for i, entry in order do
		local key = entry.x .. "_" .. entry.z
		local chunk = chunks[key]
		if not chunk or chunk.generated then
			continue
		end

		local chunkStart = os.clock()
		local blocks = TerrainGenerator.generateChunk(entry.x, entry.z)
		local chunkTime = os.clock() - chunkStart

		chunk.generated = true
		generated = generated + 1

		if logTiming then
			print(string.format("[ChunkSystem] Chunk %d/%d (%d,%d) — %d blocks, %.0fms",
				generated, totalChunks, entry.x, entry.z, blocks, chunkTime * 1000))
		end

		if onProgress then
			onProgress(generated, totalChunks, os.clock() - startTime)
		end

		-- Yield чтобы не зависать
		-- Каждые 2 чанка даём 1 кадр
		if generated % 2 == 0 then
			task.wait()
		end
	end

	local totalTime = os.clock() - startTime
	print(string.format("[ChunkSystem] Generation complete: %d chunks in %.1fs", generated, totalTime))

	return generated, totalTime
end

--[[
	Строит порядок обхода чанков спиралью от центра.
	Центр генерируется первым — игрок сразу видит ландшафт вокруг себя.
]]
function ChunkSystem._buildSpiralOrder(): {{x: number, z: number}}
	local centerX = math.floor(chunksX / 2)
	local centerZ = math.floor(chunksZ / 2)

	local order = {}
	local visited = {}

	-- BFS от центра
	local queue = {{x = centerX, z = centerZ}}
	visited[centerX .. "_" .. centerZ] = true

	local dx = {0, 1, 0, -1}
	local dz = {1, 0, -1, 0}

	while #queue > 0 do
		local current = table.remove(queue, 1)
		table.insert(order, current)

		for i = 1, 4 do
			local nx = current.x + dx[i]
			local nz = current.z + dz[i]
			local key = nx .. "_" .. nz

			if nx >= 0 and nx < chunksX and nz >= 0 and nz < chunksZ and not visited[key] then
				visited[key] = true
				table.insert(queue, {x = nx, z = nz})
			end
		end
	end

	return order
end

--[[
	Возвращает количество чанков.
]]
function ChunkSystem.getTotalChunks(): number
	return totalChunks
end

--[[
	Возвращает количество сгенерированных чанков.
]]
function ChunkSystem.getGeneratedCount(): number
	local count = 0
	for _, chunk in chunks do
		if chunk.generated then
			count = count + 1
		end
	end
	return count
end

--[[
	Сбрасывает состояние всех чанков (для /worldclear).
]]
function ChunkSystem.reset()
	for _, chunk in chunks do
		chunk.generated = false
	end
end

return ChunkSystem
