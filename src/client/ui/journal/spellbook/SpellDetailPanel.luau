local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SpellDetailBuilder = require(script.Parent:WaitForChild("SpellDetailBuilder"))
local SpellDetailLearn = require(script.Parent:WaitForChild("SpellDetailLearn"))
local SpellDetailEquip = require(script.Parent:WaitForChild("SpellDetailEquip"))

local SpellDetailPanel = {}

local elements = nil -- UI references from builder
local currentSpellId = nil
local cachedSpellData = nil

local function getCurrentSpellId()
    return currentSpellId
end

function SpellDetailPanel.build(parent)
    elements = SpellDetailBuilder.build(parent)

    -- Build sub-sections inside contentFrame
    SpellDetailLearn.build(elements.contentFrame, getCurrentSpellId)
    SpellDetailEquip.build(elements.contentFrame, getCurrentSpellId)

    return elements.panelFrame
end

function SpellDetailPanel._showPlaceholder()
    elements.contentFrame.Visible = false
    elements.placeholderLabel.Visible = true
    currentSpellId = nil
end

function SpellDetailPanel._showContent()
    elements.placeholderLabel.Visible = false
    elements.contentFrame.Visible = true
end

function SpellDetailPanel.refresh(spellId, spellData)
    cachedSpellData = spellData

    if not spellId then
        SpellDetailPanel._showPlaceholder()
        return
    end

    local spell = SpellConfig.Spells[spellId]
    if not spell then
        SpellDetailPanel._showPlaceholder()
        return
    end

    currentSpellId = spellId
    SpellDetailPanel._showContent()

    local accent = C.SCHOOL_ACCENTS[spell.School] or C.TEXT_COLOR

    -- Header info
    elements.nameLabel.Text = spell.Name or spellId
    elements.nameLabel.TextColor3 = accent

    local classParts = {}
    if spell.Tags then
        for _, tag in spell.Tags do
            table.insert(classParts, tag)
        end
    end
    elements.classLabel.Text = table.concat(classParts, ", ")

    local castTime = spell.CastTime or 0
    elements.castLabel.Text = castTime > 0 and ("Cast time: " .. castTime .. "s") or "Instant"
    elements.castLabel.Visible = true

    local cd = spell.Cooldown or 0
    elements.cooldownLabel.Text = cd > 0 and ("Cooldown: " .. cd .. "s") or ""
    elements.cooldownLabel.Visible = cd > 0

    elements.descLabel.Text = spell.Description or ""

    -- Icon
    local iconImg = elements.iconFrame:FindFirstChild("Icon")
    local iconFb = elements.iconFrame:FindFirstChild("Fallback")
    if spell.Icon and spell.Icon ~= "" and spell.Icon ~= "rbxassetid://0" then
        if iconImg then
            iconImg.Image = spell.Icon;
            iconImg.Visible = true
        end
        if iconFb then
            iconFb.Visible = false
        end
    else
        if iconImg then
            iconImg.Visible = false
        end
        if iconFb then
            iconFb.Text = spell.Name or "?";
            iconFb.Visible = true
        end
    end

    -- Sep3 always visible when spell selected
    elements.sep3.Visible = true

    -- State: learned or not
    local isLearned = spellData and spellData.LearnedSpells and spellData.LearnedSpells[spellId]

    if isLearned then
        SpellDetailLearn.hide()
        SpellDetailEquip.refresh(spell, spellId, spellData)
    else
        SpellDetailEquip.hide()
        SpellDetailLearn.refresh(spell, spellData)
    end
end

--- Update only dynamic parts (equip/learn state) without changing selected spell
function SpellDetailPanel.refreshState(spellData)
    cachedSpellData = spellData
    if currentSpellId then
        SpellDetailPanel.refresh(currentSpellId, spellData)
    end
end

function SpellDetailPanel.onLearned(callback)
    SpellDetailLearn.onLearned(callback)
end

function SpellDetailPanel.getFrame()
    return elements and elements.panelFrame
end

function SpellDetailPanel.setVisible(visible)
    if elements and elements.panelFrame then
        elements.panelFrame.Visible = visible
    end
end

function SpellDetailPanel.getSelectedSpellId()
    return currentSpellId
end

return SpellDetailPanel
