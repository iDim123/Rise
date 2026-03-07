local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ Build UI ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeathScreen"
screenGui.ResetOnSpawn = true
screenGui.DisplayOrder = 100
screenGui.Enabled = false
screenGui.Parent = playerGui

-- Container (centered)
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 320, 0, 180)
container.Position = UDim2.new(0.5, -160, 0.5, -90)
container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
container.BackgroundTransparency = 0.1
container.BorderSizePixel = 0
container.Parent = screenGui
Instance.new("UICorner", container).CornerRadius = UDim.new(0, 12)

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.Position = UDim2.new(0, 0, 0, 16)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Вы погибли"
titleLabel.TextColor3 = Color3.fromRGB(200, 50, 50)
titleLabel.TextSize = 28
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = container

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.Size = UDim2.new(1, 0, 0, 24)
timerLabel.Position = UDim2.new(0, 0, 0, 58)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = ""
timerLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
timerLabel.TextSize = 16
timerLabel.Font = Enum.Font.Gotham
timerLabel.Parent = container

local respawnBtn = Instance.new("TextButton")
respawnBtn.Name = "RespawnButton"
respawnBtn.Size = UDim2.new(0, 200, 0, 44)
respawnBtn.Position = UDim2.new(0.5, -100, 1, -60)
respawnBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
respawnBtn.BorderSizePixel = 0
respawnBtn.Text = "Возродиться"
respawnBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
respawnBtn.TextSize = 20
respawnBtn.Font = Enum.Font.GothamBold
respawnBtn.AutoButtonColor = true
respawnBtn.Parent = container
Instance.new("UICorner", respawnBtn).CornerRadius = UDim.new(0, 8)

-- ═══ Logic ═══
local isDead = false
local timerThread = nil

local function hide()
    isDead = false
    screenGui.Enabled = false
    timerThread = nil
end

local function requestRespawn()
    if not isDead then return end
    isDead = false
    Remotes.PlayerRespawn:FireServer()
    hide()
end

local function show(respawnTime)
    if isDead then return end
    isDead = true
    screenGui.Enabled = true

    local remaining = respawnTime
    timerLabel.Text = "Авто-возрождение через " .. remaining .. " сек"

    timerThread = task.spawn(function()
        while remaining > 0 and isDead do
            task.wait(1)
            remaining -= 1
            if isDead then
                timerLabel.Text = "Авто-возрождение через " .. remaining .. " сек"
            end
        end
        if isDead then
            requestRespawn()
        end
    end)
end

respawnBtn.MouseButton1Click:Connect(requestRespawn)

Remotes.PlayerDied.OnClientEvent:Connect(function(respawnTime)
    show(respawnTime or 10)
end)

player.CharacterAdded:Connect(function()
    hide()
end)
-- Button click
respawnBtn.MouseButton1Click:Connect(requestRespawn)

-- Listen for death event from server
Remotes.PlayerDied.OnClientEvent:Connect(function(respawnTime)
    show(respawnTime or 10)
end)

-- Reset when character respawns (ResetOnSpawn handles destroying old ScreenGui,
-- but we also reset state if the character loads before UI is cleaned up)
player.CharacterAdded:Connect(function()
    hide()
end)