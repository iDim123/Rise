--[[
	TerrainGenerator — генерация ландшафта из Perlin noise.
	
	Использует Roblox Terrain API (FillBlock / FillRegion).
	Heightmap вычисляется через math.noise с seed-смещениями.
	Материал определяется по высоте: Water → Sand → Grass → Rock → Snow.
	
	Генерация одного чанка (64×64 studs) занимает ~50-200ms.
	task.wait() между чанками предотвращает зависание.
]]

local workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")
local worldModules = modules:WaitForChild("world")
local WorldSeed = require(worldModules:WaitForChild("WorldSeed"))

local TerrainGenerator = {}

local terrain = workspace.Terrain

-- ═══════════════════════════════════════════════════════════
-- Материалы по высоте (нормализованная 0-1)
-- ═══════════════════════════════════════════════════════════
local MATERIAL_LAYERS = {
	{ maxHeight = 0.0,  material = Enum.Material.Water },       -- ниже SeaLevel
	{ maxHeight = 0.05, material = Enum.Material.Sand },        -- пляж
	{ maxHeight = 0.45, material = Enum.Material.LeafyGrass },  -- равнины
	{ maxHeight = 0.65, material = Enum.Material.Grass },       -- холмы
	{ maxHeight = 0.80, material = Enum.Material.Rock },        -- горы
	{ maxHeight = 1.0,  material = Enum.Material.Snow },        -- вершины
}

--[[
	Определяет материал по нормализованной высоте (0-1).
]]
local function getMaterialForHeight(normalizedHeight: number): Enum.Material
	for _, layer in MATERIAL_LAYERS do
		if normalizedHeight <= layer.maxHeight then
			return layer.material
		end
	end
	return Enum.Material.Snow
end

--[[
	Вычисляет высоту terrain в мировых координатах (x, z).
	Использует multi-octave Perlin noise для естественного рельефа.
	
	Возвращает: height (studs), normalizedHeight (0-1)
]]
function TerrainGenerator.getHeight(x: number, z: number): (number, number)
	local worldCfg = Config.World
	local noiseCfg = worldCfg.Noise
	local offsetX, offsetZ = WorldSeed.getOffsets()

	local amplitude = 1.0
	local frequency = 1.0
	local noiseValue = 0.0
	local maxAmplitude = 0.0

	-- Multi-octave Perlin noise
	for _ = 1, noiseCfg.Octaves do
		local nx = (x * noiseCfg.Scale * frequency) + offsetX
		local nz = (z * noiseCfg.Scale * frequency) + offsetZ
		noiseValue = noiseValue + math.noise(nx, nz) * amplitude

		maxAmplitude = maxAmplitude + amplitude
		amplitude = amplitude * noiseCfg.Persistence
		frequency = frequency * noiseCfg.Lacunarity
	end

	-- Нормализация -1..1 → 0..1
	local normalized = (noiseValue / maxAmplitude + 1) / 2

	-- Маппинг в реальную высоту
	local height = worldCfg.SeaLevel + normalized * (worldCfg.MaxHeight - worldCfg.SeaLevel)

	return height, normalized
end

--[[
	Генерирует terrain для одного чанка.
	
	chunkX, chunkZ — индексы чанка (0-based).
	Возвращает количество заполненных блоков.
]]
function TerrainGenerator.generateChunk(chunkX: number, chunkZ: number): number
	local worldCfg = Config.World
	local chunkSize = worldCfg.ChunkSize
	local resolution = worldCfg.TerrainResolution
	local seaLevel = worldCfg.SeaLevel
	local halfMap = worldCfg.MapSize / 2

	-- Мировые координаты начала чанка (центрировано вокруг 0,0)
	local startX = chunkX * chunkSize - halfMap
	local startZ = chunkZ * chunkSize - halfMap

	local blocksFilled = 0

	-- Итерация по вокселям внутри чанка
	for lx = 0, chunkSize - 1, resolution do
		for lz = 0, chunkSize - 1, resolution do
			local worldX = startX + lx
			local worldZ = startZ + lz

			local height, normalized = TerrainGenerator.getHeight(worldX, worldZ)

			-- Заполнение terrain столбцом от 0 до height
			local material = getMaterialForHeight(normalized)

			if height > seaLevel then
				-- Terrain выше воды
				local fillHeight = math.max(resolution, height)
				terrain:FillBlock(
					CFrame.new(worldX, fillHeight / 2, worldZ),
					Vector3.new(resolution, fillHeight, resolution),
					material
				)
				blocksFilled = blocksFilled + 1
			end

			-- Вода ниже SeaLevel
			if normalized < 0.05 then
				terrain:FillBlock(
					CFrame.new(worldX, seaLevel / 2, worldZ),
					Vector3.new(resolution, seaLevel, resolution),
					Enum.Material.Water
				)
				blocksFilled = blocksFilled + 1
			end
		end
	end

	return blocksFilled
end

--[[
	Очищает весь сгенерированный terrain.
	Безопасно для Studio — не трогает ничего кроме Terrain.
]]
function TerrainGenerator.clearTerrain()
	terrain:Clear()
	print("[TerrainGenerator] Terrain cleared")
end

return TerrainGenerator
