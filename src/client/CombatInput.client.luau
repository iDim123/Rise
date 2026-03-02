local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

-- Анимация атаки (стандартный слэш)
local SLASH_ANIM_ID = "rbxassetid://70662356098178"

local isAttacking = false

local function getMouseWorldPosition()
	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local rayOrigin = mouseRay.Origin
	local rayDirection = mouseRay.Direction

	local character = player.Character
	if not character then return nil end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	local groundY = rootPart.Position.Y - 3

	if math.abs(rayDirection.Y) < 0.001 then return nil end

	local t = (groundY - rayOrigin.Y) / rayDirection.Y
	if t < 0 then return nil end

	return rayOrigin + rayDirection * t
end

local function playAttackAnimation()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animation = Instance.new("Animation")
	animation.AnimationId = SLASH_ANIM_ID

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track:Play()

	-- Блокируем повторную атаку до конца анимации
	isAttacking = true
	track.Stopped:Wait()
	isAttacking = false
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Убираем проверку gameProcessed для атаки мечом
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isAttacking then return end

		local character = player.Character
		if not character then return end

		local tool = character:FindFirstChildOfClass("Tool")
		if not tool then return end

		local mousePos = getMouseWorldPosition()
		if not mousePos then return end

		print("[Client] AttackRequest sent!")

		Remotes.AttackRequest:FireServer(mousePos)

		task.spawn(playAttackAnimation)
	end
end)