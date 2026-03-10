--[[
    BuildingPlacer.luau
    Ghost-preview, snap-to-grid, размещение блоков, режим удаления.
    
    Модуль (не .client) — require из BuildingMenu.
    
    API:
      BuildingPlacer.startPlacing(blockTypeId)
      BuildingPlacer.startPlacingHeart()       -- NEW
      BuildingPlacer.stopPlacing()
      BuildingPlacer.startDeleteMode()
      BuildingPlacer.stopDeleteMode()
      BuildingPlacer.isActive() → boolean
      BuildingPlacer.isPlacingHeart() → boolean  -- NEW
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
local placingHeart = false -- NEW: режим размещения Castle Heart
local ghostPart = nil -- Part-призрак (обычные блоки)
local ghostModel = nil -- Model-призрак (Castle Heart)  NEW
local ghostHighlight = nil
local currentRotation = 0
local deleteMode = false
local deleteHighlight = nil
local hoveredBlock = nil
local renderConn = nil

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

-- ═══ Ghost Part (обычные блоки) ═══

local function createGhost(blockTypeId)
    local bt = Config.Building.BlockTypes[blockTypeId]
    if not bt then
        return
    end

    local size = getRotatedSize(bt.Size, currentRotation)

    local part = Instance.new("Part")
    part.Name = "BuildingGhost"
    part.Size = size
    part.Material = bt.Material or Enum.Material.SmoothPlastic
    part.Color = bt.Color or Color3.fromRGB(128, 128, 128)
    part.Transparency = BC.GHOST_TRANSPARENCY
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = false
    part.Parent = workspace

    local highlight = Instance.new("SelectionBox")
    highlight.Adornee = part
    highlight.Color3 = BC.GHOST_VALID_BORDER
    highlight.SurfaceColor3 = BC.GHOST_VALID_COLOR
    highlight.SurfaceTransparency = 0.8
    highlight.LineThickness = BC.GHOST_BORDER_THICKNESS
    highlight.Parent = part

    ghostPart = part
    ghostHighlight = highlight
end

local function destroyGhost()
    if ghostPart then
        ghostPart:Destroy()
        ghostPart = nil
        ghostHighlight = nil
    end
end

-- ═══ Ghost Model (Castle Heart) ═══  NEW

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
    platform.Transparency = BC.GHOST_TRANSPARENCY
    platform.Anchored = true
    platform.CanCollide = false
    platform.CastShadow = false
    platform.Parent = model

    model.PrimaryPart = platform

    -- Pedestal
    local pedestal = Instance.new("Part")
    pedestal.Name = "Pedestal"
    pedestal.Shape = Enum.PartType.Cylinder
    pedestal.Size = Vector3.new(vis.Pedestal.Height, vis.Pedestal.Diameter, vis.Pedestal.Diameter)
    pedestal.Material = vis.Pedestal.Material
    pedestal.Color = vis.Pedestal.Color
    pedestal.Transparency = BC.GHOST_TRANSPARENCY
    pedestal.Anchored = true
    pedestal.CanCollide = false
    pedestal.CastShadow = false
    pedestal.Orientation = Vector3.new(0, 0, 90)
    pedestal.Position = platform.Position + Vector3.new(0, vis.Platform.Size.Y / 2 + vis.Pedestal.Height / 2, 0)
    pedestal.Parent = model

    -- Orb
    local orbDiameter = vis.Orb.MinDiameter
    local orb = Instance.new("Part")
    orb.Name = "Orb"
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(orbDiameter, orbDiameter, orbDiameter)
    orb.Material = vis.Orb.Material
    orb.Color = vis.Orb.EmptyColor
    orb.Transparency = BC.GHOST_TRANSPARENCY
    orb.Anchored = true
    orb.CanCollide = false
    orb.CastShadow = false
    orb.Position = pedestal.Position + Vector3.new(0, vis.Pedestal.Height / 2 + orbDiameter / 2, 0)
    orb.Parent = model

    -- Highlight вместо SelectionBox — обводит всю Model целиком,
    -- тонкая рамка без заливки поверхности
    local highlight = Instance.new("Highlight")
    highlight.Name = "GhostHighlight"
    highlight.Adornee = model
    highlight.FillTransparency = 0.7 -- почти прозрачная заливка
    highlight.FillColor = BC.GHOST_VALID_COLOR
    highlight.OutlineColor = BC.GHOST_VALID_BORDER
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Parent = model

    model.Parent = workspace
    ghostModel = model
    ghostHighlight = highlight
end

local function destroyHeartGhost()
    if ghostModel then
        ghostModel:Destroy()
        ghostModel = nil
        ghostHighlight = nil
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
        -- Прячем ghost за пределами экрана
        for _, child in ghostModel:GetChildren() do
            if child:IsA("BasePart") then
                child.Transparency = 1
            end
        end
        return
    end

    -- Показываем ghost
    for _, child in ghostModel:GetChildren() do
        if child:IsA("BasePart") then
            child.Transparency = BC.GHOST_TRANSPARENCY
        end
    end

    local hitPos = rayResult.Position
    local snappedX = snapToGrid(hitPos.X)
    local snappedZ = snapToGrid(hitPos.Z)
    local surfaceY = hitPos.Y

    local platformPos = Vector3.new(snappedX, surfaceY + vis.Platform.Size.Y / 2, snappedZ)
    platform.Position = platformPos

    -- Обновляем позиции дочерних частей относительно платформы
    local pedestal = ghostModel:FindFirstChild("Pedestal")
    if pedestal then
        pedestal.Position = platformPos + Vector3.new(0, vis.Platform.Size.Y / 2 + vis.Pedestal.Height / 2, 0)
    end

    local orb = ghostModel:FindFirstChild("Orb")
    if orb and pedestal then
        local orbDiameter = vis.Orb.MinDiameter
        orb.Position = pedestal.Position + Vector3.new(0, vis.Pedestal.Height / 2 + orbDiameter / 2, 0)
    end

    -- Валидация (клиентская — грубая)
    local isValid = true

    -- Проверка: только на Ground (нормаль вверх)
    if rayResult.Normal.Y < 0.8 then
        isValid = false
    end

    -- Обновляем цвет
    if ghostHighlight then
        if isValid then
            ghostHighlight.FillColor = BC.GHOST_VALID_COLOR
            ghostHighlight.OutlineColor = BC.GHOST_VALID_BORDER
        else
            ghostHighlight.FillColor = BC.GHOST_INVALID_COLOR
            ghostHighlight.OutlineColor = BC.GHOST_INVALID_BORDER
        end
    end
end

-- ═══ Ghost для обычных блоков ═══

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

    ghostPart.Transparency = BC.GHOST_TRANSPARENCY
    local size = getRotatedSize(bt.Size, currentRotation)
    ghostPart.Size = size

    local hitPos = rayResult.Position
    local snappedX = snapToGrid(hitPos.X)
    local snappedZ = snapToGrid(hitPos.Z)
    local surfaceY = hitPos.Y

    local finalPos = Vector3.new(snappedX, surfaceY + size.Y / 2, snappedZ)
    ghostPart.Position = finalPos
    ghostPart.Orientation = Vector3.new(0, currentRotation, 0)

    local isValid = true
    local hrp = getCharacterRoot()
    if hrp then
        local dist = (Vector2.new(finalPos.X, finalPos.Z) - Vector2.new(hrp.Position.X, hrp.Position.Z)).Magnitude
        if dist > 100 then
            isValid = false
        end
    end

    if ghostHighlight then
        if isValid then
            ghostHighlight.Color3 = BC.GHOST_VALID_BORDER
            ghostHighlight.SurfaceColor3 = BC.GHOST_VALID_COLOR
        else
            ghostHighlight.Color3 = BC.GHOST_INVALID_BORDER
            ghostHighlight.SurfaceColor3 = BC.GHOST_INVALID_COLOR
        end
    end
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

        -- Поворот (только для обычных блоков, Castle Heart не вращается)
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
            -- Castle Heart placement
            if placingHeart and ghostModel then
                local platform = ghostModel.PrimaryPart
                if platform then
                    Remotes.PlaceCastleHeart:FireServer(platform.Position)
                    BuildingPlacer.stopPlacing()
                end
                return
            end

            -- Обычный блок
            if placingBlockTypeId and ghostPart then
                Remotes.PlaceBlock:FireServer(placingBlockTypeId, ghostPart.Position, currentRotation)
                return
            end

            -- Удаление
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

--- Начать размещение Castle Heart (ghost-модель на курсоре)
function BuildingPlacer.startPlacingHeart()
    -- Остановить всё предыдущее
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
