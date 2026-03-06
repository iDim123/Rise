local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BossTooltip = {}

local C = require(script.Parent:WaitForChild("BossJournalConstants"))

local tooltip = nil
local titleLabel = nil
local descLabel = nil

function BossTooltip.init(screenGui)
    tooltip = Instance.new("Frame")
    tooltip.Name = "BossTooltip"
    tooltip.Size = UDim2.new(0, 220, 0, 0) -- height auto
    tooltip.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    tooltip.BorderSizePixel = 0
    tooltip.Visible = false
    tooltip.ZIndex = 100
    tooltip.Parent = screenGui

    Instance.new("UICorner", tooltip).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke")
    stroke.Color = C.STROKE_COLOR
    stroke.Thickness = 1
    stroke.Parent = tooltip

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = tooltip

    titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 18)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = C.TEXT_COLOR
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 101
    titleLabel.Parent = tooltip

    descLabel = Instance.new("TextLabel")
    descLabel.Name = "Desc"
    descLabel.Size = UDim2.new(1, 0, 0, 0)
    descLabel.Position = UDim2.new(0, 0, 0, 22)
    descLabel.BackgroundTransparency = 1
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 12
    descLabel.TextColor3 = C.TEXT_DIM
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.TextWrapped = true
    descLabel.ZIndex = 101
    descLabel.Parent = tooltip
end

function BossTooltip.show(guiObject, name, description)
    if not tooltip then
        return
    end

    titleLabel.Text = name or ""

    local hasDesc = description and description ~= ""
    if hasDesc then
        descLabel.Text = description
        descLabel.Visible = true
        -- Auto-size description
        local textBounds = game:GetService("TextService"):GetTextSize(description, 12, Enum.Font.Gotham,
            Vector2.new(200, 1000))
        descLabel.Size = UDim2.new(1, 0, 0, textBounds.Y)
        tooltip.Size = UDim2.new(0, 220, 0, 22 + textBounds.Y + 16)
    else
        descLabel.Visible = false
        tooltip.Size = UDim2.new(0, 220, 0, 34)
    end

    -- Position above the icon
    local absPos = guiObject.AbsolutePosition
    local absSize = guiObject.AbsoluteSize
    local tooltipWidth = tooltip.Size.X.Offset
    local tooltipHeight = tooltip.Size.Y.Offset

    local guiService = game:GetService("GuiService")
    local inset = guiService:GetGuiInset()

    tooltip.Position = UDim2.new(0, absPos.X + absSize.X / 2 - tooltipWidth / 2 + inset.X, 0,
        absPos.Y - tooltipHeight - 6 + inset.Y)

    tooltip.Visible = true
end

function BossTooltip.hide()
    if tooltip then
        tooltip.Visible = false
    end
end

function BossTooltip.attach(guiObject, name, description)
    guiObject.MouseEnter:Connect(function()
        BossTooltip.show(guiObject, name, description)
    end)
    guiObject.MouseLeave:Connect(function()
        BossTooltip.hide()
    end)
end

return BossTooltip
