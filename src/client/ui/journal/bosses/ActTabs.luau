local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local C = require(script.Parent:WaitForChild("BossJournalConstants"))

local ActTabs = {}

local selectedAct = 1
local tabs = {}
local tabsFrame = nil
local onChangeCallback = nil

function ActTabs.init(parent, callback)
    onChangeCallback = callback

    tabsFrame = Instance.new("Frame")
    tabsFrame.Name = "ActTabs"
    tabsFrame.Size = UDim2.new(0.5, 0, 0, 36)
    tabsFrame.AnchorPoint = Vector2.new(0.5, 0)
    tabsFrame.Position = UDim2.new(0.5, 0, 0, 6)
    tabsFrame.BackgroundTransparency = 1
    tabsFrame.ZIndex = 2
    tabsFrame.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = tabsFrame
end

function ActTabs.rebuild(bossData)
    for _, tab in tabs do
        tab:Destroy()
    end
    table.clear(tabs)

    if not bossData then
        return
    end

    -- Collect unique acts
    local acts = {}
    local actSet = {}
    for bossId, _ in bossData do
        local bConfig = Config.Bosses and Config.Bosses[bossId]
        if bConfig then
            local act = bConfig.Act or 1
            if not actSet[act] then
                actSet[act] = true
                table.insert(acts, act)
            end
        end
    end
    table.sort(acts)

    -- If selected act doesn't exist, select first
    if not actSet[selectedAct] and #acts > 0 then
        selectedAct = acts[1]
    end

    -- Create tab buttons
    for i, act in acts do
        local tab = Instance.new("TextButton")
        tab.Name = "ActTab_" .. act
        tab.Size = UDim2.new(0, 100, 0, 32)
        tab.LayoutOrder = i
        tab.Font = Enum.Font.GothamBold
        tab.TextSize = 18
        tab.Text = "Act " .. act
        tab.AutoButtonColor = false
        tab.BorderSizePixel = 0
        tab.Parent = tabsFrame

        Instance.new("UICorner", tab).CornerRadius = UDim.new(0, 6)

        if act == selectedAct then
            tab.BackgroundColor3 = C.ACCENT_COLOR
            tab.TextColor3 = C.TEXT_COLOR
            tab.BackgroundTransparency = 0
        else
            tab.BackgroundColor3 = C.CARD_BG
            tab.TextColor3 = C.TEXT_DIM
            tab.BackgroundTransparency = 0.3
        end

        tab.Activated:Connect(function()
            selectedAct = act
            ActTabs.rebuild(bossData)
            if onChangeCallback then
                onChangeCallback()
            end
        end)

        table.insert(tabs, tab)
    end
end

function ActTabs.getSelectedAct()
    return selectedAct
end

return ActTabs
