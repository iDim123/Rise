local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UC = require(script.Parent:WaitForChild("UIConstants"))
local SlotFactory = require(script.Parent:WaitForChild("SlotFactory"))
local CooldownManager = require(script.Parent:WaitForChild("CooldownManager"))

local ActionBarHUD = {}

local actionBarSlots = {}
local cachedSlotsData = nil

function ActionBarHUD.build(playerGui, setActiveWeaponRemote, useItemRemote)
    local gui = Instance.new("ScreenGui")
    gui.Name = "ActionBarGui"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local frameW = UC.padding + UC.cols * (UC.slotSize + UC.padding)
    local frameH = UC.slotSize + 20

    local frame = Instance.new("Frame")
    frame.Name = "ActionBar"
    frame.Size = UDim2.new(0, frameW, 0, frameH)
    frame.AnchorPoint = Vector2.new(0.5, 1)
    frame.Position = UDim2.new(0.5, 0, 1, -10)
    frame.BackgroundColor3 = UC.windowBg
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    for col = 0, UC.cols - 1 do
        local index = col + 1
        local posX = UC.padding + col * (UC.slotSize + UC.padding)

        local slot = SlotFactory.createSlot(frame, "AB_" .. index, posX, 2)

        -- Number label
        local numLabel = Instance.new("TextLabel")
        numLabel.Name = "NumLabel"
        numLabel.Size = UDim2.new(1, 0, 0, 14)
        numLabel.Position = UDim2.new(0, 0, 1, 2)
        numLabel.BackgroundTransparency = 1
        numLabel.TextColor3 = UC.bindColor
        numLabel.TextSize = 11
        numLabel.Font = Enum.Font.GothamBold
        numLabel.Text = tostring(index)
        numLabel.TextXAlignment = Enum.TextXAlignment.Center
        numLabel.Parent = slot

        slot.MouseButton2Click:Connect(function()
            local slotData = nil
            if cachedSlotsData then
                slotData = cachedSlotsData[index]
            end

            if slotData and slotData ~= false and slotData.Type == "Consumable" then
                if not CooldownManager.isOnCooldown(slotData.Id) then
                    local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
                    local itemDef = Config.Items[slotData.Id]
                    if itemDef and itemDef.UseEffect and itemDef.UseEffect.Cooldown then
                        CooldownManager.startCooldown(slotData.Id, itemDef.UseEffect.Cooldown)
                    end
                    useItemRemote:FireServer(index)
                end
            else
                setActiveWeaponRemote:FireServer(index)
            end
        end)

        actionBarSlots[index] = slot
       
        CooldownManager.registerSlot(slot, function()
            if cachedSlotsData then
                local item = cachedSlotsData[index]
                if item and item ~= false then
                    return item.Id
                end
            end
            return nil
        end)
    end
end

function ActionBarHUD.refresh(slotsData, activeWeaponSlot)
    cachedSlotsData = slotsData  -- сохраняем для проверки при клике
    for i, slot in actionBarSlots do
        local itemData = slotsData[i]
        if itemData == false then itemData = nil end
        SlotFactory.updateSlot(slot, itemData, activeWeaponSlot, i)
    end
end

return ActionBarHUD