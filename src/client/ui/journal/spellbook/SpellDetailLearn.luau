local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local C = require(script.Parent:WaitForChild("SpellbookConstants"))

local SpellDetailLearn = {}

local learnButton = nil
local learnStroke = nil
local requireLabel = nil
local onLearnedCallback = nil
local currentSpellIdRef = nil -- function that returns current spell ID

function SpellDetailLearn.build(contentFrame, getSpellIdFn)
    currentSpellIdRef = getSpellIdFn

    -- Requirement label
    requireLabel = Instance.new("TextLabel")
    requireLabel.Name = "RequireLabel"
    requireLabel.Size = UDim2.new(1, 0, 0, 0)
    requireLabel.AutomaticSize = Enum.AutomaticSize.Y
    requireLabel.BackgroundTransparency = 1
    requireLabel.Font = Enum.Font.GothamBold
    requireLabel.TextSize = 14
    requireLabel.TextColor3 = Color3.fromRGB(200, 100, 100)
    requireLabel.TextXAlignment = Enum.TextXAlignment.Left
    requireLabel.TextWrapped = true
    requireLabel.LayoutOrder = 8
    requireLabel.Visible = false
    requireLabel.Parent = contentFrame

    -- Learn button
    learnButton = Instance.new("TextButton")
    learnButton.Name = "LearnButton"
    learnButton.Size = UDim2.new(1, 0, 0, 36)
    learnButton.BackgroundColor3 = Color3.fromRGB(40, 100, 40)
    learnButton.AutoButtonColor = false
    learnButton.Font = Enum.Font.GothamBold
    learnButton.TextSize = 16
    learnButton.TextColor3 = Color3.fromRGB(220, 255, 220)
    learnButton.Text = "Изучить"
    learnButton.LayoutOrder = 9
    learnButton.Visible = false
    learnButton.Parent = contentFrame
    Instance.new("UICorner", learnButton).CornerRadius = UDim.new(0, 6)

    learnStroke = Instance.new("UIStroke")
    learnStroke.Color = Color3.fromRGB(60, 140, 60)
    learnStroke.Thickness = 1
    learnStroke.Parent = learnButton

    -- Store the "normal" background for hover restore
    local normalBg = Color3.fromRGB(40, 100, 40)
    local hoverBg = Color3.fromRGB(50, 120, 50)

    learnButton.MouseEnter:Connect(function()
        learnButton.BackgroundColor3 = hoverBg
    end)
    learnButton.MouseLeave:Connect(function()
        learnButton.BackgroundColor3 = normalBg
    end)

    learnButton.Activated:Connect(function()
        local spellId = currentSpellIdRef and currentSpellIdRef()
        if spellId then
            Remotes.LearnSpell:FireServer(spellId)
            if onLearnedCallback then
                onLearnedCallback(spellId)
            end
        end
    end)
end

function SpellDetailLearn.refresh(spell, spellData)
    if not spell then
        learnButton.Visible = false
        requireLabel.Visible = false
        return
    end

    local accent = C.SCHOOL_ACCENTS[spell.School] or C.TEXT_COLOR
    local school = spell.School
    local tier = spell.Tier
    local isUlt = spell.Class == "Ultimate"
    local cost = spell.UnlockCost or 1
    local pointsKey = isUlt and "ULT" or tostring(tier)

    local available = 0
    if spellData and spellData.SpellPoints and spellData.SpellPoints[school] then
        available = spellData.SpellPoints[school][pointsKey] or 0
    end

    if available >= cost then
        learnButton.Visible = true
        requireLabel.Visible = false
        learnButton.BackgroundColor3 = Color3.fromRGB(40, 100, 40)
        learnStroke.Color = accent
    else
        learnButton.Visible = false
        requireLabel.Visible = true
        local tierName = isUlt and "Ultimate" or ("Tier " .. tier)
        requireLabel.Text = "Требуется: " .. cost .. " " .. school .. " " .. tierName ..
                                " Spell Point (есть: " .. available .. ")"
    end
end

function SpellDetailLearn.hide()
    learnButton.Visible = false
    requireLabel.Visible = false
end

function SpellDetailLearn.onLearned(callback)
    onLearnedCallback = callback
end

return SpellDetailLearn
