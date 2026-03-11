--[[
    FunctionalDispatcher.luau
    Маршрутизатор для функциональных блоков замка.
]] local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local DoorHandler = require(script.Parent:WaitForChild("DoorHandler"))
local ChestHandler = require(script.Parent:WaitForChild("ChestHandler"))
-- Phase 2 — раскомментировать по мере создания:
-- local WorkbenchHandler = require(script.Parent:WaitForChild("WorkbenchHandler"))
-- local BloodAltarHandler = require(script.Parent:WaitForChild("BloodAltarHandler"))
-- local CoffinHandler = require(script.Parent:WaitForChild("CoffinHandler"))

local FunctionalDispatcher = {}

function FunctionalDispatcher.onPlace(part, typeId, blockId, castle)
    local bt = Config.Building.BlockTypes[typeId]
    if not bt or not bt.Functional then
        return
    end

    local fn = bt.Functional

    if fn == "Door" then
        DoorHandler.initDoor(part)
    elseif fn == "Chest" then
        ChestHandler.onCreate(part, typeId, blockId, castle)
    end
end

function FunctionalDispatcher.onRemove(part, typeId, blockId)
    local bt = Config.Building.BlockTypes[typeId]
    if not bt or not bt.Functional then
        return
    end

    local fn = bt.Functional

    if fn == "Door" then
        DoorHandler.cleanup(part)
    elseif fn == "Chest" then
        ChestHandler.onDestroy(part, blockId)
    end
end

function FunctionalDispatcher.interact(player, part, typeId, castle, blockData)
    local bt = Config.Building.BlockTypes[typeId]
    if not bt or not bt.Functional then
        return false, "Блок не функциональный"
    end

    local fn = bt.Functional

    if fn == "Door" then
        return DoorHandler.interact(player, part)
    elseif fn == "Chest" then
        return ChestHandler.interact(player, part, blockData, castle)
    end

    return false, "Неизвестный тип: " .. tostring(fn)
end

--- Доступ к ChestHandler для сериализации и восстановления.
function FunctionalDispatcher.getChestHandler()
    return ChestHandler
end

return FunctionalDispatcher
