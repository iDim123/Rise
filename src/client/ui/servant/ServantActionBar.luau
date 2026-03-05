local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local ServantActionBar = {}

local SLOT_SIZE = 40
local AB_SLOT_SIZE = 50
local PAD = 4
local COLS = 6
local BAR_BG = Color3.fromRGB(25, 25, 35)
local SLOT_BG = Color3.fromRGB(50, 50, 65)
local ACTIVE_COLOR = Color3.fromRGB(220, 190, 80)
local TEXT_COLOR = Color3.fromRGB(200, 200, 200)
local BIND_COLOR = Color3.fromRGB(180, 180, 100)
local AB_WIDTH = PAD + 8 * (AB_SLOT_SIZE + PAD)  -- 436

local FLASK_W = 50
local GAP_F = 8
local HP_BLOCK_H = 30
local BAR_GAP_V = 10

local barGui = nil
local barFrame = nil
local slotButtons = {}
local currentMode = nil
local currentCommand = nil

local actions = {
    { id = "AttackTarget", label = "Attack\nTarget", type = "command", bind = "Shift-1" },
    { id = "Stay",         label = "Stay",           type = "command", bind = "Shift-2" },
    { id = "Follow",       label = "Follow",         type = "command", bind = "Shift-3" },
    { id = "Aggressive",   label = "Aggre-\nssive",  type = "mode",    bind = "Shift-4" },
    { id = "Defensive",    label = "Defen-\nsive",   type = "mode",    bind = "Shift-5" },
    { id = "Passive",      label = "Passive",         type = "mode",    bind = "Shift-6" },
}

local shiftKeys = {
    [Enum.KeyCode.One]   = 1,
    [Enum.KeyCode.Two]   = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four]  = 4,
    [Enum.KeyCode.Five]  = 5,
    [Enum.KeyCode.Six]   = 6,
}

local function updateHighlights()
    for i, action in actions do
        local slot = slotButtons[i]
        if not slot then continue end

        local stroke = slot:FindFirstChildOfClass("UIStroke")
        local isActive = false

        if action.type == "mode" and currentMode == action.id then
            isActive = true
        end

        if stroke then
            stroke.Color = Color3.fromRGB(80, 80, 100)
            stroke.Thickness = isActive and 2 or 1
        end

        slot.BackgroundColor3 = isActive and Color3.fromRGB(65, 60, 45) or SLOT_BG
    end
end

local function executeAction(index)
    local action = actions[index]
    if not action then return end

    if action.type == "command" then
        Remotes.ServantCommand:FireServer(action.id)
        currentCommand = action.id
    elseif action.type == "mode" then
        Remotes.SetServantMode:FireServer(action.id)
        currentMode = action.id
    end

    updateHighlights()
end

function ServantActionBar.build(playerGui)
    barGui = Instance.new("ScreenGui")
    barGui.Name = "ServantActionBarGui"
    barGui.ResetOnSpawn = false
    barGui.Parent = playerGui

    local frameW = PAD + COLS * (SLOT_SIZE + PAD)
    local frameH = SLOT_SIZE + 20

    barFrame = Instance.new("Frame")
    barFrame.Name = "ServantActionBar"
    barFrame.Size = UDim2.new(0, frameW, 0, frameH)
    barFrame.AnchorPoint = Vector2.new(0, 1)
    barFrame.Position = UDim2.new(0.5, (FLASK_W / 2) + GAP_F + AB_WIDTH + GAP_F, 1, -10)   
    barFrame.BackgroundColor3 = BAR_BG
    barFrame.BackgroundTransparency = 0.3
    barFrame.BorderSizePixel = 0
    barFrame.Visible = false
    barFrame.Parent = barGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = barFrame

    for i, action in actions do
        local posX = PAD + (i - 1) * (SLOT_SIZE + PAD)

        local slot = Instance.new("TextButton")
        slot.Name = "ServAB_" .. action.id
        slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
        slot.Position = UDim2.new(0, posX, 0, 2)
        slot.BackgroundColor3 = SLOT_BG
        slot.BorderSizePixel = 0
        slot.TextColor3 = TEXT_COLOR
        slot.TextSize = 9
        slot.Font = Enum.Font.GothamBold
        slot.TextWrapped = true
        slot.Text = action.label
        slot.AutoButtonColor = false
        slot.Parent = barFrame

        local slotCorner = Instance.new("UICorner")
        slotCorner.CornerRadius = UDim.new(0, 4)
        slotCorner.Parent = slot

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(80, 80, 100)
        stroke.Thickness = 1
        stroke.Parent = slot

        -- Bind label
        local bindLabel = Instance.new("TextLabel")
        bindLabel.Name = "BindLabel"
        bindLabel.Size = UDim2.new(1, 0, 0, 14)
        bindLabel.Position = UDim2.new(0, 0, 1, 2)
        bindLabel.BackgroundTransparency = 1
        bindLabel.TextColor3 = BIND_COLOR
        bindLabel.TextSize = 9
        bindLabel.Font = Enum.Font.GothamBold
        bindLabel.Text = action.bind
        bindLabel.TextXAlignment = Enum.TextXAlignment.Center
        bindLabel.Parent = slot

        slot.MouseButton1Click:Connect(function()
            executeAction(i)
        end)

        slotButtons[i] = slot
    end

    -- Shift+1..6 hotkeys
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not barFrame.Visible then return end
        if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and
           not UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
            return
        end

        local actionIndex = shiftKeys[input.KeyCode]
        if actionIndex then
            executeAction(actionIndex)
        end
    end)
end

function ServantActionBar.setVisible(visible)
    if barFrame then
        barFrame.Visible = visible
    end
end

function ServantActionBar.refresh(mode)
    currentMode = mode
    updateHighlights()
end

return ServantActionBar