--[[
    BuildingSerializer.luau
    Сериализация и десериализация данных замка для DataStore.

    ╔══════════════════════════════════════════════════════════════════╗
    ║  КОНТРАКТ СЕРИАЛИЗАЦИИ                                          ║
    ║                                                                  ║
    ║  Сохраняются:                                                    ║
    ║    CenterPos     — {x, y, z}                                     ║
    ║    Permissions    — {AllowCoopBuild, AllowCoopRemove,            ║
    ║                      AllowCoopInteract, AllowedPlayers: [id]}    ║
    ║    Blocks[]       — {T=typeId, P={x,y,z}, R=rotation}           ║
    ║    Containers[]   — {Id=containerId, Ref=blockIndex,            ║
    ║                      Slots={[strIdx]={Id,Amount}}}               ║
    ║                                                                  ║
    ║  НЕ сохраняются (берутся из Config при загрузке):                ║
    ║    Size, Material, Color, Cost, PlacementRule, CanRotate,        ║
    ║    Functional, FunctionalData, Icon, Description                 ║
    ║                                                                  ║
    ║  HP блоков:                                                      ║
    ║    Текущее HP НЕ сохраняется. При загрузке — полное HP           ║
    ║    из конфига. Повреждённые блоки «лечатся» при перезаходе.      ║
    ║    Намеренное поведение v1.9.                                    ║
    ║    Для будущей персистентности HP — добавить поле H в блок.      ║
    ║    Формат обратно совместим: отсутствие H = полное HP.           ║
    ║                                                                  ║
    ║  Неизвестные TypeId:                                             ║
    ║    Пропускаются с warn. Позволяет безопасно удалять типы         ║
    ║    блоков из конфига без потери остальных данных.                 ║
    ║                                                                  ║
    ║  Размер оценка:                                                  ║
    ║    500 блоков ≈ 30-50 KB (JSON). Лимит DataStore 4 MB.           ║
    ║    Контейнеры добавляют ≈ 0.5-2 KB на сундук.                   ║
    ╚══════════════════════════════════════════════════════════════════╝

    Используется: BuildingManager (collect/initPlayer), DataService
    Зависимости: Config (Building.BlockTypes), CastleBorder (serializePermissions)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local BuildingSerializer = {}

-- ═══════════════════════════════════════════════════════════
-- Приватные хелперы
-- ═══════════════════════════════════════════════════════════

--- Vector3 → компактная таблица {x, y, z}
--- @param v Vector3
--- @return table
local function vec3ToTable(v)
    return {
        x = math.round(v.X * 100) / 100,
        y = math.round(v.Y * 100) / 100,
        z = math.round(v.Z * 100) / 100,
    }
end

--- {x, y, z} → Vector3
--- @param t table
--- @return Vector3 | nil
local function tableToVec3(t)
    if not t or type(t) ~= "table" then return nil end
    local x = tonumber(t.x)
    local y = tonumber(t.y)
    local z = tonumber(t.z)
    if not x or not y or not z then return nil end
    return Vector3.new(x, y, z)
end

-- ═══════════════════════════════════════════════════════════
-- Сериализация
-- ═══════════════════════════════════════════════════════════

--- Сериализовать данные одного замка для DataStore.
---
--- @param castleData table — данные замка из BuildingManager:
---   {
---     ownerId: number,
---     centerPos: Vector3,
---     blocks: { [blockId] = { typeId, position: Vector3, rotation: number, containerId? } },
---     blockCount: number,
---   }
--- @param permissions table | nil — из CastleBorder.serializePermissions
--- @param containerSerializer function? — function(containerId) → serialized | nil
---   Вызывается для каждого блока с containerId. Передаётся из BuildingManager
---   который делегирует ContainerManager.serializeContainer (Phase 2).
--- @return table — данные для DataStore
function BuildingSerializer.serialize(castleData, permissions, containerSerializer)
    local result = {
        CenterPos = vec3ToTable(castleData.centerPos),
        Claim = claimData,     -- включает HeartLevel + permissions
        Blocks = {},
        Containers = {},
    }

    -- Сериализуем блоки
    -- blockIndex нужен для привязки контейнеров к блокам
    local blockIndex = 0
    for blockId, block in castleData.blocks do
        blockIndex += 1

        local entry = {
            T = block.typeId,
            P = vec3ToTable(block.position),
            R = block.rotation,
        }

        table.insert(result.Blocks, entry)

        -- Контейнер привязан к блоку (Phase 2: castle_chest)
        if block.containerId and containerSerializer then
            local containerData = containerSerializer(block.containerId)
            if containerData then
                containerData.Ref = blockIndex
                table.insert(result.Containers, containerData)
            end
        end
    end

    return result
end

--- Десериализовать данные замка из DataStore.
---
--- @param saved table — данные из DataStore (результат serialize)
--- @return table | nil — восстановленные данные:
---   {
---     centerPos: Vector3,
---     permissions: table (для CastleBorder.registerClaim),
---     blocks: { { typeId, position: Vector3, rotation: number, size: Vector3 } },
---     containers: { { Ref: number (1-based blockIndex), Id: string, Type: string, Slots: table } },
---   }
function BuildingSerializer.deserialize(saved)
    if not saved or type(saved) ~= "table" then
        warn("[BuildingSerializer] deserialize: invalid data (nil or not table)")
        return nil
    end

    -- CenterPos
    local centerPos = tableToVec3(saved.CenterPos)
    if not centerPos then
        warn("[BuildingSerializer] deserialize: invalid CenterPos")
        return nil
    end

    -- Permissions (передаются напрямую в CastleBorder.registerClaim)
    local permissions = saved.Permissions -- может быть nil → дефолтные

    -- Blocks
    local blocks = {}
    local blockTypes = Config.Building and Config.Building.BlockTypes or {}
    local skipped = 0

    if saved.Blocks then
        for i, entry in saved.Blocks do
            -- Валидация typeId
            local typeId = entry.T
            if not typeId or not blockTypes[typeId] then
                warn("[BuildingSerializer] deserialize: unknown typeId '" .. tostring(typeId)
                    .. "' at index " .. i .. ", skipping")
                skipped += 1
                -- Вставляем nil-маркер чтобы не сбивать индексы для Containers.Ref
                table.insert(blocks, false)
                continue
            end

            -- Position
            local position = tableToVec3(entry.P)
            if not position then
                warn("[BuildingSerializer] deserialize: invalid position at index " .. i .. ", skipping")
                skipped += 1
                table.insert(blocks, false)
                continue
            end

            -- Rotation
            local rotation = tonumber(entry.R) or 0

            -- Size из конфига (не сохраняется)
            local bt = blockTypes[typeId]
            local size = bt.Size
            if rotation == 90 or rotation == 270 then
                size = Vector3.new(size.Z, size.Y, size.X)
            end

            table.insert(blocks, {
                typeId = typeId,
                position = position,
                rotation = rotation,
                size = size,
            })
        end
    end

    if skipped > 0 then
        warn("[BuildingSerializer] deserialize: skipped " .. skipped .. " block(s) with unknown typeId")
    end

    -- Containers (Phase 2)
    local containers = {}
    if saved.Containers then
        for _, cData in saved.Containers do
            table.insert(containers, {
                Ref = cData.Ref,      -- индекс блока в массиве blocks (1-based)
                Id = cData.Id,
                Type = cData.Type,
                Slots = cData.Slots,
            })
        end
    end

    local claim = saved.Claim -- { HeartLevel, AllowCoopBuild, ... AllowedPlayers }
    local heartLevel = claim and claim.HeartLevel or 1

    return {
        centerPos = centerPos,
        heartLevel = heartLevel,
        permissions = claim,
        blocks = blocks,
        containers = containers,
    }
end

-- ═══════════════════════════════════════════════════════════
-- Утилиты
-- ═══════════════════════════════════════════════════════════

--- Оценить размер сериализованных данных (приблизительно, в байтах).
--- Для диагностики и stress-тестов.
--- @param serialized table — результат serialize
--- @return number — приблизительный размер в байтах
function BuildingSerializer.estimateSize(serialized)
    -- Грубая оценка: ~60 байт на блок (JSON: {"T":"stone_wall","P":{"x":12,"y":2.5,"z":-8},"R":90})
    -- + ~200 байт на контейнер + ~100 байт на заголовок
    local blockCount = serialized.Blocks and #serialized.Blocks or 0
    local containerCount = serialized.Containers and #serialized.Containers or 0
    return 100 + blockCount * 60 + containerCount * 200
end

--- Создать пустые данные замка (для нового игрока).
--- @return table
function BuildingSerializer.getDefault()
    return nil -- nil = у игрока нет замка
end

return BuildingSerializer