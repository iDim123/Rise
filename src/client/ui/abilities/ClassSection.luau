local C = require(script.Parent:WaitForChild("AbilitiesConstants"))
local SlotFactory = require(script.Parent:WaitForChild("SlotFactory"))

local ClassSection = {}

local slots = {}

local STYLE = {
    bg = C.CLASS_SLOT_BG,
    border = C.CLASS_SLOT_BORDER,
    borderEmpty = C.CLASS_SLOT_BORDER_EMPTY
}

function ClassSection.build(barFrame, screenGui, startCol)
    for i, key in C.CLASS_KEYS do
        local col = startCol + (i - 1)
        local slotData = SlotFactory.create(barFrame, key, col, STYLE)
        SlotFactory.setEmpty(slotData, key, STYLE)
        slots[key] = slotData
    end

    return #C.CLASS_KEYS
end

function ClassSection.handleInput(keyCode)
    -- Reserved for future class spell system
    return false
end

function ClassSection.hasAbility(key)
    return false
end

return ClassSection
