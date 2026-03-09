local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local Config = require(ReplicatedStorage:WaitForChild("Config"))

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
local stuckTimeoutTask = nil
local isHolding = false -- LMB зажат
local lastWeaponCooldown = 0.3

local STUCK_TIMEOUT = 3.0
local REFIRE_DELAY = 0.05 -- задержка перед повторным выстрелом

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
        pcall(task.cancel, stuckTimeoutTask)
        stuckTimeoutTask = nil
    end
    state = STATE_IDLE
    earlyReleasePos = nil
end

-- ═══════════════════════════════════════════════════════════
-- Отправка RangedRelease и автоперезапуск
-- ═══════════════════════════════════════════════════════════
local beginCast
local sendReleaseAndRefire

sendReleaseAndRefire = function(mousePos)
    cleanup()
    if mousePos then
        Remotes.RangedRelease:FireServer(mousePos)
    end
    if isHolding then
        -- Ждём cooldown оружия перед следующим кастом
        -- CastTime уже прошёл, нужно выждать только Cooldown
        local cooldown = lastWeaponCooldown or 0.3
        local delay = math.max(cooldown + 0.05, 0.1) -- +50ms запас на сеть
        task.delay(delay, function()
            if isHolding then
                beginCast()
            end
        end)
    else
        print("[RangedInput] no refire — not holding")
    end
end

beginCast = function()
    if state ~= STATE_IDLE then
        return
    end

    -- Получаем конфиг оружия для cooldown
    local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
    if tool and Config.Weapons then
        local weaponConfig = Config.Weapons[tool.Name]
        if weaponConfig then
            lastWeaponCooldown = weaponConfig.Cooldown or 0.3
        end
    end

    local mousePos = getMouseWorldPosition()
    if not mousePos then
        return
    end

    state = STATE_CASTING
    earlyReleasePos = nil

    Remotes.AttackRequest:FireServer(mousePos)

    -- Подписка на CastComplete
    local playerGui = player:WaitForChild("PlayerGui")
    local castBarUI = playerGui:FindFirstChild("CastBarUI")
    if castBarUI then
        local completeEvent = castBarUI:FindFirstChild("CastComplete")
        if completeEvent then
            castCompleteConn = completeEvent.Event:Connect(function()
                    earlyReleasePos)
                if castCompleteConn then
                    castCompleteConn:Disconnect()
                    castCompleteConn = nil
                end

                if stuckTimeoutTask then
                    pcall(task.cancel, stuckTimeoutTask)
                    stuckTimeoutTask = nil
                end

                if state == STATE_CASTING then
                    if earlyReleasePos then
                        local pos = earlyReleasePos
                        cleanup()
                        Remotes.RangedRelease:FireServer(pos)
                    elseif isHolding then
                        local currentPos = getMouseWorldPosition()
                        sendReleaseAndRefire(currentPos)
                    else
                        state = STATE_READY
                    end
                end
            end)
        end
    end

    -- Подписка на CastCancel
    castCancelConn = Remotes.CastCancel.OnClientEvent:Connect(function()
        cleanup()
    end)

    -- Таймаут
    stuckTimeoutTask = task.delay(STUCK_TIMEOUT, function()
        if state == STATE_CASTING then
            cleanup()
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API
-- ═══════════════════════════════════════════════════════════

function RangedInput.start()
    isHolding = true

    if state == STATE_CASTING then
        cleanup()
    end

    beginCast()
end

function RangedInput.stop()
    isHolding = false

    if state == STATE_CASTING then
        earlyReleasePos = getMouseWorldPosition()

    elseif state == STATE_READY then
        local mousePos = getMouseWorldPosition()
        sendReleaseAndRefire(mousePos)
    end
end

function RangedInput.isActive()
    return state ~= STATE_IDLE
end

return RangedInput
