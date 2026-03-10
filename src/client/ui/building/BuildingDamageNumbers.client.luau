--[[
    BuildingDamageNumbers.client.luau
    Floating damage numbers над структурами.
    Слушает StructureDamageEvent от сервера.
    
    Паттерн: аналогично ResourceNumbers.client.luau
]] local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local BC = require(script.Parent:WaitForChild("BuildingConstants"))

local player = Players.LocalPlayer

local MAX_DISTANCE = 80

local function showDamageNumber(entity, currentHP, maxHP, damage)
    -- Проверка: entity существует и является Part
    if not entity or not entity:IsA("BasePart") or not entity.Parent then
        return
    end

    -- Не показываем если далеко
    local character = player.Character
    if not character then
        return
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end

    local dist = (hrp.Position - entity.Position).Magnitude
    if dist > MAX_DISTANCE then
        return
    end

    -- Создаём BillboardGui на entity
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "StructureDmg"
    billboard.Size = UDim2.new(0, 120, 0, 36)
    billboard.StudsOffset = Vector3.new(math.random(-10, 10) / 10, entity.Size.Y / 2 + 1, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = MAX_DISTANCE
    billboard.Adornee = entity
    billboard.Parent = entity

    -- Текст урона
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = BC.DAMAGE_TEXT_SIZE
    label.TextColor3 = BC.DAMAGE_COLOR
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.3
    label.Text = "-" .. math.floor(damage)
    label.Parent = billboard

    -- Анимация: всплытие вверх
    local floatTween = TweenService:Create(billboard, TweenInfo.new(BC.DAMAGE_LIFETIME, Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out), {
        StudsOffset = billboard.StudsOffset + Vector3.new(0, BC.DAMAGE_FLOAT_HEIGHT, 0)
    })
    floatTween:Play()

    -- Затухание
    task.delay(BC.DAMAGE_LIFETIME * 0.6, function()
        if not label.Parent then
            return
        end
        local fadeTween = TweenService:Create(label, TweenInfo.new(BC.DAMAGE_LIFETIME * 0.4, Enum.EasingStyle.Quad), {
            TextTransparency = 1,
            TextStrokeTransparency = 1
        })
        fadeTween:Play()
    end)

    -- Уничтожение
    task.delay(BC.DAMAGE_LIFETIME, function()
        if billboard and billboard.Parent then
            billboard:Destroy()
        end
    end)
end

-- ═══ HP Bar для структур (BillboardGui, показывается при повреждении) ═══

local structureHPBars = {} -- [entity] = { billboard, hpBar, hideThread }
local HP_BAR_SHOW_TIME = 4

local function getOrCreateHPBar(entity)
    if structureHPBars[entity] then
        return structureHPBars[entity]
    end

    if not entity or not entity.Parent then
        return nil
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "StructureHPBar"
    billboard.Size = UDim2.new(0, 80, 0, 10)
    billboard.StudsOffset = Vector3.new(0, entity.Size.Y / 2 + 0.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = MAX_DISTANCE
    billboard.Adornee = entity
    billboard.Enabled = false
    billboard.Parent = entity

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    bg.BorderSizePixel = 0
    bg.Parent = billboard
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 3)

    local hpBar = Instance.new("Frame")
    hpBar.Name = "HPFill"
    hpBar.Size = UDim2.new(1, 0, 1, 0)
    hpBar.BackgroundColor3 = BC.hpBarGreen
    hpBar.BorderSizePixel = 0
    hpBar.Parent = bg
    Instance.new("UICorner", hpBar).CornerRadius = UDim.new(0, 3)

    local data = {
        billboard = billboard,
        hpBar = hpBar,
        hideThread = nil
    }
    structureHPBars[entity] = data
    return data
end

local function updateStructureHP(entity, currentHP, maxHP)
    if not entity or not entity.Parent then
        return
    end
    if maxHP <= 0 then
        return
    end

    local ratio = currentHP / maxHP
    if ratio >= 1 then
        -- Полное HP — скрываем
        local data = structureHPBars[entity]
        if data then
            data.billboard.Enabled = false
        end
        return
    end

    local data = getOrCreateHPBar(entity)
    if not data then
        return
    end

    data.billboard.Enabled = true
    data.hpBar.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)

    -- Цвет HP бара
    if ratio > 0.5 then
        data.hpBar.BackgroundColor3 = BC.hpBarGreen
    elseif ratio > 0.25 then
        data.hpBar.BackgroundColor3 = BC.hpBarYellow
    else
        data.hpBar.BackgroundColor3 = BC.hpBarRed
    end

    -- Автоскрытие через N секунд
    if data.hideThread then
        task.cancel(data.hideThread)
    end
    data.hideThread = task.delay(HP_BAR_SHOW_TIME, function()
        if data.billboard and data.billboard.Parent then
            data.billboard.Enabled = false
        end
    end)
end

-- ═══ Подписка на StructureDamageEvent ═══
Remotes.StructureDamageEvent.OnClientEvent:Connect(function(entity, currentHP, maxHP, damage)
    showDamageNumber(entity, currentHP, maxHP, damage)
    updateStructureHP(entity, currentHP, maxHP)
end)

-- ═══ Cleanup: убираем данные для уничтоженных entity ═══
task.spawn(function()
    while true do
        task.wait(10)
        for entity, data in structureHPBars do
            if not entity or not entity.Parent then
                if data.hideThread then
                    pcall(task.cancel, data.hideThread)
                end
                structureHPBars[entity] = nil
            end
        end
    end
end)
