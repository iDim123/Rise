local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local ContainerManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("ContainerManager"))

-- ────────────────────────────────────────────────────────────
-- 1. Регистрируем все SpawnPoint-ы из workspace/Containers
-- ────────────────────────────────────────────────────────────
local function initSpawnPoints()
    local containersFolder = workspace:FindFirstChild("Containers")
    if not containersFolder then
        warn("[ContainerServer] workspace/Containers не найдена")
        return
    end

    for _, child in containersFolder:GetDescendants() do
        -- SpawnPoint — это BasePart с атрибутом ContainerType
        if child:IsA("BasePart") and child:GetAttribute("ContainerType") then
            ContainerManager.registerSpawnPoint(child)
        end
    end
end

initSpawnPoints()

-- ────────────────────────────────────────────────────────────
-- 2. Remote: ContainerOpen — запрос открытия
-- ────────────────────────────────────────────────────────────
-- После каста (CastTime > 0) клиент присылает ContainerOpen ещё раз
-- с флагом castDone = true. При первом запросе сервер запускает каст.
Remotes.ContainerOpen.OnServerEvent:Connect(function(player, containerId, castDone)
    local data = ContainerManager.getData(containerId)
    if not data then
        return
    end

    -- Проверка: кастовали ли мы для этого игрока?
    if data.config.CastTime and data.config.CastTime > 0 then
        if not castDone then
            -- Первый запрос → запускаем каст (сервер не даст открыть без завершения)
            ContainerManager.requestOpen(player, containerId)
            return
        else
            -- Каст завершён — проверяем что игрок действительно был в касте
            if data._casting and data._casting[player.UserId] then
                data._casting[player.UserId] = nil
                ContainerManager._finishOpen(player, data)
            end
        end
    else
        ContainerManager.requestOpen(player, containerId)
    end
end)

-- ────────────────────────────────────────────────────────────
-- 3. Remote: ContainerClose
-- ────────────────────────────────────────────────────────────
Remotes.ContainerClose.OnServerEvent:Connect(function(player, containerId)
    ContainerManager.close(player, containerId)
end)

-- ────────────────────────────────────────────────────────────
-- 4. Remote: ContainerTakeItem
-- ────────────────────────────────────────────────────────────
Remotes.ContainerTakeItem.OnServerEvent:Connect(function(player, containerId, slotIndex)
    if type(slotIndex) ~= "number" then
        return
    end
    ContainerManager.takeItem(player, containerId, slotIndex)
end)

-- ────────────────────────────────────────────────────────────
-- 5. Remote: ContainerTakeAll
-- ────────────────────────────────────────────────────────────
Remotes.ContainerTakeAll.OnServerEvent:Connect(function(player, containerId)
    ContainerManager.takeAll(player, containerId)
end)

-- ────────────────────────────────────────────────────────────
-- 6. Remote: ContainerSort
-- ────────────────────────────────────────────────────────────
Remotes.ContainerSort.OnServerEvent:Connect(function(player, containerId)
    ContainerManager.sort(player, containerId)
end)

-- ────────────────────────────────────────────────────────────
-- 7. Очистка при выходе игрока
-- ────────────────────────────────────────────────────────────
game:GetService("Players").PlayerRemoving:Connect(function(player)
    for _, data in ContainerManager.getAll() do
        if data.openedBy[player.UserId] then
            ContainerManager.close(player, data.id)
        end
    end
end)

print("[ContainerServer] Инициализирован")
