local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local TierProgressBar = {}

local barFrame = nil
local markers = {}
local fillFrame = nil

local TIER_NAMES = {"I", "II", "III", "UTL"}

function TierProgressBar.build(parent)
    barFrame = Instance.new("Frame")
    barFrame.Name = "TierProgressBar"
    barFrame.Size = UDim2.new(1, 0, 0, C.TIER_BAR_H)
    barFrame.BackgroundTransparency = 1
    barFrame.Parent = parent

    -- "Tier" label
    local tierLabel = Instance.new("TextLabel")
    tierLabel.Size = UDim2.new(0, C.TIER_LABEL_W, 0, 20)
    tierLabel.Position = UDim2.new(0, 0, 0.5, -10)
    tierLabel.BackgroundTransparency = 1
    tierLabel.Font = Enum.Font.Gotham
    tierLabel.TextSize = 12
    tierLabel.TextColor3 = C.TEXT_DIM
    tierLabel.Text = "Tier"
    tierLabel.TextXAlignment = Enum.TextXAlignment.Left
    tierLabel.Parent = barFrame

    -- Progress line
    local lineX = C.TIER_LABEL_W + 10
    local lineW = -lineX - 10

    local lineBg = Instance.new("Frame")
    lineBg.Name = "LineBg"
    lineBg.Size = UDim2.new(1, lineW, 0, 4)
    lineBg.Position = UDim2.new(0, lineX, 0.5, -2)
    lineBg.BackgroundColor3 = C.TIER_MARKER_DIM
    lineBg.BorderSizePixel = 0
    lineBg.Parent = barFrame

    Instance.new("UICorner", lineBg).CornerRadius = UDim.new(0, 2)

    fillFrame = Instance.new("Frame")
    fillFrame.Name = "Fill"
    fillFrame.Size = UDim2.new(0, 0, 1, 0)
    fillFrame.BackgroundColor3 = C.TIER_MARKER
    fillFrame.BorderSizePixel = 0
    fillFrame.Parent = lineBg

    Instance.new("UICorner", fillFrame).CornerRadius = UDim.new(0, 2)

    -- Tier markers (labels above the line)
    for i, name in TIER_NAMES do
        local xRatio = (i - 1) / (#TIER_NAMES - 1)

        local marker = Instance.new("TextLabel")
        marker.Name = "Marker_" .. name
        marker.Size = UDim2.new(0, 40, 0, 16)
        marker.AnchorPoint = Vector2.new(0.5, 1)
        marker.Position = UDim2.new(xRatio, 0, 0, -6) -- relative to lineBg
        marker.BackgroundTransparency = 1
        marker.Font = Enum.Font.GothamBold
        marker.TextSize = 12
        marker.TextColor3 = C.TEXT_DIM
        marker.Text = name
        marker.Parent = lineBg

        markers[i] = marker
    end

    return barFrame
end

-- progress: 0 = nothing, 1 = tier 1 reached, 2 = tier 2 reached, 3 = tier 3, 4 = ultimate
function TierProgressBar.refresh(tierReached)
    tierReached = tierReached or 0

    local fillRatio = math.clamp(tierReached / (#TIER_NAMES - 1), 0, 1)
    if fillFrame then
        fillFrame.Size = UDim2.new(fillRatio, 0, 1, 0)
    end

    for i, marker in markers do
        local reached = (i - 1) <= tierReached
        marker.TextColor3 = reached and C.TEXT_COLOR or C.TEXT_DIM
    end
end

return TierProgressBar
