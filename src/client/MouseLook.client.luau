local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

-- ===== НАСТРОЙКИ =====
local ROTATION_SMOOTHNESS = 0.25   -- плавность поворота (0.01 = медленно, 1 = мгновенно)
-- =====================

-- Отключаем стандартный автоповорот персонажа
player.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.AutoRotate = false
end)

-- Если персонаж уже загружен
if player.Character then
	local humanoid = player.Character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.AutoRotate = false
	end
end

-- Получаем позицию мыши на плоскости земли (Y = уровень ног)
local function getMouseWorldPosition()
	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local rayOrigin = mouseRay.Origin
	local rayDirection = mouseRay.Direction

	-- Находим пересечение луча с горизонтальной плоскостью на уровне персонажа
	local character = player.Character
	if not character then return nil end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	local groundY = rootPart.Position.Y - 3 -- уровень ног

	-- Луч: P = Origin + t * Direction
	-- Ищем t, при котором P.Y = groundY
	if math.abs(rayDirection.Y) < 0.001 then return nil end

	local t = (groundY - rayOrigin.Y) / rayDirection.Y
	if t < 0 then return nil end

	local hitPoint = rayOrigin + rayDirection * t
	return hitPoint
end

-- Главный цикл поворота
RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local mousePos = getMouseWorldPosition()
	if not mousePos then return end

	-- Направление от персонажа к курсору (только по XZ, без Y)
	local direction = Vector3.new(
		mousePos.X - rootPart.Position.X,
		0,
		mousePos.Z - rootPart.Position.Z
	)

	if direction.Magnitude < 0.1 then return end

	-- Целевой поворот
	local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)

	-- Плавный поворот через Lerp
	local currentCFrame = rootPart.CFrame
	local smoothed = currentCFrame:Lerp(
		CFrame.new(currentCFrame.Position) * targetCFrame.Rotation,
		ROTATION_SMOOTHNESS
	)

	rootPart.CFrame = smoothed
end)