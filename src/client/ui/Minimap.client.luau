local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ НАСТРОЙКИ ═══
local MAP_SIZE = 180
local MAP_RADIUS = MAP_SIZE / 2
local DOT_SIZE = 6
local BOSS_DOT_SIZE = 10
local UPDATE_INTERVAL = 0.1
local MARGIN = 16

-- Зум
local mapRange = 120
local MAP_RANGE_MIN = 40
local MAP_RANGE_MAX = 300
local MAP_ZOOM_STEP = 15

-- Замени на свой AssetId после загрузки иконки в Roblox
local PLAYER_ICON = "rbxassetid://100520573334113"
local PLAYER_ICON_SIZE = 18

local CASTLE_DOT_SIZE = 12

local COLORS = {
    Background = Color3.fromRGB(15, 15, 25),
    Border = Color3.fromRGB(80, 80, 100),
    Player = Color3.fromRGB(50, 200, 80),
    Enemy = Color3.fromRGB(200, 50, 50),
    Boss = Color3.fromRGB(200, 50, 220),
    OtherPlayer = Color3.fromRGB(50, 150, 255),
    Resource = Color3.fromRGB(180, 150, 50),
    Cardinal = Color3.fromRGB(180, 180, 190),
    NorthColor = Color3.fromRGB(200, 50, 50),
    ButtonBG = Color3.fromRGB(35, 35, 50),
    ButtonText = Color3.fromRGB(200, 200, 200),
    CastleOwn = Color3.fromRGB(220, 180, 50),     -- свой замок
    CastleOther = Color3.fromRGB(160, 100, 200),   -- чужой замок
}

-- ═══ BUILD UI ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Minimap"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Контейнер всей миникарты
local outerFrame = Instance.new("Frame")
outerFrame.Name = "OuterFrame"
outerFrame.Size = UDim2.new(0, MAP_SIZE + 60, 0, MAP_SIZE + 60)
outerFrame.Position = UDim2.new(1, -MAP_SIZE - 60 - MARGIN, 0, 0)
outerFrame.BackgroundTransparency = 1
outerFrame.BorderSizePixel = 0
outerFrame.Parent = screenGui

-- Круглая карта
local mapFrame = Instance.new("Frame")
mapFrame.Name = "MapFrame"
mapFrame.Size = UDim2.new(0, MAP_SIZE, 0, MAP_SIZE)
mapFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mapFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mapFrame.BackgroundColor3 = COLORS.Background
mapFrame.BackgroundTransparency = 0.2
mapFrame.BorderSizePixel = 0
mapFrame.ClipsDescendants = true
mapFrame.Parent = outerFrame
Instance.new("UICorner", mapFrame).CornerRadius = UDim.new(0.5, 0)

local mapStroke = Instance.new("UIStroke")
mapStroke.Color = COLORS.Border
mapStroke.Thickness = 1.5
mapStroke.Parent = mapFrame

-- ═══ РОМБЫ СТОРОН СВЕТА (на ободке) ═══
local CARDINAL_SIZE = 22
local CARDINAL_OFFSET = MAP_SIZE / 2 + CARDINAL_SIZE / 2 - 10 -- чуть за пределами круга

local function createCardinalDiamond(text, angleDegs, color)
    -- angleDegs: 0=верх(N), 90=право(E), 180=низ(S), 270=лево(W)
    local rad = math.rad(angleDegs - 90)
    local cx = CARDINAL_OFFSET * math.cos(rad)
    local cy = CARDINAL_OFFSET * math.sin(rad)

    local container = Instance.new("Frame")
    container.Name = "Cardinal_" .. text
    container.Size = UDim2.new(0, CARDINAL_SIZE, 0, CARDINAL_SIZE)
    container.Position = UDim2.new(0.5, cx, 0.5, cy)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.BackgroundColor3 = COLORS.Background
    container.BackgroundTransparency = 0.1
    container.BorderSizePixel = 0
    container.Rotation = 45  -- ромб
    container.ZIndex = 15
    container.Parent = outerFrame
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 3)

    local containerStroke = Instance.new("UIStroke")
    containerStroke.Color = COLORS.Border
    containerStroke.Thickness = 1
    containerStroke.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or COLORS.Cardinal
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.Rotation = -45  -- компенсируем поворот контейнера
    label.ZIndex = 16
    label.Parent = container

    return container
end

createCardinalDiamond("N", 0, COLORS.NorthColor)
createCardinalDiamond("E", 90)
createCardinalDiamond("S", 180)
createCardinalDiamond("W", 270)

-- ═══ ИКОНКА ИГРОКА ═══
local playerIcon = Instance.new("ImageLabel")
playerIcon.Name = "PlayerIcon"
playerIcon.Size = UDim2.new(0, PLAYER_ICON_SIZE, 0, PLAYER_ICON_SIZE)
playerIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
playerIcon.AnchorPoint = Vector2.new(0.5, 0.5)
playerIcon.BackgroundTransparency = 1
playerIcon.Image = PLAYER_ICON
playerIcon.ImageColor3 = COLORS.Player
playerIcon.ZIndex = 11
playerIcon.Parent = mapFrame

-- Fallback если иконка не загружена — зелёный ромб
if PLAYER_ICON == "rbxassetid://0" then
    playerIcon.Image = ""
    playerIcon.BackgroundColor3 = COLORS.Player
    playerIcon.BackgroundTransparency = 0
    playerIcon.Rotation = 45
    playerIcon.Size = UDim2.new(0, 10, 0, 10)
    Instance.new("UICorner", playerIcon).CornerRadius = UDim.new(0, 2)
end

-- ═══ КНОПКИ ЗУМА ═══
local function createZoomButton(text, offsetX, offsetY)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 24, 0, 24)
    btn.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.BackgroundColor3 = COLORS.ButtonBG
    btn.BackgroundTransparency = 0.1
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = COLORS.ButtonText
    btn.TextSize = 16
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = true
    btn.ZIndex = 15
    btn.Parent = outerFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = COLORS.Border
    btnStroke.Thickness = 1
    btnStroke.Parent = btn

    return btn
end

-- Кнопки справа-внизу от карты
local btnRadius = MAP_SIZE / 2 + 8
local zoomInBtn = createZoomButton("+", btnRadius - 14, btnRadius - 6)
local zoomOutBtn = createZoomButton("−", btnRadius + 14, btnRadius - 6)

zoomInBtn.MouseButton1Click:Connect(function()
    mapRange = math.clamp(mapRange - MAP_ZOOM_STEP, MAP_RANGE_MIN, MAP_RANGE_MAX)
end)

zoomOutBtn.MouseButton1Click:Connect(function()
    mapRange = math.clamp(mapRange + MAP_ZOOM_STEP, MAP_RANGE_MIN, MAP_RANGE_MAX)
end)

-- Скролл при наведении
local isHovering = false

mapFrame.MouseEnter:Connect(function()
    isHovering = true
end)

mapFrame.MouseLeave:Connect(function()
    isHovering = false
end)

UserInputService.InputChanged:Connect(function(input)
    if not isHovering then return end
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        mapRange = math.clamp(
            mapRange - input.Position.Z * MAP_ZOOM_STEP,
            MAP_RANGE_MIN,
            MAP_RANGE_MAX
        )
    end
end)

-- ═══ DOT POOL ═══
local dotPool = {}
local activeDots = 0

local function getDot()
    activeDots += 1
    if dotPool[activeDots] then
        local dot = dotPool[activeDots]
        dot.Visible = true
        return dot
    end

    local dot = Instance.new("Frame")
    dot.Name = "Dot_" .. activeDots
    dot.BorderSizePixel = 0
    dot.ZIndex = 5
    dot.Parent = mapFrame
    Instance.new("UICorner", dot).CornerRadius = UDim.new(0.5, 0)
    dotPool[activeDots] = dot
    return dot
end

local function resetDots()
    for i = 1, activeDots do
        dotPool[i].Visible = false
    end
    activeDots = 0
end

-- ═══ WORLD → MINIMAP ═══
local function worldToMinimap(playerPos, targetPos)
    local offset = targetPos - playerPos
    local relX = offset.X
    local relZ = offset.Z
    local dist2D = math.sqrt(relX * relX + relZ * relZ)

    if dist2D > mapRange then
        return nil, nil
    end

    local pixelX = MAP_RADIUS + (relX / mapRange) * MAP_RADIUS
    local pixelY = MAP_RADIUS + (relZ / mapRange) * MAP_RADIUS

    local dx = pixelX - MAP_RADIUS
    local dy = pixelY - MAP_RADIUS
    if dx * dx + dy * dy > MAP_RADIUS * MAP_RADIUS then
        return nil, nil
    end

    return pixelX, pixelY
end

local function placeDot(worldPos, playerPos, color, size)
    local px, py = worldToMinimap(playerPos, worldPos)
    if not px then return end

    local dot = getDot()
    dot.Size = UDim2.new(0, size, 0, size)
    dot.Position = UDim2.new(0, px - size / 2, 0, py - size / 2)
    dot.BackgroundColor3 = color
end

-- ═══ UPDATE ═══
local lastUpdate = 0

local function update()
    local now = tick()
    if now - lastUpdate < UPDATE_INTERVAL then return end
    lastUpdate = now

    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local playerPos = rootPart.Position

    resetDots()

    -- Вращение иконки игрока
    local look = rootPart.CFrame.LookVector
    local angle = math.atan2(look.X, -look.Z)
    playerIcon.Rotation = math.deg(angle) + (PLAYER_ICON == "rbxassetid://0" and 45 or 0)

    -- Враги
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, enemy in enemiesFolder:GetChildren() do
            local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
            local enemyHum = enemy:FindFirstChild("Humanoid")
            if not enemyRoot or not enemyHum or enemyHum.Health <= 0 then continue end

            local isBoss = enemy:GetAttribute("IsBoss")
            if isBoss then
                placeDot(enemyRoot.Position, playerPos, COLORS.Boss, BOSS_DOT_SIZE)
            else
                placeDot(enemyRoot.Position, playerPos, COLORS.Enemy, DOT_SIZE)
            end
        end
    end

    -- Замки
    local castlesFolder = workspace:FindFirstChild("Castles")
    if castlesFolder then
        for _, folder in castlesFolder:GetChildren() do
            -- Ищем Castle Heart (Model с IsCastleHeart)
            for _, obj in folder:GetChildren() do
                if obj:IsA("Model") and obj:GetAttribute("IsCastleHeart") then
                    local primary = obj.PrimaryPart
                    if primary then
                        -- Определяем владельца по имени папки: "Castle_<userId>"
                        local isOwn = folder.Name == "Castle_" .. tostring(player.UserId)
                        local color = isOwn and COLORS.CastleOwn or COLORS.CastleOther
                        placeDot(primary.Position, playerPos, color, CASTLE_DOT_SIZE)
                    end
                end
            end
        end
    end


    -- Другие игроки
    for _, otherPlayer in Players:GetPlayers() do
        if otherPlayer == player then continue end
        local otherChar = otherPlayer.Character
        if not otherChar then continue end
        if otherChar:GetAttribute("IsDead") then continue end
        local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
        if not otherRoot then continue end

        placeDot(otherRoot.Position, playerPos, COLORS.OtherPlayer, DOT_SIZE)
    end

    -- Ресурсы
    local resourceFolder = workspace:FindFirstChild("Resources")
    if resourceFolder then
        for _, node in resourceFolder:GetChildren() do
            local nodePart = node:IsA("BasePart") and node or node:FindFirstChildOfClass("BasePart")
            if not nodePart then continue end

            placeDot(nodePart.Position, playerPos, COLORS.Resource, DOT_SIZE - 2)
        end
    end
end

RunService.Heartbeat:Connect(update)