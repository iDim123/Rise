local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local TierProgressBar = {}

local barFrame = nil
local lineBg = nil
local sectionFills = {}
local tierLabels = {}
local checkpoints = {}

local TIER_NAMES = {"I", "II", "III", "ULT"}
local NUM_SECTIONS = #TIER_NAMES
local CHECKPOINT_SIZE = 12
local LINE_HEIGHT = 4

function TierProgressBar.build(parent)
    barFrame = Instance.new("Frame")
    barFrame.Name = "TierProgressBar"
    barFrame.Size = UDim2.new(1, 0, 0, C.TIER_BAR_H)
    barFrame.BackgroundTransparency = 1
    barFrame.Parent = parent

    -- "Tier" label
    local tierTextLabel = Instance.new("TextLabel")
    tierTextLabel.Size = UDim2.new(0, C.TIER_LABEL_W, 0, 20)
    tierTextLabel.Position = UDim2.new(0, 0, 0.5, -8)
    tierTextLabel.BackgroundTransparency = 1
    tierTextLabel.Font = Enum.Font.GothamBold
    tierTextLabel.TextSize = 20
    tierTextLabel.TextColor3 = C.TEXT_DIM
    tierTextLabel.Text = "Tier"
    tierTextLabel.TextXAlignment = Enum.TextXAlignment.Left
    tierTextLabel.Parent = barFrame

    -- Progress line background
    local lineX = C.TIER_LABEL_W + 10
    local lineW = -lineX - 10

    lineBg = Instance.new("Frame")
    lineBg.Name = "LineBg"
    lineBg.Size = UDim2.new(1, lineW, 0, LINE_HEIGHT)
    lineBg.Position = UDim2.new(0, lineX, 0.5, 2)
    lineBg.BackgroundColor3 = C.TIER_MARKER_DIM
    lineBg.BorderSizePixel = 0
    lineBg.ClipsDescendants = true
    lineBg.Parent = barFrame

    Instance.new("UICorner", lineBg).CornerRadius = UDim.new(0, 2)

    -- Section fills (inside lineBg, clipped)
    for i = 1, NUM_SECTIONS do
        local sectionWidth = 1 / NUM_SECTIONS
        local sectionX = (i - 1) * sectionWidth

        local fill = Instance.new("Frame")
        fill.Name = "Fill_" .. i
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.Position = UDim2.new(sectionX, 0, 0, 0)
        fill.BackgroundColor3 = C.TIER_MARKER
        fill.BorderSizePixel = 0
        fill.Parent = lineBg

        sectionFills[i] = {
            frame = fill,
            maxWidth = sectionWidth
        }
    end

    -- Tier labels (centered in each section) — in barFrame, above line
    for i, name in TIER_NAMES do
        local label = Instance.new("TextLabel")
        label.Name = "TierLabel_" .. name
        label.Size = UDim2.new(0, 50, 0, 16)
        label.AnchorPoint = Vector2.new(0.5, 1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextColor3 = C.TEXT_DIM
        label.Text = name
        label.Parent = barFrame

        tierLabels[i] = label
    end

    -- Checkpoints (on section boundaries) — in barFrame, on the line
    -- 4 checkpoints: after tier1, after tier2, after tier3, end
    for i = 1, NUM_SECTIONS do
        local cp = Instance.new("Frame")
        cp.Name = "Checkpoint_" .. i
        cp.Size = UDim2.new(0, CHECKPOINT_SIZE, 0, CHECKPOINT_SIZE)
        cp.AnchorPoint = Vector2.new(0.5, 0.5)
        cp.BackgroundColor3 = C.TIER_MARKER_DIM
        cp.BorderSizePixel = 0
        cp.Parent = barFrame

        Instance.new("UICorner", cp).CornerRadius = UDim.new(0, CHECKPOINT_SIZE / 2)

        local cpStroke = Instance.new("UIStroke")
        cpStroke.Color = C.TIER_MARKER_DIM
        cpStroke.Thickness = 1.5
        cpStroke.Parent = cp

        checkpoints[i] = {
            frame = cp,
            stroke = cpStroke
        }
    end

    barFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        TierProgressBar._updatePositions()
    end)

    task.defer(function()
        TierProgressBar._updatePositions()
    end)

    return barFrame
end

function TierProgressBar._updatePositions()
    if not barFrame or not lineBg then
        return
    end

    local lineX = C.TIER_LABEL_W + 10
    local lineAbsWidth = lineBg.AbsoluteSize.X
    if lineAbsWidth <= 0 then
        return
    end

    local lineY = lineBg.AbsolutePosition.Y - barFrame.AbsolutePosition.Y + LINE_HEIGHT / 2

    -- Position tier labels centered in each section
    local sectionPixelWidth = lineAbsWidth / NUM_SECTIONS
    for i, label in tierLabels do
        local centerX = lineX + (i - 0.5) * sectionPixelWidth
        label.Position = UDim2.new(0, centerX, 0, lineY - LINE_HEIGHT / 2 - 12)
    end

    -- Position checkpoints on section boundaries
    for i = 1, NUM_SECTIONS do
        local cp = checkpoints[i]
        if cp then
            local xPos = lineX + (i / NUM_SECTIONS) * lineAbsWidth
            cp.frame.Position = UDim2.new(0, xPos, 0, lineY)
        end
    end
end

function TierProgressBar.refresh(schoolId, learnedSpells)
    learnedSpells = learnedSpells or {}

    local tierTotal = {0, 0, 0, 0}
    local tierLearned = {0, 0, 0, 0}

    for spellId, spell in SpellConfig.Spells do
        if spell.School == schoolId then
            local bucket
            if spell.Class == "Ultimate" then
                bucket = 4
            else
                bucket = math.clamp(spell.Tier or 1, 1, 3)
            end
            tierTotal[bucket] = tierTotal[bucket] + 1
            if learnedSpells[spellId] then
                tierLearned[bucket] = tierLearned[bucket] + 1
            end
        end
    end

    -- Update checkpoints: checkpoint i lights up when tier i is complete
    local accent = C.SCHOOL_ACCENTS[schoolId] or C.TIER_MARKER

    -- Update section fills
    for i = 1, NUM_SECTIONS do
        local total = tierTotal[i]
        local learned = tierLearned[i]
        local ratio = total > 0 and (learned / total) or 0
        local isComplete = (total > 0 and learned >= total)

        local section = sectionFills[i]
        if section then
            section.frame.Size = UDim2.new(section.maxWidth * ratio, 0, 1, 0)
            section.frame.BackgroundColor3 = accent
        end

        -- Tier label: bright if complete
        if tierLabels[i] then
            tierLabels[i].TextColor3 = isComplete and C.TEXT_COLOR or C.TEXT_DIM
        end
    end

    for i = 1, NUM_SECTIONS do
        local cp = checkpoints[i]
        if not cp then continue end

        local isComplete = (tierTotal[i] > 0 and tierLearned[i] >= tierTotal[i])

        if isComplete then
            cp.frame.BackgroundColor3 = accent
            cp.stroke.Color = accent
        else
            cp.frame.BackgroundColor3 = C.TIER_MARKER_DIM
            cp.stroke.Color = C.TIER_MARKER_DIM
        end
    end

    TierProgressBar._updatePositions()
end

return TierProgressBar
