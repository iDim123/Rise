local Players = game:GetService("Players")

local MouseUtil = {}

function MouseUtil.getWorldPosition()
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()
    local camera = workspace.CurrentCamera
    local character = player.Character
    if not character then
        return Vector3.new(0, 0, 0)
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return Vector3.new(0, 0, 0)
    end

    local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local rayOrigin = mouseRay.Origin
    local rayDirection = mouseRay.Direction

    local groundY = rootPart.Position.Y - 3
    if math.abs(rayDirection.Y) < 0.001 then
        return rootPart.Position + rootPart.CFrame.LookVector * 10
    end
    local t = (groundY - rayOrigin.Y) / rayDirection.Y
    if t < 0 then
        return rootPart.Position + rootPart.CFrame.LookVector * 10
    end

    return rayOrigin + rayDirection * t
end

return MouseUtil
