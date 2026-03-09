local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local C = require(script.Parent:WaitForChild("AbilitiesConstants"))
local SlotFactory = require(script.Parent:WaitForChild("SlotFactory"))
local AbilityTooltip = require(script.Parent:WaitForChild("AbilityTooltip"))
local AbilityCooldowns = require(script.Parent:WaitForChild("AbilityCooldowns"))
local MouseUtil = require(script.Parent:WaitForChild("MouseUtil"))

local UltimateSection = {}

local slots = {}
local equippedSpell = nil -- spellId for Z
local spellConfig = nil

local STYLE = {
    bg = C.ULT_SLOT_BG,
    border = C.ULT_SLOT_BORDER,
    borderEmpty = C.ULT_SLOT_BORDER_EMPTY
}

function UltimateSection.build(barFrame, screenGui, startCol)
    for i, key in C.ULT_KEYS do
        local col = startCol + (i - 1)
        local slotData = SlotFactory.create(barFrame, key, col, STYLE)

        slotData.frame.MouseEnter:Connect(function()
            if spellConfig then
                AbilityTooltip.show(screenGui, key, {
                    Name = spellConfig.Name,
                    Description = spellConfig.Description,
                    Cooldown = spellConfig.Cooldown
                }, slotData.frame, C.SLOT_SIZE)
            end
        end)
        slotData.frame.MouseLeave:Connect(function()
            if AbilityTooltip.getHoveredKey() == key then
                AbilityTooltip.hide()
            end
        end)

        slots[key] = slotData
    end

    return #C.ULT_KEYS
end

function UltimateSection.refresh()
    local key = "Z"
    local spellId = equippedSpell
    spellConfig = spellId and Config.Spells and Config.Spells[spellId] or nil

    local slotData = slots[key]
    if spellConfig then
        SlotFactory.setIcon(slotData, spellConfig.Icon, spellConfig.Name or spellId, STYLE)
    else
        SlotFactory.setEmpty(slotData, key, STYLE)
    end
end

function UltimateSection.updateEquipped(equipped)
    equippedSpell = equipped and equipped["Z"] or nil
    UltimateSection.refresh()
end

function UltimateSection.handleInput(keyCode)
    if keyCode == C.KEYCODES.Z then
        if not equippedSpell then
            return false
        end
        if AbilityCooldowns.isOnCooldown("Z") then
            return true
        end
        Remotes.CastSpell:FireServer(equippedSpell, MouseUtil.getWorldPosition())
        return true
    end
    return false
end

function UltimateSection.handleCooldown(spellId, duration)
    if equippedSpell == spellId then
        AbilityCooldowns.start("Z", duration)
        return true
    end
    return false
end

function UltimateSection.handleChargeUpdate(spellId, charges, maxCharges)
    if equippedSpell == spellId then
        SlotFactory.setCharges(slots["Z"], charges, maxCharges)
        return true
    end
    return false
end

function UltimateSection.hasSpell()
    return equippedSpell ~= nil
end

return UltimateSection
