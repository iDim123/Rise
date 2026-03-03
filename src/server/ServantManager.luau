local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local ServantManager = {}
local playerServants = {} -- [userId] = { captured = {}, activeId = nil }

function ServantManager.init(player)
    if playerServants[player.UserId] then return end

    playerServants[player.UserId] = {
        captured = {},  -- массив слуг { id, name, enemyType, bloodQuality, baseATK, baseHP, atk, hp, weaponSlot, mode }
        activeId = nil, -- id активного слуги
        activeEntity = nil, -- ссылка на модель в Workspace
    }
    print("[Servants] Initialized for " .. player.Name)
end

function ServantManager.getData(player)
    return playerServants[player.UserId]
end

function ServantManager.getCapturedList(player)
    local data = playerServants[player.UserId]
    if not data then return {} end
    return data.captured
end

function ServantManager.captureEnemy(player, enemyEntity)
    local data = playerServants[player.UserId]
    if not data then return false, "No data" end

    -- Лимит
    if #data.captured >= Config.Servants.MaxCaptured then
        return false, "Max servants reached"
    end

    -- Проверка HP врага
    local currentHP = enemyEntity:GetAttribute("CurrentHP")
    local maxHP = enemyEntity:GetAttribute("MaxHP")
    if not currentHP or not maxHP or maxHP == 0 then return false, "No HP data" end
    if currentHP / maxHP > Config.Servants.CaptureThreshold then
        return false, "Enemy HP too high"
    end

    -- Проверка дистанции
    local character = player.Character
    if not character then return false, "No character" end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local enemyRoot = enemyEntity:FindFirstChild("HumanoidRootPart")
    if not rootPart or not enemyRoot then return false, "No root parts" end

    local distance = (enemyRoot.Position - rootPart.Position).Magnitude
    if distance > Config.Servants.CaptureRange then return false, "Too far" end

    -- Получаем данные врага
    local enemyType = enemyEntity:GetAttribute("EnemyType") or "Unknown"
    local bloodQuality = enemyEntity:GetAttribute("BloodQuality") or 0
    local enemyConfig = Config.Enemies[enemyType]

    local baseATK = enemyConfig and enemyConfig.Damage or 10
    local baseHP = enemyConfig and enemyConfig.MaxHP or 80

    -- Формула: Результат = БА + БА * (качество / 100)
    local qualityMultiplier = bloodQuality / 100
    local finalATK = math.floor(baseATK + baseATK * qualityMultiplier)
    local finalHP = math.floor(baseHP + baseHP * qualityMultiplier)

    -- Создаём запись слуги
    local servantId = tostring(tick()) .. "_" .. math.random(1000, 9999)
    local servant = {
        id = servantId,
        name = enemyType .. " Servant",
        enemyType = enemyType,
        bloodQuality = bloodQuality,
        baseATK = baseATK,
        baseHP = baseHP,
        atk = finalATK,
        hp = finalHP,
        maxHP = finalHP,
        weaponSlot = false,
        mode = Config.Servants.Modes.Aggressive,
    }

    table.insert(data.captured, servant)

    -- Сохраняем данные для респавна
    local spawnPos = enemyEntity:GetAttribute("SpawnPosition")
    local respawnType = enemyEntity:GetAttribute("EnemyType")

    -- Уничтожаем врага
    enemyEntity:Destroy()

    -- Респавн через задержку
    if respawnType and spawnPos then
        local respawnConfig = Config.Enemies[respawnType]
        if respawnConfig then
            task.delay(respawnConfig.RespawnTime, function()
                local ServerStorage = game:GetService("ServerStorage")
                local enemiesFolder = ServerStorage:FindFirstChild("enemies")
                if not enemiesFolder then return end
                local template = enemiesFolder:FindFirstChild(respawnType)
                if not template then return end

                local newEnemy = template:Clone()
                local activeEnemies = workspace:FindFirstChild("Enemies")
                if not activeEnemies then return end
                newEnemy.Parent = activeEnemies

                local root = newEnemy:FindFirstChild("HumanoidRootPart")
                if root then
                    root.Anchored = false
                    root.CFrame = CFrame.new(spawnPos)
                end

                local hum = newEnemy:FindFirstChild("Humanoid")
                if hum then hum.WalkSpeed = respawnConfig.WalkSpeed end

                newEnemy:SetAttribute("EnemyType", respawnType)
                newEnemy:SetAttribute("SpawnPosition", spawnPos)

                local HealthMgr = require(script.Parent:WaitForChild("HealthManager"))
                HealthMgr.init(newEnemy, respawnConfig.MaxHP)

                local bloodType = respawnConfig.BloodType or "Outcast"
                local bqRange = respawnConfig.BloodQuality or { Min = 1, Max = 1 }
                newEnemy:SetAttribute("BloodType", bloodType)
                newEnemy:SetAttribute("BloodQuality", math.random(bqRange.Min, bqRange.Max))

                print("[Servants] Respawned " .. respawnType .. " at " .. tostring(spawnPos))
            end)
        end
    end

    print("[Servants] " .. player.Name .. " captured " .. enemyType
        .. " (Blood: " .. bloodQuality .. "%, ATK: " .. finalATK .. ", HP: " .. finalHP .. ")")

    return true, servantId
end

function ServantManager.getServantById(player, servantId)
    local data = playerServants[player.UserId]
    if not data then return nil end
    for _, servant in data.captured do
        if servant.id == servantId then
            return servant
        end
    end
    return nil
end

function ServantManager.summon(player, servantId)
    local data = playerServants[player.UserId]
    if not data then return false end

    local servant = ServantManager.getServantById(player, servantId)
    if not servant then return false end

    -- Отзываем текущего если есть
    if data.activeEntity then
        ServantManager.dismiss(player)
    end

    local character = player.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    -- Клонируем модель из ServerStorage
    local enemiesFolder = ServerStorage:FindFirstChild("enemies")
    if not enemiesFolder then return false end
    local template = enemiesFolder:FindFirstChild(servant.enemyType)
    if not template then return false end

    local entity = template:Clone()
    entity.Name = servant.name

    -- Устанавливаем позицию рядом с игроком
    local spawnPos = rootPart.Position + rootPart.CFrame.RightVector * 4
    local entityRoot = entity:FindFirstChild("HumanoidRootPart")
    if entityRoot then
        entityRoot.CFrame = CFrame.new(spawnPos)
    end

    -- Настраиваем характеристики
    local humanoid = entity:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.MaxHealth = servant.maxHP
        humanoid.Health = servant.hp
        humanoid.WalkSpeed = 16
    end

    -- Атрибуты
    entity:SetAttribute("IsServant", true)
    entity:SetAttribute("OwnerUserId", player.UserId)
    entity:SetAttribute("ServantId", servantId)
    entity:SetAttribute("ServantATK", servant.atk)
    entity:SetAttribute("ServantMode", servant.mode)
    entity:SetAttribute("CurrentHP", servant.hp)
    entity:SetAttribute("MaxHP", servant.maxHP)

    -- Помещаем в Workspace
    local servantsFolder = workspace:FindFirstChild("Servants")
    if not servantsFolder then
        servantsFolder = Instance.new("Folder")
        servantsFolder.Name = "Servants"
        servantsFolder.Parent = workspace
    end
    entity.Parent = servantsFolder

    data.activeId = servantId
    data.activeEntity = entity

    print("[Servants] " .. player.Name .. " summoned " .. servant.name)
    return true
end

function ServantManager.dismiss(player)
    local data = playerServants[player.UserId]
    if not data then return false end

    if data.activeEntity then
        -- Сохраняем текущий HP
        local servant = ServantManager.getServantById(player, data.activeId)
        if servant then
            local hp = data.activeEntity:GetAttribute("CurrentHP")
            if hp then servant.hp = hp end
        end

        data.activeEntity:Destroy()
        data.activeEntity = nil
    end

    data.activeId = nil
    print("[Servants] " .. player.Name .. " dismissed servant")
    return true
end

function ServantManager.setMode(player, mode)
    local data = playerServants[player.UserId]
    if not data or not data.activeId then return false end

    local servant = ServantManager.getServantById(player, data.activeId)
    if not servant then return false end

    servant.mode = mode

    if data.activeEntity then
        data.activeEntity:SetAttribute("ServantMode", mode)
    end

    return true
end

function ServantManager.setCommand(player, command, targetEntity)
    local data = playerServants[player.UserId]
    if not data or not data.activeEntity then return false end

    data.activeEntity:SetAttribute("ServantCommand", command)

    if command == Config.Servants.Commands.AttackTarget and targetEntity then
        data.activeEntity:SetAttribute("ServantTargetName", targetEntity.Name)
    end

    return true
end

function ServantManager.renameServant(player, servantId, newName)
    local servant = ServantManager.getServantById(player, servantId)
    if not servant then return false end

    newName = string.sub(newName, 1, 20) -- макс 20 символов
    servant.name = newName

    local data = playerServants[player.UserId]
    if data and data.activeEntity and data.activeId == servantId then
        data.activeEntity.Name = newName
    end

    return true
end

function ServantManager.remove(player)
    local data = playerServants[player.UserId]
    if data and data.activeEntity then
        data.activeEntity:Destroy()
    end
    playerServants[player.UserId] = nil
end

return ServantManager