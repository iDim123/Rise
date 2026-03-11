--[[
    DoorHandler.luau
    Обработка дверей в замке: открытие/закрытие по F.
    
    Механика:
    - Дверь поворачивается на 90° при открытии (TweenService)
    - CanCollide отключается при открытии
    - Повторное нажатие F закрывает дверь
    - Проверка прав через CastleBorder.canInteract
    
    Используется: BuildingServer (InteractBlock маршрутизация)
    Зависимости: CastleBorder, TweenService
]] local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local CastleBorder = require(modules:WaitForChild("building"):WaitForChild("CastleBorder"))

local DoorHandler = {}

-- Состояние дверей: doorStates[part] = { isOpen, tweening, closedCFrame }
local doorStates = {}

local TWEEN_TIME = 0.4
local TWEEN_INFO = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--- Инициализировать дверь при размещении.
--- Вызывается из BuildingManager после создания Part.
--- @param part BasePart — Part двери (уже в workspace)
function DoorHandler.initDoor(part)
    doorStates[part] = {
        isOpen = false,
        tweening = false,
        closedCFrame = part.CFrame
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

    -- Проверка прав доступа
    local ownerId = part:GetAttribute("CastleOwnerId")
    if ownerId then
        if not CastleBorder.canInteract(player.UserId, ownerId) then
            return false, "Нет прав доступа"
        end
    end

    state.tweening = true

    if state.isOpen then
        -- Закрываем: возвращаем к closedCFrame
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
        -- Открываем: поворот на 90° вокруг левого края
        -- Определяем pivot — левый край двери
        local size = part.Size
        local cf = state.closedCFrame

        -- Ширина двери — Size.X (или Size.Z если повёрнута на 90/270)
        -- Pivot на -X/2 в локальных координатах
        local pivotOffset = cf:PointToWorldSpace(Vector3.new(-size.X / 2, 0, 0))
        local pivotCFrame = CFrame.new(pivotOffset)

        -- Целевой CFrame: поворот на 90° вокруг pivot по Y
        local openCFrame = pivotCFrame * CFrame.Angles(0, math.rad(-90), 0) * pivotCFrame:Inverse() * cf

        part.CanCollide = false
        local tween = TweenService:Create(part, TWEEN_INFO, {
            CFrame = openCFrame
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
