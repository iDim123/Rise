local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer

local function showDamageNumber(entity, amount, color)
    local head = entity:FindFirstChild("Head")
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DamageNumber"
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.AlwaysOnTop = true
    billboard.Adornee = head

    -- Случайное смещение чтобы цифры не накладывались
    local offsetX = math.random(-15, 15) / 10
    billboard.StudsOffset = Vector3.new(offsetX, 3, 0)

    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.5
    label.TextSize = 22
    label.Font = Enum.Font.GothamBold
    label.Text = tostring(amount)
    label.Parent = billboard

    -- Анимация: летит вверх и исчезает
    local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local offsetTween = TweenService:Create(billboard, tweenInfo, {
        StudsOffset = billboard.StudsOffset + Vector3.new(0, 2, 0),
    })

    local fadeTween = TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    })

    offsetTween:Play()
    fadeTween:Play()

    fadeTween.Completed:Connect(function()
        billboard:Destroy()
    end)
end

-- Слушаем событие урона
Remotes.DamageEvent.OnClientEvent:Connect(function(entity, currentHP, maxHP, damage, attackerName)
    if not entity or not entity.Parent then return end
    if not damage then return end

    local character = player.Character

    -- Определяем цвет
    if character and entity == character then
        -- Урон по игроку — красный
        showDamageNumber(entity, damage, Color3.fromRGB(255, 50, 50))
    else
        -- Урон по врагу/другому — белый
        showDamageNumber(entity, damage, Color3.fromRGB(255, 255, 255))
    end
end)

-- Слушаем событие лечения
Remotes.HealEvent.OnClientEvent:Connect(function(entity, currentHP, maxHP, healAmount)
    if not entity or not entity.Parent then return end
    if not healAmount then return end

    local character = player.Character
    if character and entity == character then
        showDamageNumber(entity, "+" .. healAmount, Color3.fromRGB(50, 220, 50))
    end
end)