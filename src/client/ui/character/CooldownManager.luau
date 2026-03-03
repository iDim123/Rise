local RunService = game:GetService("RunService")

local CooldownManager = {}

-- [itemId] = { endTime = tick(), duration = number }
local activeCooldowns = {}

-- Все слоты, которые нужно обновлять: { frame = slot, getItemId = function }
local trackedSlots = {}

function CooldownManager.startCooldown(itemId, duration)
    activeCooldowns[itemId] = {
        endTime = tick() + duration,
        duration = duration,
    }
end

function CooldownManager.getRemainingTime(itemId)
    local cd = activeCooldowns[itemId]
    if not cd then return 0 end
    local remaining = cd.endTime - tick()
    if remaining <= 0 then
        activeCooldowns[itemId] = nil
        return 0
    end
    return remaining
end

function CooldownManager.getFraction(itemId)
    local cd = activeCooldowns[itemId]
    if not cd then return 0 end
    local remaining = cd.endTime - tick()
    if remaining <= 0 then
        activeCooldowns[itemId] = nil
        return 0
    end
    return remaining / cd.duration
end

function CooldownManager.isOnCooldown(itemId)
    return CooldownManager.getRemainingTime(itemId) > 0
end

function CooldownManager.registerSlot(slotFrame, getItemIdFunc)
    table.insert(trackedSlots, {
        frame = slotFrame,
        getItemId = getItemIdFunc,
    })
end

-- Каждый кадр обновляем все зарегистрированные слоты
RunService.RenderStepped:Connect(function()
    for _, entry in trackedSlots do
        local slot = entry.frame
        local itemId = entry.getItemId()

        local overlay = slot:FindFirstChild("CooldownOverlay")
        local cdText = slot:FindFirstChild("CooldownText")

        if not overlay or not cdText then continue end

        if itemId and CooldownManager.isOnCooldown(itemId) then
            local remaining = CooldownManager.getRemainingTime(itemId)
            local fraction = CooldownManager.getFraction(itemId)

            -- Шторка сверху вниз (fraction 1 = полностью закрыт, 0 = открыт)
            overlay.Visible = true
            overlay.Size = UDim2.new(1, 0, fraction, 0)
            overlay.Position = UDim2.new(0, 0, 1 - fraction, 0)

            cdText.Visible = true
            cdText.Text = tostring(math.ceil(remaining))
        else
            overlay.Visible = false
            overlay.Size = UDim2.new(1, 0, 1, 0)
            cdText.Visible = false
            cdText.Text = ""
        end
    end
end)

return CooldownManager