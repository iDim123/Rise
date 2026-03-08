-- CastBar.client.luau
-- Универсальная полоска каста (контейнеры, оружие, способности)
--
-- Новый дизайн:
--   [Иконка] [====== Название ========== 2.4с ======]
--   Иконка слева (если передана), название внутри бара, время справа
--
-- API через Remotes:
--   CastStart → { Duration, Label, Icon, MovementMode, SpeedMult,
--                  CancelKey, CancelOnStun, CancelOnDamage }
--   CastCancel → отмена
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

-- ════════════════════════════════════════════════════════════
-- Константы стиля
-- ════════════════════════════════════════════════════════════
local BAR_WIDTH = 320
local BAR_HEIGHT = 32
local ICON_SIZE = BAR_HEIGHT + 4 -- чуть больше бара
local ICON_PAD = 6
local CORNER = UDim.new(0, 4)

local COLOR_BG = Color3.fromRGB(18, 18, 28)
local COLOR_BAR_BG = Color3.fromRGB(35, 35, 55)
local COLOR_FILL = Color3.fromRGB(90, 75, 170) -- фиолетовый, как на референсе
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_TIME = Color3.fromRGB(220, 220, 220)
local COLOR_STROKE = Color3.fromRGB(60, 60, 80)
local COLOR_ICON_BG = Color3.fromRGB(30, 30, 45)

-- ════════════════════════════════════════════════════════════
-- Создание UI
-- ════════════════════════════════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CastBarUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

-- Контейнер (иконка + бар в одну строку)
local castFrame = Instance.new("Frame")
castFrame.Name = "CastFrame"
castFrame.Size = UDim2.new(0, ICON_SIZE + ICON_PAD + BAR_WIDTH, 0, ICON_SIZE)
castFrame.AnchorPoint = Vector2.new(0.5, 0)
castFrame.Position = UDim2.new(0.5, 0, 0.72, 0)
castFrame.BackgroundTransparency = 1
castFrame.Visible = false
castFrame.Parent = screenGui

-- ── Иконка (квадрат слева) ────────────────────────────────
local iconFrame = Instance.new("Frame")
iconFrame.Name = "IconFrame"
iconFrame.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
iconFrame.Position = UDim2.new(0, 0, 0.5, 0)
iconFrame.AnchorPoint = Vector2.new(0, 0.5)
iconFrame.BackgroundColor3 = COLOR_ICON_BG
iconFrame.BorderSizePixel = 0
iconFrame.Visible = false
iconFrame.Parent = castFrame

Instance.new("UICorner", iconFrame).CornerRadius = CORNER

local iconStroke = Instance.new("UIStroke")
iconStroke.Color = COLOR_STROKE
iconStroke.Thickness = 1.5
iconStroke.Parent = iconFrame

local iconImage = Instance.new("ImageLabel")
iconImage.Name = "Icon"
iconImage.Size = UDim2.new(1, -6, 1, -6)
iconImage.Position = UDim2.new(0, 3, 0, 3)
iconImage.BackgroundTransparency = 1
iconImage.ScaleType = Enum.ScaleType.Fit
iconImage.Image = ""
iconImage.Parent = iconFrame

-- ── Бар (справа от иконки) ────────────────────────────────
local barFrame = Instance.new("Frame")
barFrame.Name = "BarFrame"
barFrame.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
barFrame.Position = UDim2.new(0, ICON_SIZE + ICON_PAD, 0.5, 0)
barFrame.AnchorPoint = Vector2.new(0, 0.5)
barFrame.BackgroundColor3 = COLOR_BAR_BG
barFrame.BorderSizePixel = 0
barFrame.ClipsDescendants = true
barFrame.Parent = castFrame

Instance.new("UICorner", barFrame).CornerRadius = CORNER

local barStroke = Instance.new("UIStroke")
barStroke.Color = COLOR_STROKE
barStroke.Thickness = 1.5
barStroke.Parent = barFrame

-- Заполняющаяся полоса
local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = COLOR_FILL
barFill.BorderSizePixel = 0
barFill.Parent = barFrame

Instance.new("UICorner", barFill).CornerRadius = CORNER

-- Свечение на конце полосы (тонкая белая полоска)
local barGlow = Instance.new("Frame")
barGlow.Name = "Glow"
barGlow.Size = UDim2.new(0, 3, 1, 0)
barGlow.Position = UDim2.new(1, -3, 0, 0)
barGlow.BackgroundColor3 = Color3.fromRGB(200, 200, 255)
barGlow.BackgroundTransparency = 0.4
barGlow.BorderSizePixel = 0
barGlow.Parent = barFill

-- Название каста (внутри бара, по центру-лево)
local castLabel = Instance.new("TextLabel")
castLabel.Name = "CastLabel"
castLabel.Size = UDim2.new(1, -60, 1, 0)
castLabel.Position = UDim2.new(0, 10, 0, 0)
castLabel.BackgroundTransparency = 1
castLabel.TextColor3 = COLOR_TEXT
castLabel.Font = Enum.Font.GothamBold
castLabel.TextSize = 14
castLabel.Text = "Каст..."
castLabel.TextXAlignment = Enum.TextXAlignment.Left
castLabel.TextYAlignment = Enum.TextYAlignment.Center
castLabel.ZIndex = 5
castLabel.Parent = barFrame

-- Время (внутри бара, справа)
local timeLabel = Instance.new("TextLabel")
timeLabel.Name = "TimeLabel"
timeLabel.Size = UDim2.new(0, 50, 1, 0)
timeLabel.Position = UDim2.new(1, -55, 0, 0)
timeLabel.BackgroundTransparency = 1
timeLabel.TextColor3 = COLOR_TIME
timeLabel.Font = Enum.Font.GothamBold
timeLabel.TextSize = 14
timeLabel.Text = "0.0"
timeLabel.TextXAlignment = Enum.TextXAlignment.Right
timeLabel.TextYAlignment = Enum.TextYAlignment.Center
timeLabel.ZIndex = 5
timeLabel.Parent = barFrame

-- ════════════════════════════════════════════════════════════
-- Состояние
-- ════════════════════════════════════════════════════════════
local castState = {
    active = false,
    duration = 0,
    startTime = 0,
    movementMode = "Free",
    speedMult = 1,
    cancelKey = "MMB",
    cancelOnStun = true,
    cancelOnDamage = false,
    fillTween = nil,
    heartbeatConn = nil,
    timerConn = nil
}

local isCancelledByServer = false

local function getHumanoid()
    if character then
        return character:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

-- ════════════════════════════════════════════════════════════
-- Движение
-- ════════════════════════════════════════════════════════════
local function applyMovementMode(mode, speedMult)
    local hum = getHumanoid()
    if not hum then
        return
    end

    if mode == "Locked" then
        hum.WalkSpeed = 0
    elseif mode == "Slowed" then
        local baseSpeed = 16
        hum.WalkSpeed = math.max(0, baseSpeed * (speedMult or 0.5))
    end
    -- Free / CancelOnMove — не трогаем
end

local function restoreMovement()
    local hum = getHumanoid()
    if not hum then
        return
    end
    hum.WalkSpeed = 16
end

-- ════════════════════════════════════════════════════════════
-- Обновление позиции бара (с иконкой / без)
-- ════════════════════════════════════════════════════════════
local function updateLayout(hasIcon)
    if hasIcon then
        iconFrame.Visible = true
        barFrame.Position = UDim2.new(0, ICON_SIZE + ICON_PAD, 0.5, 0)
        castFrame.Size = UDim2.new(0, ICON_SIZE + ICON_PAD + BAR_WIDTH, 0, ICON_SIZE)
    else
        iconFrame.Visible = false
        barFrame.Position = UDim2.new(0, 0, 0.5, 0)
        castFrame.Size = UDim2.new(0, BAR_WIDTH, 0, ICON_SIZE)
    end
end

-- ════════════════════════════════════════════════════════════
-- Cleanup helpers
-- ════════════════════════════════════════════════════════════
local function cleanupConnections()
    if castState.fillTween then
        castState.fillTween:Cancel()
        castState.fillTween = nil
    end
    if castState.heartbeatConn then
        castState.heartbeatConn:Disconnect()
        castState.heartbeatConn = nil
    end
    if castState.timerConn then
        castState.timerConn:Disconnect()
        castState.timerConn = nil
    end
end

-- ════════════════════════════════════════════════════════════
-- Завершить каст успешно
-- ════════════════════════════════════════════════════════════
local function completeCast()
    if not castState.active then
        return
    end
    castState.active = false

    cleanupConnections()
    barFill.Size = UDim2.new(1, 0, 1, 0)
    timeLabel.Text = "0.0"
    restoreMovement()

    task.delay(0.2, function()
        castFrame.Visible = false
        barFill.Size = UDim2.new(0, 0, 1, 0)
    end)
end

-- ════════════════════════════════════════════════════════════
-- Отменить каст
-- ════════════════════════════════════════════════════════════
local function cancelCast()
    if not castState.active then
        return
    end
    castState.active = false

    cleanupConnections()
    restoreMovement()
    castFrame.Visible = false
    barFill.Size = UDim2.new(0, 0, 1, 0)

    if not isCancelledByServer then
        Remotes.CastCancelRequest:FireServer()
    end
end

-- ════════════════════════════════════════════════════════════
-- Запустить CastBar
-- ════════════════════════════════════════════════════════════
local function startCast(params)
    -- params: { Duration, Label, Icon, MovementMode, SpeedMult,
    --           CancelKey, CancelOnStun, CancelOnDamage }
    if castState.active then
        cleanupConnections()
    end

    local duration = params.Duration or 1

    castState.active = true
    castState.duration = duration
    castState.startTime = tick()
    castState.movementMode = params.MovementMode or "Free"
    castState.speedMult = params.SpeedMult or 1
    castState.cancelKey = params.CancelKey or "MMB"
    castState.cancelOnStun = params.CancelOnStun ~= false
    castState.cancelOnDamage = params.CancelOnDamage or false

    -- Иконка
    local hasIcon = params.Icon and params.Icon ~= ""
    if hasIcon then
        iconImage.Image = params.Icon
    end
    updateLayout(hasIcon)

    -- Текст
    castLabel.Text = params.Label or "Каст..."
    timeLabel.Text = string.format("%.1f", duration) .. " / " .. string.format("%.1f", castState.duration)

    -- Сброс и показ
    barFill.Size = UDim2.new(0, 0, 1, 0)
    castFrame.Visible = true

    -- Tween заполнения
    castState.fillTween = TweenService:Create(barFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Size = UDim2.new(1, 0, 1, 0)
    })
    castState.fillTween:Play()

    -- Применяем движение
    applyMovementMode(castState.movementMode, castState.speedMult)

    -- Heartbeat: обновляем таймер + CancelOnMove
    local startPos = character and character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart.Position

    castState.heartbeatConn = RunService.Heartbeat:Connect(function()
        if not castState.active then
            return
        end

        -- Обновляем отображение оставшегося времени
        local elapsed = tick() - castState.startTime
        local remaining = math.max(0, duration - elapsed)
        timeLabel.Text = string.format("%.1f", remaining) .. " / " .. string.format("%.1f", castState.duration)

        -- CancelOnMove
        if castState.movementMode == "CancelOnMove" and startPos then
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - startPos).Magnitude > 1.5 then
                cancelCast()
            end
        end
    end)

    -- Авто-завершение
    task.delay(duration, function()
        if castState.active then
            completeCast()
        end
    end)
end

-- ════════════════════════════════════════════════════════════
-- Remotes
-- ════════════════════════════════════════════════════════════
Remotes.CastStart.OnClientEvent:Connect(function(params)
    startCast(params)
end)

Remotes.CastCancel.OnClientEvent:Connect(function()
    isCancelledByServer = true
    cancelCast()
    isCancelledByServer = false
end)

-- ════════════════════════════════════════════════════════════
-- Отмена по CancelKey
-- ════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not castState.active then
        return
    end

    local cancelKey = castState.cancelKey
    local pressed = false

    if cancelKey == "MMB" then
        pressed = (input.UserInputType == Enum.UserInputType.MouseButton3)
    elseif cancelKey == "RMB" then
        pressed = (input.UserInputType == Enum.UserInputType.MouseButton2)
    else
        local ok, keyEnum = pcall(function()
            return Enum.KeyCode[cancelKey]
        end)
        if ok and keyEnum and input.KeyCode == keyEnum then
            pressed = true
        end
    end

    if pressed then
        cancelCast()
    end
end)

-- Stun / Knockdown
RunService.Heartbeat:Connect(function()
    if not castState.active then
        return
    end
    if not castState.cancelOnStun then
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

-- Урон → отмена
Remotes.DamageEvent.OnClientEvent:Connect(function(entity, hp, maxHP, damage, attackerName)
    if not castState.active then
        return
    end
    if not castState.cancelOnDamage then
        return
    end
    if entity == character then
        cancelCast()
    end
end)

-- ════════════════════════════════════════════════════════════
-- BindableEvent для интеграции с ContainerUI
-- ════════════════════════════════════════════════════════════
local castCompleteEvent = Instance.new("BindableEvent")
castCompleteEvent.Name = "CastComplete"
castCompleteEvent.Parent = screenGui

local _origComplete = completeCast
completeCast = function()
    _origComplete()
    castCompleteEvent:Fire()
end
