-- Серверный тик: время суток, Lighting, солнечный дебафф, лунные фазы

local Players            = game:GetService("Players")
local Lighting           = game:GetService("Lighting")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")

local Config      = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes     = require(ReplicatedStorage:WaitForChild("Remotes"))
local BuffManager = require(script.Parent:WaitForChild("BuffManager"))
local EventBus    = require(script.Parent:WaitForChild("EventBus"))

local DNC = Config.DayNight
local LC  = Config.LunarCycle

local DayNightManager = {}

-- ════════════════════════════════════════════════════════════
-- Состояние
-- ════════════════════════════════════════════════════════════
local totalCycleTime = DNC.DayDuration + DNC.NightDuration   -- 1200 сек
local cycleTimer     = 0          -- текущее время внутри цикла (0 .. totalCycleTime)
local lunarTimer     = 0          -- текущее время внутри лунного цикла
local currentPhase   = "night"    -- "day" | "night" | "transition_dawn" | "transition_dusk"
local currentLunar   = "new_moon"

-- Shelter tracking: [player] = lastShelterTime (tick когда последний раз был в тени)
local shelterData = {}

-- ════════════════════════════════════════════════════════════
-- Вспомогательные
-- ════════════════════════════════════════════════════════════

local function lerp(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end

local function lerpColor(c1, c2, t)
	t = math.clamp(t, 0, 1)
	return Color3.new(
		lerp(c1.R, c2.R, t),
		lerp(c1.G, c2.G, t),
		lerp(c1.B, c2.B, t)
	)
end

-- Применить Lighting параметры (интерполяция между двумя пресетами)
local function applyLighting(from, to, alpha)
	Lighting.ClockTime      = lerp(from.ClockTime, to.ClockTime, alpha)
	Lighting.Brightness     = lerp(from.Brightness, to.Brightness, alpha)
	Lighting.Ambient        = lerpColor(from.Ambient, to.Ambient, alpha)
	Lighting.OutdoorAmbient = lerpColor(from.OutdoorAmbient, to.OutdoorAmbient, alpha)
	Lighting.FogEnd         = lerp(from.FogEnd, to.FogEnd, alpha)
	Lighting.FogColor       = lerpColor(from.FogColor, to.FogColor, alpha)
end

local function setLighting(preset)
	Lighting.ClockTime      = preset.ClockTime
	Lighting.Brightness     = preset.Brightness
	Lighting.Ambient        = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	Lighting.FogEnd         = preset.FogEnd
	Lighting.FogColor       = preset.FogColor
end

-- Получить ночной пресет (обычная ночь или кровавая луна)
local function getNightPreset()
	if currentLunar == "blood_moon" then
		return DNC.BloodMoon
	end
	return DNC.Night
end

-- ════════════════════════════════════════════════════════════
-- Лунный цикл
-- ════════════════════════════════════════════════════════════
local activeLunarBuffs = {}  -- { buffId = true } — чтобы знать что снять

local function getLunarPhase(timer)
	local elapsed = 0
	for _, phase in LC.Phases do
		local phaseDuration = LC.FullCycleDuration * phase.Duration
		if timer < elapsed + phaseDuration then
			return phase.Id, (timer - elapsed) / phaseDuration
		end
		elapsed += phaseDuration
	end
	return LC.Phases[1].Id, 0
end

local function getLunarPhaseConfig(phaseId)
	for _, phase in LC.Phases do
		if phase.Id == phaseId then
			return phase
		end
	end
	return nil
end

local function applyLunarBuffs(phaseConfig)
	-- Снимаем старые лунные баффы
	for buffId, _ in activeLunarBuffs do
		for _, player in Players:GetPlayers() do
			local char = player.Character
			if char then
				BuffManager.removeBuff(char, buffId)
			end
		end
		-- TODO: враги — снять вражеские баффы
	end
	activeLunarBuffs = {}

	if not phaseConfig then return end

	-- Применяем новые баффы игрокам
	for _, buffDef in phaseConfig.PlayerBuffs do
		activeLunarBuffs[buffDef.BuffId] = true
		for _, player in Players:GetPlayers() do
			local char = player.Character
			if char then
				-- Длительность = бесконечно (обновляется каждый тик фазы)
				BuffManager.applyBuff(char, buffDef.BuffId, 999999, "lunar")
			end
		end
	end

	-- TODO: вражеские баффы (EnemyBuffs) через EnemyManager
end

-- ════════════════════════════════════════════════════════════
-- Солнечный дебафф
-- ════════════════════════════════════════════════════════════
local sunCheckTimer = 0

local function isInShelter(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local origin = hrp.Position + Vector3.new(0, 2, 0)
	local direction = Vector3.new(0, DNC.SunlightDebuff.RaycastHeight, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(origin, direction, params)
	return result ~= nil
end

local function updateSunlightDebuff(dt)
	-- Только днём
	if currentPhase ~= "day" and currentPhase ~= "transition_dawn" then
		-- Ночь — снимаем дебафф у всех
		for _, player in Players:GetPlayers() do
			local char = player.Character
			if char then
				BuffManager.removeBuff(char, DNC.SunlightDebuff.BuffId)
			end
		end
		shelterData = {}
		return
	end

	sunCheckTimer += dt
	if sunCheckTimer < DNC.SunlightDebuff.CheckInterval then return end
	sunCheckTimer = 0

	local now = tick()

	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then continue end

		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end

		local inShelter = isInShelter(char)

		if inShelter then
			-- Запоминаем время входа в тень
			if not shelterData[player] then
				shelterData[player] = now
			end

			-- Если в тени дольше GracePeriod — снимаем дебафф
			local shelterTime = now - shelterData[player]
			if shelterTime >= DNC.SunlightDebuff.ShelterGracePeriod then
				BuffManager.removeBuff(char, DNC.SunlightDebuff.BuffId)
			end
		else
			-- На солнце — сбрасываем таймер тени, применяем/обновляем дебафф
			shelterData[player] = nil
			BuffManager.applyBuff(
				char,
				DNC.SunlightDebuff.BuffId,
				DNC.SunlightDebuff.Duration,
				"sunlight"
			)
		end
	end
end

-- ════════════════════════════════════════════════════════════
-- Синхронизация с клиентами
-- ════════════════════════════════════════════════════════════
local syncTimer = 0
local SYNC_INTERVAL = 5  -- секунд

local function sendSync(player)
	local isDay = (currentPhase == "day" or currentPhase == "transition_dawn")
	Remotes.DayNightSync:FireClient(player, {
		CycleTimer   = cycleTimer,
		TotalCycle   = totalCycleTime,
		IsDay        = isDay,
		Phase        = currentPhase,
		LunarPhase   = currentLunar,
		LunarTimer   = lunarTimer,
	})
end

local function broadcastSync()
	for _, player in Players:GetPlayers() do
		sendSync(player)
	end
end

-- ════════════════════════════════════════════════════════════
-- Главный тик
-- ════════════════════════════════════════════════════════════
local TRANSITION = DNC.TransitionTime

function DayNightManager.update(dt)
	-- Обновляем таймеры
	cycleTimer = (cycleTimer + dt) % totalCycleTime
	lunarTimer = (lunarTimer + dt) % LC.FullCycleDuration

	-- ── Определяем фазу дня ──
	local prevPhase = currentPhase

	-- Раскладка цикла: [0 .. NightDuration] = ночь, [NightDuration .. NightDuration+Day] = день
	-- С переходами на стыках
	local nightEnd  = DNC.NightDuration
	local dayEnd    = nightEnd + DNC.DayDuration

	if cycleTimer < TRANSITION then
		-- Переход: закат → ночь (начало цикла = начало ночи)
		currentPhase = "transition_dusk"
		local alpha = cycleTimer / TRANSITION
		applyLighting(DNC.Day, getNightPreset(), alpha)

	elseif cycleTimer < nightEnd - TRANSITION then
		-- Глубокая ночь
		currentPhase = "night"
		setLighting(getNightPreset())

	elseif cycleTimer < nightEnd then
		-- Переход: ночь → рассвет
		currentPhase = "transition_dawn"
		local alpha = (cycleTimer - (nightEnd - TRANSITION)) / TRANSITION
		applyLighting(getNightPreset(), DNC.Day, alpha)

	elseif cycleTimer < dayEnd - TRANSITION then
		-- День
		currentPhase = "day"
		setLighting(DNC.Day)

	else
		-- Переход: день → закат
		currentPhase = "transition_dusk"
		local alpha = (cycleTimer - (dayEnd - TRANSITION)) / TRANSITION
		applyLighting(DNC.Day, getNightPreset(), alpha)
	end

	-- ── Лунная фаза ──
	local prevLunar = currentLunar
	currentLunar = getLunarPhase(lunarTimer)

	if currentLunar ~= prevLunar then
		local phaseConfig = getLunarPhaseConfig(currentLunar)
		applyLunarBuffs(phaseConfig)
		print("[DayNight] Лунная фаза:", currentLunar)
	end

	-- ── Солнечный дебафф ──
	updateSunlightDebuff(dt)

	-- ── Синхронизация ──
	syncTimer += dt
	if syncTimer >= SYNC_INTERVAL then
		syncTimer = 0
		broadcastSync()
	end

	-- Лог смены фазы
	if currentPhase ~= prevPhase then
		print("[DayNight] Фаза:", currentPhase, "| Лунная:", currentLunar)
	end
end

-- ════════════════════════════════════════════════════════════
-- Инициализация
-- ════════════════════════════════════════════════════════════
function DayNightManager.init()
	-- Начинаем с ночи
	cycleTimer = 0
	lunarTimer = 0
	currentPhase = "night"
	currentLunar = getLunarPhase(0)
	setLighting(getNightPreset())

	-- Применяем начальные лунные баффы
	local phaseConfig = getLunarPhaseConfig(currentLunar)
	applyLunarBuffs(phaseConfig)

	-- Подключаем Heartbeat
	RunService.Heartbeat:Connect(function(dt)
		DayNightManager.update(dt)
	end)

	-- Отправляем синхронизацию новым игрокам
	Players.PlayerAdded:Connect(function(player)
		task.wait(2)  -- ждём загрузку персонажа
		sendSync(player)

		-- Применяем лунные баффы новому игроку
		player.CharacterAdded:Connect(function(char)
			task.wait(0.5)
			local phaseConfig2 = getLunarPhaseConfig(currentLunar)
			if phaseConfig2 then
				for _, buffDef in phaseConfig2.PlayerBuffs do
					BuffManager.applyBuff(char, buffDef.BuffId, 999999, "lunar")
				end
			end
		end)
	end)

	-- Очистка
	Players.PlayerRemoving:Connect(function(player)
		shelterData[player] = nil
	end)

	print("[DayNight] Инициализирован. Цикл:", totalCycleTime, "сек")
end

-- Геттеры для других модулей
function DayNightManager.isDay()
	return currentPhase == "day" or currentPhase == "transition_dawn"
end

function DayNightManager.isNight()
	return currentPhase == "night" or currentPhase == "transition_dusk"
end

function DayNightManager.getLunarPhase()
	return currentLunar
end

function DayNightManager.getPhase()
	return currentPhase
end

return DayNightManager