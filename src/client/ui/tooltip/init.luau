local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local TC = require(script:WaitForChild("TooltipConstants"))
local TooltipHeader = require(script:WaitForChild("TooltipHeader"))
local TooltipAttributes = require(script:WaitForChild("TooltipAttributes"))
local TooltipDescription = require(script:WaitForChild("TooltipDescription"))
local TooltipFooter = require(script:WaitForChild("TooltipFooter"))

local ItemTooltip = {}

local tooltipGui = nil
local currentTooltip = nil

function ItemTooltip.init(gui)
    -- Создаём отдельный ScreenGui поверх всего
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    tooltipGui = Instance.new("ScreenGui")
    tooltipGui.Name = "TooltipGui"
    tooltipGui.ResetOnSpawn = false
    tooltipGui.DisplayOrder = 999
    tooltipGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    tooltipGui.Parent = playerGui
end

function ItemTooltip.show(itemData, slotFrame)
    ItemTooltip.hide()

    if not itemData or not tooltipGui then return end

    local itemDef = Config.Items[itemData.Id]
    if not itemDef then
        itemDef = itemData
    end

    local tooltip = Instance.new("Frame")
    tooltip.Name = "ItemTooltip"
    tooltip.Size = UDim2.new(0, TC.TOOLTIP_W, 0, 0)
    tooltip.AutomaticSize = Enum.AutomaticSize.Y
    tooltip.BackgroundColor3 = TC.BG_COLOR
    tooltip.BorderSizePixel = 0
    tooltip.Parent = tooltipGui
    tooltip.Position = UDim2.new(0, -9999, 0, -9999)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, TC.CORNER)
    corner.Parent = tooltip

    local stroke = Instance.new("UIStroke")
    stroke.Color = TC.BORDER_COLOR
    stroke.Thickness = TC.BORDER
    stroke.Parent = tooltip

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 0)
    layout.Parent = tooltip

    TooltipHeader.build(tooltip, itemDef, itemData)
    TooltipAttributes.build(tooltip, itemDef, 10)
    TooltipDescription.build(tooltip, itemDef.Description, 20)
    TooltipFooter.build(tooltip, itemDef, itemData, 30)

    currentTooltip = tooltip

    local function positionTooltip()
        if not currentTooltip or currentTooltip ~= tooltip then return end

        local slotAbsPos = slotFrame.AbsolutePosition
        local slotAbsSize = slotFrame.AbsoluteSize
        local viewportSize = tooltipGui.AbsoluteSize
        local tooltipH = tooltip.AbsoluteSize.Y
        local tooltipW = TC.TOOLTIP_W

        local x = slotAbsPos.X + slotAbsSize.X + 8
        local y = slotAbsPos.Y

        if x + tooltipW > viewportSize.X - 4 then
            x = slotAbsPos.X - tooltipW - 8
        end
        if x < 4 then x = 4 end

        if y + tooltipH > viewportSize.Y - 4 then
            y = viewportSize.Y - tooltipH - 4
        end
        if y < 4 then y = 4 end

        tooltip.Position = UDim2.new(0, x, 0, y)
    end

    local conn
    conn = tooltip:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if not currentTooltip or currentTooltip ~= tooltip then
            if conn then conn:Disconnect() end
            return
        end
        positionTooltip("signal")
        if conn then conn:Disconnect() end
    end)

    task.delay(0.05, function()
        if conn and conn.Connected then
            conn:Disconnect()
        end
        positionTooltip("fallback")
    end)
end

function ItemTooltip.hide()
    if currentTooltip then
        currentTooltip:Destroy()
        currentTooltip = nil
    end
end

return ItemTooltip