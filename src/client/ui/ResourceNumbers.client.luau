local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player = Players.LocalPlayer
local RESOURCE_COLOR = Color3.fromRGB(255, 220, 50)
local FLOAT_HEIGHT = 4
local LIFETIME = 1.5
local TEXT_SIZE = 20

local function showResourceNumber(node, resourceId, amount)
    local character = player.Character or player.CharacterAdded:Wait()
    local head = character:FindFirstChild("Head")
    if not head then return end

    local itemDef = Config.Items[resourceId]
    local displayName = itemDef and itemDef.Name or resourceId

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ResourceNumber"
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 60
    billboard.Adornee = head
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = TEXT_SIZE
    label.TextColor3 = RESOURCE_COLOR
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.3
    label.Text = "+" .. amount .. " " .. displayName
    label.Parent = billboard

    local floatTween = TweenService:Create(billboard, TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = billboard.StudsOffset + Vector3.new(0, FLOAT_HEIGHT, 0)
    })
    floatTween:Play()

    task.delay(LIFETIME * 0.6, function()
        local fadeTween = TweenService:Create(label, TweenInfo.new(LIFETIME * 0.4, Enum.EasingStyle.Quad), {
            TextTransparency = 1,
            TextStrokeTransparency = 1,
        })
        fadeTween:Play()
    end)

    task.delay(LIFETIME, function()
        billboard:Destroy()
    end)
end

Remotes.ResourceGathered.OnClientEvent:Connect(function(node, resourceId, amount)
    showResourceNumber(node, resourceId, amount)
end)