local ServantStatsPanel = {}

local PANEL_BG = Color3.fromRGB(35, 35, 50)
local TEXT_COLOR = Color3.fromRGB(200, 200, 220)
local LABEL_COLOR = Color3.fromRGB(140, 140, 160)

local labels = {}

function ServantStatsPanel.build(parent, x, y, w, h)
    local panel = Instance.new("Frame")
    panel.Name = "ServantStatsPanel"
    panel.Size = UDim2.new(0, w, 0, h)
    panel.Position = UDim2.new(0, x, 0, y)
    panel.BackgroundColor3 = PANEL_BG
    panel.BorderSizePixel = 0
    panel.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = panel

    local stats = {
        { key = "level",      display = "Level" },
        { key = "experience", display = "Experience" },
        { key = "hp",         display = "HP" },
        { key = "power",      display = "Power" },
        { key = "atk",        display = "AttackPower" },
        { key = "expertise",  display = "Expertise" },
    }

    local padX = 10
    local rowH = 36
    local startY = 10

    for i, stat in stats do
        local posY = startY + (i - 1) * rowH

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -padX * 2, 0, 16)
        nameLabel.Position = UDim2.new(0, padX, 0, posY)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = LABEL_COLOR
        nameLabel.TextSize = 11
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Text = stat.display
        nameLabel.Parent = panel

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Name = "Value_" .. stat.key
        valueLabel.Size = UDim2.new(1, -padX * 2, 0, 18)
        valueLabel.Position = UDim2.new(0, padX, 0, posY + 14)
        valueLabel.BackgroundTransparency = 1
        valueLabel.TextColor3 = TEXT_COLOR
        valueLabel.TextSize = 15
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextXAlignment = Enum.TextXAlignment.Left
        valueLabel.Text = "—"
        valueLabel.Parent = panel

        labels[stat.key] = valueLabel
    end

    return panel
end

function ServantStatsPanel.refresh(servant)
    if not servant then return end

    if labels.level then
        labels.level.Text = tostring(servant.level or 1)
    end
    if labels.experience then
        labels.experience.Text = tostring(servant.experience or 0)
    end
    if labels.hp then
        labels.hp.Text = servant.hp .. " / " .. servant.maxHP
    end
    if labels.power then
        labels.power.Text = tostring(servant.power or 0)
    end
    if labels.atk then
        labels.atk.Text = tostring(servant.atk or 0)
    end
    if labels.expertise then
        labels.expertise.Text = servant.expertise .. "%"
    end
end

return ServantStatsPanel