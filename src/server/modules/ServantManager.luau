local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local ServantManager = {}
local playerServants = {}

-- === Формулы ===

local function calcItemLevelSum(equipment)
    local sum = 0
    for _, item in equipment do
        if item and item ~= false then
            local itemDef = Config.Items[item.Id]
            sum = sum + (itemDef and itemDef.ItemLevel or item.ItemLevel or 0)
        end
    end
    return sum
end

local function calcPower(expertise, equipment)
    local base = Config.Servants.PowerBase
    local sum = calcItemLevelSum(equipment)
    return math.floor(base + base * expertise / 100 + sum)
end

local function recalcStats(servant)
    local power = calcPower(servant.expertise, servant.equipment)
    servant.power = power
    servant.atk = math.floor(servant.baseATK + power / 10)
    servant.maxHP = math.floor(servant.baseHP + power)
    if servant.hp > servant.maxHP then
        servant.hp = servant.maxHP
    end
end

-- === Init ===

function ServantManager.init(player)
    if playerServants[player.UserId] then return end
    playerServants[player.UserId] = {
        captured = {},
        activeId = nil,
        activeEntity = nil,
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

-- === Capture ===

function ServantManager.captureEnemy(player, enemyEntity)
    local data = playerServants[player.UserId]
    if not data then return false, "No data" end

    if #data.captured >= Config.Servants.MaxCaptured then
        return false, "Max servants reached"
    end

    local currentHP = enemyEntity:GetAttribute("CurrentHP")
    local maxHP = enemyEntity:GetAttribute("MaxHP")
    if not currentHP or not maxHP or maxHP == 0 then return false, "No HP data" end
    if currentHP / maxHP > Config.Servants.CaptureThreshold then
        return false, "Enemy HP too high"
    end

    local character = player.Character
    if not character then return false, "No character" end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local enemyRoot = enemyEntity:FindFirstChild("HumanoidRootPart")
    if not rootPart or not enemyRoot then return false, "No root parts" end

    local distance = (enemyRoot.Position - rootPart.Position).Magnitude
    if distance > Config.Servants.CaptureRange then return false, "Too far" end

    local enemyType = enemyEntity:GetAttribute("EnemyType") or "Unknown"
    local bloodQuality = enemyEntity:GetAttribute("BloodQuality") or 0
    local enemyConfig = Config.Enemies[enemyType]

    local baseATK = enemyConfig and enemyConfig.Damage or 10
    local baseHP = enemyConfig and enemyConfig.MaxHP or 80

    -- Инициализируем пустую экипировку
    local equipment = {}
    for _, slotConfig in Config.Servants.EquipmentSlots do
        equipment[slotConfig.Id] = false
    end

    local servantId = tostring(tick()) .. "_" .. math.random(1000, 9999)
    local servant = {
        id = servantId,
        name = enemyType .. " Servant",
        enemyType = enemyType,
        expertise = bloodQuality,
        level = 1,
        experience = 0,
        baseATK = baseATK,
        baseHP = baseHP,
        atk = 0,
        hp = 0,
        maxHP = 0,
        power = 0,
        equipment = equipment,
        favorite = false,
        mode = Config.Servants.Modes.Aggressive,
    }

    recalcStats(servant)
    servant.hp = servant.maxHP

    table.insert(data.captured, servant)

    local spawnPos = enemyEntity:GetAttribute("SpawnPosition")
    local respawnType = enemyEntity:GetAttribute("EnemyType")

    enemyEntity:Destroy()

    if respawnType and spawnPos then
        EventBus.fire("EntityRemoved", respawnType, spawnPos)
    end

    print("[Servants] " .. player.Name .. " captured " .. enemyType
        .. " (Expertise: " .. bloodQuality .. "%, Power: " .. servant.power
        .. ", ATK: " .. servant.atk .. ", HP: " .. servant.maxHP .. ")")

    return true, servantId
end


function ServantManager.createFromEgg(player, enemyType, bloodQuality)
    local data = playerServants[player.UserId]
    if not data then return false, "No data" end

    if #data.captured >= Config.Servants.MaxCaptured then
        return false, "Max servants reached"
    end

    local enemyConfig = Config.Enemies[enemyType]
    if not enemyConfig then return false, "Unknown enemy type" end

    local baseATK = enemyConfig.Damage or 10
    local baseHP = enemyConfig.MaxHP or 100

    local equipment = {}
    for _, slotConfig in Config.Servants.EquipmentSlots do
        equipment[slotConfig.Id] = false
    end

    local servantId = tostring(tick()) .. "_" .. math.random(1000, 9999)
    local servant = {
        id = servantId,
        name = enemyType .. " Servant",
        enemyType = enemyType,
        expertise = bloodQuality,
        level = 1,
        experience = 0,
        baseATK = baseATK,
        baseHP = baseHP,
        atk = 0,
        hp = 0,
        maxHP = 0,
        power = 0,
        equipment = equipment,
        favorite = false,
        mode = Config.Servants.Modes.Passive,
    }

    recalcStats(servant)
    servant.hp = servant.maxHP

    table.insert(data.captured, servant)

    print("[Servants] Egg created " .. servant.name
        .. " for " .. player.Name
        .. " (Expertise: " .. bloodQuality .. "%, Power: " .. servant.power
        .. ", ATK: " .. servant.atk .. ", HP: " .. servant.maxHP .. ")")

    return true, servantId
end
-- === Lookup ===

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

-- === Equipment ===

function ServantManager.equipItem(player, servantId, slotId, itemData)
    local servant = ServantManager.getServantById(player, servantId)
    if not servant then return false, nil end

    -- Проверяем что слот существует
    local validSlot = false
    for _, slotConfig in Config.Servants.EquipmentSlots do
        if slotConfig.Id == slotId then
            validSlot = true
            break
        end
    end
    if not validSlot then return false, nil end

    local previousItem = servant.equipment[slotId]
    if previousItem == false then previousItem = nil end

    servant.equipment[slotId] = itemData
    recalcStats(servant)

    -- Обновляем активного слугу если он заспавнен
    local data = playerServants[player.UserId]
    if data and data.activeEntity and data.activeId == servantId then
        data.activeEntity:SetAttribute("ServantATK", servant.atk)
        data.activeEntity:SetAttribute("MaxHP", servant.maxHP)
        data.activeEntity:SetAttribute("CurrentHP", servant.hp)
        local humanoid = data.activeEntity:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.MaxHealth = servant.maxHP
            humanoid.Health = servant.hp
        end
    end

    return true, previousItem
end

function ServantManager.unequipItem(player, servantId, slotId)
    local servant = ServantManager.getServantById(player, servantId)
    if not servant then return false, nil end

    local item = servant.equipment[slotId]
    if not item or item == false then return false, nil end

    servant.equipment[slotId] = false
    recalcStats(servant)

    local data = playerServants[player.UserId]
    if data and data.activeEntity and data.activeId == servantId then
        data.activeEntity:SetAttribute("ServantATK", servant.atk)
        data.activeEntity:SetAttribute("MaxHP", servant.maxHP)
        data.activeEntity:SetAttribute("CurrentHP", servant.hp)
        local humanoid = data.activeEntity:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.MaxHealth = servant.maxHP
            humanoid.Health = servant.hp
        end
    end

    return true, item
end

-- === Favorite ===

function ServantManager.toggleFavorite(player, servantId)
    local servant = ServantManager.getServantById(player, servantId)
    if not servant then return false end
    servant.favorite = not servant.favorite
    return true
end

-- === Summon ===

function ServantManager.summon(player, servantId)
    local data = playerServants[player.UserId]
    if not data then return false end

    local servant = ServantManager.getServantById(player, servantId)
    if not servant then return false end

    if data.activeEntity then
        ServantManager.dismiss(player)
    end

    local character = player.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local enemiesFolder = ServerStorage:FindFirstChild("enemies")
    if not enemiesFolder then return false end
    local template = enemiesFolder:FindFirstChild(servant.enemyType)
    if not template then return false end

    local entity = template:Clone()
    entity.Name = servant.name

    local spawnPos = rootPart.Position + rootPart.CFrame.RightVector * 4
    local entityRoot = entity:FindFirstChild("HumanoidRootPart")
    if entityRoot then
        entityRoot.CFrame = CFrame.new(spawnPos)
    end

    local humanoid = entity:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.MaxHealth = servant.maxHP
        humanoid.Health = servant.hp
        humanoid.WalkSpeed = 16
    end

    entity:SetAttribute("IsServant", true)
    entity:SetAttribute("OwnerUserId", player.UserId)
    entity:SetAttribute("ServantId", servantId)
    entity:SetAttribute("ServantATK", servant.atk)
    entity:SetAttribute("ServantMode", servant.mode)
    entity:SetAttribute("CurrentHP", servant.hp)
    entity:SetAttribute("MaxHP", servant.maxHP)

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

-- === Dismiss ===

function ServantManager.dismiss(player)
    local data = playerServants[player.UserId]
    if not data then return false end

    if data.activeEntity then
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

-- === Mode / Command ===

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

-- === Rename ===

function ServantManager.renameServant(player, servantId, newName)
    local servant = ServantManager.getServantById(player, servantId)
    if not servant then return false end
    newName = string.sub(newName, 1, 20)
    servant.name = newName
    local data = playerServants[player.UserId]
    if data and data.activeEntity and data.activeId == servantId then
        data.activeEntity.Name = newName
    end
    return true
end

-- === Cleanup ===

function ServantManager.remove(player)
    local data = playerServants[player.UserId]
    if data and data.activeEntity then
        data.activeEntity:Destroy()
    end
    playerServants[player.UserId] = nil
end

return ServantManager