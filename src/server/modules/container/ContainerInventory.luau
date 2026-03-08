-- Забор предметов, сортировка, broadcast обновлений
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ContainerLoot = require(script.Parent:WaitForChild("ContainerLoot"))

local _InventoryManager, _InventorySync
local function getInventoryManager()
    if not _InventoryManager then
        _InventoryManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("InventoryManager"))
    end
    return _InventoryManager
end
local function getInventorySync()
    if not _InventorySync then
        _InventorySync = require(ServerScriptService:WaitForChild("modules"):WaitForChild("InventorySync"))
    end
    return _InventorySync
end

local ContainerInventory = {}

-- Отправить обновлённые слоты всем кто открыл контейнер
function ContainerInventory.broadcastUpdate(data)
    local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
    for userId, _ in data.openedBy do
        local player = game:GetService("Players"):GetPlayerByUserId(userId)
        if player then
            Remotes.ContainerUpdate:FireClient(player, data.id, ContainerLoot.serialize(data.slots))
        end
    end
end

-- Игрок берёт один предмет
-- closeFn: function(player, containerId) — для закрытия при пустом сундуке
function ContainerInventory.takeItem(player, containerId, slotIndex, containers, closeFn)
    local data = containers[containerId]
    if not data then
        return false
    end
    if data.state ~= "Opened" then
        return false
    end
    if not data.openedBy[player.UserId] then
        return false
    end

    local slot = data.slots[slotIndex]
    if not slot then
        return false
    end

    local ok = getInventoryManager().addItemFromConfig(player, slot.ItemId, slot.Amount)
    if not ok then
        local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
        Remotes.Notify:FireClient(player, "Инвентарь переполнен!", "warning")
        return false
    end

    data.slots[slotIndex] = false
    ContainerLoot.updateEmptyAttribute(data)
    getInventorySync().sendFullUpdate(player)

    -- Если сундук пуст — закрываем
    if ContainerLoot.isEmpty(data.slots) then
        if closeFn then
            closeFn(player, containerId)
        end
    else
        ContainerInventory.broadcastUpdate(data)
    end

    return true
end

-- Игрок берёт всё
function ContainerInventory.takeAll(player, containerId, containers, closeFn)
    local data = containers[containerId]
    if not data then
        return
    end
    if data.state ~= "Opened" then
        return
    end
    if not data.openedBy[player.UserId] then
        return
    end

    local anyAdded = false
    for i, slot in data.slots do
        if slot then
            local ok = getInventoryManager().addItemFromConfig(player, slot.ItemId, slot.Amount)
            if ok then
                data.slots[i] = false
                anyAdded = true
            end
        end
    end

    ContainerLoot.updateEmptyAttribute(data)

    if anyAdded then
        getInventorySync().sendFullUpdate(player)
    end

    if ContainerLoot.isEmpty(data.slots) then
        if closeFn then
            closeFn(player, containerId)
        end
    else
        ContainerInventory.broadcastUpdate(data)
    end
end

-- Сортировка
function ContainerInventory.sort(player, containerId, containers)
    local data = containers[containerId]
    if not data then
        return
    end
    if data.state ~= "Opened" then
        return
    end
    if not data.openedBy[player.UserId] then
        return
    end

    ContainerLoot.sort(data.slots, data.config.Slots)
    ContainerInventory.broadcastUpdate(data)
end

return ContainerInventory
