local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local ContainerManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("container"):WaitForChild(
    "ContainerManager"))
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
Remotes.ContainerOpen.OnServerEvent:Connect(function(player, containerId)
    -- Простая защита от спама
    local CastManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("CastManager"))
    if CastManager.isActive(player) then
        return
    end -- уже кастует

    ContainerManager.requestOpen(player, containerId)
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
