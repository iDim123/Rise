--[[
    BuildingPlacer.luau
    Ghost-preview, snap-to-grid, размещение блоков, режим удаления.
    
    API:
      BuildingPlacer.startPlacing(blockTypeId)
      BuildingPlacer.startPlacingHeart()
      BuildingPlacer.stopPlacing()
      BuildingPlacer.startDeleteMode()
      BuildingPlacer.stopDeleteMode()
      BuildingPlacer.isActive() → boolean
      BuildingPlacer.isPlacingHeart() → boolean
      BuildingPlacer.cleanup()
]] local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local BC = require(script.Parent:WaitForChild("BuildingConstants"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local BuildingPlacer = {}

-- ═══ Состояние ═══
local placingBlockTypeId = nil
local placingHeart = false
local ghostPart = nil
local ghostModel = nil
local currentRotation = 0
local deleteMode = false
local deleteHighlight = nil
local hoveredBlock = nil
local renderConn = nil

-- ═══ Цвета для валидности ghost ═══
local VALID_TINT = Color3.fromRGB(100, 255, 100)
local INVALID_TINT = Color3.fromRGB(255, 80, 80)
local GHOST_ALPHA = 0.5

-- ═══ Helpers ═══

local function getCharacterRoot()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function snapToGrid(value)
    return math.round(value / BC.GRID_SIZE) * BC.GRID_SIZE
end

local function getRotatedSize(baseSize, rotation)
    if rotation == 90 or rotation == 270 then
        return Vector3.new(baseSize.Z, baseSize.Y, baseSize.X)
    end
    return baseSize
end

local function getMouseRayHit()
    local unitRay = mouse.UnitRay
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = {}
    if ghostPart then
        table.insert(filterList, ghostPart)
    end
    if ghostModel then
        table.insert(filterList, ghostModel)
    end
    if player.Character then
        table.insert(filterList, player.Character)
    end
    params.FilterDescendantsInstances = filterList

    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 200, params)
    return result
end

--- Применить оттенок валидности к Part
local function tintPart(part, isValid)
    if isValid then
        -- Слегка зеленоватый оттенок оригинального цвета
        local orig = part:GetAttribute("_OrigColor")
        if orig then
            part.Color = orig:Lerp(VALID_TINT, 0.3)
        end
    else
        local orig = part:GetAttribute("_OrigColor")
        if orig then
            part.Color = orig:Lerp(INVALID_TINT, 0.5)
        end
    end
end

-- ═══ Ghost Part (обычные блоки) ═══

local function createGhost(blockTypeId)
    local bt = Config.Building.BlockTypes[blockTypeId]
    if not bt then
        return
    end

    local size = getRotatedSize(bt.Size, currentRotation)
    local color = bt.Color or Color3.fromRGB(128, 128, 128)

    local part = Instance.new("Part")
    part.Name = "BuildingGhost"
    part.Size = size
    part.Material = bt.Material or Enum.Material.SmoothPlastic
    part.Color = color
    part.Transparency = GHOST_ALPHA
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = false
    part:SetAttribute("_OrigColor", color)
    part.Parent = workspace

    ghostPart = part
end

local function destroyGhost()
    if ghostPart then
        ghostPart:Destroy()
        ghostPart = nil
    end
end

local function updateGhostPosition()
    if not ghostPart or not placingBlockTypeId then
        return
    end

    local bt = Config.Building.BlockTypes[placingBlockTypeId]
    if not bt then
        return
    end

    local rayResult = getMouseRayHit()
    if not rayResult then
        ghostPart.Transparency = 1
        return
    end

    ghostPart.Transparency = GHOST_ALPHA

    local size = getRotatedSize(bt.Size, currentRotation)
    ghostPart.Size = size

    local hitPos = rayResult.Position
    local snappedX = snapToGrid(hitPos.X)
    local snappedZ = snapToGrid(hitPos.Z)
    local surfaceY = hitPos.Y

    local finalPos = Vector3.new(snappedX, surfaceY + size.Y / 2, snappedZ)

    -- Edge-snap для стен на фундаменте
    local hitPart = rayResult.Instance
    if bt.PlacementRule == "OnFoundation" and bt.Category == "Wall" and hitPart and hitPart:IsA("BasePart") and
        hitPart:GetAttribute("IsStructure") then

        local hitTypeId = hitPart:GetAttribute("BlockTypeId")
        if hitTypeId then
            local hitBt = Config.Building.BlockTypes[hitTypeId]
            local hitCat = hitBt and hitBt.Category

            if hitCat == "Foundation" then
                local fPos = hitPart.Position
                local fSize = hitPart.Size
                local halfFX = fSize.X / 2
                local halfFZ = fSize.Z / 2
                local fSurfaceY = fPos.Y + fSize.Y / 2

                if currentRotation == 0 or currentRotation == 180 then
                    local northEdge = fPos.Z - halfFZ
                    local southEdge = fPos.Z + halfFZ
                    local dN = math.abs(snappedZ - northEdge)
                    local dS = math.abs(snappedZ - southEdge)
                    local edgeZ = dN <= dS and northEdge or southEdge
                    finalPos = Vector3.new(fPos.X, fSurfaceY + size.Y / 2, edgeZ)
                else
                    local westEdge = fPos.X - halfFX
                    local eastEdge = fPos.X + halfFX
                    local dW = math.abs(snappedX - westEdge)
                    local dE = math.abs(snappedX - eastEdge)
                    local edgeX = dW <= dE and westEdge or eastEdge
                    finalPos = Vector3.new(edgeX, fSurfaceY + size.Y / 2, fPos.Z)
                end
            end
        end
    end

    ghostPart.Position = finalPos

    -- Валидация (грубая клиентская)
    local isValid = true
    local hrp = getCharacterRoot()
    if hrp then
        local dist = (Vector2.new(finalPos.X, finalPos.Z) - Vector2.new(hrp.Position.X, hrp.Position.Z)).Magnitude
        if dist > 100 then
            isValid = false
        end
    end

    tintPart(ghostPart, isValid)
end

-- ═══ Ghost Model (Castle Heart) ═══

local function createHeartGhost()
    local heartCfg = Config.Building.CastleHeart
    local vis = heartCfg.Visual

    local model = Instance.new("Model")
    model.Name = "CastleHeartGhost"

    -- Platform
    local platform = Instance.new("Part")
    platform.Name = "Platform"
    platform.Size = vis.Platform.Size
    platform.Material = vis.Platform.Material
    platform.Color = vis.Platform.Color
    platform.Transparency = GHOST_ALPHA
    platform.Anchored = true
    platform.CanCollide = false
    platform.CastShadow = false
    platform:SetAttribute("_OrigColor", vis.Platform.Color)
    platform.Parent = model

    model.PrimaryPart = platform

    -- Pedestal
    local pedestal = Instance.new("Part")
    pedestal.Name = "Pedestal"
    pedestal.Shape = Enum.PartType.Cylinder
    pedestal.Size = Vector3.new(vis.Pedestal.Height, vis.Pedestal.Diameter, vis.Pedestal.Diameter)
    pedestal.Material = vis.Pedestal.Material
    pedestal.Color = vis.Pedestal.Color
    pedestal.Transparency = GHOST_ALPHA
    pedestal.Anchored = true
    pedestal.CanCollide = false
    pedestal.CastShadow = false
    pedestal.Orientation = Vector3.new(0, 0, 90)
    pedestal.Position = platform.Position + Vector3.new(0, vis.Platform.Size.Y / 2 + vis.Pedestal.Height / 2, 0)
    pedestal:SetAttribute("_OrigColor", vis.Pedestal.Color)
    pedestal.Parent = model

    -- Orb
    local orbDiameter = vis.Orb.MinDiameter
    local orb = Instance.new("Part")
    orb.Name = "Orb"
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(orbDiameter, orbDiameter, orbDiameter)
    orb.Material = vis.Orb.Material
    orb.Color = vis.Orb.EmptyColor
    orb.Transparency = GHOST_ALPHA
    orb.Anchored = true
    orb.CanCollide = false
    orb.CastShadow = false
    orb.Position = pedestal.Position + Vector3.new(0, vis.Pedestal.Height / 2 + orbDiameter / 2, 0)
    orb:SetAttribute("_OrigColor", vis.Orb.EmptyColor)
    orb.Parent = model

    model.Parent = workspace
    ghostModel = model
end

local function destroyHeartGhost()
    if ghostModel then
        ghostModel:Destroy()
        ghostModel = nil
    end
end

local function tintHeartGhost(isValid)
    if not ghostModel then
        return
    end
    for _, child in ghostModel:GetChildren() do
        if child:IsA("BasePart") then
            tintPart(child, isValid)
        end
    end
end

local function updateHeartGhostPosition()
    if not ghostModel then
        return
    end

    local vis = Config.Building.CastleHeart.Visual
    local platform = ghostModel.PrimaryPart
    if not platform then
        return
    end

    local rayResult = getMouseRayHit()
    if not rayResult then
        for _, child in ghostModel:GetChildren() do
            if child:IsA("BasePart") then
                child.Transparency = 1
            end
        end
        return
    end

    -- Показываем
    for _, child in ghostModel:GetChildren() do
        if child:IsA("BasePart") then
            child.Transparency = GHOST_ALPHA
        end
    end

    local hitPos = rayResult.Position
    local snappedX = snapToGrid(hitPos.X)
    local snappedZ = snapToGrid(hitPos.Z)
    local surfaceY = hitPos.Y

    local platformPos = Vector3.new(snappedX, surfaceY + vis.Platform.Size.Y / 2, snappedZ)
    platform.Position = platformPos

    local pedestal = ghostModel:FindFirstChild("Pedestal")
    if pedestal then
        pedestal.Position = platformPos + Vector3.new(0, vis.Platform.Size.Y / 2 + vis.Pedestal.Height / 2, 0)
    end

    local orb = ghostModel:FindFirstChild("Orb")
    if orb and pedestal then
        local orbDiameter = vis.Orb.MinDiameter
        orb.Position = pedestal.Position + Vector3.new(0, vis.Pedestal.Height / 2 + orbDiameter / 2, 0)
    end

    -- Валидация
    local isValid = true
    if rayResult.Normal and rayResult.Normal.Y < 0.8 then
        isValid = false
    end

    tintHeartGhost(isValid)
end

-- ═══ Delete Mode ═══

local function createDeleteHighlight()
    if deleteHighlight then
        return
    end
    deleteHighlight = Instance.new("SelectionBox")
    deleteHighlight.Color3 = BC.DELETE_HIGHLIGHT_COLOR
    deleteHighlight.SurfaceColor3 = BC.DELETE_HIGHLIGHT_COLOR
    deleteHighlight.SurfaceTransparency = BC.DELETE_HIGHLIGHT_TRANSPARENCY
    deleteHighlight.LineThickness = 2
    deleteHighlight.Parent = player.PlayerGui
end

local function updateDeleteMode()
    if not deleteMode or not deleteHighlight then
        return
    end

    local rayResult = getMouseRayHit()
    hoveredBlock = nil

    if rayResult and rayResult.Instance then
        local hit = rayResult.Instance
        if hit:IsA("BasePart") and hit:GetAttribute("IsStructure") and hit:GetAttribute("BlockId") then
            if not hit:GetAttribute("IsCastleHeart") then
                hoveredBlock = hit
                deleteHighlight.Adornee = hit
                deleteHighlight.Visible = true
                return
            end
        end
    end

    deleteHighlight.Adornee = nil
    deleteHighlight.Visible = false
end

local function destroyDeleteHighlight()
    if deleteHighlight then
        deleteHighlight:Destroy()
        deleteHighlight = nil
    end
    hoveredBlock = nil
end

-- ═══ Render Loop ═══

local function onRenderStepped()
    if placingHeart then
        updateHeartGhostPosition()
    elseif placingBlockTypeId then
        updateGhostPosition()
    elseif deleteMode then
        updateDeleteMode()
    end
end

local function connectRender()
    if renderConn then
        return
    end
    renderConn = RunService.RenderStepped:Connect(onRenderStepped)
end

local function disconnectRender()
    if renderConn then
        renderConn:Disconnect()
        renderConn = nil
    end
end

-- ═══ Input ═══

local inputConn = nil

local function connectInput()
    if inputConn then
        return
    end
    inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end

        -- Поворот
        if input.KeyCode == BC.KEY_ROTATE and placingBlockTypeId then
            local bt = Config.Building.BlockTypes[placingBlockTypeId]
            if bt and bt.CanRotate then
                currentRotation = (currentRotation + 90) % 360
            end
            return
        end

        -- Отмена
        if input.KeyCode == BC.KEY_CANCEL then
            if placingHeart then
                BuildingPlacer.stopPlacing()
            elseif placingBlockTypeId then
                BuildingPlacer.stopPlacing()
            elseif deleteMode then
                BuildingPlacer.stopDeleteMode()
            end
            return
        end

        -- Размещение (LMB)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if placingHeart and ghostModel then
                local platform = ghostModel.PrimaryPart
                if platform then
                    Remotes.PlaceCastleHeart:FireServer(platform.Position)
                    BuildingPlacer.stopPlacing()
                end
                return
            end

            if placingBlockTypeId and ghostPart then
                Remotes.PlaceBlock:FireServer(placingBlockTypeId, ghostPart.Position, currentRotation)
                return
            end

            if deleteMode and hoveredBlock then
                local blockId = hoveredBlock:GetAttribute("BlockId")
                if blockId then
                    Remotes.RemoveBlock:FireServer(blockId)
                end
                return
            end
        end
    end)
end

local function disconnectInput()
    if inputConn then
        inputConn:Disconnect()
        inputConn = nil
    end
end

-- ═══ Публичное API ═══

function BuildingPlacer.startPlacingHeart()
    BuildingPlacer.stopPlacing()
    BuildingPlacer.stopDeleteMode()

    placingHeart = true
    placingBlockTypeId = nil
    currentRotation = 0

    createHeartGhost()
    connectRender()
    connectInput()
end

function BuildingPlacer.startPlacing(blockTypeId)
    local bt = Config.Building.BlockTypes[blockTypeId]
    if not bt then
        return
    end

    BuildingPlacer.stopPlacing()
    BuildingPlacer.stopDeleteMode()

    placingBlockTypeId = blockTypeId
    placingHeart = false
    currentRotation = 0

    createGhost(blockTypeId)
    connectRender()
    connectInput()
end

function BuildingPlacer.stopPlacing()
    placingBlockTypeId = nil
    placingHeart = false
    currentRotation = 0
    destroyGhost()
    destroyHeartGhost()

    if not deleteMode then
        disconnectRender()
        disconnectInput()
    end
end

function BuildingPlacer.startDeleteMode()
    BuildingPlacer.stopPlacing()
    deleteMode = true
    createDeleteHighlight()
    connectRender()
    connectInput()
end

function BuildingPlacer.stopDeleteMode()
    deleteMode = false
    destroyDeleteHighlight()

    if not placingBlockTypeId and not placingHeart then
        disconnectRender()
        disconnectInput()
    end
end

function BuildingPlacer.isActive()
    return placingBlockTypeId ~= nil or placingHeart or deleteMode
end

function BuildingPlacer.isPlacingHeart()
    return placingHeart
end

function BuildingPlacer.getPlacingType()
    return placingBlockTypeId
end

function BuildingPlacer.isDeleteMode()
    return deleteMode
end

function BuildingPlacer.cleanup()
    BuildingPlacer.stopPlacing()
    BuildingPlacer.stopDeleteMode()
end

return BuildingPlacer
