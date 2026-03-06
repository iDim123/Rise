local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local uiFolder = script.Parent:WaitForChild("character")
local C = require(uiFolder:WaitForChild("UIConstants"))

local servantLevelData = { Level = 1, XP = 0, XPToNext = 100 }

-- ═══ ScreenGui ═══
local screenGui = playerGui:WaitForChild("PlayerHUD")
-- Если PlayerHPBlock ещё не создал — ждём
if not screenGui then
    screenGui = playerGui:WaitForChild("PlayerHUD", 5)
end

-- ═══ Servant Block ═══
local servantBlock = Instance.new("Frame")
servantBlock.Name = "ServantHPBlock"
servantBlock.Size = UDim2.new(0, C.LEVEL_SIZE + C.LEVEL_GAP + C.HP_BAR_WIDTH, 0, C.HP_BLOCK_H)
servantBlock.AnchorPoint = Vector2.new(0, 1)
servantBlock.Position = UDim2.new(0.5, (C.FLASK_WIDTH / 2) + C.GAP, 1, -(C.MARGIN + C.AB_HEIGHT + C.GAP))
servantBlock.BackgroundTransparency = 1
servantBlock.Visible = false
servantBlock.Parent = screenGui

-- Level Circle (left)
local sLevelFrame = Instance.new("Frame")
sLevelFrame.Name = "ServantLevelFrame"
sLevelFrame.Size = UDim2.new(0, C.LEVEL_SIZE, 0, C.LEVEL_SIZE)
sLevelFrame.Position = UDim2.new(0, 0, 0.5, -C.LEVEL_SIZE / 2)
sLevelFrame.BackgroundColor3 = C.LEVEL_BG
sLevelFrame.BorderSizePixel = 0
sLevelFrame.Parent = servantBlock
Instance.new("UICorner", sLevelFrame).CornerRadius = UDim.new(0.5, 0)

local sLevelStroke = Instance.new("UIStroke")
sLevelStroke.Color = C.LEVEL_BORDER
sLevelStroke.Thickness = 2
sLevelStroke.Parent = sLevelFrame

local sLevelText = Instance.new("TextLabel")
sLevelText.Name = "LevelText"
sLevelText.Size = UDim2.new(1, 0, 1, 0)
sLevelText.BackgroundTransparency = 1
sLevelText.Text = "1"
sLevelText.TextColor3 = C.TEXT_COLOR
sLevelText.TextSize = 16
sLevelText.Font = Enum.Font.GothamBold
sLevelText.Parent = sLevelFrame

-- HP Bar (right of level)
local sHpFrame = Instance.new("Frame")
sHpFrame.Name = "ServantHPBarFrame"
sHpFrame.Size = UDim2.new(0, C.HP_BAR_WIDTH, 0, C.HP_HEIGHT)
sHpFrame.Position = UDim2.new(0, C.LEVEL_SIZE + C.LEVEL_GAP, 0, 0)
sHpFrame.BackgroundColor3 = C.BG_COLOR
sHpFrame.BorderSizePixel = 0
sHpFrame.Parent = servantBlock
Instance.new("UICorner", sHpFrame).CornerRadius = UDim.new(0, 4)

local sHpBar = Instance.new("Frame")
sHpBar.Name = "HPBar"
sHpBar.Size = UDim2.new(1, 0, 1, 0)
sHpBar.BackgroundColor3 = C.HP_RED
sHpBar.BorderSizePixel = 0
sHpBar.Parent = sHpFrame
Instance.new("UICorner", sHpBar).CornerRadius = UDim.new(0, 4)

local sHpText = Instance.new("TextLabel")
sHpText.Name = "HPText"
sHpText.Size = UDim2.new(1, 0, 1, 0)
sHpText.BackgroundTransparency = 1
sHpText.TextColor3 = C.TEXT_COLOR
sHpText.TextSize = 13
sHpText.Font = Enum.Font.GothamBold
sHpText.Text = ""
sHpText.ZIndex = 2
sHpText.Parent = sHpFrame

-- XP Bar
local sXpFrame = Instance.new("Frame")
sXpFrame.Name = "ServantXPBarFrame"
sXpFrame.Size = UDim2.new(0, C.HP_BAR_WIDTH, 0, C.XP_HEIGHT)
sXpFrame.Position = UDim2.new(0, C.LEVEL_SIZE + C.LEVEL_GAP, 0, C.HP_HEIGHT + 2)
sXpFrame.BackgroundColor3 = C.XP_BG
sXpFrame.BorderSizePixel = 0
sXpFrame.Parent = servantBlock
Instance.new("UICorner", sXpFrame).CornerRadius = UDim.new(0, 3)

local sXpBar = Instance.new("Frame")
sXpBar.Name = "XPBar"
sXpBar.Size = UDim2.new(0, 0, 1, 0)
sXpBar.BackgroundColor3 = C.XP_COLOR
sXpBar.BorderSizePixel = 0
sXpBar.Parent = sXpFrame
Instance.new("UICorner", sXpBar).CornerRadius = UDim.new(0, 3)

local sXpText = Instance.new("TextLabel")
sXpText.Name = "XPText"
sXpText.Size = UDim2.new(1, 0, 1, 0)
sXpText.BackgroundTransparency = 1
sXpText.TextColor3 = C.TEXT_DIM
sXpText.TextSize = 8
sXpText.Font = Enum.Font.Gotham
sXpText.Text = ""
sXpText.ZIndex = 2
sXpText.Parent = sXpFrame

-- ═══ Update ═══
local function updateServantLevel()
    sLevelText.Text = tostring(servantLevelData.Level)
    if servantLevelData.XPToNext > 0 then
        local r = math.clamp(servantLevelData.XP / servantLevelData.XPToNext, 0, 1)
        sXpBar.Size = UDim2.new(r, 0, 1, 0)
        sXpText.Text = servantLevelData.XP .. " / " .. servantLevelData.XPToNext .. " XP"
    else
        sXpBar.Size = UDim2.new(1, 0, 1, 0)
        sXpText.Text = "MAX"
    end
end

local function updateServant()
    local folder = workspace:FindFirstChild("Servants")
    if not folder then servantBlock.Visible = false return end
    local found = false
    for _, servant in folder:GetChildren() do
        if servant:GetAttribute("OwnerUserId") == player.UserId then
            local sHP = servant:GetAttribute("CurrentHP")
            local sMax = servant:GetAttribute("MaxHP")
            if sHP and sMax and sMax > 0 then
                local ratio = math.clamp(sHP / sMax, 0, 1)
                sHpBar.Size = UDim2.new(ratio, 0, 1, 0)
                sHpBar.BackgroundColor3 = C.HP_RED
                sHpText.Text = sHP .. "/" .. sMax
                servantBlock.Visible = true
                found = true
            end
            break
        end
    end
    if not found then servantBlock.Visible = false end
end

-- ═══ Events ═══
Remotes.UpdateServantLevel.OnClientEvent:Connect(function(_servantId, data)
    servantLevelData.Level = data.Level or servantLevelData.Level
    servantLevelData.XP = data.XP or servantLevelData.XP
    servantLevelData.XPToNext = data.XPToNext or servantLevelData.XPToNext
    updateServantLevel()
end)

updateServantLevel()

RunService.RenderStepped:Connect(function()
    updateServant()
end)