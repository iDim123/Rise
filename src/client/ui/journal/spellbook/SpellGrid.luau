local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local SpellCard = require(script.Parent:WaitForChild("SpellCard"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SpellGrid = {}

local frame
local cards = {}
local selectedSpellId = nil
local onSelectCallback = nil

function SpellGrid.build(parent)
    frame = Instance.new("Frame")
    frame.Name = "SpellGrid"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    return frame
end

function SpellGrid.rebuild(schoolId, learnedSpells, spellData)
    if not frame then
        return
    end

    -- Очистить
    for _, child in frame:GetChildren() do
        child:Destroy()
    end
    cards = {}
    selectedSpellId = nil

    -- Паддинг
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, C.CONTENT_PAD)
    padding.PaddingTop = UDim.new(0, C.CONTENT_PAD)
    padding.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
    layout.Parent = frame

    -- Собрать заклинания по тирам
    local tierSpells = {}
    local school = SpellConfig.Schools[schoolId]
    if not school then
        return
    end

    for _, tier in school.Tiers do
        local tierNum = tier.Tier
        tierSpells[tierNum] = tierSpells[tierNum] or {}
        for _, sid in tier.Spells do
            table.insert(tierSpells[tierNum], sid)
        end
    end

    -- Определяем доступные spell points для этой школы
    local availablePoints = {}
    if spellData and spellData.SpellPoints and spellData.SpellPoints[schoolId] then
        availablePoints = spellData.SpellPoints[schoolId]
    end

    local learned = learnedSpells or {}

    -- Создаём строки по тирам
    local tierOrder = {}
    for t in tierSpells do
        table.insert(tierOrder, t)
    end
    table.sort(tierOrder)

    for orderIdx, tierNum in ipairs(tierOrder) do
        local spells = tierSpells[tierNum]

        -- Контейнер строки
        local row = Instance.new("Frame")
        row.Name = "Tier_" .. tierNum
        row.Size = UDim2.new(1, 0, 0, C.SPELL_ICON_SIZE + 22 + 20)
        row.BackgroundTransparency = 1
        row.LayoutOrder = orderIdx
        row.Parent = frame

        -- Метка тира
        local tierLabel = Instance.new("TextLabel")
        tierLabel.Name = "TierLabel"
        tierLabel.Size = UDim2.new(0, C.TIER_LABEL_W, 1, 0)
        tierLabel.BackgroundTransparency = 1
        tierLabel.Text = "T" .. tierNum
        tierLabel.TextColor3 = C.TEXT_DIM
        tierLabel.Font = Enum.Font.GothamBold
        tierLabel.TextSize = 16
        tierLabel.Parent = row

        -- Есть ли доступные очки для этого тира
        local tierKey = tostring(tierNum)
        local pointsForTier = (availablePoints[tierKey] or 0)

        for i, spellId in ipairs(spells) do
            local isLearned = (learned[spellId] == true)

            -- canLearn: не изучено + есть очки для этого тира
            local canLearn = false
            if not isLearned and pointsForTier > 0 then
                canLearn = true
            end

            local isSelected = (spellId == selectedSpellId)

            local cardBtn = SpellCard.build(row, spellId, isLearned, isSelected, schoolId, canLearn)
            if cardBtn then
                cardBtn.Position = UDim2.new(0, C.TIER_LABEL_W + (i - 1) * (C.SPELL_ICON_SIZE + C.SPELL_ICON_GAP), 0, 0)
                cards[spellId] = cardBtn

                cardBtn.Activated:Connect(function()
                    SpellGrid.selectSpell(spellId)
                end)
            end
        end
    end
end

function SpellGrid.selectSpell(spellId)
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
