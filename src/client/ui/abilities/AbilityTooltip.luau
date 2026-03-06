local AbilityTooltip = {}

local TOOLTIP_WIDTH = 220
local TOOLTIP_PAD = 10
local TOOLTIP_BG = Color3.fromRGB(20, 20, 20)
local TOOLTIP_BORDER = Color3.fromRGB(100, 100, 100)
local TOOLTIP_TEXT = Color3.fromRGB(230, 230, 230)
local TOOLTIP_SUB = Color3.fromRGB(160, 160, 160)
local TOOLTIP_CORNER = 8

local tooltipFrame = nil
local hoveredKey = nil

local function ensureFrame(screenGui)
    if tooltipFrame then return tooltipFrame end

    local frame = Instance.new("Frame")
    frame.Name = "AbilityTooltip"
    frame.BackgroundColor3 = TOOLTIP_BG
    frame.Size = UDim2.new(0, TOOLTIP_WIDTH, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Visible = false
    frame.ZIndex = 100
    frame.Parent = screenGui

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, TOOLTIP_CORNER)

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

    tooltipFrame = frame
    return frame
end

function AbilityTooltip.show(screenGui, key, ability, slotFrame, slotSize)
    if not ability then return end
    local frame = ensureFrame(screenGui)

    frame.Title.Text = ability.Name or ability.Id
    frame.Description.Text = ability.Description or ""

    if key == "LMB" then
        frame.Cooldown.Text = ""
        frame.Cooldown.Visible = false
    else
        frame.Cooldown.Text = "Cooldown: " .. (ability.Cooldown or 0) .. "s"
        frame.Cooldown.Visible = true
    end

    local absPos = slotFrame.AbsolutePosition
    local viewportSize = workspace.CurrentCamera.ViewportSize
    local x = absPos.X + slotSize / 2 - TOOLTIP_WIDTH / 2
    x = math.clamp(x, 4, viewportSize.X - TOOLTIP_WIDTH - 4)

    frame.Position = UDim2.new(0, x, 0, absPos.Y - 80)
    frame.Visible = true
    hoveredKey = key

    task.defer(function()
        if not frame.Visible then return end
        local h = frame.AbsoluteSize.Y
        frame.Position = UDim2.new(0, x, 0, absPos.Y - h - 8)
    end)
end

function AbilityTooltip.hide()
    if tooltipFrame then tooltipFrame.Visible = false end
    hoveredKey = nil
end

function AbilityTooltip.getHoveredKey()
    return hoveredKey
end

return AbilityTooltip