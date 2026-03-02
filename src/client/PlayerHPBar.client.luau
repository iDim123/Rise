local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- === Создание UI ===

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Контейнер
local frame = Instance.new("Frame")
frame.Name = "HPBarFrame"
frame.Size = UDim2.new(0, 300, 0, 30)
frame.Position = UDim2.new(0.5, -150, 0, 30)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 6)
frameCorner.Parent = frame

-- Полоска HP
local hpBar = Instance.new("Frame")
hpBar.Name = "HPBar"
hpBar.Size = UDim2.new(1, 0, 1, 0)
hpBar.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
hpBar.BorderSizePixel = 0
hpBar.Parent = frame

local hpBarCorner = Instance.new("UICorner")
hpBarCorner.CornerRadius = UDim.new(0, 6)
hpBarCorner.Parent = hpBar

-- Текст HP
local hpText = Instance.new("TextLabel")
hpText.Name = "HPText"
hpText.Size = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
hpText.TextSize = 16
hpText.Font = Enum.Font.GothamBold
hpText.Text = "100 / 100"
hpText.ZIndex = 2
hpText.Parent = frame

-- === Обновление ===

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end

	local currentHP = character:GetAttribute("CurrentHP")
	local maxHP = character:GetAttribute("MaxHP")

	if not currentHP or not maxHP then return end

	local ratio = currentHP / maxHP
	hpBar.Size = UDim2.new(ratio, 0, 1, 0)
	hpText.Text = currentHP .. " / " .. maxHP

	-- Цвет: зелёный → жёлтый → красный
	if ratio > 0.5 then
		hpBar.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	elseif ratio > 0.25 then
		hpBar.BackgroundColor3 = Color3.fromRGB(220, 180, 30)
	else
		hpBar.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	end
end)