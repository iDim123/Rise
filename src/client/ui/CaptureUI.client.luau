local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local isCasting = false
local castStartTime = 0

-- ===== Cast bar =====
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

-- ===== Hotkey T =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.Servants.CaptureKey then
        if isCasting then
            isCasting = false
            castFrame.Visible = false
            Remotes.CaptureRequest:FireServer("cancel")
        else
            Remotes.CaptureRequest:FireServer("start")
        end
    end
end)

-- ===== Server result =====
Remotes.CaptureResult.OnClientEvent:Connect(function(success, message)
    if message == "casting" then
        isCasting = true
        castStartTime = tick()
        castFrame.Visible = true
    elseif message == "captured" then
        isCasting = false
        castFrame.Visible = false
    else
        isCasting = false
        castFrame.Visible = false
    end
end)

-- ===== Cast progress =====
game:GetService("RunService").RenderStepped:Connect(function()
    if not isCasting then return end

    local elapsed = tick() - castStartTime
    local progress = math.clamp(elapsed / Config.Servants.CaptureTime, 0, 1)
    castBar.Size = UDim2.new(progress, 0, 1, 0)
    castText.Text = "Захват... " .. string.format("%.1f", Config.Servants.CaptureTime - elapsed) .. "с"

    if elapsed >= Config.Servants.CaptureTime then
        isCasting = false
        castFrame.Visible = false
    end
end)