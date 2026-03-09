local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SchoolTabs = require(script.Parent:WaitForChild("SchoolTabs"))
local SchoolInfoPanel = require(script.Parent:WaitForChild("SchoolInfoPanel"))
local TierProgressBar = require(script.Parent:WaitForChild("TierProgressBar"))
local SpellGrid = require(script.Parent:WaitForChild("SpellGrid"))
local SpellDetailPanel = require(script.Parent:WaitForChild("SpellDetailPanel"))
local SpellSlotBar = require(script.Parent:WaitForChild("SpellSlotBar"))

local SpellbookPage = {}

local pageFrame = nil
local spellData = nil -- { SpellPoints, LearnedSpells, EquippedSlots, SchoolProgress }
local isVisible = false
local dataLoaded = false

-- ═══ Build ═══
function SpellbookPage.build(contentParent, screenGui)
    pageFrame = Instance.new("Frame")
    pageFrame.Name = "SpellbookPage"
    pageFrame.Size = UDim2.new(0.8, 0, 0.9, 0) -- 80% ширины, 90% высоты
    pageFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    pageFrame.Position = UDim2.new(0.5, 0, 0.5, 0) -- центрирован
    pageFrame.BackgroundTransparency = 1
    pageFrame.Visible = false
    pageFrame.Parent = contentParent

    -- School tabs (top)
    SchoolTabs.build(pageFrame)

    -- Main content area (below tabs, above slot bar)
    local mainArea = Instance.new("Frame")
    mainArea.Name = "MainArea"
    mainArea.Size = UDim2.new(1, -C.CONTENT_PAD * 2, 1, -(C.SCHOOL_TAB_H + C.SLOT_BAR_H + C.CONTENT_PAD))
    mainArea.Position = UDim2.new(0, C.CONTENT_PAD, 0, C.SCHOOL_TAB_H + 4)
    mainArea.BackgroundTransparency = 1
    mainArea.Parent = pageFrame

    -- School info panel (left)
    SchoolInfoPanel.build(mainArea)

    -- Tier progress bar (above spell grid)
    local centerArea = Instance.new("Frame")
    centerArea.Name = "CenterArea"
    centerArea.Size = UDim2.new(1, -(C.SCHOOL_INFO_W + C.DETAIL_W + C.CONTENT_PAD * 2), 1, 0)
    centerArea.Position = UDim2.new(0, C.SCHOOL_INFO_W + C.CONTENT_PAD, 0, 0)
    centerArea.BackgroundTransparency = 1
    centerArea.Parent = mainArea

    TierProgressBar.build(centerArea)

    -- Spell grid (center, below tier bar)
    local gridContainer = Instance.new("Frame")
    gridContainer.Name = "GridContainer"
    gridContainer.Size = UDim2.new(1, 0, 1, -C.TIER_BAR_H)
    gridContainer.Position = UDim2.new(0, 0, 0, C.TIER_BAR_H)
    gridContainer.BackgroundTransparency = 1
    gridContainer.Parent = centerArea

    SpellGrid.build(gridContainer)

    -- Detail panel (right)
    SpellDetailPanel.build(mainArea)

    -- Slot bar (bottom)
    SpellSlotBar.build(pageFrame)

    -- ═══ Callbacks ═══

    SchoolTabs.onSelect(function(schoolId)
        SpellbookPage._onSchoolChanged(schoolId)
    end)

    SpellGrid.onSelect(function(spellId)
        SpellDetailPanel.refresh(spellId)
        -- Rebuild grid to update selection highlight
        local currentSchool = SchoolTabs.getSelected()
        local learned = spellData and spellData.LearnedSpells or {}
        SpellGrid.rebuild(currentSchool, learned)
    end)

    SpellSlotBar.onSlotClick(function(slotKey)
        local selectedSpell = SpellGrid.getSelected()
        if not selectedSpell then
            return
        end

        -- Equip the selected spell to this slot
        Remotes.EquipSpell:FireServer(selectedSpell, slotKey)
    end)

    -- ═══ Remote listeners ═══
    Remotes.UpdateSpellData.OnClientEvent:Connect(function(data)
        if data then
            spellData = data
            SpellbookPage._refreshAll()
        end
    end)
end

-- ═══ School change ═══
function SpellbookPage._onSchoolChanged(schoolId)
    SchoolInfoPanel.refresh(schoolId)

    local learned = spellData and spellData.LearnedSpells or {}
    SpellGrid.clearSelection()
    SpellGrid.rebuild(schoolId, learned)
    SpellDetailPanel.refresh(nil) -- clear detail

    -- Update tier progress
    local progress = spellData and spellData.SchoolProgress and spellData.SchoolProgress[schoolId]
    local tierReached = 0
    if progress then
        tierReached = progress.Tier or 0
    end
    TierProgressBar.refresh(tierReached)
end

-- ═══ Refresh all ═══
function SpellbookPage._refreshAll()
    local currentSchool = SchoolTabs.getSelected()
    if currentSchool then
        SpellbookPage._onSchoolChanged(currentSchool)
    end

    local equipped = spellData and spellData.EquippedSlots or {}
    SpellSlotBar.refresh(equipped)
end

-- ═══ Page lifecycle ═══
function SpellbookPage.setVisible(visible)
    isVisible = visible
    if pageFrame then
        pageFrame.Visible = visible
    end
end

function SpellbookPage.onActivate()
    if not dataLoaded then
        task.spawn(function()
            local data = Remotes.GetSpellData:InvokeServer()
            if data then
                spellData = data
                dataLoaded = true
                SchoolTabs.selectFirst()
                SpellbookPage._refreshAll()
            end
        end)
    else
        -- Всегда выбираем первую вкладку если ни одна не выбрана
        if not SchoolTabs.getSelected() then
            SchoolTabs.selectFirst()
        end
        SpellbookPage._refreshAll()
    end
end

function SpellbookPage.onDeactivate()
    -- nothing
end

return SpellbookPage
