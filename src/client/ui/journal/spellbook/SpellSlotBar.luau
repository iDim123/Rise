local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SpellSlotBar = {}

local barFrame = nil
local slotFrames = {}
local equippedSlots = {}
local onSlotClickCallback = nil

function SpellSlotBar.build(parent)
    barFrame = Instance.new("Frame")
    barFrame.Name = "SpellSlotBar"
    barFrame.Size = UDim2.new(1, 0, 0, C.SLOT_BAR_H)
    barFrame.AnchorPoint = Vector2.new(0.5, 1)
    barFrame.Position = UDim2.new(0.5, 0, 1, 0)
    barFrame.BackgroundTransparency = 1
    barFrame.Parent = parent

    local labelFrame = Instance.new("Frame")
    labelFrame.Size = UDim2.new(0.5, 0, 0, 1)
    labelFrame.AnchorPoint = Vector2.new(0.5, 0)
    labelFrame.Position = UDim2.new(0.5, 0, 0, 0)
    labelFrame.BackgroundColor3 = C.SEPARATOR
    labelFrame.BackgroundTransparency = 0.5
    labelFrame.BorderSizePixel = 0
    labelFrame.Parent = barFrame

    local slotsLabel = Instance.new("TextLabel")
    slotsLabel.Size = UDim2.new(0, 120, 0, 16)
    slotsLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    slotsLabel.Position = UDim2.new(0.5, 0, 0, 0)
    slotsLabel.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
    slotsLabel.BackgroundTransparency = 0
    slotsLabel.Font = Enum.Font.Gotham
    slotsLabel.TextSize = 16
    slotsLabel.TextColor3 = C.TEXT_DIM
    slotsLabel.Text = "Current Spells"
    slotsLabel.Parent = barFrame

    local slotContainer = Instance.new("Frame")
    slotContainer.Name = "SlotContainer"
    slotContainer.Size = UDim2.new(0, 3 * C.SLOT_SIZE + 2 * C.SLOT_GAP, 0, C.SLOT_SIZE + 20)
    slotContainer.AnchorPoint = Vector2.new(0.5, 0)
    slotContainer.Position = UDim2.new(0.5, 0, 0, 18)
    slotContainer.BackgroundTransparency = 1
    slotContainer.Parent = barFrame

    local slots = SpellConfig.SpellSlots
    for i, slotDef in slots do
        local slotKey = slotDef.Key
        local x = (i - 1) * (C.SLOT_SIZE + C.SLOT_GAP)

        local slot = Instance.new("ImageButton")
        slot.Name = "Slot_" .. slotKey
        slot.Size = UDim2.new(0, C.SLOT_SIZE, 0, C.SLOT_SIZE)
        slot.Position = UDim2.new(0, x, 0, 0)
        slot.BackgroundColor3 = C.SLOT_BG
        slot.AutoButtonColor = false
        slot.Image = ""
        slot.ClipsDescendants = true
        slot.Parent = slotContainer

        Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 6)

        local slotStroke = Instance.new("UIStroke")
        slotStroke.Color = C.SLOT_BORDER
        slotStroke.Thickness = 1
        slotStroke.Parent = slot

        local iconImg = Instance.new("ImageLabel")
        iconImg.Name = "Icon"
        iconImg.Size = UDim2.new(1, 0, 1, 0)
        iconImg.BackgroundTransparency = 1
        iconImg.ScaleType = Enum.ScaleType.Stretch
        iconImg.Visible = false
        iconImg.Parent = slot
        Instance.new("UICorner", iconImg).CornerRadius = UDim.new(0, 6)

        local fallback = Instance.new("TextLabel")
        fallback.Name = "Fallback"
        fallback.Size = UDim2.new(1, -4, 1, -4)
        fallback.Position = UDim2.new(0, 2, 0, 2)
        fallback.BackgroundTransparency = 1
        fallback.Font = Enum.Font.GothamBold
        fallback.TextSize = 10
        fallback.TextColor3 = C.TEXT_DIM
        fallback.TextWrapped = true
        fallback.Visible = false
        fallback.Parent = slot

        local hotkeyLabel = Instance.new("TextLabel")
        hotkeyLabel.Size = UDim2.new(0, C.SLOT_SIZE, 0, 16)
        hotkeyLabel.Position = UDim2.new(0, x, 0, C.SLOT_SIZE + 2)
        hotkeyLabel.BackgroundTransparency = 1
        hotkeyLabel.Font = Enum.Font.GothamBold
        hotkeyLabel.TextSize = 14
        hotkeyLabel.TextColor3 = C.TEXT_BRIGHT
        hotkeyLabel.Text = slotKey
        hotkeyLabel.Parent = slotContainer

        slotFrames[slotKey] = {
            frame = slot,
            iconImage = iconImg,
            fallback = fallback
        }

        slot.Activated:Connect(function()
            if onSlotClickCallback then
                onSlotClickCallback(slotKey)
            end
        end)

        slot.MouseButton2Click:Connect(function()
            if equippedSlots[slotKey] then
                Remotes.UnequipSpell:FireServer(slotKey)
            end
        end)

        slot.MouseEnter:Connect(function()
            slot.BackgroundColor3 = C.CARD_BG_HOVER
        end)
        slot.MouseLeave:Connect(function()
            local filled = equippedSlots[slotKey] ~= nil
            slot.BackgroundColor3 = filled and C.SLOT_BG_FILLED or C.SLOT_BG
        end)
    end

    return barFrame
end

function SpellSlotBar.refresh(equipped)
    equippedSlots = equipped or {}

    for slotKey, slotData in slotFrames do
        local spellId = equippedSlots[slotKey]
        local spell = spellId and SpellConfig.Spells[spellId]

        if spell then
            if spell.Icon and spell.Icon ~= "" and spell.Icon ~= "rbxassetid://0" then
                slotData.iconImage.Image = spell.Icon
                slotData.iconImage.Visible = true
                slotData.fallback.Visible = false
            else
                slotData.iconImage.Visible = false
                slotData.fallback.Text = spell.Name or "?"
                slotData.fallback.Visible = true
            end
            slotData.frame.BackgroundColor3 = C.SLOT_BG_FILLED
        else
            slotData.iconImage.Visible = false
            slotData.fallback.Visible = false
            slotData.frame.BackgroundColor3 = C.SLOT_BG
        end
    end
end

function SpellSlotBar.onSlotClick(callback)
    onSlotClickCallback = callback
end

return SpellSlotBar
