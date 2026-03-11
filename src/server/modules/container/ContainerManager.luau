-- Публичное API, маршрутизация к подмодулям
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local ContainerSpawner = require(script.Parent:WaitForChild("ContainerSpawner"))
local ContainerInteraction = require(script.Parent:WaitForChild("ContainerInteraction"))
local ContainerInventory = require(script.Parent:WaitForChild("ContainerInventory"))
local ContainerLoot = require(script.Parent:WaitForChild("ContainerLoot"))

local STATE = {
    INACTIVE = "Inactive",
    ACTIVE = "Active",
    OPENED = "Opened",
    DESPAWNED = "Despawned"
}

local ContainerManager = {}
ContainerManager.STATE = STATE

-- Общая таблица всех контейнеров
local containers = {}

-- ── Регистрация спавн-точки ──────────────────────────────
function ContainerManager.registerSpawnPoint(spawnPoint)
    local cfgId = spawnPoint:GetAttribute("ContainerType")
    if not cfgId then
        warn("[ContainerManager] SpawnPoint без ContainerType:", spawnPoint:GetFullName())
        return
    end

    local cfg = Config.Containers[cfgId]
    if not cfg then
        warn("[ContainerManager] Неизвестный ContainerType:", tostring(cfgId))
        return
    end

    local containerId = spawnPoint:GetAttribute("ContainerId") or ContainerSpawner.makeId()
    spawnPoint:SetAttribute("ContainerId", containerId)

    containers[containerId] = {
        id = containerId,
        cfgId = cfgId,
        config = cfg,
        state = STATE.INACTIVE,
        model = nil,
        slots = {},
        openedBy = {},
        spawnPoint = spawnPoint,
        despawnTimer = nil,
        respawnTimer = nil,
        _despawnFn = function(id)
            ContainerSpawner.despawn(id, containers, STATE)
        end
    }

    ContainerSpawner.trySpawn(containerId, containers, STATE)
end

-- ── Взаимодействие ───────────────────────────────────────
function ContainerManager.requestOpen(player, containerId)
    return ContainerInteraction.requestOpen(player, containerId, containers, STATE)
end

function ContainerManager.close(player, containerId)
    ContainerInteraction.close(player, containerId, containers)
end

-- ── Инвентарь контейнера ─────────────────────────────────
function ContainerManager.takeItem(player, containerId, slotIndex)
    ContainerInventory.takeItem(player, containerId, slotIndex, containers, ContainerManager.close)
end

function ContainerManager.takeAll(player, containerId)
    ContainerInventory.takeAll(player, containerId, containers, ContainerManager.close)
end

function ContainerManager.sort(player, containerId)
    ContainerInventory.sort(player, containerId, containers)
end

function ContainerManager.depositItem(player, containerId, inventorySlotIndex)
    ContainerInventory.depositItem(player, containerId, inventorySlotIndex, containers)
end

-- ── Геттеры ──────────────────────────────────────────────
function ContainerManager.getData(containerId)
    return containers[containerId]
end

function ContainerManager.getAll()
    return containers
end

function ContainerManager.isEmpty(containerId)
    local data = containers[containerId]
    if not data then
        return true
    end
    return ContainerLoot.isEmpty(data.slots)
end

return ContainerManager
