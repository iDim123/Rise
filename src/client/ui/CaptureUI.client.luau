local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local isCasting = false
local castStartTime = 0

-- ===== Прогресс-бар каста =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CaptureHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local castFrame = Instance.new("Frame")
castFrame.Size = UDim2.new(0, 250, 0, 25)
castFrame.Position = UDim2.new(0.5, -125, 0.6, 0)
castFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
castFrame.BorderSizePixel = 0
castFrame.Visible = false
castFrame.Parent = screenGui

local castCorner = Instance.new("UICorner")
castCorner.CornerRadius = UDim.new(0, 4)
castCorner.Parent = castFrame

local castBar = Instance.new("Frame")
castBar.Name = "CastBar"
castBar.Size = UDim2.new(0, 0, 1, 0)
castBar.BackgroundColor3 = Color3.fromRGB(180, 50, 220)
castBar.BorderSizePixel = 0
castBar.Parent = castFrame

local castBarCorner = Instance.new("UICorner")
castBarCorner.CornerRadius = UDim.new(0, 4)
castBarCorner.Parent = castBar

local castText = Instance.new("TextLabel")
castText.Size = UDim2.new(1, 0, 1, 0)
castText.BackgroundTransparency = 1
castText.TextColor3 = Color3.fromRGB(255, 255, 255)
castText.TextSize = 13
castText.Font = Enum.Font.GothamBold
castText.Text = "Захват..."
castText.Parent = castFrame

-- ===== Надпись над врагами =====
local captureLabels = {}

local function createCaptureLabel(enemy)
    if captureLabels[enemy] then return end
    local head = enemy:FindFirstChild("Head")
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CaptureLabel"
    billboard.Size = UDim2.new(0, 150, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 5.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = head
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(180, 50, 220)
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.Text = "Захватить [T]"
    label.Parent = billboard

    captureLabels[enemy] = billboard
end

local function removeCaptureLabel(enemy)
    if captureLabels[enemy] then
        captureLabels[enemy]:Destroy()
        captureLabels[enemy] = nil
    end
end

-- ===== Горячая клавиша T =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.Servants.CaptureKey then
        if isCasting then
            -- Отмена каста
            isCasting = false
            castFrame.Visible = false
            Remotes.CaptureRequest:FireServer("cancel")
        else
            -- Начало каста
            Remotes.CaptureRequest:FireServer("start")
        end
    end
end)

-- ===== Результат от сервера =====
Remotes.CaptureResult.OnClientEvent:Connect(function(success, message)
    if message == "casting" then
        isCasting = true
        castStartTime = tick()
        castFrame.Visible = true
    elseif message == "captured" then
        isCasting = false
        castFrame.Visible = false
        -- Можно добавить эффект/звук
    else
        isCasting = false
        castFrame.Visible = false
    end
end)

-- ===== Обновление каждый кадр =====
RunService.RenderStepped:Connect(function()
    -- Обновление прогресс-бара каста
    if isCasting then
        local elapsed = tick() - castStartTime
        local progress = math.clamp(elapsed / Config.Servants.CaptureTime, 0, 1)
        castBar.Size = UDim2.new(progress, 0, 1, 0)
        castText.Text = "Захват... " .. string.format("%.1f", Config.Servants.CaptureTime - elapsed) .. "с"

        if elapsed >= Config.Servants.CaptureTime then
            isCasting = false
            castFrame.Visible = false
        end
    end

    -- Обновляем надписи "Захватить [T]" над врагами
    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return end

    for _, enemy in enemiesFolder:GetChildren() do
        local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
        if not enemyRoot then
            removeCaptureLabel(enemy)
            continue
        end

        -- Нельзя захватить — не показываем
        if enemy:GetAttribute("CanCapture") == false then
            removeCaptureLabel(enemy)
            continue
        end

        local currentHP = enemy:GetAttribute("CurrentHP")
        local maxHP = enemy:GetAttribute("MaxHP")

        if currentHP and maxHP and maxHP > 0 then
            local hpRatio = currentHP / maxHP
            local distance = (enemyRoot.Position - rootPart.Position).Magnitude

            if hpRatio <= Config.Servants.CaptureThreshold and distance <= Config.Servants.CaptureRange then
                createCaptureLabel(enemy)
            else
                removeCaptureLabel(enemy)
            end
        else
            removeCaptureLabel(enemy)
        end
    end
end)