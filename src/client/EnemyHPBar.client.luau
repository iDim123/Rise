local RunService = game:GetService("RunService")

local function createHPBar(enemy)
	-- Проверяем что ещё нет полоски
	local head = enemy:FindFirstChild("Head")
	if not head then return end
	if head:FindFirstChild("EnemyHPGui") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EnemyHPGui"
	billboard.Size = UDim2.new(4, 0, 0.5, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	-- Фон
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = bg

	-- Полоска HP
	local hpBar = Instance.new("Frame")
	hpBar.Name = "HPBar"
	hpBar.Size = UDim2.new(1, 0, 1, 0)
	hpBar.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	hpBar.BorderSizePixel = 0
	hpBar.Parent = bg

	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 4)
	hpCorner.Parent = hpBar

	-- Имя врага
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = enemy.Name
	nameLabel.Parent = bg
end

-- Обновление полосок
RunService.RenderStepped:Connect(function()
	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if not enemiesFolder then return end

	for _, enemy in enemiesFolder:GetChildren() do
		-- Создаём полоску если ещё нет
		createHPBar(enemy)

		-- Обновляем
		local head = enemy:FindFirstChild("Head")
		if not head then continue end

		local billboard = head:FindFirstChild("EnemyHPGui")
		if not billboard then continue end

		local currentHP = enemy:GetAttribute("CurrentHP")
		local maxHP = enemy:GetAttribute("MaxHP")
		if not currentHP or not maxHP then continue end

		local bg = billboard:FindFirstChild("Background")
		if not bg then continue end

		local hpBar = bg:FindFirstChild("HPBar")
		if not hpBar then continue end

		local ratio = currentHP / maxHP
		hpBar.Size = UDim2.new(ratio, 0, 1, 0)
	end
end)