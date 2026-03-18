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

-- ── Debug: Fly mode (L) ──
local flying = false
local flySpeed = 80
local bodyVelocity = nil
local bodyGyro = nil
local savedCollision: {[BasePart]: boolean} = {} -- исходные CanCollide
local collisionConn = nil -- RenderStepped connection для принудительного noclip

local function startFly()
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	flying = true
	humanoid.PlatformStand = true

	-- Отключить коллизию всех частей персонажа
	savedCollision = {}
	for _, part in char:GetDescendants() do
		if part:IsA("BasePart") then
			savedCollision[part] = part.CanCollide
			part.CanCollide = false
		end
	end

	-- Roblox сбрасывает CanCollide каждый кадр для Humanoid-частей,
	-- поэтому принудительно выключаем каждый RenderStepped
	collisionConn = RunService.Stepped:Connect(function()
		if not flying then return end
		local c = player.Character
		if not c then return end
		for _, part in c:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end)

	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.Parent = hrp

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.D = 200
	bodyGyro.P = 10000
	bodyGyro.CFrame = hrp.CFrame
	bodyGyro.Parent = hrp

	print("[Debug] Fly ON")
end

local function stopFly()
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")

	flying = false

	-- Отключить принудительный noclip
	if collisionConn then
		collisionConn:Disconnect()
		collisionConn = nil
	end

	-- Восстановить CanCollide
	for part, wasCollide in savedCollision do
		if part and part.Parent then
			part.CanCollide = wasCollide
		end
	end
	savedCollision = {}

	if humanoid then
		humanoid.PlatformStand = false
	end
	if bodyVelocity then
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end
	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end

	print("[Debug] Fly OFF")
end

-- L — toggle fly
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.L then
		if flying then
			stopFly()
		else
			startFly()
		end
	end
end)

-- Обновление направления полёта каждый кадр
RunService.RenderStepped:Connect(function()
	if not flying or not bodyVelocity or not bodyGyro then return end

	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local camera = workspace.CurrentCamera
	local moveDir = Vector3.zero

	-- WASD относительно камеры
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveDir = moveDir + camera.CFrame.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveDir = moveDir - camera.CFrame.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveDir = moveDir - camera.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveDir = moveDir + camera.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		moveDir = moveDir + Vector3.new(0, 1, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		moveDir = moveDir - Vector3.new(0, 1, 0)
	end

	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit * flySpeed
	end

	bodyVelocity.Velocity = moveDir
	bodyGyro.CFrame = camera.CFrame
end)

-- Сброс fly при смерти персонажа
player.CharacterAdded:Connect(function()
	if flying then
		flying = false
		bodyVelocity = nil
		bodyGyro = nil
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        if input.KeyCode == Enum.KeyCode.One then
            Remotes.DebugCommand:FireServer("/spellpoint Blood 1")
        elseif input.KeyCode == Enum.KeyCode.Two then
            Remotes.DebugCommand:FireServer("/spellpoint Chaos 1")
        elseif input.KeyCode == Enum.KeyCode.Three then
            Remotes.DebugCommand:FireServer("/spellpoint Chaos 1 2")
            Remotes.DebugCommand:FireServer("/spellpoint Blood 1 2")
            Remotes.DebugCommand:FireServer("/spellpoint Chaos 2 2")
            Remotes.DebugCommand:FireServer("/spellpoint Blood 2 2")
            Remotes.DebugCommand:FireServer("/spellpoint Chaos 3 2")
            Remotes.DebugCommand:FireServer("/spellpoint Blood 3 2")
            Remotes.DebugCommand:FireServer("/spellpoint Blood ULT 1")
            Remotes.DebugCommand:FireServer("/spellpoint Chaos ULT 1")
        elseif input.KeyCode == Enum.KeyCode.Four then
            Remotes.DebugCommand:FireServer("/savecastle")
        elseif input.KeyCode == Enum.KeyCode.Five then
            Remotes.DebugCommand:FireServer("/wipecastle")
        end
    end
end)
