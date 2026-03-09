local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
    return
end

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Создаём поле ввода (тильда ~ для открытия)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DebugConsole"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 100
screenGui.Parent = playerGui

local inputBox = Instance.new("TextBox")
inputBox.Name = "CommandInput"
inputBox.Size = UDim2.new(0.35, 0, 0, 30)
inputBox.Position = UDim2.new(0, 10, 1, -40)
inputBox.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
inputBox.BackgroundTransparency = 0.2
inputBox.TextColor3 = Color3.fromRGB(220, 220, 220)
inputBox.PlaceholderText = "/help"
inputBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
inputBox.Font = Enum.Font.Code
inputBox.TextSize = 14
inputBox.ClearTextOnFocus = false -- не очищать при фокусе
inputBox.Visible = false
inputBox.Parent = screenGui

Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", inputBox).Color = Color3.fromRGB(60, 60, 80)

-- Тильда (~) открывает/закрывает консоль
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end
    if input.KeyCode == Enum.KeyCode.Backquote then
        inputBox.Visible = not inputBox.Visible
        if inputBox.Visible then
            inputBox.Text = ""
            inputBox:CaptureFocus()
        end
    end
end)

-- Enter отправляет команду
inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed and inputBox.Text ~= "" then
        Remotes.DebugCommand:FireServer(inputBox.Text)
        inputBox.Text = ""
    end
    inputBox.Visible = false
end)
