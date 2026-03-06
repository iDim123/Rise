local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UC = require(script.Parent:WaitForChild("UIConstants"))

local BloodPoolPanel = {}

local panelFrame = nil
local player = Players.LocalPlayer

-- UI refs
local bloodIconImage = nil
local bloodTypeLabel = nil
local bloodAmountLabel = nil
local qualityLabel = nil
local qualityBar = nil
local tierMarkers = {}   -- { I = frame, II = frame, MAX = frame }
local bonusLabels = {}   -- { frame, ... }

-- ═══ Constants ═══
local TEXT_COLOR = Color3.fromRGB(220, 220, 220)
local DIM_COLOR = Color3.fromRGB(120, 120, 130)
local ACTIVE_COLOR = Color3.fromRGB(255, 255, 200)
local BAR_BG = Color3.fromRGB(30, 30, 42)
local BAR_FILL = Color3.fromRGB(180, 30, 30)
local BAR_HEIGHT = 14
local TIER_LABEL_COLOR = Color3.fromRGB(180, 180, 180)

-- ═══ Helper: calc bonus ═══
local function calcTierBonus(tierData, quality)
	local qMin = tierData.QualityRange[1]
	local qMax = tierData.QualityRange[2]
	local t = math.clamp((quality - qMin) / math.max(qMax - qMin, 1), 0, 1)
	return tierData.Min + (tierData.Max - tierData.Min) * t
end

-- ═══ Build ═══
function BloodPoolPanel.build(parent, contentY)
	panelFrame = Instance.new("ScrollingFrame")
	panelFrame.Name = "BloodPoolPanel"
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
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panelFrame

	-- ── Row 1: Header (icon + type + amount) ──
	local headerRow = Instance.new("Frame")
	headerRow.Name = "HeaderRow"
	headerRow.Size = UDim2.new(1, 0, 0, 50)
	headerRow.BackgroundTransparency = 1
	headerRow.LayoutOrder = 1
	headerRow.Parent = panelFrame

	bloodIconImage = Instance.new("ImageLabel")
	bloodIconImage.Name = "BloodIcon"
	bloodIconImage.Size = UDim2.new(0, 46, 0, 46)
	bloodIconImage.Position = UDim2.new(0, 0, 0, 2)
	bloodIconImage.BackgroundTransparency = 1
	bloodIconImage.ScaleType = Enum.ScaleType.Fit
	bloodIconImage.Parent = headerRow

	local infoFrame = Instance.new("Frame")
	infoFrame.Size = UDim2.new(1, -56, 1, 0)
	infoFrame.Position = UDim2.new(0, 56, 0, 0)
	infoFrame.BackgroundTransparency = 1
	infoFrame.Parent = headerRow

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 22)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 16
	titleLabel.TextColor3 = TEXT_COLOR
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "Blood Pool"
	titleLabel.Parent = infoFrame

	bloodTypeLabel = Instance.new("TextLabel")
	bloodTypeLabel.Name = "BloodType"
	bloodTypeLabel.Size = UDim2.new(0.5, 0, 0, 22)
	bloodTypeLabel.Position = UDim2.new(0.5, 0, 0, 0)
	bloodTypeLabel.BackgroundTransparency = 1
	bloodTypeLabel.Font = Enum.Font.GothamBold
	bloodTypeLabel.TextSize = 16
	bloodTypeLabel.TextColor3 = TEXT_COLOR
	bloodTypeLabel.TextXAlignment = Enum.TextXAlignment.Right
	bloodTypeLabel.Text = ""
	bloodTypeLabel.Parent = infoFrame

	bloodAmountLabel = Instance.new("TextLabel")
	bloodAmountLabel.Name = "Amount"
	bloodAmountLabel.Size = UDim2.new(1, 0, 0, 18)
	bloodAmountLabel.Position = UDim2.new(0, 0, 0, 24)
	bloodAmountLabel.BackgroundTransparency = 1
	bloodAmountLabel.Font = Enum.Font.Gotham
	bloodAmountLabel.TextSize = 13
	bloodAmountLabel.TextColor3 = DIM_COLOR
	bloodAmountLabel.TextXAlignment = Enum.TextXAlignment.Left
	bloodAmountLabel.Text = "0 / 100 Liters"
	bloodAmountLabel.Parent = infoFrame

	-- ── Row 2: Quality bar ──
	local qualityRow = Instance.new("Frame")
	qualityRow.Name = "QualityRow"
	qualityRow.Size = UDim2.new(1, 0, 0, 40)
	qualityRow.BackgroundTransparency = 1
	qualityRow.LayoutOrder = 2
	qualityRow.Parent = panelFrame

	qualityLabel = Instance.new("TextLabel")
	qualityLabel.Name = "QualityLabel"
	qualityLabel.Size = UDim2.new(0, 80, 0, 18)
	qualityLabel.BackgroundTransparency = 1
	qualityLabel.Font = Enum.Font.GothamBold
	qualityLabel.TextSize = 13
	qualityLabel.TextColor3 = TEXT_COLOR
	qualityLabel.TextXAlignment = Enum.TextXAlignment.Left
	qualityLabel.Text = "Blood quality\n0%"
	qualityLabel.Parent = qualityRow

	-- Tier labels row
	local tierLabelRow = Instance.new("Frame")
	tierLabelRow.Size = UDim2.new(1, -90, 0, 14)
	tierLabelRow.Position = UDim2.new(0, 90, 0, 0)
	tierLabelRow.BackgroundTransparency = 1
	tierLabelRow.Parent = qualityRow

	local thresholds = Config.Blood.TierThresholds or { I = 1, II = 50, MAX = 100 }
	local tierNames = { "I", "II", "MAX" }
	for _, tierName in tierNames do
		local pct = thresholds[tierName] or 0
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, 30, 1, 0)
		lbl.Position = UDim2.new(pct / 100, -15, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 11
		lbl.TextColor3 = TIER_LABEL_COLOR
		lbl.Text = tierName
		lbl.Parent = tierLabelRow
		tierMarkers[tierName] = lbl
	end

	-- Bar background
	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(1, -90, 0, BAR_HEIGHT)
	barBg.Position = UDim2.new(0, 90, 0, 16)
	barBg.BackgroundColor3 = BAR_BG
	barBg.BorderSizePixel = 0
	barBg.Parent = qualityRow
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 3)

	qualityBar = Instance.new("Frame")
	qualityBar.Name = "Fill"
	qualityBar.Size = UDim2.new(0, 0, 1, 0)
	qualityBar.BackgroundColor3 = BAR_FILL
	qualityBar.BorderSizePixel = 0
	qualityBar.Parent = barBg
	Instance.new("UICorner", qualityBar).CornerRadius = UDim.new(0, 3)

	-- Tier dividers on bar
	for _, tierName in tierNames do
		local pct = thresholds[tierName] or 0
		if pct > 0 and pct < 100 then
			local divider = Instance.new("Frame")
			divider.Size = UDim2.new(0, 2, 1, 0)
			divider.Position = UDim2.new(pct / 100, -1, 0, 0)
			divider.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
			divider.BorderSizePixel = 0
			divider.ZIndex = 2
			divider.Parent = barBg
		end
	end

	-- ── Row 3+: Bonus descriptions ──
	-- Will be built dynamically in refresh

	return panelFrame
end

-- ═══ Refresh ═══
function BloodPoolPanel.refresh()
	if not panelFrame then return end

	local character = player.Character
	if not character then return end

	local bloodType = character:GetAttribute("BloodType") or "Outcast"
	local quality = character:GetAttribute("BloodQuality") or 0
	local amount = character:GetAttribute("BloodAmount") or 0

	local typeConfig = Config.Blood.Types[bloodType]

	-- Header
	if typeConfig then
		bloodIconImage.Image = typeConfig.Icon or ""
		bloodTypeLabel.Text = typeConfig.DisplayName or bloodType
		bloodTypeLabel.TextColor3 = typeConfig.Color or TEXT_COLOR
	else
		bloodIconImage.Image = ""
		bloodTypeLabel.Text = bloodType
		bloodTypeLabel.TextColor3 = TEXT_COLOR
	end

	bloodAmountLabel.Text = string.format("%.1f / %.0f Liters", amount / 10, Config.Blood.MaxAmount or 10)

	-- Quality
	qualityLabel.Text = string.format("Blood quality\n%d%%", math.floor(quality))
	qualityBar.Size = UDim2.new(math.clamp(quality / 100, 0, 1), 0, 1, 0)

	-- Clear old bonus labels
	for _, lbl in bonusLabels do
		lbl:Destroy()
	end
	bonusLabels = {}

	-- Build bonus descriptions
	if not typeConfig or not typeConfig.Tiers then return end

	local thresholds = Config.Blood.TierThresholds or { I = 1, II = 50, MAX = 100 }
	local tierOrder = { "I", "II", "MAX" }
	local layoutOrder = 10
	local hasMAX = (quality >= thresholds.MAX)

	for _, tierName in tierOrder do
		local tierData = typeConfig.Tiers[tierName]
		if not tierData then continue end

		local isActive = (quality >= (thresholds[tierName] or 999))

		local bonusRow = Instance.new("Frame")
		bonusRow.Name = "Bonus_" .. tierName
		bonusRow.Size = UDim2.new(1, 0, 0, 36)
		bonusRow.BackgroundTransparency = 1
		bonusRow.LayoutOrder = layoutOrder
		bonusRow.Parent = panelFrame

		local tierLabel = Instance.new("TextLabel")
		tierLabel.Size = UDim2.new(0, 40, 0, 28)
		tierLabel.BackgroundTransparency = 1
		tierLabel.Font = Enum.Font.GothamBold
		tierLabel.TextSize = 20
		tierLabel.TextColor3 = isActive and ACTIVE_COLOR or DIM_COLOR
		tierLabel.TextXAlignment = Enum.TextXAlignment.Left
		tierLabel.Text = tierName
		tierLabel.Parent = bonusRow

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -50, 0, 28)
		descLabel.Position = UDim2.new(0, 50, 0, 4)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 13
		descLabel.TextColor3 = isActive and TEXT_COLOR or DIM_COLOR
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextWrapped = true
		descLabel.Parent = bonusRow

		if tierData.Type == "BoostAll" then
			descLabel.Text = tierData.Description or "Boost all effects"
		elseif tierData.Stat and tierData.Description then
			if isActive then
				local bonus = calcTierBonus(tierData, quality)
				if hasMAX then
					local maxTier = typeConfig.Tiers.MAX
					if maxTier and maxTier.Type == "BoostAll" then
						bonus = bonus * maxTier.Multiplier
					end
				end
				descLabel.Text = string.format(tierData.Description, string.format("%.1f", bonus * 100))
			else
				local rangeStr = string.format("%d-%d", math.floor(tierData.Min * 100), math.floor(tierData.Max * 100))
				descLabel.Text = string.format(tierData.Description, rangeStr)
			end
		end

		table.insert(bonusLabels, bonusRow)
		layoutOrder = layoutOrder + 1
	end
end

-- ═══ Visibility ═══
function BloodPoolPanel.setVisible(visible)
	if panelFrame then
		panelFrame.Visible = visible
	end
	if visible then
		BloodPoolPanel.refresh()
	end
end

return BloodPoolPanel