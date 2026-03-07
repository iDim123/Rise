local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Enum.KeyCode.F5 then
        Remotes.DebugCommand:FireServer("save")
    elseif input.KeyCode == Enum.KeyCode.F6 then
        Remotes.DebugCommand:FireServer("data")
    elseif input.KeyCode == Enum.KeyCode.F7 then
        Remotes.DebugCommand:FireServer("addxp")
    elseif input.KeyCode == Enum.KeyCode.F8 then
        Remotes.DebugCommand:FireServer("wipe")
    elseif input.KeyCode == Enum.KeyCode.F9 then
        Remotes.DebugCommand:FireServer("togglesave")
    end

end)
