local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ===== НАСТРОЙКИ КАМЕРЫ =====
local CAMERA_ANGLE = 45
local CAMERA_DISTANCE = 50
local CAMERA_ROTATION = -45
local SMOOTHNESS = 0.15

local MIN_DISTANCE = 20
local MAX_DISTANCE = 80
local ZOOM_STEP = 5

-- Смещение точки фокуса вниз (к ногам)
local FOCUS_OFFSET = Vector3.new(0, -3, 0)
-- =============================

local currentPosition = Vector3.zero

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		CAMERA_DISTANCE = math.clamp(
			CAMERA_DISTANCE - input.Position.Z * ZOOM_STEP,
			MIN_DISTANCE,
			MAX_DISTANCE
		)
	end
end)

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	camera.CameraType = Enum.CameraType.Scriptable

	-- Точка фокуса = позиция персонажа + смещение вниз к ногам
	local targetPos = rootPart.Position + FOCUS_OFFSET

	currentPosition = currentPosition:Lerp(targetPos, SMOOTHNESS)

	local angleRad = math.rad(CAMERA_ANGLE)
	local rotationRad = math.rad(CAMERA_ROTATION)

	local offset = Vector3.new(
		math.sin(rotationRad) * math.cos(angleRad) * CAMERA_DISTANCE,
		math.sin(angleRad) * CAMERA_DISTANCE,
		math.cos(rotationRad) * math.cos(angleRad) * CAMERA_DISTANCE
	)

	local cameraPos = currentPosition + offset

	camera.CFrame = CFrame.lookAt(cameraPos, currentPosition)
end)
