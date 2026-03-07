local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local HealthManager -- подключим позже чтобы избежать циклических зависимостей

local BloodManager = {}
local playerBlood = {} -- [userId] = { Type, Quality, Amount }

function BloodManager.setHealthManager(hm)
    HealthManager = hm
end

function BloodManager.init(player)
    playerBlood[player.UserId] = {
        Type = "Outcast",
        Quality = 0,
        Amount = 50,
    }

    local character = player.Character
    if character then
        character:SetAttribute("BloodType", "Outcast")
        character:SetAttribute("BloodQuality", 0)
        character:SetAttribute("BloodAmount", 50)
    end

    print("[Blood] Initialized for " .. player.Name .. ": Outcast 50%")
end

function BloodManager.getData(player)
    return playerBlood[player.UserId]
end

function BloodManager.getBuffs(player)
    local data = playerBlood[player.UserId]
    if not data then return {} end

    local bloodConfig = Config.Blood.Types[data.Type]
    if not bloodConfig or not bloodConfig.Buffs then return {} end

    local buffs = {}
    local qualityFraction = data.Quality / 100 -- 0.0 - 1.0

    for buffName, range in bloodConfig.Buffs do
        buffs[buffName] = range.Min + (range.Max - range.Min) * qualityFraction
    end

    return buffs
end

function BloodManager.getStatBonuses(character)
    local bonuses = {}
    local bloodType = character:GetAttribute("BloodType")
    local quality = character:GetAttribute("BloodQuality") or 0

    if not bloodType or quality <= 0 then return bonuses end

    local typeConfig = Config.Blood.Types[bloodType]
    if not typeConfig or not typeConfig.Tiers then return bonuses end

    local thresholds = Config.Blood.TierThresholds
    if not thresholds then return bonuses end

    local hasMAX = (quality >= thresholds.MAX)

    -- Collect BloodBonusPower from equipment only (avoid recursion)
    local bloodBonusPower = 1.0
    local Players = game:GetService("Players")
    local player = Players:GetPlayerFromCharacter(character)
    if player then
        local InventoryManager = require(game:GetService("ServerScriptService")
            :WaitForChild("modules"):WaitForChild("InventoryManager"))
        local equipment = InventoryManager.getEquipment(player)
        for _, item in equipment do
            if item and item ~= false and item.Stats and item.Stats.BloodBonusPower then
                bloodBonusPower = bloodBonusPower + item.Stats.BloodBonusPower
            end
        end
    end

    for tierKey, tierData in typeConfig.Tiers do
        if tierKey == "MAX" then continue end

        local threshold = thresholds[tierKey]
        if quality >= threshold and tierData.Stat then
            local qMin = tierData.QualityRange[1]
            local qMax = tierData.QualityRange[2]
            local t = math.clamp((quality - qMin) / math.max(qMax - qMin, 1), 0, 1)
            local bonus = tierData.Min + (tierData.Max - tierData.Min) * t

            if hasMAX then
                local maxTier = typeConfig.Tiers.MAX
                if maxTier and maxTier.Type == "BoostAll" then
                    bonus = bonus * maxTier.Multiplier
                end
            end

            -- Apply BloodBonusPower
            bonus = bonus * bloodBonusPower

            bonuses[tierData.Stat] = (bonuses[tierData.Stat] or 0) + bonus
        end
    end

    return bonuses
end
function BloodManager.drinkBlood(player, enemyEntity)
    local data = playerBlood[player.UserId]
    if not data then return false end

    local character = player.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    if enemyEntity:GetAttribute("IsBoss") then return false end
    
    -- Проверка дистанции
    local enemyRoot = enemyEntity:FindFirstChild("HumanoidRootPart")
    if not enemyRoot then return false end
    local distance = (enemyRoot.Position - rootPart.Position).Magnitude
    if distance > Config.Blood.DrinkRange then return false end

    -- Проверка HP врага < 20%
    local currentHP = enemyEntity:GetAttribute("CurrentHP")
    local maxHP = enemyEntity:GetAttribute("MaxHP")
    if not currentHP or not maxHP then return false end
    if currentHP / maxHP > Config.Blood.DrinkThreshold then return false end

    -- Получаем тип и качество крови врага
    local enemyBloodType = enemyEntity:GetAttribute("BloodType") or "Outcast"
    local enemyBloodQuality = enemyEntity:GetAttribute("BloodQuality") or 0

    -- Меняем кровь игрока
    data.Type = enemyBloodType
    data.Quality = enemyBloodQuality
    data.Amount = 100

    -- Обновляем атрибуты персонажа
    character:SetAttribute("BloodType", data.Type)
    character:SetAttribute("BloodQuality", data.Quality)
    character:SetAttribute("BloodAmount", data.Amount)

    -- Убиваем врага
    if HealthManager then
        HealthManager.takeDamage(enemyEntity, 999999, character)
    end

    local displayName = Config.Blood.Types[enemyBloodType]
        and Config.Blood.Types[enemyBloodType].DisplayName
        or enemyBloodType

    print("[Blood] " .. player.Name .. " drank " .. displayName .. " blood (" .. enemyBloodQuality .. "%)")

    return true
end

-- Расход крови со временем
local drainAccumulator = {}

function BloodManager.tick(player, deltaTime)
    local data = playerBlood[player.UserId]
    if not data then return end

    local character = player.Character
    if not character then return end

    local userId = player.UserId
    drainAccumulator[userId] = (drainAccumulator[userId] or 0) + deltaTime

    if drainAccumulator[userId] < Config.Blood.DrainTickSeconds then return end
    drainAccumulator[userId] = 0

    -- BloodDrainRate modifier
    local StatsManager = require(game:GetService("ServerScriptService"):WaitForChild("modules"):WaitForChild("StatsManager"))
    local drainMod = StatsManager.get(player, "BloodDrainRate")

    local drainPerSecond = (Config.Blood.DrainRate / 60) * drainMod
    data.Amount = data.Amount - drainPerSecond

    if data.Amount <= 0 then
        if data.Type ~= "Outcast" then
            -- Текущая кровь кончилась → переход на Изгоя
            data.Type = "Outcast"
            data.Quality = 0
            data.Amount = Config.Blood.OutcastFallbackAmount
            print("[Blood] " .. player.Name .. " blood expired → Outcast " .. data.Amount .. "%")
        else
            -- Изгой тоже кончился → HP = 1
            data.Amount = 0
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 1 then
                humanoid.Health = 1
                character:SetAttribute("CurrentHP", 1)
            end
        end
    end

    -- Обновляем атрибуты
    character:SetAttribute("BloodType", data.Type)
    character:SetAttribute("BloodQuality", data.Quality)
    character:SetAttribute("BloodAmount", math.max(0, data.Amount))
end

function BloodManager.remove(player)
    playerBlood[player.UserId] = nil
    drainAccumulator[player.UserId] = nil
end

return BloodManager