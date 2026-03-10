local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local C = require(script.Parent:WaitForChild("AbilitiesConstants"))
local SlotFactory = require(script.Parent:WaitForChild("SlotFactory"))
local AbilityTooltip = require(script.Parent:WaitForChild("AbilityTooltip"))
local AbilityCooldowns = require(script.Parent:WaitForChild("AbilityCooldowns"))
local MouseUtil = require(script.Parent:WaitForChild("MouseUtil"))
local SpellAimSender = require(script.Parent:WaitForChild("SpellAimSender"))

local SpellSection = {}

local slots = {}
local equippedSpells = {}
local spellConfigs = {}

local STYLE = {
    bg = C.SPELL_SLOT_BG,
    border = C.SPELL_SLOT_BORDER,
    borderEmpty = C.SPELL_SLOT_BORDER_EMPTY
}

-- Listen for cast end to stop aim sender
local player = Players.LocalPlayer
local castEndConnected = false

local function ensureCastEndListeners()
    if castEndConnected then
        return
    end
    castEndConnected = true

    -- CastComplete comes from CastBar UI BindableEvent
    task.spawn(function()
        local playerGui = player:WaitForChild("PlayerGui")
        local castBarUI = playerGui:WaitForChild("CastBarUI", 5)
        if castBarUI then
            local completeEvent = castBarUI:FindFirstChild("CastComplete")
            if completeEvent then
                completeEvent.Event:Connect(function()
                    SpellAimSender.stop()
                end)
            end
        end
    end)

    -- CastCancel from server
    if Remotes.CastCancel then
        Remotes.CastCancel.OnClientEvent:Connect(function()
            SpellAimSender.stop()
        end)
    end
end

function SpellSection.build(barFrame, screenGui, startCol)
    ensureCastEndListeners()

    for i, key in C.SPELL_KEYS do
        local col = startCol + (i - 1)
        local slotData = SlotFactory.create(barFrame, key, col, STYLE)

        slotData.frame.MouseEnter:Connect(function()
            local cfg = spellConfigs[key]
            if cfg then
                AbilityTooltip.show(screenGui, key, {
                    Name = cfg.Name,
                    Description = cfg.Description,
                    Cooldown = cfg.Cooldown
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

    return #C.SPELL_KEYS
end

function SpellSection.refresh()
    for _, key in C.SPELL_KEYS do
        local spellId = equippedSpells[key]
        local spellCfg = spellId and Config.Spells and Config.Spells[spellId] or nil
        spellConfigs[key] = spellCfg

        local slotData = slots[key]
        if spellCfg then
            SlotFactory.setIcon(slotData, spellCfg.Icon, spellCfg.Name or spellId, STYLE)
        else
            SlotFactory.setEmpty(slotData, key, STYLE)
        end
    end
end

function SpellSection.updateEquipped(equipped)
    equippedSpells = equipped or {}
    SpellSection.refresh()
end

function SpellSection.handleInput(keyCode)
    for _, key in C.SPELL_KEYS do
        if C.KEYCODES[key] and keyCode == C.KEYCODES[key] then
            local spellId = equippedSpells[key]
            if not spellId then
                return false
            end
            if AbilityCooldowns.isOnCooldown(key) then
                return true
            end
            -- Start sending aim updates for cast-time spells
            local spellCfg = spellConfigs[key]
            if spellCfg and spellCfg.CastTime and spellCfg.CastTime > 0.05 then
                SpellAimSender.start()
            end
            Remotes.CastSpell:FireServer(spellId, MouseUtil.getWorldPosition())
            return true
        end
    end
    return false
end

function SpellSection.handleCooldown(spellId, duration)
    for _, key in C.SPELL_KEYS do
        if equippedSpells[key] == spellId then
            AbilityCooldowns.start(key, duration)
            return true
        end
    end
    return false
end

function SpellSection.handleChargeUpdate(spellId, charges, maxCharges)
    for _, key in C.SPELL_KEYS do
        if equippedSpells[key] == spellId then
            SlotFactory.setCharges(slots[key], charges, maxCharges)
            return true
        end
    end
    return false
end

function SpellSection.hasSpell(key)
    return equippedSpells[key] ~= nil
end

function SpellSection.getEquipped()
    return equippedSpells
end

return SpellSection
