local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local C = require(script.Parent:WaitForChild("BossJournalConstants"))
local BossCard = require(script.Parent:WaitForChild("BossCard"))
local BossTooltip = require(script.Parent:WaitForChild("BossTooltip"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BossJournal = {}

local isOpen = false
local bossData = nil
local bossCards = {}

local screenGui, mainFrame, scrollFrame

-- ═══ Build UI ═══
function BossJournal.build()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BossJournalGui"
    screenGui.DisplayOrder = 850
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = playerGui

    BossTooltip.init(screenGui)
    -- ═══ Fullscreen background ═══
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "BossJournalWindow"
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.Position = UDim2.new(0, 0, 0, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = screenGui

    -- Background image (dark atmospheric art)
    local bgImage = Instance.new("ImageLabel")
    bgImage.Name = "BackgroundImage"
    bgImage.Size = UDim2.new(1, 0, 1, 0)
    bgImage.BackgroundTransparency = 1
    bgImage.Image = "rbxassetid://130567382079214" -- замени на свой ассет
    bgImage.ImageTransparency = 0.4
    bgImage.ScaleType = Enum.ScaleType.Crop
    bgImage.Parent = mainFrame

    -- Dark overlay for readability
    local overlay = Instance.new("Frame")
    overlay.Name = "DarkOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.3
    overlay.BorderSizePixel = 0
    overlay.Parent = mainFrame

    -- ═══ Header (top bar) ═══
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, 0, 0, C.HEADER_H)
    headerFrame.BackgroundColor3 = C.HEADER_BG
    headerFrame.BackgroundTransparency = 0.3
    headerFrame.BorderSizePixel = 0
    headerFrame.ZIndex = 2
    headerFrame.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Журнал боссов"
    titleLabel.TextColor3 = C.TEXT_COLOR
    titleLabel.TextSize = 22
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.ZIndex = 2
    titleLabel.Parent = headerFrame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.Position = UDim2.new(1, -10, 0.5, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    closeBtn.TextColor3 = Color3.fromRGB(200, 100, 100)
    closeBtn.Text = "x"
    closeBtn.TextSize = 20
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 2
    closeBtn.Parent = headerFrame

    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

    closeBtn.Activated:Connect(function()
        BossJournal.close()
    end)

    -- ═══ Center content container ═══
    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "ContentContainer"
    contentContainer.Size = UDim2.new(0.5, 0, 1, -(C.HEADER_H + 20))
    contentContainer.AnchorPoint = Vector2.new(0.5, 0)
    contentContainer.Position = UDim2.new(0.5, 0, 0, C.HEADER_H + 10)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Parent = mainFrame

    -- ═══ Scroll frame inside center container ═══
    scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "BossListScroll"
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = C.STROKE_COLOR
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = contentContainer

    -- Listen for updates
    Remotes.BossFinishResult.OnClientEvent:Connect(function(result)
        if not bossData then return end
        local bossId = result.BossId
        if bossData[bossId] then
            bossData[bossId].Essence = result.Essence
            if result.FirstKill then
                bossData[bossId].TechUnlocked = true
            end
        end
        if isOpen then
            BossJournal.rebuildList()
        end
    end)

    Remotes.BossCaptureResult.OnClientEvent:Connect(function(result)
        if not bossData then return end
        if result.Success and result.BossId and bossData[result.BossId] then
            bossData[result.BossId].Captured = true
        end
        if isOpen then
            BossJournal.rebuildList()
        end
    end)
end

-- ═══ Rebuild list ═══
function BossJournal.rebuildList()
    for _, entry in bossCards do
        if entry.frame then entry.frame:Destroy() end
    end
    table.clear(bossCards)

    if not bossData or not scrollFrame then return end

    -- Remove old layout if exists
    local oldLayout = scrollFrame:FindFirstChildOfClass("UIListLayout")
    if oldLayout then oldLayout:Destroy() end

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, C.CARD_PADDING)
    listLayout.Parent = scrollFrame

    local listPadding = Instance.new("UIPadding")
    listPadding.PaddingTop = UDim.new(0, C.CARD_PADDING)
    listPadding.PaddingBottom = UDim.new(0, C.CARD_PADDING)
    listPadding.Parent = scrollFrame

    -- Sort by Act, then Level
    local sortedIds = {}
    for bossId, _ in bossData do
        table.insert(sortedIds, bossId)
    end
    table.sort(sortedIds, function(a, b)
        local da = bossData[a]
        local db = bossData[b]
        if (da.Act or 1) ~= (db.Act or 1) then
            return (da.Act or 1) < (db.Act or 1)
        end
        return (da.Level or 1) < (db.Level or 1)
    end)

    for idx, bossId in sortedIds do
        local pData = bossData[bossId]
        local bConfig = Config.Bosses and Config.Bosses[bossId]
        if not bConfig then continue end

        local _, cardData = BossCard.build(scrollFrame, bossId, bConfig, pData, 0)
        cardData.frame.LayoutOrder = idx
        -- Position managed by UIListLayout, not manual yOffset
        cardData.frame.Position = UDim2.new(0, 0, 0, 0)
        bossCards[bossId] = cardData
    end
end

-- ═══ Open / Close / Toggle ═══
function BossJournal.open()
    if isOpen then return end
    isOpen = true
    mainFrame.Visible = true

    task.spawn(function()
        local data = Remotes.GetBossData:InvokeServer()
        if data then
            bossData = data
            BossJournal.rebuildList()
        end
    end)
end

function BossJournal.close()
    if not isOpen then return end
    isOpen = false
    mainFrame.Visible = false
end

function BossJournal.toggle()
    if isOpen then
        BossJournal.close()
    else
        BossJournal.open()
    end
end

function BossJournal.isOpen()
    return isOpen
end

return BossJournal