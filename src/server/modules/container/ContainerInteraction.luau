-- Открытие, каст, закрытие контейнеров
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ContainerLoot = require(script.Parent:WaitForChild("ContainerLoot"))

local _CastManager
local function getCastManager()
    if not _CastManager then
        _CastManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("CastManager"))
    end
    return _CastManager
end

local ContainerInteraction = {}

-- Игрок запрашивает открыть контейнер
-- containers, STATE — передаются из фасада
function ContainerInteraction.requestOpen(player, containerId, containers, STATE)
    local data = containers[containerId]
    if not data then
        return false, "Контейнер не найден"
    end
    if data.state ~= STATE.ACTIVE and data.state ~= STATE.OPENED then
        return false, "Контейнер недоступен"
    end

    -- NEW: пустой контейнер нельзя открыть
    if ContainerLoot.isEmpty(data.slots) then
        return false, "Контейнер пуст"
    end

    if data._casting and data._casting[player.UserId] then
        return false, "Уже открывается"
    end

    if getCastManager().isActive(player) then
        return false, "Занят"
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
            if dist > data.config.InteractRange + 2 then
                return false, "Слишком далеко"
            end
        end
    end

    -- Если CastTime > 0 — запускаем каст
    local cfg = data.config
    if cfg.CastTime and cfg.CastTime > 0 then
        ContainerInteraction._startCast(player, data, containerId, containers, STATE)
        return true, "casting"
    end

    -- Мгновенное открытие
    ContainerInteraction.finishOpen(player, data)
    return true, "opened"
end

-- Запуск CastBar
function ContainerInteraction._startCast(player, data, containerId, containers, STATE)
    local cfg = data.config

    getCastManager().start(player, {
        Duration = cfg.CastTime,
        Label = "Открытие: " .. cfg.Name,
        MovementMode = cfg.CastMovementMode or "CancelOnMove",
        SpeedMult = cfg.CastSpeedMult or 0,
        CancelKey = cfg.CastCancelKey or "MMB",
        CancelOnStun = true,
        CancelOnDamage = false,

        OnComplete = function(p)
            local d = containers[containerId]
            if d and (d.state == STATE.ACTIVE or d.state == STATE.OPENED) then
                ContainerInteraction.finishOpen(p, d)
            end
        end,

        OnCancel = function(p, reason)
            local d = containers[containerId]
            if d and d._casting then
                d._casting[p.UserId] = nil
            end
        end
    })

    data._casting = data._casting or {}
    data._casting[player.UserId] = true
end

-- Завершить открытие — сменить состояние, отправить слоты
function ContainerInteraction.finishOpen(player, data)
    if data._casting then
        data._casting[player.UserId] = nil
    end

    data.state = "Opened"
    data.openedBy[player.UserId] = true
    ContainerLoot.updateEmptyAttribute(data)

    local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
    Remotes.ContainerOpened:FireClient(player, data.id, ContainerLoot.serialize(data.slots), data.config.Name)

    -- Таймер despawn
    if not data.despawnTimer then
        -- despawn вызывается через фасад, но таймер ставим здесь
        -- Сохраняем ссылку на функцию despawn через замыкание
        if data._despawnFn then
            data.despawnTimer = task.delay(data.config.DespawnTime, function()
                data._despawnFn(data.id)
            end)
        end
    end
end

-- Игрок закрывает окно
function ContainerInteraction.close(player, containerId, containers)
    local data = containers[containerId]
    if not data then
        return
    end

    data.openedBy[player.UserId] = nil

    if data._casting then
        data._casting[player.UserId] = nil
    end

    local anyoneWatching = false
    for _ in data.openedBy do
        anyoneWatching = true
        break
    end

    if not anyoneWatching then
        local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
        for _, p in game:GetService("Players"):GetPlayers() do
            Remotes.ContainerClosed:FireClient(p, containerId)
        end
    end
end

return ContainerInteraction
