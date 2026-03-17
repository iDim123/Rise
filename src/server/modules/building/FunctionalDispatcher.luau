local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local DoorHandler = require(script.Parent:WaitForChild("DoorHandler"))
local ChestHandler = require(script.Parent:WaitForChild("ChestHandler"))
local StationHandler = require(script.Parent:WaitForChild("StationHandler"))
local CraftStationHandler = require(script.Parent:WaitForChild("CraftStationHandler"))
local CoffinHandler = require(script.Parent:WaitForChild("CoffinHandler"))

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
    elseif fn == "Station" then
        StationHandler.onCreate(part, typeId, blockId, castle)
    elseif fn == "CraftStation" then
        CraftStationHandler.onCreate(part, typeId, blockId, castle)
    elseif fn == "Coffin" then
        CoffinHandler.onCreate(part, typeId, blockId, castle)
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
    elseif fn == "Station" then
        StationHandler.onDestroy(part, blockId)
    elseif fn == "CraftStation" then
        CraftStationHandler.onDestroy(part, blockId)
    elseif fn == "Coffin" then
        CoffinHandler.onDestroy(part, blockId)
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
    elseif fn == "Station" then
        return StationHandler.interact(player, part, blockData, castle)
    elseif fn == "CraftStation" then
        return CraftStationHandler.interact(player, part, blockData, castle)
    elseif fn == "Coffin" then
        return CoffinHandler.interact(player, part, blockData, castle)
    end

    return false, "Неизвестный тип: " .. tostring(fn)
end

function FunctionalDispatcher.getChestHandler()
    return ChestHandler
end

function FunctionalDispatcher.getStationHandler()
    return StationHandler
end

function FunctionalDispatcher.getCraftStationHandler()
    return CraftStationHandler
end

function FunctionalDispatcher.getCoffinHandler()
    return CoffinHandler
end

return FunctionalDispatcher
