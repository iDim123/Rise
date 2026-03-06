local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuBar = require(script.Parent.Parent:WaitForChild("MenuBar"))
local BossJournal = require(script.Parent:WaitForChild("BossJournal"))

BossJournal.build()

-- MenuBar button
MenuBar.onButtonClick("BossJournal", function()
    BossJournal.toggle()
end)

-- Hotkey B
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end
    if input.KeyCode == Enum.KeyCode.B then
        BossJournal.toggle()
    end
end)
