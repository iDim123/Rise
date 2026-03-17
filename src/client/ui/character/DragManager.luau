local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local UC = require(script.Parent:WaitForChild("UIConstants"))

local DragManager = {}
local dropTargets = {}

DragManager.dragFrom = nil
DragManager.dragOverIndex = nil

local dragGhost = nil
local screenGui = nil
local dragData = nil -- { slotIndex: number, item: table }

function DragManager.init(gui)
    screenGui = gui
end

function DragManager.startDrag(slotIndex, itemData, source, extraData)
    DragManager.dragFrom = slotIndex
    dragData = {
        slotIndex = slotIndex,
        item = itemData,
        source = source or "inventory",
        extraData = extraData or nil
    }
    DragManager.createGhost(itemData)
end

function DragManager.getDragData()
    return dragData
end

function DragManager.getSource()
    return dragData and dragData.source or nil
end

function DragManager.reset(slotFrames)
    DragManager.dragFrom = nil
    DragManager.dragOverIndex = nil
    dragData = nil
    DragManager.destroyGhost()
end

function DragManager.createGhost(itemData)
    DragManager.destroyGhost()

    local Players = game:GetService("Players")
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    -- Отдельный ScreenGui поверх всех окон
    local dragLayer = playerGui:FindFirstChild("DragLayer")
    if not dragLayer then
        dragLayer = Instance.new("ScreenGui")
        dragLayer.Name = "DragLayer"
        dragLayer.DisplayOrder = 1000
        dragLayer.ResetOnSpawn = false
        dragLayer.Parent = playerGui
    end

    local mousePos = UserInputService:GetMouseLocation()

    local ghost = Instance.new("Frame")
    ghost.Name = "DragGhost"
    ghost.Size = UDim2.new(0, UC.slotSize, 0, UC.slotSize)
    ghost.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    ghost.BackgroundTransparency = 0.3
    ghost.BorderSizePixel = 0
    ghost.Position = UDim2.new(0, mousePos.X - UC.slotSize / 2, 0, mousePos.Y - UC.slotSize / 2)
    ghost.Parent = dragLayer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = ghost

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 180, 255)
    stroke.Thickness = 2
    stroke.Parent = ghost

    if itemData.Icon and itemData.Icon ~= "" and itemData.Icon ~= "rbxassetid://0" then
        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.new(0.8, 0, 0.8, 0)
        icon.Position = UDim2.new(0.1, 0, 0.1, 0)
        icon.BackgroundTransparency = 1
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Image = itemData.Icon
        icon.Parent = ghost
    else
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -4, 0.6, 0)
        label.Position = UDim2.new(0, 2, 0.05, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 9
        label.Font = Enum.Font.GothamBold
        label.TextWrapped = true
        label.Text = itemData.Name
        label.Parent = ghost
    end

    dragGhost = ghost
end
function DragManager.updateGhostPosition()
    if not dragGhost then
        return
    end
    local mousePos = UserInputService:GetMouseLocation()
    dragGhost.Position = UDim2.new(0, mousePos.X - UC.slotSize / 2, 0, mousePos.Y - UC.slotSize / 2)
end

function DragManager.destroyGhost()
    if dragGhost then
        dragGhost:Destroy()
        dragGhost = nil
    end
end

function DragManager.isDragging()
    return DragManager.dragFrom ~= nil
end

function DragManager.registerDropTarget(slotFrame, callback)
    dropTargets[slotFrame] = callback
end

function DragManager.unregisterDropTarget(slotFrame)
    dropTargets[slotFrame] = nil
end

function DragManager.tryDrop(mousePos)
    local GuiService = game:GetService("GuiService")
    local inset = GuiService:GetGuiInset()
    local adjustedPos = Vector2.new(mousePos.X - inset.X, mousePos.Y - inset.Y)

    for slotFrame, callback in dropTargets do
        local absPos = slotFrame.AbsolutePosition
        local absSize = slotFrame.AbsoluteSize
        if adjustedPos.X >= absPos.X and adjustedPos.X <= absPos.X + absSize.X and adjustedPos.Y >= absPos.Y and
            adjustedPos.Y <= absPos.Y + absSize.Y then
            callback(DragManager.getDragData())
            return true
        end
    end
    return false
end

-- Автообновление позиции призрака
RunService.RenderStepped:Connect(function()
    if DragManager.dragFrom and dragGhost then
        DragManager.updateGhostPosition()
    end
end)

return DragManager
