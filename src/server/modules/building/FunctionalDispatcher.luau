--[[
    FunctionalDispatcher.luau
    Маршрутизатор для функциональных блоков замка.
    
    Принимает события жизненного цикла блоков (place, remove, destroy)
    и взаимодействия (interact) — маршрутизирует к конкретным хендлерам.
    
    BuildingManager вызывает только 3 метода:
      FunctionalDispatcher.onPlace(part, typeId, blockId, castle)
      FunctionalDispatcher.onRemove(part, typeId)
      FunctionalDispatcher.interact(player, part, typeId, castle, blockData)
    
    Используется: BuildingManager, BuildingServer
    Зависимости: DoorHandler (+ будущие ChestHandler, WorkbenchHandler и т.д.)
]] local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local DoorHandler = require(script.Parent:WaitForChild("DoorHandler"))
-- Phase 2 — раскомментировать по мере создания:
-- local ChestHandler = require(script.Parent:WaitForChild("ChestHandler"))
-- local WorkbenchHandler = require(script.Parent:WaitForChild("WorkbenchHandler"))
-- local BloodAltarHandler = require(script.Parent:WaitForChild("BloodAltarHandler"))
-- local CoffinHandler = require(script.Parent:WaitForChild("CoffinHandler"))

local FunctionalDispatcher = {}

--- Вызывается при размещении функционального блока.
--- @param part BasePart
--- @param typeId string
--- @param blockId string
--- @param castle table — данные замка из BuildingManager
function FunctionalDispatcher.onPlace(part, typeId, blockId, castle)
    local bt = Config.Building.BlockTypes[typeId]
    if not bt or not bt.Functional then
        return
    end

    local fn = bt.Functional

    if fn == "Door" then
        DoorHandler.initDoor(part)
        -- elseif fn == "Chest" then
        --     ChestHandler.onCreate(part, typeId, blockId, castle)
        -- elseif fn == "Coffin" then
        --     CoffinHandler.onCreate(part, castle)
    end
end

--- Вызывается при удалении/уничтожении функционального блока.
--- @param part BasePart
--- @param typeId string
function FunctionalDispatcher.onRemove(part, typeId)
    local bt = Config.Building.BlockTypes[typeId]
    if not bt or not bt.Functional then
        return
    end

    local fn = bt.Functional

    if fn == "Door" then
        DoorHandler.cleanup(part)
        -- elseif fn == "Chest" then
        --     ChestHandler.onDestroy(part)
        -- elseif fn == "Coffin" then
        --     CoffinHandler.onDestroy(part)
    end
end

--- Взаимодействие игрока с функциональным блоком (F).
--- @param player Player
--- @param part BasePart
--- @param typeId string
--- @param castle table
--- @param blockData table — запись из castle.blocks[blockId]
--- @return boolean, string?
function FunctionalDispatcher.interact(player, part, typeId, castle, blockData)
    local bt = Config.Building.BlockTypes[typeId]
    if not bt or not bt.Functional then
        return false, "Блок не функциональный"
    end

    local fn = bt.Functional

    if fn == "Door" then
        return DoorHandler.interact(player, part)
        -- elseif fn == "Chest" then
        --     return ChestHandler.interact(player, part, blockData, castle)
        -- elseif fn == "Workbench" then
        --     return WorkbenchHandler.interact(player, part)
        -- elseif fn == "BloodAltar" then
        --     return BloodAltarHandler.interact(player, part)
    end

    return false, "Неизвестный тип: " .. tostring(fn)
end

return FunctionalDispatcher
