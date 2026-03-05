local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelColor = require(ReplicatedStorage:WaitForChild("LevelColorUtil"))
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local HOVER_LINGER = 3  -- seconds to keep billboard after losing hover

-- State: [enemy] = { lastHoverTime: number, hovered: boolean }
local enemyState = {}

local function updateHPBar(enemy)
    local head = enemy:FindFirstChild("Head")
    if not head then return end

    local billboard = head:FindFirstChild("EnemyHPGui")
    if not billboard then return end

    local currentHP = enemy:GetAttribute("CurrentHP")
    local maxHP = enemy:GetAttribute("MaxHP")
    if not currentHP or not maxHP or maxHP == 0 then return end

    local damaged = (currentHP < maxHP)
    local state = enemyState[enemy]
    local hovered = state and state.hovered
    local lingering = state and (tick() - (state.lastHoverTime or 0) < HOVER_LINGER)

    -- Show if: damaged OR currently hovered OR still lingering
    billboard.Enabled = damaged or hovered or lingering

    local bg = billboard:FindFirstChild("Background")
    if not bg then return end

    local hpBar = bg:FindFirstChild("HPBar")
    if hpBar then
        hpBar.Size = UDim2.new(currentHP / maxHP, 0, 1, 0)
        local levelLabel = billboard:FindFirstChild("LevelLabel")
        if levelLabel then
            local level = enemy:GetAttribute("Level")
            local playerLevel = 1
            local character = player.Character
            if character then
                playerLevel = character:GetAttribute("Level") or 1
            end

            if level then
                local color = LevelColor.getColor(level, playerLevel)
                levelLabel.TextColor3 = color
                if LevelColor.isSkull(level, playerLevel) then
                    levelLabel.Text = LevelColor.SkullText
                else
                    levelLabel.Text = tostring(level)
                end
            else
                levelLabel.Text = "?"
                levelLabel.TextColor3 = LevelColor.Colors.White
            end
        end
    end

end

local function createHPBar(enemy)
    local head = enemy:FindFirstChild("Head")
    local humanoid = enemy:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
    if not head then
        head = enemy:WaitForChild("Head", 5)
    end
    if not head then return end
    if head:FindFirstChild("EnemyHPGui") then return end

  -- Billboard wider to fit level + bar
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EnemyHPGui"
    billboard.Size = UDim2.new(5, 0, 0.8, 0)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = false
    billboard.Parent = head

    -- Level label (left side, 20% width)
    local levelLabel = Instance.new("TextLabel")
    levelLabel.Name = "LevelLabel"
    levelLabel.Size = UDim2.new(0.15, 0, 1, 0)
    levelLabel.Position = UDim2.new(0, 0, 0, 0)
    levelLabel.BackgroundTransparency = 1
    levelLabel.Font = Enum.Font.GothamBold
    levelLabel.TextSize = 14
    levelLabel.TextColor3 = Color3.fromRGB(80, 220, 240)
    levelLabel.TextStrokeTransparency = 0.5
    levelLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    levelLabel.Text = ""
    levelLabel.Parent = billboard
   
    -- HP bar background (right of level)
    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.new(0.83, 0, 0.45, 0)
    bg.Position = UDim2.new(0.19, 0, 0.275, 0)
    bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    bg.BorderSizePixel = 0
    bg.Parent = billboard

    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)

    local hpBar = Instance.new("Frame")
    hpBar.Name = "HPBar"
    hpBar.Size = UDim2.new(1, 0, 1, 0)
    hpBar.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
    hpBar.BorderSizePixel = 0
    hpBar.Parent = bg
   
    Instance.new("UICorner", hpBar).CornerRadius = UDim.new(0, 4)

    enemyState[enemy] = { lastHoverTime = 0, hovered = false }

    enemy:GetAttributeChangedSignal("CurrentHP"):Connect(function()
        updateHPBar(enemy)
    end)

    updateHPBar(enemy)
end

-- ═══ Hover detection + update loop ═══
local function getModelFromPart(part)
    if not part then return nil end
    local current = part
    while current and current ~= workspace do
        if current:IsA("Model") and current:GetAttribute("CurrentHP") then
            return current
        end
        current = current.Parent
    end
    return nil
end

RunService.RenderStepped:Connect(function()
    -- Determine which enemy is hovered
    local hoveredEnemy = nil
    local target = mouse.Target
    if target then
        local model = getModelFromPart(target)
        local enemiesFolder = workspace:FindFirstChild("Enemies")
        if model and enemiesFolder and model:IsDescendantOf(enemiesFolder) then
            hoveredEnemy = model
        end
    end

    -- Update hover states
    for enemy, state in enemyState do
        if enemy.Parent then
            local wasHovered = state.hovered
            state.hovered = (enemy == hoveredEnemy)

            if state.hovered then
                state.lastHoverTime = tick()
            end

            -- Update billboard if hover state changed or lingering expired
            if state.hovered ~= wasHovered or (not state.hovered and tick() - state.lastHoverTime < HOVER_LINGER + 0.5) then
                updateHPBar(enemy)
            end
        else
            enemyState[enemy] = nil
        end
    end
end)

-- ═══ Watch enemies folder ═══
local function watchEnemiesFolder(folder)
    for _, enemy in folder:GetChildren() do
        task.spawn(createHPBar, enemy)
    end
    folder.ChildAdded:Connect(function(enemy)
        task.spawn(createHPBar, enemy)
    end)
    folder.ChildRemoved:Connect(function(enemy)
        enemyState[enemy] = nil
    end)
end

local enemiesFolder = workspace:WaitForChild("Enemies", 30)
if enemiesFolder then
    watchEnemiesFolder(enemiesFolder)
end