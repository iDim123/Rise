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
        Amount = 100,
    }

    local character = player.Character
    if character then
        character:SetAttribute("BloodType", "Outcast")
        character:SetAttribute("BloodQuality", 0)
        character:SetAttribute("BloodAmount", 100)
    end

    print("[Blood] Initialized for " .. player.Name .. ": Outcast 100%")
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

function BloodManager.drinkBlood(player, enemyEntity)
    local data = playerBlood[player.UserId]
    if not data then return false end

    local character = player.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

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

    -- Каждую секунду тратим кровь
    if drainAccumulator[userId] < Config.Blood.DrainTickSeconds then return end
    drainAccumulator[userId] = 0

    local drainPerSecond = Config.Blood.DrainRate / 60 -- 2%/мин = 0.0333%/сек
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