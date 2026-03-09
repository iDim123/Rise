local UserInputService = game:GetService("UserInputService")

local JournalWindow = require(script.Parent:WaitForChild("JournalWindow"))
local MenuBar = require(script.Parent.Parent:WaitForChild("MenuBar"))
local BossPage = require(script.Parent:WaitForChild("bosses"):WaitForChild("BossPage"))
local SpellbookPage = require(script.Parent:WaitForChild("spellbook"):WaitForChild("SpellbookPage"))

-- Build the journal
JournalWindow.build()

-- Register pages
JournalWindow.registerPage("Bosses", BossPage)
JournalWindow.registerPage("Spellbook", SpellbookPage)
-- JournalWindow.registerPage("Map", MapPage) -- будущее

-- MenuBar integration
MenuBar.onButtonClick("BossJournal", function()
    JournalWindow.toggle("Bosses")
end)

MenuBar.onButtonClick("Spellbook", function()
    JournalWindow.toggle("Spellbook")
end)

-- Hotkeys
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.B then
        JournalWindow.toggle("Bosses")
    elseif input.KeyCode == Enum.KeyCode.P then
        JournalWindow.toggle("Spellbook")
    end
end)
