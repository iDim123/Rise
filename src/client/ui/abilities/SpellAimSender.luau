local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local MouseUtil = require(script.Parent:WaitForChild("MouseUtil"))

local SpellAimSender = {}

local AIM_RATE = 0.05 -- send aim every 50ms
local isActive = false
local connection = nil
local lastSendTime = 0

function SpellAimSender.start()
    if isActive then
        return
    end
    isActive = true
    lastSendTime = 0

    connection = RunService.RenderStepped:Connect(function()
        if not isActive then
            SpellAimSender.stop()
            return
        end
        local now = tick()
        if (now - lastSendTime) < AIM_RATE then
            return
        end
        lastSendTime = now

        local pos = MouseUtil.getWorldPosition()
        if pos and Remotes.SpellAim then
            Remotes.SpellAim:FireServer(pos)
        end
    end)
end

function SpellAimSender.stop()
    isActive = false
    if connection then
        connection:Disconnect()
        connection = nil
    end
    -- Send one final position
    local pos = MouseUtil.getWorldPosition()
    if pos and Remotes.SpellAim then
        Remotes.SpellAim:FireServer(pos)
    end
end

return SpellAimSender
