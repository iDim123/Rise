local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ Constants (matching ActionBar) ═══
local SLOT_SIZE = Config.Inventory.SlotSize
local PADDING = Config.Inventory.Padding
local WINDOW_BG = Color3.fromRGB(25, 25, 35)
local SLOT_BG = Color3.fromRGB(50, 50, 65)
local SLOT_BORDER = Color3.fromRGB(80, 80, 100)
local BIND_COLOR = Color3.fromRGB(180, 180, 100)
local ACTIVE_STROKE = Color3.fromRGB(200, 170, 60)
local COOLDOWN_COLOR = Color3.fromRGB(0, 0, 0)
local COOLDOWN_TRANSPARENCY = 0.45
local CORNER_RADIUS = 6

local TOOLTIP_WIDTH = 220
local TOOLTIP_PAD = 10
local TOOLTIP_BG = Color3.fromRGB(20, 20, 20)
local TOOLTIP_BORDER = Color3.fromRGB(100, 100, 100)
local TOOLTIP_TEXT = Color3.fromRGB(230, 230, 230)
local TOOLTIP_SUB = Color3.fromRGB(160, 160, 160)
local TOOLTIP_CORNER = 8

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
local FLASK_WIDTH = 50
local GAP = 8

-- ═══ State ═══
local slots = {}
local cooldowns = {}
local currentAbilities = {} -- [key] = ability config or nil

local tooltipFrame = nil
local hoveredKey = nil

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AbilitiesBarGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 810
screenGui.Parent = playerGui

-- ═══ Frame ═══
local abFrameW = PADDING + TOTAL_SLOTS * (SLOT_SIZE + PADDING)
local abFrameH = SLOT_SIZE + 20

local abCols = Config.Inventory.Columns
local actionBarW = PADDING + abCols * (SLOT_SIZE + PADDING)

local barFrame = Instance.new("Frame")
barFrame.Name = "AbilitiesBar"
barFrame.Size = UDim2.new(0, abFrameW, 0, abFrameH)
barFrame.AnchorPoint = Vector2.new(0, 1)
barFrame.Position = UDim2.new(0.5, (FLASK_WIDTH / 2) + GAP, 1, -10)
barFrame.BackgroundColor3 = WINDOW_BG
barFrame.BackgroundTransparency = 0.3
barFrame.BorderSizePixel = 0
barFrame.Parent = screenGui

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, CORNER_RADIUS)
barCorner.Parent = barFrame

-- ═══ Tooltip ═══
local function createTooltip()
    local frame = Instance.new("Frame")
    frame.Name = "AbilityTooltip"
    frame.BackgroundColor3 = TOOLTIP_BG
    frame.Size = UDim2.new(0, TOOLTIP_WIDTH, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Visible = false
    frame.ZIndex = 100
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, TOOLTIP_CORNER)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = TOOLTIP_BORDER
    stroke.Thickness = 1
    stroke.Parent = frame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, TOOLTIP_PAD)
    pad.PaddingBottom = UDim.new(0, TOOLTIP_PAD)
    pad.PaddingLeft = UDim.new(0, TOOLTIP_PAD)
    pad.PaddingRight = UDim.new(0, TOOLTIP_PAD)
    pad.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 18)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = TOOLTIP_TEXT
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.LayoutOrder = 1
    title.ZIndex = 101
    title.Parent = frame

    local desc = Instance.new("TextLabel")
    desc.Name = "Description"
    desc.BackgroundTransparency = 1
    desc.Size = UDim2.new(1, 0, 0, 0)
    desc.AutomaticSize = Enum.AutomaticSize.Y
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 12
    desc.TextColor3 = TOOLTIP_SUB
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextWrapped = true
    desc.LayoutOrder = 2
    desc.ZIndex = 101
    desc.Parent = frame

    local cdLabel = Instance.new("TextLabel")
    cdLabel.Name = "Cooldown"
    cdLabel.BackgroundTransparency = 1
    cdLabel.Size = UDim2.new(1, 0, 0, 16)
    cdLabel.Font = Enum.Font.Gotham
    cdLabel.TextSize = 12
    cdLabel.TextColor3 = TOOLTIP_SUB
    cdLabel.TextXAlignment = Enum.TextXAlignment.Left
    cdLabel.LayoutOrder = 3
    cdLabel.ZIndex = 101
    cdLabel.Parent = frame

    return frame
end

local function showTooltip(key, slotFrame)
    local ability = currentAbilities[key]
    if not ability then return end
    if not tooltipFrame then tooltipFrame = createTooltip() end

    tooltipFrame.Title.Text = ability.Name or ability.Id
    tooltipFrame.Description.Text = ability.Description or ""

    if key == "LMB" then
        tooltipFrame.Cooldown.Text = ""
        tooltipFrame.Cooldown.Visible = false
    else
        tooltipFrame.Cooldown.Text = "Cooldown: " .. (ability.Cooldown or 0) .. "s"
        tooltipFrame.Cooldown.Visible = true
    end

    local absPos = slotFrame.AbsolutePosition
    local viewportSize = workspace.CurrentCamera.ViewportSize
    local x = absPos.X + SLOT_SIZE / 2 - TOOLTIP_WIDTH / 2

    if x + TOOLTIP_WIDTH > viewportSize.X - 4 then
        x = viewportSize.X - TOOLTIP_WIDTH - 4
    end
    if x < 4 then x = 4 end

    tooltipFrame.Position = UDim2.new(0, x, 0, absPos.Y - 80)
    tooltipFrame.Visible = true
    hoveredKey = key

    task.defer(function()
        if not tooltipFrame or not tooltipFrame.Visible then return end
        local h = tooltipFrame.AbsoluteSize.Y
        tooltipFrame.Position = UDim2.new(0, x, 0, absPos.Y - h - 8)
    end)
end

local function hideTooltip()
    if tooltipFrame then tooltipFrame.Visible = false end
    hoveredKey = nil
end

-- ═══ Slot builder ═══
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

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = slot

    local stroke = Instance.new("UIStroke")
    stroke.Color = SLOT_BORDER
    stroke.Thickness = 1
    stroke.Parent = slot

    -- Icon
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

    -- Fallback text
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

    -- Cooldown overlay (only for Q, E)
    local overlay = Instance.new("Frame")
    overlay.Name = "CooldownOverlay"
    overlay.BackgroundColor3 = COOLDOWN_COLOR
    overlay.BackgroundTransparency = COOLDOWN_TRANSPARENCY
    overlay.BorderSizePixel = 0
    overlay.Size = UDim2.new(1, 0, 0, 0)
    overlay.ZIndex = 3
    overlay.Visible = false
    overlay.Parent = slot

    -- Cooldown timer
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

    -- Key label (parented to barFrame to avoid clipping)
    local bindText = key
    if key == "LMB" then bindText = "LMB" end

    local keyLabel = Instance.new("TextLabel")
    keyLabel.Name = "KeyLabel_" .. key
    keyLabel.Size = UDim2.new(0, SLOT_SIZE, 0, 14)
    keyLabel.Position = UDim2.new(0, posX, 0, SLOT_SIZE + 4)
    keyLabel.BackgroundTransparency = 1
    keyLabel.TextColor3 = BIND_COLOR
    keyLabel.TextSize = 11
    keyLabel.Font = Enum.Font.GothamBold
    keyLabel.Text = bindText
    keyLabel.TextXAlignment = Enum.TextXAlignment.Center
    keyLabel.Parent = barFrame

    -- Hover
    slot.MouseEnter:Connect(function()
        showTooltip(key, slot)
    end)
    slot.MouseLeave:Connect(function()
        if hoveredKey == key then hideTooltip() end
    end)

    slots[key] = {
        frame = slot,
        icon = icon,
        fallback = fallback,
        overlay = overlay,
        timerLabel = timerLabel,
        keyLabel = keyLabel,
        stroke = stroke,
    }
end

for i, key in SLOT_KEYS do
    createSlot(key, i - 1)
end

-- ═══ Update abilities from weapon ═══
local function updateAbilities()
    local character = player.Character
    if not character then
        for _, key in SLOT_KEYS do currentAbilities[key] = nil end
        return
    end

    local tool = character:FindFirstChildOfClass("Tool")
    local weaponConfig = nil
    if tool then weaponConfig = Config.Weapons[tool.Name] end

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

-- ═══ Input (only Q and E send remote, LMB handled by CombatInput) ═══
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    for _, key in { "Q", "E", "Space", "R", "T", "Z", "X" } do
        if KEYCODES[key] and input.KeyCode == KEYCODES[key] then
            local ability = currentAbilities[key]
            if not ability then return end
            local cd = cooldowns[key]
            if cd and tick() < cd.endTime then return end
            Remotes.UseAbility:FireServer(key, getMouseWorldPosition())
            break
        end
    end
end)

-- ═══ Cooldown from server ═══
Remotes.AbilityCooldown.OnClientEvent:Connect(function(key, duration)
    if not slots[key] then return end
    cooldowns[key] = { endTime = tick() + duration, duration = duration }
    slots[key].stroke.Color = ACTIVE_STROKE
end)

-- ═══ Render ═══
RunService.RenderStepped:Connect(function()
    updateAbilities()

    local now = tick()
    for _, key in { "Q", "E", "Space", "R", "T", "Z", "X" } do
        local slot = slots[key]
        local cd = cooldowns[key]
        if cd and now < cd.endTime then
            local rem = cd.endTime - now
            slot.overlay.Size = UDim2.new(1, 0, math.clamp(rem / cd.duration, 0, 1), 0)
            slot.overlay.Visible = true
            slot.timerLabel.Text = string.format("%.0f", math.ceil(rem))
            slot.timerLabel.Visible = true
        else
            slot.overlay.Visible = false
            slot.timerLabel.Visible = false
            if cd then
                cooldowns[key] = nil
                slot.stroke.Color = currentAbilities[key] and SLOT_BORDER or Color3.fromRGB(50, 50, 50)
            end
        end
    end
end)

player.CharacterAdded:Connect(updateAbilities)
updateAbilities()