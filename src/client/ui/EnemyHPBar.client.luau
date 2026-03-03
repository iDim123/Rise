local RunService = game:GetService("RunService")

local function createHPBar(enemy)
    local head = enemy:FindFirstChild("Head")
    if not head then return end
    if head:FindFirstChild("EnemyHPGui") then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EnemyHPGui"
    billboard.Size = UDim2.new(4, 0, 0.5, 0)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = head

    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    bg.BorderSizePixel = 0
    bg.Parent = billboard

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 4)
    bgCorner.Parent = bg

    local hpBar = Instance.new("Frame")
    hpBar.Name = "HPBar"
    hpBar.Size = UDim2.new(1, 0, 1, 0)
    hpBar.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
    hpBar.BorderSizePixel = 0
    hpBar.Parent = bg

    local hpCorner = Instance.new("UICorner")
    hpCorner.CornerRadius = UDim.new(0, 4)
    hpCorner.Parent = hpBar

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

local function updateHPBar(enemy)
    local head = enemy:FindFirstChild("Head")
    if not head then return end

    local billboard = head:FindFirstChild("EnemyHPGui")
    if not billboard then return end

    local currentHP = enemy:GetAttribute("CurrentHP")
    local maxHP = enemy:GetAttribute("MaxHP")
    if not currentHP or not maxHP or maxHP == 0 then return end

    local bg = billboard:FindFirstChild("Background")
    if not bg then return end

    local hpBar = bg:FindFirstChild("HPBar")
    if hpBar then
        hpBar.Size = UDim2.new(currentHP / maxHP, 0, 1, 0)
    end

    local nameLabel = bg:FindFirstChild("NameLabel")
    if nameLabel then
        local bloodQuality = enemy:GetAttribute("BloodQuality") or 0
        nameLabel.Text = bloodQuality .. "% " .. enemy.Name
    end
end

-- Подписка на появление врагов — создаём HP-бар один раз
local function watchEnemiesFolder(folder)
    for _, enemy in folder:GetChildren() do
        createHPBar(enemy)
    end
    folder.ChildAdded:Connect(function(enemy)
        task.wait() -- дождаться атрибутов
        createHPBar(enemy)
    end)
end

-- Ждём папку Enemies
local enemiesFolder = workspace:WaitForChild("Enemies", 10)
if enemiesFolder then
    watchEnemiesFolder(enemiesFolder)
end

-- Обновление — только значения, без создания
RunService.RenderStepped:Connect(function()
    if not enemiesFolder then return end
    for _, enemy in enemiesFolder:GetChildren() do
        updateHPBar(enemy)
    end
end)