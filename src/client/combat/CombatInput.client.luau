local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local comboIndex = 1
local lastAttackTime = 0
local isAttacking = false
local isHolding = false
local currentTrack = nil

local comboConfig = Config.Weapons.Sword.Combo
local comboWindow = Config.Weapons.Sword.ComboWindow

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

local function playAttackAnimation(animId)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	if currentTrack then
		currentTrack:Stop()
		currentTrack = nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animId

	currentTrack = animator:LoadAnimation(animation)
	currentTrack.Priority = Enum.AnimationPriority.Action
	currentTrack:Play()

	isAttacking = true
	currentTrack.Stopped:Wait()
	isAttacking = false
end

local function performAttack()
	local character = player.Character
	if not character then return end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then return end
	local mousePos = getMouseWorldPosition()
	if not mousePos then return end

	local now = tick()
	local gap = now - lastAttackTime

	if gap > comboWindow then
		comboIndex = 1
	else
		comboIndex = comboIndex % #comboConfig + 1
	end


	lastAttackTime = now

	local combo = comboConfig[comboIndex]
	Remotes.AttackRequest:FireServer(mousePos, comboIndex)
	playAttackAnimation(combo.AnimationId)
end

-- Цикл автоатаки при зажатой ЛКМ
local function attackLoop()
	while isHolding do
		if not isAttacking then
			local character = player.Character
			if not character then break end
			local tool = character:FindFirstChildOfClass("Tool")
			if not tool then break end
			performAttack()
		end
		task.wait(0.05)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if isHolding then return end
        isHolding = true
        task.spawn(attackLoop)
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isHolding = false
	end
end)