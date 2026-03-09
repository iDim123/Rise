local AbilityCooldowns = {}

-- [key] = { endTime, duration }
local active = {}

-- [key] = { overlay, timerLabel, stroke, activeColor, inactiveColor }
local trackedSlots = {}

function AbilityCooldowns.start(key, duration)
    active[key] = {
        endTime = tick() + duration,
        duration = duration
    }
    local tracked = trackedSlots[key]
    if tracked and tracked.stroke then
        tracked.stroke.Color = tracked.activeColor
    end
end

function AbilityCooldowns.isOnCooldown(key)
    local cd = active[key]
    if not cd then
        return false
    end
    if tick() >= cd.endTime then
        active[key] = nil
        return false
    end
    return true
end

function AbilityCooldowns.registerSlot(key, overlay, timerLabel, stroke, activeColor, inactiveColor)
    trackedSlots[key] = {
        overlay = overlay,
        timerLabel = timerLabel,
        stroke = stroke,
        activeColor = activeColor or Color3.fromRGB(200, 170, 60),
        inactiveColor = inactiveColor or Color3.fromRGB(50, 50, 50)
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
                tracked.stroke.Color = hasAbilityFn(key) and tracked.activeColor or tracked.inactiveColor
            end
        end
    end
end

return AbilityCooldowns
