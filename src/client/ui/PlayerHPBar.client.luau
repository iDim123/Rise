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

-- ===== HP бар слуги =====
local servantFrame = Instance.new("Frame")
servantFrame.Size = UDim2.new(0, 150, 0, 16)
servantFrame.Position = UDim2.new(0.5, 105, 0, 10) -- справа от HP игрока
servantFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
servantFrame.BorderSizePixel = 0
servantFrame.Visible = false
servantFrame.Parent = screenGui

local servantFrameCorner = Instance.new("UICorner")
servantFrameCorner.CornerRadius = UDim.new(0, 4)
servantFrameCorner.Parent = servantFrame

local servantBar = Instance.new("Frame")
servantBar.Name = "ServantBar"
servantBar.Size = UDim2.new(1, 0, 1, 0)
servantBar.BackgroundColor3 = Color3.fromRGB(80, 50, 180)
servantBar.BorderSizePixel = 0
servantBar.Parent = servantFrame

local servantBarCorner = Instance.new("UICorner")
servantBarCorner.CornerRadius = UDim.new(0, 4)
servantBarCorner.Parent = servantBar

local servantText = Instance.new("TextLabel")
servantText.Size = UDim2.new(1, 0, 1, 0)
servantText.BackgroundTransparency = 1
servantText.TextColor3 = Color3.fromRGB(255, 255, 255)
servantText.TextSize = 10
servantText.Font = Enum.Font.GothamBold
servantText.Text = ""
servantText.Parent = servantFrame

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

	  -- Обновляем HP слуги
    local servantsFolder = workspace:FindFirstChild("Servants")
    if servantsFolder then
        local foundServant = false
        for _, servant in servantsFolder:GetChildren() do
            if servant:GetAttribute("OwnerUserId") == player.UserId then
                local sHP = servant:GetAttribute("CurrentHP")
                local sMaxHP = servant:GetAttribute("MaxHP")
                if sHP and sMaxHP and sMaxHP > 0 then
                    local sRatio = sHP / sMaxHP
                    servantBar.Size = UDim2.new(sRatio, 0, 1, 0)
                    servantText.Text = servant.Name .. " " .. sHP .. "/" .. sMaxHP
                    servantFrame.Visible = true
                    foundServant = true
                end
                break
            end
        end
        if not foundServant then
            servantFrame.Visible = false
        end
    else
        servantFrame.Visible = false
    end
end)


