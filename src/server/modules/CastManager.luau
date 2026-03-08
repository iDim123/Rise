-- Централизованный серверный модуль управления состоянием каста.
-- Используется в: Фаза 2 (контейнеры), Фаза 4 (лук), Фаза 5 (заклинания).
--
-- API:
--   CastManager.start(player, params) → castId | nil
--   CastManager.cancel(player, reason?)
--   CastManager.isActive(player) → bool
--   CastManager.getCast(player) → castData | nil
--
-- params = {
--   Duration        : number               -- длительность в секундах
--   Label           : string               -- текст на CastBar
--   MovementMode    : string               -- "Locked"|"Slowed"|"Free"|"CancelOnMove"
--   SpeedMult       : number?              -- множитель скорости для Slowed (default 0.5)
--   CancelKey       : string?              -- "MMB"|"RMB"|"F" и т.д. (передаётся клиенту)
--   CancelOnStun    : bool?                -- прерывать при Stun/Knockdown (default true)
--   CancelOnDamage  : bool?                -- прерывать при получении урона (default false)
--   OnComplete      : function(player)?    -- колбэк при успешном завершении
--   OnCancel        : function(player, reason)? -- колбэк при отмене
-- }

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes   = require(ReplicatedStorage:WaitForChild("Remotes"))
local EventBus  = require(ServerScriptService:WaitForChild("modules"):WaitForChild("EventBus"))

-- ─────────────────────────────────────────────────────────
-- Режимы движения
-- ─────────────────────────────────────────────────────────
local MOVEMENT_MODE = {
    LOCKED          = "Locked",        -- WalkSpeed = 0, WASD игнорируется
    SLOWED          = "Slowed",        -- WalkSpeed = base * SpeedMult
    FREE            = "Free",          -- скорость не меняется
    CANCEL_ON_MOVE  = "CancelOnMove",  -- любое движение отменяет каст
}

-- ─────────────────────────────────────────────────────────
-- Внутренние данные
-- ─────────────────────────────────────────────────────────
-- activeCasts[player] = {
--   castId         : string
--   player         : Player
--   params         : table
--   startTime      : number (tick())
--   duration       : number
--   baseSpeed      : number        -- WalkSpeed до каста
--   startPosition  : Vector3       -- для CancelOnMove
--   timerTask      : thread        -- task.delay handle
--   cancelled      : bool
-- }
local activeCasts = {}

-- ─────────────────────────────────────────────────────────
-- Вспомогательные
-- ─────────────────────────────────────────────────────────

local function makeCastId()
    return "cast_" .. tostring(math.floor(tick() * 10000)) .. "_" .. tostring(math.random(1000, 9999))
end

-- Безопасно получить Humanoid персонажа
local function getHumanoid(player)
    local character = player.Character
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

-- Получить текущий WalkSpeed персонажа (базовый, до каста)
local function getBaseSpeed(player)
    -- Берём из StatsManager если доступен, иначе fallback 16
    local ok, StatsManager = pcall(function()
        return require(ServerScriptService:WaitForChild("modules"):WaitForChild("StatsManager"))
    end)
    if ok and StatsManager then
        local moveSpeed = StatsManager.get(player, "MoveSpeed")
        return 16 * (moveSpeed or 1)
    end
    return 16
end

-- Получить позицию HumanoidRootPart
local function getRootPosition(player)
    local character = player.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

-- Применить ограничение движения по режиму
local function applyMovementRestriction(player, mode, speedMult, baseSpeed)
    local humanoid = getHumanoid(player)
    if not humanoid then return end

    if mode == MOVEMENT_MODE.LOCKED then
        humanoid.WalkSpeed = 0
    elseif mode == MOVEMENT_MODE.SLOWED then
        local mult = speedMult or 0.5
        humanoid.WalkSpeed = math.max(0, baseSpeed * mult)
    elseif mode == MOVEMENT_MODE.FREE or mode == MOVEMENT_MODE.CANCEL_ON_MOVE then
        -- скорость не меняем
    end
end

-- Восстановить WalkSpeed после каста
local function restoreMovement(player, baseSpeed)
    local humanoid = getHumanoid(player)
    if not humanoid then return end
    -- Через StatsManager чтобы учесть баффы/дебаффы скорости
    local ok, StatsManager = pcall(function()
        return require(ServerScriptService:WaitForChild("modules"):WaitForChild("StatsManager"))
    end)
    if ok and StatsManager then
        StatsManager.recalculate(player)
    else
        humanoid.WalkSpeed = baseSpeed or 16
    end
end

-- ─────────────────────────────────────────────────────────
-- Публичное API
-- ─────────────────────────────────────────────────────────

local CastManager = {}
CastManager.MOVEMENT_MODE = MOVEMENT_MODE

-- Запустить каст для игрока.
-- Возвращает castId если запущен, nil если игрок уже кастует.
function CastManager.start(player, params)
    -- Уже активный каст — отклоняем (вызывающая сторона сама решает что делать)
    if activeCasts[player] then
        return nil, "already_casting"
    end

    -- Валидация обязательных полей
    assert(type(params.Duration) == "number" and params.Duration > 0,
        "[CastManager] Duration должен быть > 0")

    local castId   = makeCastId()
    local mode     = params.MovementMode or MOVEMENT_MODE.FREE
    local baseSpeed = getBaseSpeed(player)
    local startPos = getRootPosition(player)

    local castData = {
        castId        = castId,
        player        = player,
        params        = params,
        startTime     = tick(),
        duration      = params.Duration,
        baseSpeed     = baseSpeed,
        startPosition = startPos,
        timerTask     = nil,
        cancelled     = false,
    }

    activeCasts[player] = castData

    -- Применяем ограничение движения на сервере
    applyMovementRestriction(player, mode, params.SpeedMult, baseSpeed)

    -- Уведомляем клиент — CastBar.client.luau покажет полоску
    Remotes.CastStart:FireClient(player, {
        Duration        = params.Duration,
        Label           = params.Label or "Каст...",
        MovementMode    = mode,
        SpeedMult       = params.SpeedMult or 0.5,
        CancelKey       = params.CancelKey or "MMB",
        CancelOnStun    = params.CancelOnStun ~= false,
        CancelOnDamage  = params.CancelOnDamage or false,
    })

    -- Авто-завершение по таймеру
    castData.timerTask = task.delay(params.Duration, function()
        -- Проверяем что каст всё ещё активен и это именно наш castId
        local current = activeCasts[player]
        if current and current.castId == castId and not current.cancelled then
            CastManager._complete(player, castId)
        end
    end)

    return castId
end

-- Успешное завершение каста (внутреннее)
function CastManager._complete(player, castId)
    local castData = activeCasts[player]
    if not castData or castData.castId ~= castId then return end
    if castData.cancelled then return end

    activeCasts[player] = nil

    -- Восстанавливаем движение
    restoreMovement(player, castData.baseSpeed)

    -- Вызываем OnComplete колбэк
    if castData.params.OnComplete then
        task.spawn(castData.params.OnComplete, player)
    end
end

-- Отменить каст игрока
-- reason: "player" | "stun" | "damage" | "move" | "server" | "disconnect"
function CastManager.cancel(player, reason)
    local castData = activeCasts[player]
    if not castData then return end

    castData.cancelled = true
    activeCasts[player] = nil

    -- Восстанавливаем движение
    restoreMovement(player, castData.baseSpeed)

    -- Уведомляем клиент — CastBar скроется
    Remotes.CastCancel:FireClient(player)

    -- Вызываем OnCancel колбэк
    if castData.params.OnCancel then
        task.spawn(castData.params.OnCancel, player, reason or "server")
    end
end

-- Проверить, кастует ли игрок прямо сейчас
function CastManager.isActive(player)
    return activeCasts[player] ~= nil
end

-- Получить текущие данные каста
function CastManager.getCast(player)
    return activeCasts[player]
end

-- ─────────────────────────────────────────────────────────
-- Heartbeat: логика CancelOnMove + Stun/Knockdown
-- ─────────────────────────────────────────────────────────
local MOVE_THRESHOLD = 1.5  -- studs — минимальное смещение для отмены

RunService.Heartbeat:Connect(function()
    for player, castData in activeCasts do
        -- Проверяем что игрок ещё в игре
        if not player.Parent then
            CastManager.cancel(player, "disconnect")
            continue
        end

        local character = player.Character
        if not character then
            CastManager.cancel(player, "server")
            continue
        end

        local mode = castData.params.MovementMode or MOVEMENT_MODE.FREE

        -- ── CancelOnMove: проверяем смещение ──
        if mode == MOVEMENT_MODE.CANCEL_ON_MOVE then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp and castData.startPosition then
                local moved = (hrp.Position - castData.startPosition).Magnitude
                if moved > MOVE_THRESHOLD then
                    CastManager.cancel(player, "move")
                    continue
                end
            end
        end

        -- ── Locked: принудительно удерживаем WalkSpeed = 0 ──
        -- (страховка от клиентских попыток сдвинуться)
        if mode == MOVEMENT_MODE.LOCKED then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.WalkSpeed ~= 0 then
                humanoid.WalkSpeed = 0
            end
        end

        -- ── Stun / Knockdown прерывание ──
        if castData.params.CancelOnStun ~= false then
            local isStunned = character:GetAttribute("Stunned")
                or character:GetAttribute("Knockdown")
            if isStunned then
                CastManager.cancel(player, "stun")
                continue
            end
        end
    end
end)

-- ─────────────────────────────────────────────────────────
-- Интеграция с EventBus: прерывание при смерти
-- ─────────────────────────────────────────────────────────
EventBus.on("PlayerDied", function(player, entity, attacker)
    if CastManager.isActive(player) then
        CastManager.cancel(player, "server")
    end
end)

-- ─────────────────────────────────────────────────────────
-- Remote: клиент запросил отмену (MMB / RMB)
-- ─────────────────────────────────────────────────────────
-- CastCancel уже есть в Remotes, добавляем обработчик входящего события
-- Для этого в Remotes.luau нужно разделить CastCancel на:
--   CastCancel  (Server → Client)  ← уже есть
--   CastCancelRequest (Client → Server) ← добавляем
-- Но чтобы не ломать уже написанный код —
-- слушаем CastCancel в оба направления через отдельное событие (см. Remotes ниже)
Remotes.CastCancelRequest.OnServerEvent:Connect(function(player)
    local castData = activeCasts[player]
    if not castData then return end
    CastManager.cancel(player, "player")
end)

-- ─────────────────────────────────────────────────────────
-- Интеграция CancelOnDamage
-- ─────────────────────────────────────────────────────────
-- HealthManager вызывает EventBus "EntityTookDamage" — подключаемся к нему.
-- Если события нет — CastManager подписывается через хук в HealthManager (см. ниже).
EventBus.on("EntityTookDamage", function(entity, damage, attacker)
    local player = Players:GetPlayerFromCharacter(entity)
    if not player then return end

    local castData = activeCasts[player]
    if not castData then return end

    if castData.params.CancelOnDamage then
        CastManager.cancel(player, "damage")
    end
end)

-- ─────────────────────────────────────────────────────────
-- Очистка при выходе из игры
-- ─────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
    if activeCasts[player] then
        activeCasts[player].cancelled = true
        activeCasts[player] = nil
    end
end)

return CastManager