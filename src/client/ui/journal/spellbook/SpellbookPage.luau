local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))
local JournalWindow = require(script.Parent.Parent:WaitForChild("JournalWindow"))
local JC = require(script.Parent.Parent:WaitForChild("JournalConstants"))

local SchoolTabs = require(script.Parent:WaitForChild("SchoolTabs"))
local SchoolInfoPanel = require(script.Parent:WaitForChild("SchoolInfoPanel"))
local TierProgressBar = require(script.Parent:WaitForChild("TierProgressBar"))
local SpellGrid = require(script.Parent:WaitForChild("SpellGrid"))
local SpellDetailPanel = require(script.Parent:WaitForChild("SpellDetailPanel"))
local SpellSlotBar = require(script.Parent:WaitForChild("SpellSlotBar"))

local SpellbookPage = {}

local pageFrame = nil
local spellData = nil
local isVisible = false
local dataLoaded = false

-- ═══ Build ═══
function SpellbookPage.build(contentParent, screenGui)
    pageFrame = Instance.new("Frame")
    pageFrame.Name = "SpellbookPage"
    pageFrame.Size = UDim2.new(0.8, 0, 0.9, 0)
    pageFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    pageFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    pageFrame.BackgroundTransparency = 1
    pageFrame.Visible = false
    pageFrame.Parent = contentParent

    SchoolTabs.build(pageFrame)

    local mainArea = Instance.new("Frame")
    mainArea.Name = "MainArea"
    mainArea.Size = UDim2.new(1, -C.CONTENT_PAD * 2, 1, -(C.SCHOOL_TAB_H + C.SLOT_BAR_H + C.CONTENT_PAD))
    mainArea.Position = UDim2.new(0, C.CONTENT_PAD, 0, C.SCHOOL_TAB_H + 4)
    mainArea.BackgroundTransparency = 1
    mainArea.Parent = pageFrame

    SchoolInfoPanel.build(mainArea)

    local centerArea = Instance.new("Frame")
    centerArea.Name = "CenterArea"
    centerArea.Size = UDim2.new(1, -(C.SCHOOL_INFO_W + C.DETAIL_W + C.CONTENT_PAD * 2), 1, 0)
    centerArea.Position = UDim2.new(0, C.SCHOOL_INFO_W + C.CONTENT_PAD, 0, 0)
    centerArea.BackgroundTransparency = 1
    centerArea.Parent = mainArea

    TierProgressBar.build(centerArea)

    local gridContainer = Instance.new("Frame")
    gridContainer.Name = "GridContainer"
    gridContainer.Size = UDim2.new(1, 0, 1, -C.TIER_BAR_H)
    gridContainer.Position = UDim2.new(0, 0, 0, C.TIER_BAR_H)
    gridContainer.BackgroundTransparency = 1
    gridContainer.Parent = centerArea

    SpellGrid.build(gridContainer)

    SpellDetailPanel.build(mainArea)

    SpellSlotBar.build(pageFrame)

    -- ═══ Callbacks ═══

    SchoolTabs.onSelect(function(schoolId)
        SpellbookPage._onSchoolChanged(schoolId)
    end)

    SpellGrid.onSelect(function(spellId)
        SpellDetailPanel.refresh(spellId, spellData)
        -- Rebuild grid to update selection highlight
        local currentSchool = SchoolTabs.getSelected()
        local learned = spellData and spellData.LearnedSpells or {}
        SpellGrid.rebuild(currentSchool, learned, spellData)
    end)

    SpellSlotBar.onSlotClick(function(slotKey)
        local selectedSpell = SpellGrid.getSelected()
        if not selectedSpell then
            return
        end
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
    local schoolBg = JC.SCHOOL_BACKGROUNDS[schoolId]
    JournalWindow.setBackground(schoolBg)

    SchoolInfoPanel.refresh(schoolId)

    SpellGrid.clearSelection()
    SpellDetailPanel.refresh(nil)

    local learned = spellData and spellData.LearnedSpells or {}
    SpellGrid.rebuild(schoolId, learned, spellData)

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
    if not SchoolTabs.getSelected() then
        SchoolTabs.selectFirst()
    end

    if not dataLoaded then
        task.spawn(function()
            local data = Remotes.GetSpellData:InvokeServer()
            if data then
                spellData = data
                dataLoaded = true
            end
            SpellbookPage._refreshAll()
        end)
    else
        SpellbookPage._refreshAll()
    end
end

function SpellbookPage.onDeactivate()
    SpellGrid.clearSelection()
    SpellDetailPanel.refresh(nil)
    JournalWindow.setBackground(nil)
end

return SpellbookPage
