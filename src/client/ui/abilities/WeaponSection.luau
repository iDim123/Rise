local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local C = require(script.Parent:WaitForChild("AbilitiesConstants"))
local SlotFactory = require(script.Parent:WaitForChild("SlotFactory"))
local AbilityTooltip = require(script.Parent:WaitForChild("AbilityTooltip"))
local AbilityCooldowns = require(script.Parent:WaitForChild("AbilityCooldowns"))
local MouseUtil = require(script.Parent:WaitForChild("MouseUtil"))

local player = Players.LocalPlayer

local WeaponSection = {}

local slots = {}
local currentAbilities = {}
local toolConnectionAdded = nil
local toolConnectionRemoved = nil

local STYLE = {
    bg = C.SLOT_BG,
    border = C.SLOT_BORDER,
    borderEmpty = C.SLOT_BORDER_INACTIVE
}

function WeaponSection.build(barFrame, screenGui, startCol)
    for i, key in C.WEAPON_KEYS do
        local col = startCol + (i - 1)
        local slotData = SlotFactory.create(barFrame, key, col, STYLE)

        slotData.frame.MouseEnter:Connect(function()
            AbilityTooltip.show(screenGui, key, currentAbilities[key], slotData.frame, C.SLOT_SIZE)
        end)
        slotData.frame.MouseLeave:Connect(function()
            if AbilityTooltip.getHoveredKey() == key then
                AbilityTooltip.hide()
            end
        end)

        slots[key] = slotData
    end

    local function connectCharacter(character)
        if toolConnectionAdded then
            toolConnectionAdded:Disconnect()
        end
        if toolConnectionRemoved then
            toolConnectionRemoved:Disconnect()
        end

        toolConnectionAdded = character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                WeaponSection.refresh()
            end
        end)
        toolConnectionRemoved = character.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") then
                WeaponSection.refresh()
            end
        end)

        WeaponSection.refresh()
    end

    player.CharacterAdded:Connect(connectCharacter)
    if player.Character then
        connectCharacter(player.Character)
    end

    return #C.WEAPON_KEYS
end

function WeaponSection.refresh()
    local character = player.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    local weaponConfig = tool and Config.Weapons[tool.Name] or nil

    for _, key in C.WEAPON_KEYS do
        local ability = nil
        if key == "LMB" then
            ability = weaponConfig and weaponConfig.ComboAbility
        else
            ability = weaponConfig and weaponConfig.Abilities and weaponConfig.Abilities[key]
        end
        currentAbilities[key] = ability

        local slotData = slots[key]
        if ability then
            SlotFactory.setIcon(slotData, ability.Icon, ability.Name or ability.Id, STYLE)
        else
            SlotFactory.setEmpty(slotData, key, STYLE)
        end
    end
end

function WeaponSection.handleInput(keyCode)
    for _, key in {"Q", "E", "Space"} do
        if C.KEYCODES[key] and keyCode == C.KEYCODES[key] then
            local ability = currentAbilities[key]
            if not ability then
                return false
            end
            if AbilityCooldowns.isOnCooldown(key) then
                return true
            end
            Remotes.UseAbility:FireServer(key, MouseUtil.getWorldPosition())
            return true
        end
    end
    return false
end

function WeaponSection.hasAbility(key)
    return currentAbilities[key] ~= nil
end

return WeaponSection
