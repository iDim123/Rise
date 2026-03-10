local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellConfig = require(ReplicatedStorage:WaitForChild("config"):WaitForChild("SpellConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SpellDetailEquip = {}

local equipSection = nil
-- local equippedLabel = nil
local equipButtons = {} -- { [slotKey] = { btn, stroke } }
local currentSpellIdRef = nil

-- Colors
local BTN_NORMAL = Color3.fromRGB(50, 50, 70)
local BTN_HOVER = Color3.fromRGB(65, 65, 90)
local BTN_EQUIPPED = Color3.fromRGB(40, 80, 40)
local BTN_EQUIPPED_HOVER = Color3.fromRGB(50, 100, 50)

function SpellDetailEquip.build(contentFrame, getSpellIdFn)
    currentSpellIdRef = getSpellIdFn

    equipSection = Instance.new("Frame")
    equipSection.Name = "EquipSection"
    equipSection.Size = UDim2.new(1, 0, 0, 0)
    equipSection.AutomaticSize = Enum.AutomaticSize.Y
    equipSection.BackgroundTransparency = 1
    equipSection.LayoutOrder = 10
    equipSection.Visible = false
    equipSection.Parent = contentFrame

    local equipLayout = Instance.new("UIListLayout")
    equipLayout.SortOrder = Enum.SortOrder.LayoutOrder
    equipLayout.Padding = UDim.new(0, 6)
    equipLayout.Parent = equipSection

    -- equippedLabel = Instance.new("TextLabel")
    -- equippedLabel.Name = "EquippedLabel"
    -- equippedLabel.Size = UDim2.new(1, 0, 0, 18)
    -- equippedLabel.BackgroundTransparency = 1
    -- equippedLabel.Font = Enum.Font.GothamBold
    -- equippedLabel.TextSize = 14
    -- equippedLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
    -- equippedLabel.TextXAlignment = Enum.TextXAlignment.Left
    -- equippedLabel.LayoutOrder = 1
    -- equippedLabel.Visible = false
    -- equippedLabel.Parent = equipSection

    local slotDefs = SpellConfig.SpellSlots
    for i, slotDef in slotDefs do
        local slotKey = slotDef.Key
        local btn = Instance.new("TextButton")
        btn.Name = "EquipBtn_" .. slotKey
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = BTN_NORMAL
        btn.AutoButtonColor = false
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.TextColor3 = C.TEXT_COLOR
        btn.Text = "Экипировать в " .. slotKey .. " (" .. slotDef.AllowedClass .. ")"
        btn.LayoutOrder = 10 + i
        btn.Parent = equipSection
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = C.STROKE_COLOR
        btnStroke.Thickness = 1
        btnStroke.Parent = btn

        -- Track state for hover
        local isEquippedState = false

        equipButtons[slotKey] = {
            btn = btn,
            stroke = btnStroke,
            isEquipped = false
        }

        btn.MouseEnter:Connect(function()
            local state = equipButtons[slotKey]
            btn.BackgroundColor3 = state.isEquipped and BTN_EQUIPPED_HOVER or BTN_HOVER
        end)
        btn.MouseLeave:Connect(function()
            local state = equipButtons[slotKey]
            btn.BackgroundColor3 = state.isEquipped and BTN_EQUIPPED or BTN_NORMAL
        end)

        btn.Activated:Connect(function()
            local spellId = currentSpellIdRef and currentSpellIdRef()
            if spellId then
                Remotes.EquipSpell:FireServer(spellId, slotKey)
            end
        end)
    end
end

function SpellDetailEquip.refresh(spell, spellId, spellData)
    if not spell or not spellId then
        equipSection.Visible = false
        return
    end

    equipSection.Visible = true

    -- Check where this spell is currently equipped
    local equippedInSlot = nil
    if spellData and spellData.EquippedSlots then
        for slotKey, eqId in spellData.EquippedSlots do
            if eqId == spellId then
                equippedInSlot = slotKey
                break
            end
        end
    end

    -- if equippedInSlot then
    --     equippedLabel.Text = "✓ Экипировано в слот " .. equippedInSlot
    --     equippedLabel.Visible = true
    -- else
    --     equippedLabel.Visible = false
    -- end

    -- Update equip buttons
    for slotKey, slotInfo in equipButtons do
        local btn = slotInfo.btn
        local slotDef = nil
        for _, sd in SpellConfig.SpellSlots do
            if sd.Key == slotKey then
                slotDef = sd
                break
            end
        end

        if slotDef and slotDef.AllowedClass == spell.Class then
            btn.Visible = true
            local currentInSlot = spellData and spellData.EquippedSlots and spellData.EquippedSlots[slotKey]

            if currentInSlot == spellId then
                btn.Text = "✓ Слот " .. slotKey .. " (экипировано)"
                btn.BackgroundColor3 = BTN_EQUIPPED
                slotInfo.isEquipped = true
            elseif currentInSlot then
                local otherSpell = SpellConfig.Spells[currentInSlot]
                local otherName = otherSpell and otherSpell.Name or currentInSlot
                btn.Text = "Слот " .. slotKey .. " (заменить " .. otherName .. ")"
                btn.BackgroundColor3 = BTN_NORMAL
                slotInfo.isEquipped = false
            else
                btn.Text = "Слот " .. slotKey .. " (пусто)"
                btn.BackgroundColor3 = BTN_NORMAL
                slotInfo.isEquipped = false
            end
        else
            btn.Visible = false
            slotInfo.isEquipped = false
        end
    end
end

function SpellDetailEquip.hide()
    equipSection.Visible = false
end

return SpellDetailEquip
