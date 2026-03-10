--[[
    BuildingPlacer.luau
    Ghost-preview, snap-to-grid, размещение блоков, режим удаления.
    
    Модуль (не .client) — require из BuildingMenu.
    
    API:
      BuildingPlacer.startPlacing(blockTypeId)
      BuildingPlacer.stopPlacing()
      BuildingPlacer.startDeleteMode()
      BuildingPlacer.stopDeleteMode()
      BuildingPlacer.isActive() → boolean
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
local placingBlockTypeId = nil -- текущий выбранный тип блока
local ghostPart = nil -- Part-призрак
local ghostHighlight = nil -- SelectionBox / Highlight
local currentRotation = 0 -- 0, 90, 180, 270
local deleteMode = false
local deleteHighlight = nil -- Highlight для режима удаления
local hoveredBlock = nil -- Part под курсором в режиме удаления
local renderConn = nil -- RenderStepped connection

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
    if player.Character then
        table.insert(filterList, player.Character)
    end
    params.FilterDescendantsInstances = filterList

    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 200, params)
    return result
end

-- ═══ Ghost Part ═══

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

    -- Highlight (SelectionBox)
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

    -- Проверки валидности (клиентская превалидация)
    local isValid = true

    -- Проверка: внутри ClaimRadius (примерная — полная валидация на сервере)
    local hrp = getCharacterRoot()
    if hrp then
        local dist = (Vector2.new(finalPos.X, finalPos.Z) - Vector2.new(hrp.Position.X, hrp.Position.Z)).Magnitude
        if dist > 100 then -- грубый лимит, точную проверку делает сервер
            isValid = false
        end
    end

    -- Цвет ghost
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
            -- Не Castle Heart
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
    if placingBlockTypeId then
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
            if placingBlockTypeId then
                BuildingPlacer.stopPlacing()
            elseif deleteMode then
                BuildingPlacer.stopDeleteMode()
            end
            return
        end

        -- Размещение (LMB)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if placingBlockTypeId and ghostPart then
                Remotes.PlaceBlock:FireServer(placingBlockTypeId, ghostPart.Position, currentRotation)
                -- Не останавливаем — можно ставить блоки подряд
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

function BuildingPlacer.startPlacing(blockTypeId)
    local bt = Config.Building.BlockTypes[blockTypeId]
    if not bt then
        return
    end

    -- Остановить предыдущее
    BuildingPlacer.stopPlacing()
    BuildingPlacer.stopDeleteMode()

    placingBlockTypeId = blockTypeId
    currentRotation = 0

    createGhost(blockTypeId)
    connectRender()
    connectInput()
end

function BuildingPlacer.stopPlacing()
    placingBlockTypeId = nil
    currentRotation = 0
    destroyGhost()

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

    if not placingBlockTypeId then
        disconnectRender()
        disconnectInput()
    end
end

function BuildingPlacer.isActive()
    return placingBlockTypeId ~= nil or deleteMode
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
