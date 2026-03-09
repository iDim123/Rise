local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local MeleeInput = {}

-- ═══════════════════════════════════════════════════════════
-- Состояние
-- ═══════════════════════════════════════════════════════════

local comboIndex = 1
local lastAttackTime = 0
local isAttacking = false
local isHolding = false
local currentTrack = nil

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

local function getWeaponConfig()
    local character = player.Character
    if not character then
        return nil
    end
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then
        return nil
    end
    return Config.Weapons[tool.Name]
end

local function playAttackAnimation(animId)
    local character = player.Character
    if not character then
        return
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        return
    end

    if currentTrack then
        currentTrack:Stop()
        currentTrack = nil
    end

    if not animId or animId == "" or animId == "rbxassetid://0" then
        isAttacking = true
        task.wait(0.3)
        isAttacking = false
        return
    end

    local animation = Instance.new("Animation")
    animation.AnimationId = animId

    currentTrack = animator:LoadAnimation(animation)
    currentTrack.Priority = Enum.AnimationPriority.Action
    currentTrack:Play()

    isAttacking = true
    currentTrack.Stopped:Wait()
    isAttacking = false
end

-- ═══════════════════════════════════════════════════════════
-- Атака
-- ═══════════════════════════════════════════════════════════

local function performAttack()
    local character = player.Character
    if not character then
        return
    end
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then
        return
    end
    local mousePos = getMouseWorldPosition()
    if not mousePos then
        return
    end

    local weaponConfig = getWeaponConfig()
    if not weaponConfig then
        return
    end

    local now = tick()
    local gap = now - lastAttackTime
    local comboWindow = weaponConfig.ComboWindow or 1.2
    local comboConfig = weaponConfig.Combo

    if gap > comboWindow then
        comboIndex = 1
    else
        comboIndex = comboIndex % #comboConfig + 1
    end

    lastAttackTime = now

    local combo = comboConfig[comboIndex]
    Remotes.AttackRequest:FireServer(mousePos, comboIndex)
    playAttackAnimation(combo.AnimationId)
end

local function attackLoop()
    while isHolding do
        if not isAttacking then
            local character = player.Character
            if not character then
                break
            end
            local tool = character:FindFirstChildOfClass("Tool")
            if not tool then
                break
            end
            performAttack()
        end
        task.wait(0.05)
    end
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API
-- ═══════════════════════════════════════════════════════════

function MeleeInput.start()
    if isHolding then
        return
    end
    isHolding = true
    task.spawn(attackLoop)
end

function MeleeInput.stop()
    isHolding = false
end

function MeleeInput.isActive()
    return isHolding
end

return MeleeInput
