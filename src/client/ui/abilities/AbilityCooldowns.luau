local RunService = game:GetService("RunService")

local AbilityCooldowns = {}

-- [key] = { endTime, duration }
local active = {}

-- [key] = { overlay, timerLabel, stroke }
local trackedSlots = {}

local SLOT_BORDER = Color3.fromRGB(80, 80, 100)
local ACTIVE_STROKE = Color3.fromRGB(200, 170, 60)
local INACTIVE_BORDER = Color3.fromRGB(50, 50, 50)

function AbilityCooldowns.start(key, duration)
    active[key] = { endTime = tick() + duration, duration = duration }
    local tracked = trackedSlots[key]
    if tracked and tracked.stroke then
        tracked.stroke.Color = ACTIVE_STROKE
    end
end

function AbilityCooldowns.isOnCooldown(key)
    local cd = active[key]
    if not cd then return false end
    if tick() >= cd.endTime then
        active[key] = nil
        return false
    end
    return true
end

function AbilityCooldowns.registerSlot(key, overlay, timerLabel, stroke)
    trackedSlots[key] = {
        overlay = overlay,
        timerLabel = timerLabel,
        stroke = stroke,
    }
end

function AbilityCooldowns.tick(hasAbilityFn)
    local now = tick()
    for key, tracked in trackedSlots do
        local cd = active[key]
        if cd and now < cd.endTime then
            local rem = cd.endTime - now
            tracked.overlay.Size = UDim2.new(1, 0, math.clamp(rem / cd.duration, 0, 1), 0)
            tracked.overlay.Visible = true
            tracked.timerLabel.Text = string.format("%.0f", math.ceil(rem))
            tracked.timerLabel.Visible = true
        else
            tracked.overlay.Visible = false
            tracked.timerLabel.Visible = false
            if cd then
                active[key] = nil
                tracked.stroke.Color = hasAbilityFn(key) and SLOT_BORDER or INACTIVE_BORDER
            end
        end
    end
end

return AbilityCooldowns