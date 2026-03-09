local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))
local SpellCard = require(script.Parent:WaitForChild("SpellCard"))

local SpellGrid = {}

local gridFrame = nil
local cardInstances = {}
local selectedSpellId = nil
local onSelectCallback = nil

function SpellGrid.build(parent)
    gridFrame = Instance.new("Frame")
    gridFrame.Name = "SpellGrid"
    gridFrame.Size = UDim2.new(1, 0, 1, 0)
    gridFrame.Position = UDim2.new(0, 0, 0, 0)
    gridFrame.BackgroundTransparency = 1
    gridFrame.Parent = parent

    return gridFrame
end

function SpellGrid.rebuild(schoolId, learnedSpells)
    -- Clear
    for _, inst in cardInstances do
        inst:Destroy()
    end
    table.clear(cardInstances)

    -- Remove old children
    for _, child in gridFrame:GetChildren() do
        child:Destroy()
    end

    if not schoolId then
        return
    end

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.Parent = gridFrame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = gridFrame

    -- Collect spells for this school, grouped by tier
    local tiers = {{}, {}, {}, {}} -- tier 1, 2, 3, ult
    for spellId, spell in SpellConfig.Spells do
        if spell.School == schoolId then
            local tier = spell.Tier or 1
            if spell.Class == "Ultimate" then
                table.insert(tiers[4], spell)
            else
                tier = math.clamp(tier, 1, 3)
                table.insert(tiers[tier], spell)
            end
        end
    end

    local tierNames = {"I", "II", "III", "ULT"}

    for tierIdx, spells in tiers do
        local tierRow = Instance.new("Frame")
        tierRow.Name = "TierRow_" .. tierIdx
        tierRow.Size = UDim2.new(1, 0, 0, C.SPELL_ICON_SIZE + 8)
        tierRow.BackgroundTransparency = 1
        tierRow.LayoutOrder = tierIdx
        tierRow.Parent = gridFrame

        -- Tier label
        local tierLabel = Instance.new("TextLabel")
        tierLabel.Size = UDim2.new(0, C.TIER_LABEL_W, 0, C.SPELL_ICON_SIZE)
        tierLabel.Position = UDim2.new(0, 0, 0, 4)
        tierLabel.BackgroundTransparency = 1
        tierLabel.Font = Enum.Font.GothamBold
        tierLabel.TextSize = 16
        tierLabel.TextColor3 = tierIdx == 4 and C.ULT_COLOR or C.TEXT_DIM
        tierLabel.Text = tierNames[tierIdx]
        tierLabel.TextXAlignment = Enum.TextXAlignment.Center
        tierLabel.Parent = tierRow

        -- Spell icons
        local iconX = C.TIER_LABEL_W + 10
        for i, spell in spells do
            local isLearned = learnedSpells and learnedSpells[spell.Id] or false
            local isSelected = selectedSpellId == spell.Id

            local card = SpellCard.build(tierRow, spell, isLearned, isSelected, i)
            card.Position = UDim2.new(0, iconX + (i - 1) * (C.SPELL_ICON_SIZE + C.SPELL_ICON_GAP), 0, 4)
            cardInstances[spell.Id] = card

            card.Activated:Connect(function()
                SpellGrid.selectSpell(spell.Id)
            end)
        end
    end
end

function SpellGrid.selectSpell(spellId)
    if selectedSpellId == spellId then
        return
    end
    selectedSpellId = spellId

    if onSelectCallback then
        onSelectCallback(spellId)
    end
end

function SpellGrid.onSelect(callback)
    onSelectCallback = callback
end

function SpellGrid.getSelected()
    return selectedSpellId
end

function SpellGrid.clearSelection()
    selectedSpellId = nil
end

return SpellGrid
