local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local TC = require(script.Parent:WaitForChild("TooltipConstants"))

local TooltipAttributes = {}

local STAT_LABELS = {
    Defense     = "Defense",
    Attack      = "Attack",
    Health      = "Health",
    Strength    = "Strength",
    Agility     = "Agility",
    Intelligence = "Intelligence",
}

local function addRow(parent, label, value, order)
    local row = Instance.new("Frame")
    row.Name = "Row_" .. label
    row.Size = UDim2.new(1, 0, 0, 18)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0, 50, 1, 0)
    valLabel.Position = UDim2.new(0, 0, 0, 0)
    valLabel.BackgroundTransparency = 1
    valLabel.TextColor3 = TC.ATTR_NUM_COLOR
    valLabel.TextSize = 13
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextXAlignment = Enum.TextXAlignment.Left
    valLabel.Text = value
    valLabel.Parent = row

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -54, 1, 0)
    nameLabel.Position = UDim2.new(0, 54, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = TC.ATTR_VALUE_COLOR
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = label
    nameLabel.Parent = row

    return row
end

function TooltipAttributes.build(parent, itemDef, layoutOrder)
    local hasContent = false
    local stats = itemDef.Stats
    local effect = itemDef.UseEffect
    local weaponConfig = itemDef.Type == "Weapon" and Config.Weapons and Config.Weapons[itemDef.Id]

    if stats then
        for _, _ in stats do hasContent = true; break end
    end
    if effect then hasContent = true end
    if weaponConfig then hasContent = true end

    if not hasContent then return nil end

    -- Separator
    local sep = Instance.new("Frame")
    sep.Name = "Separator"
    sep.Size = UDim2.new(1, -TC.PAD * 2, 0, 1)
    sep.Position = UDim2.new(0, TC.PAD, 0, 0)
    sep.BackgroundColor3 = TC.SEPARATOR_COLOR
    sep.BorderSizePixel = 0
    sep.LayoutOrder = layoutOrder
    sep.Parent = parent

    local container = Instance.new("Frame")
    container.Name = "Attributes"
    container.Size = UDim2.new(1, 0, 0, 0)
    container.AutomaticSize = Enum.AutomaticSize.Y
    container.BackgroundTransparency = 1
    container.LayoutOrder = layoutOrder + 1
    container.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)
    layout.Parent = container

    local cPad = Instance.new("UIPadding")
    cPad.PaddingLeft = UDim.new(0, TC.PAD)
    cPad.PaddingRight = UDim.new(0, TC.PAD)
    cPad.PaddingTop = UDim.new(0, 6)
    cPad.PaddingBottom = UDim.new(0, 6)
    cPad.Parent = container

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "AttrTitle"
    title.Size = UDim2.new(1, 0, 0, 16)
    title.BackgroundTransparency = 1
    title.TextColor3 = TC.ATTR_TITLE_COLOR
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Attributes"
    title.LayoutOrder = 0
    title.Parent = container

    local rowOrder = 1

    -- Stats
    if stats then
        for statName, statValue in stats do
            local displayName = STAT_LABELS[statName] or statName
            local sign = statValue >= 0 and "+" or ""
            addRow(container, displayName, sign .. tostring(statValue), rowOrder)
            rowOrder += 1
        end
    end

    -- Weapon damage
    if weaponConfig then
        addRow(container, "Physical Power", tostring(weaponConfig.Damage or 0), rowOrder)
        rowOrder += 1
        if weaponConfig.Cooldown then
            addRow(container, "Attack Speed", tostring(weaponConfig.Cooldown) .. "s", rowOrder)
            rowOrder += 1
        end
    end

    -- Use effects
    if effect then
        if effect.Type == "Heal" and effect.Amount then
            addRow(container, "Restores Health", "+" .. tostring(effect.Amount), rowOrder)
            rowOrder += 1
        end
        if effect.Cooldown then
            addRow(container, "Cooldown", tostring(effect.Cooldown) .. "s", rowOrder)
            rowOrder += 1
        end
    end

    return container
end

return TooltipAttributes