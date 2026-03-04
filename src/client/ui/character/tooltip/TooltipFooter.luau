local TC = require(script.Parent:WaitForChild("TooltipConstants"))

local TooltipFooter = {}

function TooltipFooter.build(parent, itemDef, itemData, layoutOrder)
    if not itemDef.Stackable then return nil end

    local amount = itemData.Amount or 1
    local maxStack = itemDef.MaxStack or 1

    local footer = Instance.new("Frame")
    footer.Name = "Footer"
    footer.Size = UDim2.new(1, 0, 0, 24)
    footer.BackgroundTransparency = 1
    footer.LayoutOrder = layoutOrder
    footer.Parent = parent

    local fPad = Instance.new("UIPadding")
    fPad.PaddingLeft = UDim.new(0, TC.PAD)
    fPad.PaddingRight = UDim.new(0, TC.PAD)
    fPad.Parent = footer

    local fLabel = Instance.new("TextLabel")
    fLabel.Size = UDim2.new(1, 0, 1, 0)
    fLabel.BackgroundTransparency = 1
    fLabel.TextColor3 = TC.FOOTER_COLOR
    fLabel.TextSize = 11
    fLabel.Font = Enum.Font.Gotham
    fLabel.TextXAlignment = Enum.TextXAlignment.Left
    fLabel.Text = "Stackable (" .. tostring(amount) .. "/" .. tostring(maxStack) .. ")"
    fLabel.Parent = footer

    return footer
end

return TooltipFooter