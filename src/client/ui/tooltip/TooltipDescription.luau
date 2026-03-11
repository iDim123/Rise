local TC = require(script.Parent:WaitForChild("TooltipConstants"))

local TooltipDescription = {}

function TooltipDescription.build(parent, description, layoutOrder)
    if not description or description == "" then return nil end

    local wrapper = Instance.new("Frame")
    wrapper.Name = "Description"
    wrapper.Size = UDim2.new(1, 0, 0, 0)
    wrapper.AutomaticSize = Enum.AutomaticSize.Y
    wrapper.BackgroundTransparency = 1
    wrapper.LayoutOrder = layoutOrder
    wrapper.Parent = parent

    local wPad = Instance.new("UIPadding")
    wPad.PaddingLeft = UDim.new(0, TC.PAD)
    wPad.PaddingRight = UDim.new(0, TC.PAD)
    wPad.PaddingTop = UDim.new(0, 4)
    wPad.PaddingBottom = UDim.new(0, 6)
    wPad.Parent = wrapper

    local descBg = Instance.new("Frame")
    descBg.Name = "DescBg"
    descBg.Size = UDim2.new(1, 0, 0, 0)
    descBg.AutomaticSize = Enum.AutomaticSize.Y
    descBg.BackgroundColor3 = TC.DESC_BG
    descBg.BorderSizePixel = 0
    descBg.Parent = wrapper

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 4)
    bgCorner.Parent = descBg

    local bgPad = Instance.new("UIPadding")
    bgPad.PaddingLeft = UDim.new(0, 8)
    bgPad.PaddingRight = UDim.new(0, 8)
    bgPad.PaddingTop = UDim.new(0, 6)
    bgPad.PaddingBottom = UDim.new(0, 6)
    bgPad.Parent = descBg

    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "DescText"
    descLabel.Size = UDim2.new(1, 0, 0, 0)
    descLabel.AutomaticSize = Enum.AutomaticSize.Y
    descLabel.BackgroundTransparency = 1
    descLabel.TextColor3 = TC.DESC_COLOR
    descLabel.TextSize = 12
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextWrapped = true
    descLabel.Text = description
    descLabel.Parent = descBg

    return wrapper
end

return TooltipDescription