--[[
    BuildingServer.server.luau
    Remote-оркестратор строительной системы.

    Обрабатывает все Building/CastleHeart remotes от клиента.
    Rate-limit 0.3 с на игрока для мутирующих операций.

    Зависимости: BuildingManager, CastleBorder, Remotes, EventBus
]] local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local EventBus = require(modules:WaitForChild("EventBus"))

local BuildingManager = require(modules:WaitForChild("building"):WaitForChild("BuildingManager"))
local CastleBorder = require(modules:WaitForChild("building"):WaitForChild("CastleBorder"))

-- ═══════════════════════════════════════════════════════════
-- Rate limiting
-- ═══════════════════════════════════════════════════════════
local RATE_LIMIT = 0.3
local lastAction = {} -- [userId] = os.clock()

local function isRateLimited(player)
    local now = os.clock()
    local userId = player.UserId
    if lastAction[userId] and now - lastAction[userId] < RATE_LIMIT then
        return true
    end
    lastAction[userId] = now
    return false
end

-- ═══════════════════════════════════════════════════════════
-- Castle Heart
-- ═══════════════════════════════════════════════════════════

Remotes.PlaceCastleHeart.OnServerEvent:Connect(function(player, position)
    if isRateLimited(player) then
        return
    end

    if typeof(position) ~= "Vector3" then
        warn("[BuildingServer] PlaceCastleHeart: invalid position from " .. player.Name)
        return
    end

    local ok, err = BuildingManager.placeCastleHeart(player, position)
    if not ok then
        Remotes.Notify:FireClient(player, err or "Не удалось поставить сердце", "warning")
    end
end)

Remotes.UpgradeCastleHeart.OnServerEvent:Connect(function(player)
    if isRateLimited(player) then
        return
    end

    local ok, err = BuildingManager.upgradeHeart(player)
    if ok then
        -- Отправляем обновлённую информацию клиенту
        local info = BuildingManager.getCastleHeartInfo(player.UserId)
        if info then
            Remotes.CastleHeartInfo:FireClient(player, info)
        end
    else
        Remotes.Notify:FireClient(player, err or "Не удалось улучшить сердце", "warning")
    end
end)

Remotes.DestroyCastle.OnServerEvent:Connect(function(player)
    if isRateLimited(player) then
        return
    end

    -- Только владелец может уничтожить свой замок
    local castle = BuildingManager.getCastle(player.UserId)
    if not castle then
        Remotes.Notify:FireClient(player, "У вас нет замка", "warning")
        return
    end

    local ok, err = BuildingManager.destroyCastle(player)
    if not ok then
        Remotes.Notify:FireClient(player, err or "Не удалось уничтожить замок", "warning")
    end
end)

-- ═══════════════════════════════════════════════════════════
-- Building Blocks
-- ═══════════════════════════════════════════════════════════

Remotes.PlaceBlock.OnServerEvent:Connect(function(player, blockTypeId, position, rotation)
    if isRateLimited(player) then
        return
    end

    if type(blockTypeId) ~= "string" then
        return
    end
    if typeof(position) ~= "Vector3" then
        return
    end
    if type(rotation) ~= "number" then
        return
    end

    local ok, err = BuildingManager.placeBlock(player, blockTypeId, position, rotation)
    if not ok then
        Remotes.Notify:FireClient(player, err or "Не удалось разместить блок", "warning")
    end
end)

Remotes.RemoveBlock.OnServerEvent:Connect(function(player, blockId)
    if isRateLimited(player) then
        return
    end

    if type(blockId) ~= "string" then
        return
    end

    local ok, err = BuildingManager.removeBlock(player, blockId)
    if not ok then
        Remotes.Notify:FireClient(player, err or "Не удалось удалить блок", "warning")
    end
end)

-- ═══════════════════════════════════════════════════════════
-- Permissions
-- ═══════════════════════════════════════════════════════════

Remotes.SetBuildPermission.OnServerEvent:Connect(function(player, permissionKey, value)
    if isRateLimited(player) then
        return
    end

    if type(permissionKey) ~= "string" then
        return
    end
    if type(value) ~= "boolean" then
        return
    end

    local ownerId = player.UserId
    if not CastleBorder.hasCastle(ownerId) then
        Remotes.Notify:FireClient(player, "У вас нет замка", "warning")
        return
    end

    local ok = CastleBorder.setPermission(ownerId, permissionKey, value)
    if ok then
        -- Обновляем UI клиента
        local info = BuildingManager.getCastleHeartInfo(ownerId)
        if info then
            Remotes.CastleHeartInfo:FireClient(player, info)
        end
    else
        Remotes.Notify:FireClient(player, "Неизвестное право доступа", "warning")
    end
end)

Remotes.AddBuildAlly.OnServerEvent:Connect(function(player, allyUserId)
    if isRateLimited(player) then
        return
    end

    if type(allyUserId) ~= "number" then
        return
    end

    local ownerId = player.UserId
    if not CastleBorder.hasCastle(ownerId) then
        Remotes.Notify:FireClient(player, "У вас нет замка", "warning")
        return
    end

    local ok = CastleBorder.addAlly(ownerId, allyUserId)
    if ok then
        local info = BuildingManager.getCastleHeartInfo(ownerId)
        if info then
            Remotes.CastleHeartInfo:FireClient(player, info)
        end
        Remotes.Notify:FireClient(player, "Союзник добавлен", "success")
    else
        Remotes.Notify:FireClient(player, "Не удалось добавить союзника", "warning")
    end
end)

Remotes.RemoveBuildAlly.OnServerEvent:Connect(function(player, allyUserId)
    if isRateLimited(player) then
        return
    end

    if type(allyUserId) ~= "number" then
        return
    end

    local ownerId = player.UserId
    if not CastleBorder.hasCastle(ownerId) then
        Remotes.Notify:FireClient(player, "У вас нет замка", "warning")
        return
    end

    local ok = CastleBorder.removeAlly(ownerId, allyUserId)
    if ok then
        local info = BuildingManager.getCastleHeartInfo(ownerId)
        if info then
            Remotes.CastleHeartInfo:FireClient(player, info)
        end
        Remotes.Notify:FireClient(player, "Союзник удалён", "success")
    else
        Remotes.Notify:FireClient(player, "Не удалось удалить союзника", "warning")
    end
end)

-- ═══════════════════════════════════════════════════════════
-- RemoteFunctions (запрос данных)
-- ═══════════════════════════════════════════════════════════

Remotes.GetBuildings.OnServerInvoke = function(player)
    local ownerId = player.UserId
    local castle = BuildingManager.getCastle(ownerId)
    if not castle then
        return {}
    end
    return BuildingManager.getBlocksForClient(ownerId)
end

Remotes.GetCastleHeartInfo.OnServerInvoke = function(player)
    return BuildingManager.getCastleHeartInfo(player.UserId)
end

-- ═══════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════

Players.PlayerRemoving:Connect(function(player)
    lastAction[player.UserId] = nil
end)

EventBus.on("PlayerCleanup", function(player)
    lastAction[player.UserId] = nil
end)

print("[BuildingServer] Initialized")
