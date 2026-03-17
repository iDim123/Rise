--[[
    CoffinHandler.luau
    Обработчик гробов (Coffin).

    Механика:
      - 1 Coffin = 1 игрок (привязка через F).
      - Привязка к новому Coffin снимает старую.
      - Смерть → респавн перед привязанным Coffin.
      - Разрушение Coffin → привязка сбрасывается.
      - F на занятый чужой → "Гроб уже занят".

    Используется: FunctionalDispatcher, HealthManager
]] local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local CastleBorder = require(modules:WaitForChild("building"):WaitForChild("CastleBorder"))

local CoffinHandler = {}

-- ═══════════════════════════════════════════════════════════
-- Состояние
-- ═══════════════════════════════════════════════════════════

-- coffinData[blockId] = {
--   part: BasePart,
--   boundUserId: number | nil,   -- кто привязан
-- }
local coffinData = {}

-- Обратный поиск: userId → blockId
local userToCoffin = {}

-- ═══════════════════════════════════════════════════════════
-- Жизненный цикл
-- ═══════════════════════════════════════════════════════════

function CoffinHandler.onCreate(part, typeId, blockId, castle)
    coffinData[blockId] = {
        part = part,
        boundUserId = nil
    }

    part:SetAttribute("FunctionalType", "Coffin")
    part:SetAttribute("CoffinBlockId", blockId)

    print("[CoffinHandler] Created coffin for block " .. blockId)
end

function CoffinHandler.interact(player, part, blockData, castle)
    -- Проверка прав
    local ownerId = part:GetAttribute("CastleOwnerId")
    if ownerId then
        if not CastleBorder.canInteract(player.UserId, ownerId) then
            return false, "Нет прав доступа"
        end
    end

    -- Найти coffin data по part
    local blockId = nil
    for bId, data in coffinData do
        if data.part == part then
            blockId = bId
            break
        end
    end

    if not blockId or not coffinData[blockId] then
        return false, "Гроб не найден"
    end

    local data = coffinData[blockId]
    local userId = player.UserId

    -- Уже привязан к этому гробу
    if data.boundUserId == userId then
        Remotes.Notify:FireClient(player, "Вы уже привязаны к этому гробу", "info")
        return true
    end

    -- Занят другим игроком
    if data.boundUserId ~= nil then
        Remotes.Notify:FireClient(player, "Гроб уже занят", "warning")
        return true
    end

    -- Снять старую привязку (если игрок был привязан к другому гробу)
    local oldBlockId = userToCoffin[userId]
    if oldBlockId and coffinData[oldBlockId] then
        coffinData[oldBlockId].boundUserId = nil
    end

    -- Привязать
    data.boundUserId = userId
    userToCoffin[userId] = blockId

    Remotes.Notify:FireClient(player, "Вы привязались к гробу", "success")
    print("[CoffinHandler] " .. player.Name .. " bound to coffin " .. blockId)

    return true
end

function CoffinHandler.onDestroy(part, blockId)
    if not blockId then
        for bId, data in coffinData do
            if data.part == part then
                blockId = bId
                break
            end
        end
    end

    if not blockId or not coffinData[blockId] then
        return
    end

    local data = coffinData[blockId]

    -- Сбросить привязку
    if data.boundUserId then
        local userId = data.boundUserId
        if userToCoffin[userId] == blockId then
            userToCoffin[userId] = nil
        end
        -- Уведомить игрока если онлайн
        local Players = game:GetService("Players")
        local player = Players:GetPlayerByUserId(userId)
        if player then
            Remotes.Notify:FireClient(player, "Ваш гроб был разрушен", "warning")
        end
    end

    coffinData[blockId] = nil
    print("[CoffinHandler] Destroyed coffin " .. blockId)
end

-- ═══════════════════════════════════════════════════════════
-- API для HealthManager
-- ═══════════════════════════════════════════════════════════

--- Получить позицию привязанного гроба для респавна.
--- @param userId number
--- @return Vector3 | nil  — позиция перед гробом, или nil если нет привязки
function CoffinHandler.getRespawnPosition(userId)
    local blockId = userToCoffin[userId]
    if not blockId then
        return nil
    end

    local data = coffinData[blockId]
    if not data or not data.part or not data.part.Parent then
        -- Гроб разрушен, сбросить привязку
        userToCoffin[userId] = nil
        return nil
    end

    -- Позиция перед гробом (сдвиг по LookVector)
    local part = data.part
    local cf = part.CFrame
    local spawnPos = cf.Position + cf.LookVector * 4 + Vector3.new(0, 3, 0)
    return spawnPos
end

-- ═══════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════

--- Вызывается при выходе игрока. Снимает привязку.
function CoffinHandler.cleanupPlayer(userId)
    local blockId = userToCoffin[userId]
    if blockId and coffinData[blockId] then
        coffinData[blockId].boundUserId = nil
    end
    userToCoffin[userId] = nil
end

return CoffinHandler
