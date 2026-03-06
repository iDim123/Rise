local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local UC = require(script.Parent:WaitForChild("UIConstants"))
local AttributesPanel = {}

local panelFrame = nil
local statRows = {}      -- [statId] = { row, valueLabel }
local tooltipFrame = nil  -- tooltip справа от окна
local currentStats = {}

-- ═══ Constants ═══
local ROW_HEIGHT = 26
local ROW_PAD = 2
local LABEL_FONT = Enum.Font.Gotham
local VALUE_FONT = Enum.Font.GothamBold
local TEXT_SIZE = 13
local TEXT_COLOR = Color3.fromRGB(220, 220, 220)
local VALUE_COLOR = Color3.fromRGB(255, 255, 200)
local ROW_BG_1 = Color3.fromRGB(35, 35, 50)
local ROW_BG_2 = Color3.fromRGB(30, 30, 42)
local HEADER_COLOR = Color3.fromRGB(180, 180, 200)

local TOOLTIP_WIDTH = 220
local TOOLTIP_BG = Color3.fromRGB(20, 20, 30)
local TOOLTIP_BORDER = Color3.fromRGB(80, 80, 100)
local TOOLTIP_TEXT = Color3.fromRGB(220, 220, 220)
local TOOLTIP_DESC = Color3.fromRGB(160, 160, 180)

-- ═══ Format value ═══
local function formatValue(statId, value)
	local def = Config.Stats[statId]
	if not def then return tostring(value) end

	if def.Format == "flat" then
		return tostring(math.floor(value))
	elseif def.Format == "resist" then
		return string.format("%.1f%%", value)
	elseif def.Format == "percent" then
		-- CritChance: 0.05 → "5%"
		-- CritDamage: 1.50 → "150%"
		-- MoveSpeed: 1.00 → "100%"
		return string.format("%.0f%%", value * 100)
	end

	return tostring(math.floor(value))
end

-- ═══ Tooltip ═══
local function createTooltip(screenGui)
	local frame = Instance.new("Frame")
	frame.Name = "StatsTooltip"
	frame.BackgroundColor3 = TOOLTIP_BG
	frame.Size = UDim2.new(0, TOOLTIP_WIDTH, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Visible = false
	frame.ZIndex = 200
	frame.Parent = screenGui

	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

	local stroke = Instance.new("UIStroke")
	stroke.Color = TOOLTIP_BORDER
	stroke.Thickness = 1
	stroke.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 18)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = TOOLTIP_TEXT
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.LayoutOrder = 1
	titleLabel.ZIndex = 201
	titleLabel.Parent = frame

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Desc"
	descLabel.BackgroundTransparency = 1
	descLabel.Size = UDim2.new(1, 0, 0, 0)
	descLabel.AutomaticSize = Enum.AutomaticSize.Y
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 12
	descLabel.TextColor3 = TOOLTIP_DESC
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.LayoutOrder = 2
	descLabel.ZIndex = 201
	descLabel.Parent = frame

	return frame
end

local function showTooltip(statId, rowFrame)
	if not tooltipFrame then return end
	local def = Config.Stats[statId]
	if not def then return end

	tooltipFrame.Title.Text = def.Name
	tooltipFrame.Desc.Text = def.Description or ""

	-- Позиция: справа от окна персонажа, на уровне строки
	local absPos = rowFrame.AbsolutePosition
	local windowFrame = panelFrame.Parent -- mainFrame
	local windowAbsPos = windowFrame.AbsolutePosition
	local windowAbsSize = windowFrame.AbsoluteSize

	local x = windowAbsPos.X + windowAbsSize.X + 6
	local y = absPos.Y

	-- Clamp to screen
	local viewportSize = workspace.CurrentCamera.ViewportSize
	if x + TOOLTIP_WIDTH > viewportSize.X - 4 then
		x = windowAbsPos.X - TOOLTIP_WIDTH - 6
	end

	tooltipFrame.Position = UDim2.new(0, x, 0, y)
	tooltipFrame.Visible = true
end

local function hideTooltip()
	if tooltipFrame then
		tooltipFrame.Visible = false
	end
end

-- ═══ Build ═══
function AttributesPanel.build(parent, contentY, screenGui)
	panelFrame = Instance.new("ScrollingFrame")
	panelFrame.Name = "AttributesPanel"
	panelFrame.Position = UDim2.new(0, UC.windowPadX, 0, contentY)
	panelFrame.Size = UDim2.new(0, UC.contentWidth, 0, UC.contentH)
	panelFrame.ScrollBarThickness = 4
	panelFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
	panelFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	panelFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panelFrame.Visible = false
	panelFrame.Parent = parent
	panelFrame.BackgroundColor3 = UC.panelBg
	panelFrame.BackgroundTransparency = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panelFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ROW_PAD)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panelFrame

	-- Header
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 18
	header.TextColor3 = HEADER_COLOR
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "Stats"
	header.LayoutOrder = 0
	header.Parent = panelFrame

	-- Build rows from DisplayOrder
	local displayOrder = Config.Stats and Config.DisplayOrder or {}
	for i, statId in displayOrder do
		local def = Config.Stats[statId]
		if not def then continue end

		local rowBg = (i % 2 == 0) and ROW_BG_1 or ROW_BG_2

		local row = Instance.new("Frame")
		row.Name = "Row_" .. statId
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.BackgroundColor3 = rowBg
		row.BackgroundTransparency = 0.3
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = panelFrame

		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 3)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.7, -8, 1, 0)
		nameLabel.Position = UDim2.new(0, 8, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = LABEL_FONT
		nameLabel.TextSize = TEXT_SIZE
		nameLabel.TextColor3 = TEXT_COLOR
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = def.Name
		nameLabel.Parent = row

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Name = "Value"
		valueLabel.Size = UDim2.new(0.3, -8, 1, 0)
		valueLabel.Position = UDim2.new(0.7, 0, 0, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Font = VALUE_FONT
		valueLabel.TextSize = TEXT_SIZE
		valueLabel.TextColor3 = VALUE_COLOR
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Text = "—"
		valueLabel.Parent = row

		statRows[statId] = { row = row, valueLabel = valueLabel }

		-- Hover tooltip
		row.MouseEnter:Connect(function()
			showTooltip(statId, row)
		end)
		row.MouseLeave:Connect(function()
			hideTooltip()
		end)
	end

	-- Create tooltip in screenGui
	tooltipFrame = createTooltip(screenGui)

	return panelFrame
end

-- ═══ Refresh ═══
function AttributesPanel.refresh(stats)
	if not stats then return end
	currentStats = stats

	for statId, data in statRows do
		local value = stats[statId]
		if value then
			data.valueLabel.Text = formatValue(statId, value)
		else
			data.valueLabel.Text = "—"
		end
	end
end

-- ═══ Visibility ═══
function AttributesPanel.setVisible(visible)
	if panelFrame then
		panelFrame.Visible = visible
	end
	if not visible then
		hideTooltip()
	end
end

-- ═══ Listen for updates ═══
function AttributesPanel.connectRemote()
	Remotes.UpdateStats.OnClientEvent:Connect(function(stats)
		AttributesPanel.refresh(stats)
	end)

	-- Initial load
	task.spawn(function()
		local stats = Remotes.GetPlayerStats:InvokeServer()
		if stats then
			AttributesPanel.refresh(stats)
		end
	end)
end

return AttributesPanel