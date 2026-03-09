local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local C = require(script.Parent:WaitForChild("BossJournalConstants"))
local BossCard = require(script.Parent:WaitForChild("BossCard"))
local BossTooltip = require(script.Parent:WaitForChild("BossTooltip"))
local ActTabs = require(script.Parent:WaitForChild("ActTabs"))

local BossPage = {}

local bossData = nil
local bossCards = {}
local playerLevel = 1
local pageFrame, scrollFrame
local isVisible = false
local dataLoaded = false

-- ═══ Build ═══
function BossPage.build(contentParent, screenGui)
    BossTooltip.init(screenGui)

    pageFrame = Instance.new("Frame")
    pageFrame.Name = "BossesPage"
    pageFrame.Size = UDim2.new(1, 0, 1, 0)
    pageFrame.BackgroundTransparency = 1
    pageFrame.Visible = false
    pageFrame.Parent = contentParent

    -- Act Tabs
    ActTabs.init(pageFrame, function()
        BossPage._rebuildList()
    end)

    -- Content container
    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "ContentContainer"
    contentContainer.Size = UDim2.new(0.5, 0, 1, -52)
    contentContainer.AnchorPoint = Vector2.new(0.5, 0)
    contentContainer.Size = UDim2.new(0.5, 0, 1, -48)
    contentContainer.Position = UDim2.new(0.5, 0, 0, 44)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Parent = pageFrame

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

    -- Remote listeners
    Remotes.BossFinishResult.OnClientEvent:Connect(function(result)
        if not bossData then return end
        local bossId = result.BossId
        if bossData[bossId] then
            bossData[bossId].Essence = result.Essence
            if result.FirstKill then
                bossData[bossId].TechUnlocked = true
            end
        end
        if isVisible then BossPage._rebuildList() end
    end)

    Remotes.BossCaptureResult.OnClientEvent:Connect(function(result)
        if not bossData then return end
        if result.Success and result.BossId and bossData[result.BossId] then
            bossData[result.BossId].Captured = true
        end
        if isVisible then BossPage._rebuildList() end
    end)

    Remotes.UpdateLevel.OnClientEvent:Connect(function(data)
        if data and data.Level then
            playerLevel = data.Level
            if isVisible then BossPage._rebuildList() end
        end
    end)
end

-- ═══ Rebuild list ═══
function BossPage._rebuildList()
    for _, entry in bossCards do
        if entry.frame then entry.frame:Destroy() end
    end
    table.clear(bossCards)

    if not bossData or not scrollFrame then return end

    for _, child in scrollFrame:GetChildren() do
        if child:IsA("UIListLayout") or child:IsA("UIPadding") then
            child:Destroy()
        end
    end

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, C.CARD_PADDING)
    listLayout.Parent = scrollFrame

    local listPadding = Instance.new("UIPadding")
    listPadding.PaddingTop = UDim.new(0, C.CARD_PADDING)
    listPadding.PaddingBottom = UDim.new(0, C.CARD_PADDING)
    listPadding.Parent = scrollFrame

    local currentAct = ActTabs.getSelectedAct()
    local sortedIds = {}
    for bossId, _ in bossData do
        local bConfig = Config.Bosses and Config.Bosses[bossId]
        if bConfig and (bConfig.Act or 1) == currentAct then
            table.insert(sortedIds, bossId)
        end
    end
    table.sort(sortedIds, function(a, b)
        return (Config.Bosses[a].Level or 1) < (Config.Bosses[b].Level or 1)
    end)

    for idx, bossId in sortedIds do
        local pData = bossData[bossId]
        local bConfig = Config.Bosses[bossId]
        if not bConfig then continue end

        local isLocked = (bConfig.Level or 0) - playerLevel > 10
        local _, cardData = BossCard.build(scrollFrame, bossId, bConfig, pData, 0, isLocked)
        cardData.frame.LayoutOrder = idx
        cardData.frame.Position = UDim2.new(0, 0, 0, 0)
        bossCards[bossId] = cardData
    end
end

-- ═══ Page lifecycle ═══
function BossPage.setVisible(visible)
    isVisible = visible
    if pageFrame then
        pageFrame.Visible = visible
    end
end

function BossPage.onActivate()
    if not dataLoaded then
        task.spawn(function()
            local data = Remotes.GetBossData:InvokeServer()
            if data then
                bossData = data
                dataLoaded = true
                ActTabs.rebuild(bossData)
                BossPage._rebuildList()
            end
        end)
    end
end

function BossPage.onDeactivate()
    -- nothing needed
end

return BossPage