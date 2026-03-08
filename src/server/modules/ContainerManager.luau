-- Управляет жизненным циклом контейнеров:
--   Inactive → Active → Opened → Despawned

local _CastManager
local function getCastManager()
    if not _CastManager then
        _CastManager = require(
            game:GetService("ServerScriptService"):WaitForChild("modules"):WaitForChild("CastManager")
        )
    end
    return _CastManager
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- ──────────────────────────────────────────────
-- Состояния контейнера
-- ──────────────────────────────────────────────
local STATE = {
    INACTIVE  = "Inactive",   -- ещё не появился / ждёт таймера
    ACTIVE    = "Active",     -- стоит в мире, никто не открывал
    OPENED    = "Opened",     -- открыт (один или несколько игроков смотрят)
    DESPAWNED = "Despawned",  -- исчез, ждёт respawn
}

local ContainerManager = {}
ContainerManager.STATE = STATE

-- ──────────────────────────────────────────────
-- Внутреннее состояние
-- ──────────────────────────────────────────────
-- containers[containerId] = {
--   id, cfgId, config, state,
--   model (Part/Model в workspace),
--   slots  = { [slotIndex] = { ItemId, Amount } | false },
--   openedBy = { [userId] = true },    -- кто сейчас смотрит
--   despawnTimer  (task.delay handle),
--   respawnTimer  (task.delay handle),
-- }
local containers = {}

-- ──────────────────────────────────────────────
-- Вспомогательные функции
-- ──────────────────────────────────────────────

-- Генерация уникального ID для экземпляра контейнера
local function makeId()
    return tostring(math.floor(tick() * 1000)) .. "_" .. tostring(math.random(1, 99999))
end

-- Генерация лута по LootTable конфига
local function rollLoot(cfg)
    local slots = {}
    for i = 1, cfg.Slots do
        slots[i] = false
    end

    if math.random() > cfg.SpawnChance then
        -- шанс не сработал — сундук пустой при этой попытке
        return slots, false
    end

    local slotIdx = 1
    for _, entry in cfg.LootTable do
        if slotIdx > cfg.Slots then break end
        if math.random() <= entry.Chance then
            local amount = math.random(entry.Amount.Min, entry.Amount.Max)
            slots[slotIdx] = { ItemId = entry.ItemId, Amount = amount }
            slotIdx += 1
        end
    end

    -- Если ничего не выпало — сундук пустой (зависит от SpawnChance)
    local hasItem = false
    for _, s in slots do
        if s then hasItem = true break end
    end

    return slots, hasItem
end

-- Сериализация слотов для передачи клиенту
local function serializeSlots(slots)
    local result = {}
    for i, slot in slots do
        result[i] = slot or false
    end
    return result
end

-- ──────────────────────────────────────────────
-- Публичное API
-- ──────────────────────────────────────────────

-- Зарегистрировать спавн-точку из workspace/Containers
-- spawnPoint: BasePart с атрибутами ContainerType (string) и ContainerId (string, опционально)
function ContainerManager.registerSpawnPoint(spawnPoint)
    local cfgId = spawnPoint:GetAttribute("ContainerType")
    if not cfgId then
        warn("[ContainerManager] SpawnPoint без ContainerType: " .. spawnPoint:GetFullName())
        return
    end

    local cfg = Config.Containers[cfgId]
    if not cfg then
        warn("[ContainerManager] Неизвестный ContainerType: " .. tostring(cfgId))
        return
    end

    local containerId = spawnPoint:GetAttribute("ContainerId") or makeId()
    spawnPoint:SetAttribute("ContainerId", containerId)

    containers[containerId] = {
        id         = containerId,
        cfgId      = cfgId,
        config     = cfg,
        state      = STATE.INACTIVE,
        model      = nil,
        slots      = {},
        openedBy   = {},
        spawnPoint = spawnPoint,
        despawnTimer  = nil,
        respawnTimer  = nil,
    }

    -- Сразу пробуем заспавнить
    ContainerManager._trySpawn(containerId)
end

-- Заспавнить контейнер (поставить модель, сгенерировать лут)
function ContainerManager._trySpawn(containerId)
    local data = containers[containerId]
    if not data then return end
    local cfg = data.config

    -- Если Persistent — проверяем сохранённые данные (заглушка, DataService интеграция позже)
    local slots, hasItem = rollLoot(cfg)

    if not hasItem and cfg.RetryInterval and cfg.RetryInterval > 0 then
        -- Лут не выпал — повторим через RetryInterval
        data.state = STATE.INACTIVE
        data.respawnTimer = task.delay(cfg.RetryInterval, function()
            ContainerManager._trySpawn(containerId)
        end)
        return
    end

    data.slots = slots
    data.state = STATE.ACTIVE
    data.openedBy = {}

    -- Создаём визуальную модель из ServerStorage/containers/<cfgId>
    local template = ServerStorage:FindFirstChild("containers")
        and ServerStorage.containers:FindFirstChild(data.cfgId)
    if template then
        local model = template:Clone()
        model:SetAttribute("ContainerId", containerId)
        model.Parent = workspace

        -- Ставим на позицию SpawnPoint
        local sp = data.spawnPoint
        if model:IsA("BasePart") then
            model.CFrame = sp.CFrame
        elseif model.PrimaryPart then
            model:SetPrimaryPartCFrame(sp.CFrame)
        end
        data.model = model
    else
        -- Fallback: используем сам SpawnPoint как визуал
        data.model = data.spawnPoint
        data.spawnPoint.Transparency = 0
    end

    print(string.format("[ContainerManager] Заспавнен '%s' (%s)", cfg.Name, containerId))
end

-- Игрок запрашивает открыть контейнер
function ContainerManager.requestOpen(player, containerId)
    local data = containers[containerId]
    if not data then
        return false, "Контейнер не найден"
    end
    if data.state ~= STATE.ACTIVE and data.state ~= STATE.OPENED then
        return false, "Контейнер недоступен"
    end

    -- Проверка дальности
    local character = player.Character
    if character then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        local model = data.model
        local targetPos = nil

        if model then
            if model:IsA("BasePart") then
                targetPos = model.Position
            elseif model.PrimaryPart then
                targetPos = model.PrimaryPart.Position
            end
        end

        if hrp and targetPos then
            local dist = (hrp.Position - targetPos).Magnitude
            if dist > data.config.InteractRange + 2 then -- +2 studs погрешность
                return false, "Слишком далеко"
            end
        end
    end

    -- Если CastTime > 0 — запускаем каст, реальное открытие после завершения
    local cfg = data.config
    if cfg.CastTime and cfg.CastTime > 0 then
        ContainerManager._startCast(player, data, containerId)
        return true, "casting"
    end

    -- Мгновенное открытие
    ContainerManager._finishOpen(player, data)
    return true, "opened"
end

-- Запуск CastBar для контейнера с CastTime > 0
function ContainerManager._startCast(player, data, containerId)
    local cfg = data.config

    getCastManager().start(player, {
        Duration        = cfg.CastTime,
        Label           = "Открытие: " .. cfg.Name,
        MovementMode    = cfg.CastMovementMode or "CancelOnMove",
        SpeedMult       = cfg.CastSpeedMult or 0,
        CancelKey       = cfg.CastCancelKey or "MMB",
        CancelOnStun    = true,
        CancelOnDamage  = false,   -- урон не прерывает вскрытие по роадмапу

        OnComplete = function(p)
            -- Каст завершён — открываем контейнер
            local d = ContainerManager.getData(containerId)
            if d and (d.state == ContainerManager.STATE.ACTIVE or d.state == ContainerManager.STATE.OPENED) then
                ContainerManager._finishOpen(p, d)
            end
        end,

        OnCancel = function(p, reason)
            -- Очищаем флаг каста
            local d = ContainerManager.getData(containerId)
            if d and d._casting then
                d._casting[p.UserId] = nil
            end
        end,
    })

    data._casting = data._casting or {}
    data._casting[player.UserId] = true
end

-- Завершить открытие — сменить состояние, отправить слоты
function ContainerManager._finishOpen(player, data)
    data.state = STATE.OPENED
    data.openedBy[player.UserId] = true

    local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
    Remotes.ContainerOpened:FireClient(player, data.id, serializeSlots(data.slots), data.config.Name)

    -- Запускаем таймер despawn если ещё не запущен
    if not data.despawnTimer then
        data.despawnTimer = task.delay(data.config.DespawnTime, function()
            ContainerManager._despawn(data.id)
        end)
    end
end

-- Игрок берёт один предмет
function ContainerManager.takeItem(player, containerId, slotIndex)
    local data = containers[containerId]
    if not data then return false end
    if data.state ~= STATE.OPENED then return false end
    if not data.openedBy[player.UserId] then return false end

    local slot = data.slots[slotIndex]
    if not slot then return false end

    -- Пробуем добавить в инвентарь
    local InventoryManager = require(script.Parent:WaitForChild("InventoryManager"))
    local InventorySync    = require(script.Parent:WaitForChild("InventorySync"))
    local ok = InventoryManager.addItemFromConfig(player, slot.ItemId, slot.Amount)
    if not ok then
        local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
        Remotes.Notify:FireClient(player, "Инвентарь переполнен!", "warning")
        return false
    end

    data.slots[slotIndex] = false
    InventorySync.sendFullUpdate(player)
    ContainerManager._broadcastUpdate(data)
    return true
end

-- Игрок берёт всё
function ContainerManager.takeAll(player, containerId)
    local data = containers[containerId]
    if not data then return end
    if data.state ~= STATE.OPENED then return end
    if not data.openedBy[player.UserId] then return end

    local InventoryManager = require(script.Parent:WaitForChild("InventoryManager"))
    local InventorySync    = require(script.Parent:WaitForChild("InventorySync"))

    local anyAdded = false
    for i, slot in data.slots do
        if slot then
            local ok = InventoryManager.addItemFromConfig(player, slot.ItemId, slot.Amount)
            if ok then
                data.slots[i] = false
                anyAdded = true
            end
        end
    end

    if anyAdded then
        InventorySync.sendFullUpdate(player)
        ContainerManager._broadcastUpdate(data)
    end
end

-- Сортировка: сдвигаем все непустые слоты в начало
function ContainerManager.sort(player, containerId)
    local data = containers[containerId]
    if not data then return end
    if data.state ~= STATE.OPENED then return end
    if not data.openedBy[player.UserId] then return end

    local items = {}
    for _, slot in data.slots do
        if slot then table.insert(items, slot) end
    end

    -- Сброс
    for i = 1, data.config.Slots do
        data.slots[i] = false
    end
    for i, item in items do
        data.slots[i] = item
    end

    ContainerManager._broadcastUpdate(data)
end

-- Игрок закрывает окно контейнера
function ContainerManager.close(player, containerId)
    local data = containers[containerId]
    if not data then return end

    data.openedBy[player.UserId] = nil

    -- Если больше никто не смотрит — закрываем крышку у всех
    local anyoneWatching = false
    for _ in data.openedBy do
        anyoneWatching = true
        break
    end

    if not anyoneWatching then
        -- Шлём всем кто был рядом что контейнер визуально закрыт
        local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
        for _, p in game:GetService("Players"):GetPlayers() do
            Remotes.ContainerClosed:FireClient(p, containerId)
        end
    end
end

-- Отправить обновлённые слоты всем кто открыл этот контейнер
function ContainerManager._broadcastUpdate(data)
    local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
    for userId, _ in data.openedBy do
        local player = game:GetService("Players"):GetPlayerByUserId(userId)
        if player then
            Remotes.ContainerUpdate:FireClient(player, data.id, serializeSlots(data.slots))
        end
    end
end

-- Исчезновение контейнера
function ContainerManager._despawn(containerId)
    local data = containers[containerId]
    if not data then return end

    data.state = STATE.DESPAWNED
    data.despawnTimer = nil

    -- Закрываем UI у всех игроков
    local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
    for userId, _ in data.openedBy do
        local player = game:GetService("Players"):GetPlayerByUserId(userId)
        if player then
            Remotes.ContainerClosed:FireClient(player, data.id) 
        end
    end
    data.openedBy = {}

    -- Убираем модель из workspace
    if data.model and data.model ~= data.spawnPoint then
        data.model:Destroy()
        data.model = nil
    elseif data.model == data.spawnPoint then
        data.spawnPoint.Transparency = 1
    end

    print(string.format("[ContainerManager] Исчез '%s' (%s)", data.config.Name, containerId))

    -- Запускаем таймер respawn с джиттером
    local cfg = data.config
    local jitter = cfg.RespawnJitter or 0
    local baseTime = cfg.RespawnTime or 300
    local delay = baseTime * (1 + (math.random() * 2 - 1) * jitter)

    data.respawnTimer = task.delay(delay, function()
        data.respawnTimer = nil
        ContainerManager._trySpawn(containerId)
    end)
end

-- Получить данные контейнера (для отладки / других модулей)
function ContainerManager.getData(containerId)
    return containers[containerId]
end

-- Получить список всех активных/открытых контейнеров
function ContainerManager.getAll()
    return containers
end

return ContainerManager