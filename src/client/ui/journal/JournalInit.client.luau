local UserInputService = game:GetService("UserInputService")

local JournalWindow = require(script.Parent:WaitForChild("JournalWindow"))
local MenuBar = require(script.Parent.Parent:WaitForChild("MenuBar"))
local BossPage = require(script.Parent:WaitForChild("bosses"):WaitForChild("BossPage"))
local SpellbookPage = require(script.Parent:WaitForChild("spellbook"):WaitForChild("SpellbookPage"))
local WindowManager = require(script.Parent.Parent:WaitForChild("WindowManager"))

-- Build the journal
JournalWindow.build()
JournalWindow.setWindowManager(WindowManager) -- ← вот эта строка отсутствовала

-- Register pages
JournalWindow.registerPage("Bosses", BossPage)
JournalWindow.registerPage("Spellbook", SpellbookPage)

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

    if input.KeyCode == Enum.KeyCode.J then
        JournalWindow.toggle("Bosses")
    elseif input.KeyCode == Enum.KeyCode.P then
        JournalWindow.toggle("Spellbook")
    end
end)
