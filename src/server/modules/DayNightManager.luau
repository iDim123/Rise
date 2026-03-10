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
local cycleDuration = DNC.CycleDuration
local secsPerHour   = cycleDuration / 24
local cycleTimer    = (DNC.StartHour or 0) * secsPerHour
local lunarTimer    = 0

local currentPhase  = "night"
local currentLunar  = "new_moon"

local shelterData   = {}
local timeScale = 1
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

local function applyLighting(from, to, alpha)
    Lighting.Brightness     = lerp(from.Brightness, to.Brightness, alpha)
    Lighting.Ambient        = lerpColor(from.Ambient, to.Ambient, alpha)
    Lighting.OutdoorAmbient = lerpColor(from.OutdoorAmbient, to.OutdoorAmbient, alpha)
    Lighting.FogEnd         = lerp(from.FogEnd, to.FogEnd, alpha)
    Lighting.FogColor       = lerpColor(from.FogColor, to.FogColor, alpha)
end

local function setLighting(preset)
    Lighting.Brightness     = preset.Brightness
    Lighting.Ambient        = preset.Ambient
    Lighting.OutdoorAmbient = preset.OutdoorAmbient
    Lighting.FogEnd         = preset.FogEnd
    Lighting.FogColor       = preset.FogColor
end

local function getNightPreset()
    if currentLunar == "blood_moon" then
        return DNC.BloodMoon
    end
    return DNC.Night
end

function DayNightManager.setTime(hour)
    cycleTimer = math.clamp(hour, 0, 24) * secsPerHour
    broadcastSync()
end

function DayNightManager.setTimeScale(scale)
    timeScale = scale
end


-- ════════════════════════════════════════════════════════════
-- Время → часы / фаза
-- ════════════════════════════════════════════════════════════
local function getClockTime()
    return (cycleTimer / cycleDuration) * 24
end

local function getPhaseFromClock(clock)
    local dawn  = DNC.DawnHour
    local day   = DNC.DayHour
    local dusk  = DNC.DuskHour
    local night = DNC.NightHour

    if clock >= day and clock < dusk then
        return "day"
    elseif clock >= dawn and clock < day then
        return "transition_dawn"
    elseif clock >= dusk and clock < night then
        return "transition_dusk"
    else
        return "night"
    end
end

-- ════════════════════════════════════════════════════════════
-- Лунный цикл
-- ════════════════════════════════════════════════════════════
local activeLunarBuffs = {}

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
    for buffId, _ in activeLunarBuffs do
        for _, player in Players:GetPlayers() do
            local char = player.Character
            if char then
                BuffManager.removeBuff(char, buffId)
            end
        end
    end
    activeLunarBuffs = {}

    if not phaseConfig then return end

    for _, buffDef in phaseConfig.PlayerBuffs do
        activeLunarBuffs[buffDef.BuffId] = true
        for _, player in Players:GetPlayers() do
            local char = player.Character
            if char then
                BuffManager.applyBuff(char, buffDef.BuffId, 999999, "lunar")
            end
        end
    end
end

-- ════════════════════════════════════════════════════════════
-- Солнечный дебафф
-- ════════════════════════════════════════════════════════════
local sunCheckTimer = 0

local function isInShelter(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local origin = hrp.Position + Vector3.new(0, 2, 0)
    local sunDir = Lighting:GetSunDirection()
    if sunDir.Y <= 0.05 then return true end

    local direction = sunDir * DNC.SunlightDebuff.RaycastHeight

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }

    local result = workspace:Raycast(origin, direction, params)
    return result ~= nil
end

local function updateSunlightDebuff(dt)
    if currentPhase ~= "day" and currentPhase ~= "transition_dawn" then
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

    local now = os.clock()

    for _, player in Players:GetPlayers() do
        local char = player.Character
        if not char then continue end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local inShelter = isInShelter(char)

        if inShelter then
            if not shelterData[player] then
                shelterData[player] = now
            end
            local shelterTime = now - shelterData[player]
            if shelterTime >= DNC.SunlightDebuff.ShelterGracePeriod then
                BuffManager.removeBuff(char, DNC.SunlightDebuff.BuffId)
            end
        else
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
local SYNC_INTERVAL = 5

local function sendSync(player)
    local clock = getClockTime()
    local isDay = (currentPhase == "day" or currentPhase == "transition_dawn")
    Remotes.DayNightSync:FireClient(player, {
        CycleTimer   = cycleTimer,
        TotalCycle   = cycleDuration,
        IsDay        = isDay,
        Phase        = currentPhase,
        LunarPhase   = currentLunar,
        LunarTimer   = lunarTimer,
        ClockTime    = clock,
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
function DayNightManager.update(dt)
    dt = dt * timeScale
    cycleTimer = (cycleTimer + dt) % cycleDuration
    lunarTimer = (lunarTimer + dt) % LC.FullCycleDuration

    local clock = getClockTime()
    local prevPhase = currentPhase
    currentPhase = getPhaseFromClock(clock)

    local dawn  = DNC.DawnHour
    local day   = DNC.DayHour
    local dusk  = DNC.DuskHour
    local night = DNC.NightHour

    if currentPhase == "day" then
        setLighting(DNC.Day)
    elseif currentPhase == "night" then
        setLighting(getNightPreset())
    elseif currentPhase == "transition_dawn" then
        local alpha = (clock - dawn) / (day - dawn)
        applyLighting(getNightPreset(), DNC.Day, alpha)
    elseif currentPhase == "transition_dusk" then
        local alpha = (clock - dusk) / (night - dusk)
        applyLighting(DNC.Day, getNightPreset(), alpha)
    end

    Lighting.ClockTime = clock

    local prevLunar = currentLunar
    currentLunar = getLunarPhase(lunarTimer)

    if currentLunar ~= prevLunar then
        local phaseConfig = getLunarPhaseConfig(currentLunar)
        applyLunarBuffs(phaseConfig)
        print("[DayNight] Лунная фаза:", currentLunar)
    end

    updateSunlightDebuff(dt)

    syncTimer += dt
    if syncTimer >= SYNC_INTERVAL then
        syncTimer = 0
        broadcastSync()
    end

    if currentPhase ~= prevPhase then
        print("[DayNight] Фаза:", currentPhase, "| Час:", string.format("%.1f", clock), "| Лунная:", currentLunar)
    end
end

-- ════════════════════════════════════════════════════════════
-- Инициализация
-- ════════════════════════════════════════════════════════════
function DayNightManager.init()
    cycleTimer = (DNC.StartHour or 0) * secsPerHour
    lunarTimer = 0
    local clock = getClockTime()
    currentPhase = getPhaseFromClock(clock)
    currentLunar = getLunarPhase(0)

    if currentPhase == "night" then
        setLighting(getNightPreset())
    else
        setLighting(DNC.Day)
    end
    Lighting.ClockTime = clock

    local phaseConfig = getLunarPhaseConfig(currentLunar)
    applyLunarBuffs(phaseConfig)

    RunService.Heartbeat:Connect(function(dt)
        DayNightManager.update(dt)
    end)

    Players.PlayerAdded:Connect(function(player)
        task.wait(2)
        sendSync(player)

        player.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            local pc = getLunarPhaseConfig(currentLunar)
            if pc then
                for _, buffDef in pc.PlayerBuffs do
                    BuffManager.applyBuff(char, buffDef.BuffId, 999999, "lunar")
                end
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        shelterData[player] = nil
    end)

    print("[DayNight] Инициализирован. Цикл:", cycleDuration, "сек")
end

-- Геттеры
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