local ServantCollection = {}

local HEADER_H = 24
local ROW_H = 30
local PAD = 2
local BG_COLOR = Color3.fromRGB(30, 30, 42)
local ROW_COLOR = Color3.fromRGB(40, 40, 55)
local ROW_ACTIVE = Color3.fromRGB(55, 55, 35)
local ROW_SELECTED = Color3.fromRGB(50, 50, 75)
local TEXT_COLOR = Color3.fromRGB(200, 200, 220)
local GOLD_COLOR = Color3.fromRGB(220, 190, 80)
local HEADER_COLOR = Color3.fromRGB(140, 140, 160)

local scrollFrame = nil
local rows = {}

-- Column definitions: x offset, width, key
local columns = {
    { x = 4,   w = 20,  key = "fav",       header = "★" },
    { x = 28,  w = 30,  key = "level",     header = "Lvl" },
    { x = 62,  w = 50,  key = "power",     header = "Power" },
    { x = 116, w = 60,  key = "expertise", header = "Expertise" },
    { x = 180, w = 200, key = "name",      header = "Name" },
}

function ServantCollection.build(parent, x, y, w, h)
    local container = Instance.new("Frame")
    container.Name = "CollectionContainer"
    container.Size = UDim2.new(0, w, 0, h)
    container.Position = UDim2.new(0, x, 0, y)
    container.BackgroundColor3 = BG_COLOR
    container.BorderSizePixel = 0
    container.ClipsDescendants = true
    container.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = container

    -- Header row
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, 0, 0, HEADER_H)
    headerFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    headerFrame.BorderSizePixel = 0
    headerFrame.Parent = container

    for _, col in columns do
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, col.w, 1, 0)
        label.Position = UDim2.new(0, col.x, 0, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = HEADER_COLOR
        label.TextSize = 11
        label.Font = Enum.Font.GothamBold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = col.header
        label.Parent = headerFrame
    end

    -- Scroll area
    scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 1, -HEADER_H)
    scrollFrame.Position = UDim2.new(0, 0, 0, HEADER_H)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130)
    scrollFrame.Parent = container

    return container
end

function ServantCollection.refresh(captured, activeId, selectedId, onSelect)
    -- Clear old rows
    for _, row in rows do
        row:Destroy()
    end
    rows = {}

    if not captured then return end

    local totalH = 0
    for i, servant in captured do
        local isActive = servant.id == activeId
        local isSelected = servant.id == selectedId

        local bgColor = ROW_COLOR
        if isActive then bgColor = ROW_ACTIVE end
        if isSelected then bgColor = ROW_SELECTED end

        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -4, 0, ROW_H)
        row.Position = UDim2.new(0, 2, 0, totalH)
        row.BackgroundColor3 = bgColor
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = scrollFrame

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 3)
        rowCorner.Parent = row

        if isActive then
            local stroke = Instance.new("UIStroke")
            stroke.Color = GOLD_COLOR
            stroke.Thickness = 1
            stroke.Parent = row
        end

        for _, col in columns do
            local text = ""
            local color = TEXT_COLOR

            if col.key == "fav" then
                text = servant.favorite and "★" or ""
                color = GOLD_COLOR
            elseif col.key == "level" then
                text = tostring(servant.level or 1)
            elseif col.key == "power" then
                text = tostring(servant.power or 0)
            elseif col.key == "expertise" then
                text = servant.expertise .. "%"
            elseif col.key == "name" then
                text = servant.name
            end

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0, col.w, 1, 0)
            label.Position = UDim2.new(0, col.x, 0, 0)
            label.BackgroundTransparency = 1
            label.TextColor3 = color
            label.TextSize = 12
            label.Font = Enum.Font.Gotham
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Text = text
            label.Parent = row
        end

        row.MouseButton1Click:Connect(function()
            if onSelect then
                onSelect(servant)
            end
        end)

        table.insert(rows, row)
        totalH = totalH + ROW_H + PAD
    end

    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalH)
end

return ServantCollection