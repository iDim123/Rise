--[[
    DoorHandler.luau
    Обработка дверей в замке: открытие/закрытие по F.
    
    Механика:
    - Дверь поворачивается на 90° вокруг левого края (hinge)
    - CanCollide отключается при открытии
    - Повторное нажатие F закрывает дверь
    - Проверка прав через CastleBorder.canInteract
    
    Используется: FunctionalDispatcher
    Зависимости: CastleBorder, TweenService
]] local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local CastleBorder = require(modules:WaitForChild("building"):WaitForChild("CastleBorder"))

local DoorHandler = {}

-- doorStates[part] = { isOpen, tweening, closedCFrame, openCFrame, hingeCFrame }
local doorStates = {}

local TWEEN_TIME = 0.4
local TWEEN_INFO = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OPEN_ANGLE = math.rad(-90)

--- Вычислить CFrame двери в открытом состоянии.
--- Поворот вокруг левого края (hinge) на -90° по оси Y.
local function calcOpenCFrame(closedCF, size)
    local doorWidth, hingeLocalOffset

    if size.X >= size.Z then
        doorWidth = size.X
        hingeLocalOffset = Vector3.new(-doorWidth / 2, 0, 0)
    else
        doorWidth = size.Z
        hingeLocalOffset = Vector3.new(0, 0, -doorWidth / 2)
    end

    local hingeWorldPos = closedCF:PointToWorldSpace(hingeLocalOffset)

    local _, yRot, _ = closedCF:ToEulerAnglesYXZ()
    local hingeCF = CFrame.new(hingeWorldPos) * CFrame.fromEulerAnglesYXZ(0, yRot, 0)

    local openCF = hingeCF * CFrame.Angles(0, OPEN_ANGLE, 0) * hingeCF:Inverse() * closedCF

    return openCF, hingeCF
end

--- Инициализировать дверь при размещении.
--- @param part BasePart
function DoorHandler.initDoor(part)
    local closedCF = part.CFrame
    local openCF, hingeCF = calcOpenCFrame(closedCF, part.Size)

    doorStates[part] = {
        isOpen = false,
        tweening = false,
        closedCFrame = closedCF,
        openCFrame = openCF,
        hingeCFrame = hingeCF
    }
end

--- Взаимодействие с дверью (F).
--- @param player Player
--- @param part BasePart
--- @return boolean, string?
function DoorHandler.interact(player, part)
    local state = doorStates[part]
    if not state then
        return false, "Дверь не инициализирована"
    end

    if state.tweening then
        return false, "Дверь уже в движении"
    end

    local ownerId = part:GetAttribute("CastleOwnerId")
    if ownerId then
        if not CastleBorder.canInteract(player.UserId, ownerId) then
            return false, "Нет прав доступа"
        end
    end

    state.tweening = true

    if state.isOpen then
        local tween = TweenService:Create(part, TWEEN_INFO, {
            CFrame = state.closedCFrame
        })
        tween.Completed:Once(function()
            part.CanCollide = true
            state.isOpen = false
            state.tweening = false
        end)
        tween:Play()
    else
        part.CanCollide = false
        local tween = TweenService:Create(part, TWEEN_INFO, {
            CFrame = state.openCFrame
        })
        tween.Completed:Once(function()
            state.isOpen = true
            state.tweening = false
        end)
        tween:Play()
    end

    return true
end

--- Очистка при удалении двери.
--- @param part BasePart
function DoorHandler.cleanup(part)
    doorStates[part] = nil
end

--- Проверить, является ли Part управляемой дверью.
--- @param part BasePart
--- @return boolean
function DoorHandler.isDoor(part)
    return doorStates[part] ~= nil
end

return DoorHandler
