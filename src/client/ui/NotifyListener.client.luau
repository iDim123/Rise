local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local NotifyModule = require(script.Parent:WaitForChild("NotifyModule"))

Remotes.Notify.OnClientEvent:Connect(function(text, notifType)
    NotifyModule.show(text, notifType)
end)
