local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local AbilityTooltip = require(script.Parent:WaitForChild("AbilityTooltip"))
local AbilityCooldowns = require(script.Parent:WaitForChild("AbilityCooldowns"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ Constants ═══
local SLOT_SIZE = Config.Inventory.SlotSize
local PADDING = Config.Inventory.Padding
local COLS = Config.Inventory.Columns
local CORNER_RADIUS = 6
local FLASK_WIDTH = 50
local GAP = 8

local WINDOW_BG = Color3.fromRGB(25, 25, 35)
local SLOT_BG = Color3.fromRGB(50, 50, 65)
local SLOT_BORDER = Color3.fromRGB(80, 80, 100)
local BIND_COLOR = Color3.fromRGB(180, 180, 100)
local COOLDOWN_COLOR = Color3.fromRGB(0, 0, 0)
local COOLDOWN_TRANSPARENCY = 0.45

local TOTAL_SLOTS = 8
local SLOT_KEYS = { "LMB", "Q", "E", "Space", "R", "T", "Z", "X" }
local KEYCODES = {
    Q = Enum.KeyCode.Q,
    E = Enum.KeyCode.E,
    Space = Enum.KeyCode.Space,
    R = Enum.KeyCode.R,
    T = Enum.KeyCode.T,
    Z = Enum.KeyCode.Z,
    X = Enum.KeyCode.X,
}

-- ═══ State ═══
local slots = {}
local currentAbilities = {}
local toolConnection = nil

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AbilitiesBarGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 810
screenGui.Parent = playerGui

-- ═══ Bar Frame ═══
local barFrameW = PADDING + TOTAL_SLOTS * (SLOT_SIZE + PADDING)
local barFrameH = SLOT_SIZE + 20

local barFrame = Instance.new("Frame")
barFrame.Name = "AbilitiesBar"
barFrame.Size = UDim2.new(0, barFrameW, 0, barFrameH)
barFrame.AnchorPoint = Vector2.new(0, 1)
barFrame.Position = UDim2.new(0.5, (FLASK_WIDTH / 2) + GAP, 1, -10)
barFrame.BackgroundColor3 = WINDOW_BG
barFrame.BackgroundTransparency = 0.3
barFrame.BorderSizePixel = 0
barFrame.Parent = screenGui
Instance.new("UICorner", barFrame).CornerRadius = UDim.new(0, CORNER_RADIUS)

-- ═══ Create Slots ═══
local function createSlot(key, col)
    local posX = PADDING + col * (SLOT_SIZE + PADDING)

    local slot = Instance.new("Frame")
    slot.Name = "Ability_" .. key
    slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    slot.Position = UDim2.new(0, posX, 0, 2)
    slot.BackgroundColor3 = SLOT_BG
    slot.BorderSizePixel = 0
    slot.ClipsDescendants = true
    slot.Parent = barFrame
    Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke")
    stroke.Color = SLOT_BORDER
    stroke.Thickness = 1
    stroke.Parent = slot

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(1, -6, 1, -6)
    icon.Position = UDim2.new(0, 3, 0, 3)
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Image = ""
    icon.Visible = false
    icon.ZIndex = 2
    icon.Parent = slot

    local fallback = Instance.new("TextLabel")
    fallback.Name = "Fallback"
    fallback.BackgroundTransparency = 1
    fallback.Size = UDim2.new(1, 0, 1, 0)
    fallback.Font = Enum.Font.GothamBold
    fallback.TextSize = 10
    fallback.TextColor3 = Color3.fromRGB(150, 150, 150)
    fallback.Text = ""
    fallback.Visible = false
    fallback.ZIndex = 2
    fallback.Parent = slot

    local overlay = Instance.new("Frame")
    overlay.Name = "CooldownOverlay"
    overlay.BackgroundColor3 = COOLDOWN_COLOR
    overlay.BackgroundTransparency = COOLDOWN_TRANSPARENCY
    overlay.BorderSizePixel = 0
    overlay.Size = UDim2.new(1, 0, 0, 0)
    overlay.ZIndex = 3
    overlay.Visible = false
    overlay.Parent = slot

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "TimerLabel"
    timerLabel.BackgroundTransparency = 1
    timerLabel.Size = UDim2.new(1, 0, 1, 0)
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.TextSize = 18
    timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timerLabel.Text = ""
    timerLabel.Visible = false
    timerLabel.ZIndex = 4
    timerLabel.Parent = slot

    local keyLabel = Instance.new("TextLabel")
    keyLabel.Name = "KeyLabel_" .. key
    keyLabel.Size = UDim2.new(0, SLOT_SIZE, 0, 14)
    keyLabel.Position = UDim2.new(0, posX, 0, SLOT_SIZE + 4)
    keyLabel.BackgroundTransparency = 1
    keyLabel.TextColor3 = BIND_COLOR
    keyLabel.TextSize = 11
    keyLabel.Font = Enum.Font.GothamBold
    keyLabel.Text = key
    keyLabel.TextXAlignment = Enum.TextXAlignment.Center
    keyLabel.Parent = barFrame

    -- Hover
    slot.MouseEnter:Connect(function()
        AbilityTooltip.show(screenGui, key, currentAbilities[key], slot, SLOT_SIZE)
    end)
    slot.MouseLeave:Connect(function()
        if AbilityTooltip.getHoveredKey() == key then
            AbilityTooltip.hide()
        end
    end)

    -- Register cooldown
    AbilityCooldowns.registerSlot(key, overlay, timerLabel, stroke)

    slots[key] = {
        frame = slot,
        icon = icon,
        fallback = fallback,
        stroke = stroke,
    }
end

for i, key in SLOT_KEYS do
    createSlot(key, i - 1)
end

-- ═══ Update abilities (event-driven) ═══
local function updateAbilities()
    local character = player.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    local weaponConfig = tool and Config.Weapons[tool.Name] or nil

    for _, key in SLOT_KEYS do
        local ability = nil
        if key == "LMB" then
            ability = weaponConfig and weaponConfig.ComboAbility
        else
            ability = weaponConfig and weaponConfig.Abilities and weaponConfig.Abilities[key]
        end
        currentAbilities[key] = ability

        local slot = slots[key]
        if ability then
            if ability.Icon and ability.Icon ~= "" and ability.Icon ~= "rbxassetid://0" then
                slot.icon.Image = ability.Icon
                slot.icon.Visible = true
                slot.fallback.Visible = false
            else
                slot.icon.Visible = false
                slot.fallback.Text = string.sub(ability.Name or ability.Id, 1, 4)
                slot.fallback.Visible = true
            end
            slot.stroke.Color = SLOT_BORDER
        else
            slot.icon.Visible = false
            slot.fallback.Text = key
            slot.fallback.Visible = true
            slot.stroke.Color = Color3.fromRGB(50, 50, 50)
        end
    end
end

local function connectCharacter(character)
    -- Disconnect previous
    if toolConnection then toolConnection:Disconnect() end

    -- Watch for tool changes
    toolConnection = character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then updateAbilities() end
    end)
    character.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then updateAbilities() end
    end)

    updateAbilities()
end

player.CharacterAdded:Connect(connectCharacter)
if player.Character then
    connectCharacter(player.Character)
end

-- ═══ Mouse position ═══
local function getMouseWorldPosition()
    local mouse = player:GetMouse()
    local camera = workspace.CurrentCamera
    local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    if player.Character then params.FilterDescendantsInstances = { player.Character } end
    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    return result and result.Position or (ray.Origin + ray.Direction * 100)
end

-- ═══ Input ═══
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    for _, key in { "Q", "E", "Space", "R", "T", "Z", "X" } do
        if KEYCODES[key] and input.KeyCode == KEYCODES[key] then
            local ability = currentAbilities[key]
            if not ability then return end
            if AbilityCooldowns.isOnCooldown(key) then return end
            Remotes.UseAbility:FireServer(key, getMouseWorldPosition())
            break
        end
    end
end)

-- ═══ Cooldown from server ═══
Remotes.AbilityCooldown.OnClientEvent:Connect(function(key, duration)
    AbilityCooldowns.start(key, duration)
end)

-- ═══ Render (only cooldown tick) ═══
RunService.RenderStepped:Connect(function()
    AbilityCooldowns.tick(function(key)
        return currentAbilities[key] ~= nil
    end)
end)