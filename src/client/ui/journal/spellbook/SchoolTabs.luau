local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SchoolTabs = {}

local tabButtons = {}
local selectedSchool = nil
local onSelectCallback = nil
local container = nil

function SchoolTabs.build(parent)
    container = Instance.new("Frame")
    container.Name = "SchoolTabs"
    container.Size = UDim2.new(1, 0, 0, C.SCHOOL_TAB_H)
    container.Position = UDim2.new(0, 0, 0, 0)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, C.CONTENT_PAD)
    pad.PaddingTop = UDim.new(0, 4)
    pad.Parent = container

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Parent = container

    local schoolIds = {}
    for schoolId, _ in SpellConfig.MagicSchools do
        table.insert(schoolIds, schoolId)
    end
    table.sort(schoolIds)

    for i, schoolId in schoolIds do
        local school = SpellConfig.MagicSchools[schoolId]
        local accent = C.SCHOOL_ACCENTS[schoolId] or C.STROKE_COLOR

        local btn = Instance.new("TextButton")
        btn.Name = "SchoolTab_" .. schoolId
        btn.Size = UDim2.new(0, C.SCHOOL_TAB_W, 0, C.SCHOOL_TAB_H - 8)
        btn.BackgroundColor3 = C.TAB_INACTIVE
        btn.AutoButtonColor = false
        btn.Text = school.Name
        btn.TextColor3 = C.TEXT_DIM
        btn.TextSize = 16
        btn.Font = Enum.Font.GothamBold
        btn.LayoutOrder = i
        btn.Parent = container

        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        local stroke = Instance.new("UIStroke")
        stroke.Name = "AccentStroke"
        stroke.Color = accent
        stroke.Thickness = 0
        stroke.Parent = btn

        tabButtons[schoolId] = {
            button = btn,
            accent = accent,
            stroke = stroke
        }

        btn.Activated:Connect(function()
            SchoolTabs.select(schoolId)
        end)

        btn.MouseEnter:Connect(function()
            if selectedSchool ~= schoolId then
                btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
            end
        end)

        btn.MouseLeave:Connect(function()
            if selectedSchool ~= schoolId then
                btn.BackgroundColor3 = C.TAB_INACTIVE
            end
        end)
    end

    return container
end

function SchoolTabs.select(schoolId)
    if selectedSchool == schoolId then
        return
    end
    selectedSchool = schoolId

    for id, data in tabButtons do
        if id == schoolId then
            data.button.BackgroundColor3 = C.TAB_ACTIVE
            data.button.TextColor3 = C.TEXT_COLOR
            data.stroke.Thickness = 2
        else
            data.button.BackgroundColor3 = C.TAB_INACTIVE
            data.button.TextColor3 = C.TEXT_DIM
            data.stroke.Thickness = 0
        end
    end

    if onSelectCallback then
        onSelectCallback(schoolId)
    end
end

function SchoolTabs.onSelect(callback)
    onSelectCallback = callback
end

function SchoolTabs.getSelected()
    return selectedSchool
end

function SchoolTabs.selectFirst()
    local schoolIds = {}
    for schoolId in SpellConfig.MagicSchools do
        table.insert(schoolIds, schoolId)
    end
    table.sort(schoolIds)
    if #schoolIds > 0 then
        SchoolTabs.select(schoolIds[1])
    end
end

return SchoolTabs
