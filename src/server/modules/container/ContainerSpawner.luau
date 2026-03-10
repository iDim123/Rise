-- Спавн, despawn, respawn моделей контейнеров
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ContainerLoot = require(script.Parent:WaitForChild("ContainerLoot"))

local ContainerSpawner = {}

function ContainerSpawner.makeId()
    return tostring(math.floor(os.clock() * 1000)) .. "_" .. tostring(math.random(1, 99999))
end

-- Попытка заспавнить контейнер (поставить модель, сгенерировать лут)
-- containers — ссылка на общую таблицу, STATE — enum состояний
function ContainerSpawner.trySpawn(containerId, containers, STATE)
    local data = containers[containerId]
    if not data then
        return
    end
    local cfg = data.config

    local slots, hasItem

    if cfg.Persistent then
        local persistCfg = table.clone(cfg)
        persistCfg.SpawnChance = 1
        slots, hasItem = ContainerLoot.rollLoot(persistCfg)

        if not hasItem then
            data.state = STATE.INACTIVE
            -- NEW: помечаем SpawnPoint как пустой
            if data.spawnPoint then
                data.spawnPoint:SetAttribute("ContainerEmpty", true)
            end
            data.respawnTimer = task.delay(cfg.RetryInterval or 60, function()
                data.respawnTimer = nil
                ContainerSpawner.trySpawn(containerId, containers, STATE)
            end)
            return
        end
    else
        slots, hasItem = ContainerLoot.rollLoot(cfg)

        if not hasItem then
            -- NEW: помечаем SpawnPoint как пустой
            if data.spawnPoint then
                data.spawnPoint:SetAttribute("ContainerEmpty", true)
            end
            if cfg.RetryInterval and cfg.RetryInterval > 0 then
                data.state = STATE.INACTIVE
                data.respawnTimer = task.delay(cfg.RetryInterval, function()
                    data.respawnTimer = nil
                    ContainerSpawner.trySpawn(containerId, containers, STATE)
                end)
            end
            return
        end
    end

    -- Лут есть — снимаем флаг пустоты со SpawnPoint
    if data.spawnPoint then
        data.spawnPoint:SetAttribute("ContainerEmpty", false)
    end

    data.slots = slots
    data.state = STATE.ACTIVE
    data.openedBy = {}

    -- Создаём модель из ServerStorage/containers/<cfgId>
    local template = ServerStorage:FindFirstChild("containers") and ServerStorage.containers:FindFirstChild(data.cfgId)
    if template then
        local model = template:Clone()
        model:SetAttribute("ContainerId", containerId)
        model:SetAttribute("ContainerType", data.cfgId)
        model.Parent = workspace

        local sp = data.spawnPoint
        if model:IsA("BasePart") then
            model.CFrame = sp.CFrame
        elseif model.PrimaryPart then
            model:SetPrimaryPartCFrame(sp.CFrame)
        end
        data.model = model
    else
        data.model = data.spawnPoint
        data.spawnPoint.Transparency = 0
    end

    ContainerLoot.updateEmptyAttribute(data)

    print(string.format("[ContainerSpawner] Заспавнен '%s' (%s) [%s]", cfg.Name, containerId,
        cfg.Persistent and "Persistent" or "Random"))
end

-- Исчезновение контейнера
function ContainerSpawner.despawn(containerId, containers, STATE)
    local data = containers[containerId]
    if not data then
        return
    end

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

    -- Задержка перед уничтожением (анимация закрытия на клиенте)
    task.delay(0.5, function()
        if data.model and data.model ~= data.spawnPoint then
            data.model:Destroy()
            data.model = nil
        elseif data.model == data.spawnPoint then
            data.spawnPoint.Transparency = 1
        end
    end)

    print(string.format("[ContainerSpawner] Исчез '%s' (%s)", data.config.Name, containerId))

    -- Respawn таймер
    local cfg = data.config
    local jitter = cfg.RespawnJitter or 0
    local baseTime = cfg.RespawnTime or 300
    local delay = baseTime * (1 + (math.random() * 2 - 1) * jitter)

    data.respawnTimer = task.delay(delay, function()
        data.respawnTimer = nil
        ContainerSpawner.trySpawn(containerId, containers, STATE)
    end)
end

return ContainerSpawner
