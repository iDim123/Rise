-- Универсальная полоска каста для:
--   • Контейнеров (вскрытие замка)
--   • Дальнобойного оружия (фаза 4)
--   • Способностей (фаза 4+)
--
-- API (через ModuleScript-обёртку не нужна — управление через Remotes)
-- CastStart  → { Duration, Label, MovementMode, SpeedMult, CancelKey, CancelOnStun, CancelOnDamage }
-- CastCancel → отмена
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()

player.CharacterAdded:Connect(function(char)
    character = char
end)

-- ────────────────────────────────────────────────────────────
-- Создание UI
-- ────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CastBarUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local castFrame = Instance.new("Frame")
castFrame.Name = "CastFrame"
castFrame.Size = UDim2.new(0, 320, 0, 44)
castFrame.Position = UDim2.new(0.5, -160, 0.72, 0)
castFrame.BackgroundColor3 = Color3.fromRGB(20, 18, 14)
castFrame.BorderSizePixel = 0
castFrame.Visible = false
castFrame.Parent = screenGui

local castCorner = Instance.new("UICorner")
castCorner.CornerRadius = UDim.new(0, 8)
castCorner.Parent = castFrame

-- Фон прогресс-бара
local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, -12, 0, 14)
barBg.Position = UDim2.new(0, 6, 1, -22)
barBg.BackgroundColor3 = Color3.fromRGB(40, 35, 28)
barBg.BorderSizePixel = 0
barBg.Parent = castFrame

local barBgCorner = Instance.new("UICorner")
barBgCorner.CornerRadius = UDim.new(0, 4)
barBgCorner.Parent = barBg

-- Заполняемая часть
local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(220, 160, 40)
barFill.BorderSizePixel = 0
barFill.Parent = barBg

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(0, 4)
barFillCorner.Parent = barFill

-- Текст-заголовок
local castLabel = Instance.new("TextLabel")
castLabel.Size = UDim2.new(1, -12, 0, 22)
castLabel.Position = UDim2.new(0, 6, 0, 4)
castLabel.BackgroundTransparency = 1
castLabel.TextColor3 = Color3.fromRGB(230, 210, 160)
castLabel.Font = Enum.Font.GothamBold
castLabel.TextScaled = true
castLabel.Text = "Каст..."
castLabel.TextXAlignment = Enum.TextXAlignment.Left
castLabel.Parent = castFrame

-- Подсказка отмены
local cancelHint = Instance.new("TextLabel")
cancelHint.Size = UDim2.new(1, -12, 0, 14)
cancelHint.Position = UDim2.new(0, 6, 0, 26)
cancelHint.BackgroundTransparency = 1
cancelHint.TextColor3 = Color3.fromRGB(150, 140, 120)
cancelHint.Font = Enum.Font.Gotham
cancelHint.TextScaled = true
cancelHint.Text = "MMB — отмена"
cancelHint.TextXAlignment = Enum.TextXAlignment.Left
cancelHint.Parent = castFrame

-- ────────────────────────────────────────────────────────────
-- Состояние
-- ────────────────────────────────────────────────────────────
local castData = {
    active = false,
    duration = 0,
    startTime = 0,
    movementMode = "Free",
    speedMult = 1,
    cancelKey = "MMB",
    cancelOnStun = true,
    cancelOnDamage = false,
    fillTween = nil,
    heartbeatConn = nil
}

local humanoid = nil -- обновляется при CharacterAdded

local function getHumanoid()
    if character then
        return character:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

-- ────────────────────────────────────────────────────────────
-- Применить движение по MovementMode
-- ────────────────────────────────────────────────────────────
local function applyMovementMode(mode, speedMult)
    local hum = getHumanoid()
    if not hum then
        return
    end

    if mode == "Locked" then
        hum.WalkSpeed = 0
    elseif mode == "Slowed" then
        -- базовая скорость берётся из StatsManager — клиент использует текущую
        local baseSpeed = 16
        hum.WalkSpeed = math.max(0, baseSpeed * (speedMult or 0.5))
    elseif mode == "Free" or mode == "CancelOnMove" then
        -- не меняем скорость
    end
end

-- Восстановить скорость после каста
local function restoreMovement()
    local hum = getHumanoid()
    if not hum then
        return
    end
    -- Нормальная скорость — пусть сервер пересчитает через StatsManager
    -- На клиенте просто сбрасываем до 16 (default)
    hum.WalkSpeed = 16
end

-- ────────────────────────────────────────────────────────────
-- Запустить CastBar
-- ────────────────────────────────────────────────────────────
local function startCast(params)
    -- params: { Duration, Label, MovementMode, SpeedMult, CancelKey, CancelOnStun, CancelOnDamage }
    if castData.active then
        -- Отменяем предыдущий
        if castData.fillTween then
            castData.fillTween:Cancel()
        end
        if castData.heartbeatConn then
            castData.heartbeatConn:Disconnect()
        end
    end

    castData.active = true
    castData.duration = params.Duration or 1
    castData.startTime = tick()
    castData.movementMode = params.MovementMode or "Free"
    castData.speedMult = params.SpeedMult or 1
    castData.cancelKey = params.CancelKey or "MMB"
    castData.cancelOnStun = params.CancelOnStun ~= false
    castData.cancelOnDamage = params.CancelOnDamage or false

    castLabel.Text = params.Label or "Каст..."
    cancelHint.Text = (castData.cancelKey or "MMB") .. " — отмена"
    castFrame.Visible = true

    -- Сброс полосы
    barFill.Size = UDim2.new(0, 0, 1, 0)

    -- Анимация заполнения
    castData.fillTween = TweenService:Create(barFill, TweenInfo.new(castData.duration, Enum.EasingStyle.Linear), {
        Size = UDim2.new(1, 0, 1, 0)
    })
    castData.fillTween:Play()

    -- Применяем ограничение движения
    applyMovementMode(castData.movementMode, castData.speedMult)

    -- Heartbeat: CancelOnMove
    local startPos = character and character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart.Position

    castData.heartbeatConn = RunService.Heartbeat:Connect(function()
        if not castData.active then
            return
        end

        -- CancelOnMove: проверяем смещение
        if castData.movementMode == "CancelOnMove" and startPos then
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - startPos).Magnitude > 1.5 then
                cancelCast()
                return
            end
        end
    end)

    -- Авто-завершение по таймеру
    task.delay(castData.duration, function()
        if castData.active then
            completeCast()
        end
    end)
end

-- ────────────────────────────────────────────────────────────
-- Завершить каст успешно
-- ────────────────────────────────────────────────────────────
function completeCast()
    if not castData.active then
        return
    end
    castData.active = false

    if castData.fillTween then
        castData.fillTween:Cancel()
    end
    if castData.heartbeatConn then
        castData.heartbeatConn:Disconnect()
    end

    barFill.Size = UDim2.new(1, 0, 1, 0)
    restoreMovement()

    -- Небольшая задержка перед скрытием
    task.delay(0.15, function()
        castFrame.Visible = false
        barFill.Size = UDim2.new(0, 0, 1, 0)
    end)

    -- Для контейнеров: отправить ContainerOpen ещё раз с castDone=true
    -- (это делает ContainerUI, не CastBar — здесь просто уведомление через Binding)
    -- Фаза 4+: RangedCastComplete и т.д. будут добавлены позже
end

-- ────────────────────────────────────────────────────────────
-- Отменить каст
-- ────────────────────────────────────────────────────────────
function cancelCast()
    if not castData.active then
        return
    end
    castData.active = false

    if castData.fillTween then
        castData.fillTween:Cancel()
    end
    if castData.heartbeatConn then
        castData.heartbeatConn:Disconnect()
    end

    restoreMovement()
    castFrame.Visible = false
    barFill.Size = UDim2.new(0, 0, 1, 0)

    -- Уведомляем сервер что игрок сам отменил каст (нажал CancelKey)
    Remotes.CastCancelRequest:FireServer()
end

-- ────────────────────────────────────────────────────────────
-- Remotes
-- ────────────────────────────────────────────────────────────
Remotes.CastStart.OnClientEvent:Connect(function(params)
    startCast(params)
end)

Remotes.CastCancel.OnClientEvent:Connect(function()
    cancelCast()
end)

-- ────────────────────────────────────────────────────────────
-- Отмена по CancelKey (MMB по умолчанию)
-- ────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not castData.active then
        return
    end

    local cancelKey = castData.cancelKey
    local pressed = false

    if cancelKey == "MMB" and input.UserInputType == Enum.UserInputType.MouseButton3 then
        pressed = true
    elseif cancelKey == "RMB" and input.UserInputType == Enum.UserInputType.MouseButton2 then
        pressed = true
    elseif input.KeyCode == Enum.KeyCode[cancelKey] then
        pressed = true
    end

    if pressed then
        cancelCast()
    end
end)

-- Stun/Knockdown отмена — через атрибут (сервер ставит "Stunned" = true)
RunService.Heartbeat:Connect(function()
    if not castData.active then
        return
    end
    if not castData.cancelOnStun then
        return
    end
    if not character then
        return
    end

    local isStunned = character:GetAttribute("Stunned") or character:GetAttribute("Knockdown")
    if isStunned then
        cancelCast()
    end
end)

-- Отмена при получении урона (если CancelOnDamage = true)
Remotes.DamageEvent.OnClientEvent:Connect(function(entity, hp, maxHP, damage, attackerName)
    if not castData.active then
        return
    end
    if not castData.cancelOnDamage then
        return
    end

    -- Проверяем что урон получил именно наш персонаж
    if entity == character then
        cancelCast()
    end
end)

-- ────────────────────────────────────────────────────────────
-- Интеграция ContainerUI: после успешного каста открываем сундук
-- ────────────────────────────────────────────────────────────
-- ContainerUI слушает completeCast через BindableEvent
-- Создаём BindableEvent для связи между скриптами
local castCompleteEvent = Instance.new("BindableEvent")
castCompleteEvent.Name = "CastComplete"
castCompleteEvent.Parent = screenGui

-- Переопределяем completeCast чтобы файрить event
local _originalComplete = completeCast
function completeCast()
    _originalComplete()
    castCompleteEvent:Fire()
end
