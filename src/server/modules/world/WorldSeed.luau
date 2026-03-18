--[[
	WorldSeed — управление seed'ом мира.
	
	Seed определяет всю генерацию: terrain, биомы, spawn points.
	Одинаковый seed = одинаковый мир (детерминизм).
	
	math.noise() в Roblox не принимает seed напрямую,
	поэтому seed используется как смещение координат.
]]

local WorldSeed = {}

local currentSeed: number = 0
local seedOffsetX: number = 0
local seedOffsetZ: number = 0
local rng: Random = nil :: any

--[[
	Генерирует случайный seed (1 — 999999).
]]
function WorldSeed.generateRandom(): number
	return math.random(1, 999999)
end

--[[
	Устанавливает seed и вычисляет смещения для noise.
	Вызывать перед генерацией terrain.
]]
function WorldSeed.setSeed(seed: number)
	currentSeed = seed
	rng = Random.new(seed)

	-- Смещения для math.noise (делает noise уникальным для каждого seed)
	-- Большие значения чтобы seed'ы не пересекались
	seedOffsetX = rng:NextNumber(-10000, 10000)
	seedOffsetZ = rng:NextNumber(-10000, 10000)

	print(string.format("[WorldSeed] Seed: %d | Offset: (%.1f, %.1f)", seed, seedOffsetX, seedOffsetZ))
end

--[[
	Возвращает текущий seed.
]]
function WorldSeed.getSeed(): number
	return currentSeed
end

--[[
	Возвращает смещения для math.noise.
	Использовать: math.noise(x * scale + offsetX, z * scale + offsetZ)
]]
function WorldSeed.getOffsets(): (number, number)
	return seedOffsetX, seedOffsetZ
end

--[[
	Возвращает Random объект, привязанный к seed.
	Для детерминированных случайных выборов (spawn points, props).
]]
function WorldSeed.getRNG(): Random
	return rng
end

--[[
	Создаёт новый Random из текущего seed + дополнительный ключ.
	Для изолированных подсистем (чтобы порядок вызовов не влиял).
]]
function WorldSeed.createSubRNG(key: number): Random
	return Random.new(currentSeed + key)
end

return WorldSeed
