local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local C = require(script.Parent:WaitForChild("AbilitiesConstants"))
local AbilityCooldowns = require(script.Parent:WaitForChild("AbilityCooldowns"))

local WeaponSection = require(script.Parent:WaitForChild("WeaponSection"))
local SpellSection = require(script.Parent:WaitForChild("SpellSection"))
local UltimateSection = require(script.Parent:WaitForChild("UltimateSection"))
local ClassSection = require(script.Parent:WaitForChild("ClassSection"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ ScreenGui ═══
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AbilitiesBarGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 810
screenGui.Parent = playerGui

-- ═══ Bar Frame ═══
local totalSlots = #C.ALL_KEYS
local barFrameW = C.PADDING + totalSlots * (C.SLOT_SIZE + C.PADDING)
local barFrameH = C.SLOT_SIZE + 20

local barFrame = Instance.new("Frame")
barFrame.Name = "AbilitiesBar"
barFrame.Size = UDim2.new(0, barFrameW, 0, barFrameH)
barFrame.AnchorPoint = Vector2.new(0, 1)
barFrame.Position = UDim2.new(0.5, (C.FLASK_WIDTH / 2) + C.GAP, 1, -10)
barFrame.BackgroundColor3 = C.WINDOW_BG
barFrame.BackgroundTransparency = 0.3
barFrame.BorderSizePixel = 0
barFrame.Parent = screenGui
Instance.new("UICorner", barFrame).CornerRadius = UDim.new(0, C.CORNER_RADIUS)

-- ═══ Helper: separator line ═══
local function addSeparator(afterCol)
    local sepX = C.PADDING + afterCol * (C.SLOT_SIZE + C.PADDING) - C.PADDING / 2
    local sep = Instance.new("Frame")
    sep.Name = "Separator"
    sep.Size = UDim2.new(0, 1, 0.6, 0)
    sep.AnchorPoint = Vector2.new(0.5, 0.5)
    sep.Position = UDim2.new(0, sepX, 0.4, 0)
    sep.BackgroundColor3 = C.SEPARATOR_COLOR
    sep.BackgroundTransparency = C.SEPARATOR_TRANSPARENCY
    sep.BorderSizePixel = 0
    sep.Parent = barFrame
end

-- ═══ Build sections ═══
local col = 0

local weaponCount = WeaponSection.build(barFrame, screenGui, col)
col = col + weaponCount

-- addSeparator(col)

local spellCount = SpellSection.build(barFrame, screenGui, col)
col = col + spellCount

local ultCount = UltimateSection.build(barFrame, screenGui, col)
col = col + ultCount

-- addSeparator(col)

local classCount = ClassSection.build(barFrame, screenGui, col)
col = col + classCount

-- ═══ Input ═══
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    local keyCode = input.KeyCode

    if WeaponSection.handleInput(keyCode) then
        return
    end
    if SpellSection.handleInput(keyCode) then
        return
    end
    if UltimateSection.handleInput(keyCode) then
        return
    end
    if ClassSection.handleInput(keyCode) then
        return
    end
end)

-- ═══ Server events ═══

-- Weapon ability cooldowns
if Remotes.AbilityCooldown then
    Remotes.AbilityCooldown.OnClientEvent:Connect(function(key, duration)
        AbilityCooldowns.start(key, duration)
    end)
end

-- Spell cooldowns (spellId → find slot)
if Remotes.SpellCooldown then
    Remotes.SpellCooldown.OnClientEvent:Connect(function(spellId, duration)
        if SpellSection.handleCooldown(spellId, duration) then
            return
        end
        if UltimateSection.handleCooldown(spellId, duration) then
            return
        end
    end)
end

-- Spell charge updates
if Remotes.SpellChargeUpdate then
    Remotes.SpellChargeUpdate.OnClientEvent:Connect(function(spellId, charges, maxCharges)
        if SpellSection.handleChargeUpdate(spellId, charges, maxCharges) then
            return
        end
        if UltimateSection.handleChargeUpdate(spellId, charges, maxCharges) then
            return
        end
    end)
end

-- Spell data updates (equipped spells changed)
if Remotes.UpdateSpellData then
    Remotes.UpdateSpellData.OnClientEvent:Connect(function(data)
        if data and data.EquippedSlots then
            SpellSection.updateEquipped(data.EquippedSlots)
            UltimateSection.updateEquipped(data.EquippedSlots)
        end
    end)
end

-- ═══ Initial spell data load ═══
if Remotes.GetSpellData then
    task.spawn(function()
        local ok, data = pcall(function()
            return Remotes.GetSpellData:InvokeServer()
        end)
        if ok and data and data.EquippedSlots then
            SpellSection.updateEquipped(data.EquippedSlots)
            UltimateSection.updateEquipped(data.EquippedSlots)
        end
    end)
end

-- ═══ Render loop (cooldown tick) ═══
RunService.RenderStepped:Connect(function()
    AbilityCooldowns.tick(function(key)
        if key == "R" or key == "G" then
            return SpellSection.hasSpell(key)
        elseif key == "Z" then
            return UltimateSection.hasSpell()
        elseif key == "X" then
            return ClassSection.hasAbility(key)
        else
            return WeaponSection.hasAbility(key)
        end
    end)
end)
