local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local RangedInput = {}

-- ═══════════════════════════════════════════════════════════
-- Состояния
-- ═══════════════════════════════════════════════════════════

local STATE_IDLE = "Idle"
local STATE_CASTING = "Casting"
local STATE_READY = "Ready"

local state = STATE_IDLE
local earlyReleasePos = nil
local castCompleteConn = nil
local castCancelConn = nil
local stuckTimeoutTask = nil -- таймаут для зависшего Casting

local STUCK_TIMEOUT = 3.0 -- макс. время в Casting без CastComplete

-- ═══════════════════════════════════════════════════════════
-- Хелперы
-- ═══════════════════════════════════════════════════════════

local function getMouseWorldPosition()
    local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local rayOrigin = mouseRay.Origin
    local rayDirection = mouseRay.Direction

    local character = player.Character
    if not character then
        return nil
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return nil
    end

    local groundY = rootPart.Position.Y - 3
    if math.abs(rayDirection.Y) < 0.001 then
        return nil
    end
    local t = (groundY - rayOrigin.Y) / rayDirection.Y
    if t < 0 then
        return nil
    end

    return rayOrigin + rayDirection * t
end

-- ═══════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════

local function cleanup()
    if castCompleteConn then
        castCompleteConn:Disconnect()
        castCompleteConn = nil
    end
    if castCancelConn then
        castCancelConn:Disconnect()
        castCancelConn = nil
    end
    if stuckTimeoutTask then
        task.cancel(stuckTimeoutTask)
        stuckTimeoutTask = nil
    end
    state = STATE_IDLE
    earlyReleasePos = nil
end

-- ═══════════════════════════════════════════════════════════
-- Отправка RangedRelease
-- ═══════════════════════════════════════════════════════════

local function sendRelease(mousePos)
    if mousePos then
        Remotes.RangedRelease:FireServer(mousePos)
    end
    cleanup()
end

-- ═══════════════════════════════════════════════════════════
-- Обработка CastComplete
-- ═══════════════════════════════════════════════════════════

local function onCastComplete()
    -- Отключаем подписку сразу
    if castCompleteConn then
        castCompleteConn:Disconnect()
        castCompleteConn = nil
    end

    -- Убираем stuck таймаут — каст завершился нормально
    if stuckTimeoutTask then
        task.cancel(stuckTimeoutTask)
        stuckTimeoutTask = nil
    end

    if state == STATE_CASTING then
        if earlyReleasePos then
            -- Игрок уже отпустил LMB → отправляем запомненную позицию
            sendRelease(earlyReleasePos)
        else
            -- LMB ещё зажат → ждём отпускания
            state = STATE_READY
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API
-- ═══════════════════════════════════════════════════════════

function RangedInput.start()
    -- Если застряли в Casting — принудительно сбросить
    if state == STATE_CASTING then
        cleanup()
    end

    if state ~= STATE_IDLE then
        return
    end

    local mousePos = getMouseWorldPosition()
    if not mousePos then
        return
    end

    state = STATE_CASTING
    earlyReleasePos = nil

    -- Отправляем AttackRequest → сервер начнёт каст
    Remotes.AttackRequest:FireServer(mousePos)

    -- ── Подписка на CastComplete ──
    local playerGui = player:WaitForChild("PlayerGui")
    local castBarUI = playerGui:FindFirstChild("CastBarUI")
    if castBarUI then
        local completeEvent = castBarUI:FindFirstChild("CastComplete")
        if completeEvent then
            castCompleteConn = completeEvent.Event:Connect(onCastComplete)
        end
    end

    -- ── Подписка на CastCancel от сервера ──
    castCancelConn = Remotes.CastCancel.OnClientEvent:Connect(function()
        cleanup()
    end)

    -- ── Таймаут на случай зависания в Casting ──
    stuckTimeoutTask = task.delay(STUCK_TIMEOUT, function()
        if state == STATE_CASTING then
            cleanup()
        end
    end)
end

function RangedInput.stop()
    if state == STATE_CASTING then
        -- Каст ещё идёт → запоминаем позицию, НЕ отправляем RangedRelease
        earlyReleasePos = getMouseWorldPosition()

    elseif state == STATE_READY then
        -- Каст завершён, ожидали отпускания → отправляем текущую позицию
        local mousePos = getMouseWorldPosition()
        sendRelease(mousePos)
    end
end

function RangedInput.isActive()
    return state ~= STATE_IDLE
end

return RangedInput
