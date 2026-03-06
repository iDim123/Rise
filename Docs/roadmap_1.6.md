# Roadmap v1.6

## Обзор
Расширение системы статов, тировая система крови, боссы с механикой Essence Absorption,
разблокировка технологий, DataStore, UI (Attributes, Blood Pool, Boss Journal, MenuBar, Minimap).


Фаза 1 — Stats Foundation
StatsConfig.luau — все 20 статов: Id, Name, Description, BaseValue, Format (%, flat), Category
StatsManager.luau — getPlayerStats(player) собирает base + equipment + blood + buffs
Расширить ItemConfig — добавить новые Stats поля на предметы (PhysicalPower, MagicalResistance и т.д.)
Интеграция статов в существующие модули: WeaponManager, EnemyBehaviors, AbilityManager, ResourceManager, BloodManager, HealthManager (regen), Humanoid (speed)
Remote UpdateStats (Server → Client) + GetPlayerStats (Client → Server)
Фаза 2 — Blood Tiers
Расширить BloodConfig.luau — тиры, пороги, бонусы per blood type с min/max
Рефакторинг BloodManager.luau — расчёт тировых бонусов, интеграция со StatsManager
Remote обновления крови для UI
Фаза 3 — Character Window UI
Tab "Attributes" — таблица 20 статов + тултип справа
Tab "Blood Pool" — тип, объём, качество, шкала тиров I/II/MAX, список бонусов с описаниями
Фаза 4 — DataStore
DataService.luau — сохранение/загрузка: инвентарь, уровень, XP, кровь, Essence, разблокированные технологии, слуги
Интеграция: PlayerAdded → load, PlayerRemoving → save, auto-save interval
Фаза 5 — Boss System
BossConfig.luau — конфиг первого босса (Blood Warrior)
BossManager.luau — состояние Downed, таймер 10с, F/T взаимодействие, Essence tracking
TechManager.luau — разблокировка технологий, проверка в CraftHandler
Расширить EnemyBehaviors — поддержка босс-состояний (Downed)
Новые предметы: blood_ring, blood_necklace + рецепты с RequiredTech
Boss AI — способности босса (Q, E атаки)
Фаза 6 — Boss Journal UI + MenuBar
MenuBar.client.luau — нижний правый угол, 40×40 иконки, тултип
BossJournal.client.luau — полноэкранное окно, табы актов, карточки боссов, Essence шкала
Remotes: GetBossData, FinishBoss, CaptureBoss
Фаза 7 — Minimap
Minimap.client.luau — круглая карта (текстура), зум +/-, стрелка игрока вращается, N/S/E/W метки
---
# Roadmap v1.6

## Обзор
Расширение системы статов, тировая система крови, боссы с механикой Essence Absorption,
разблокировка технологий, DataStore, UI (Attributes, Blood Pool, Boss Journal, MenuBar, Minimap).

---

## Фаза 1 — Stats Foundation

### 1.1 StatsConfig.luau
Файл: `src/shared/config/StatsConfig.luau`

Определения всех 20 статов игрока.

```lua
local StatsConfig = {}

StatsConfig.Stats = {
    MaxHP           = { Name = "Макс. здоровье",              Base = 0,    Format = "flat",    Category = "Defensive",
                        Description = "Максимальный запас здоровья. Складывается из базы по уровню, экипировки и бонусов." },
    PhysicalPower   = { Name = "Физическая сила",             Base = 10,   Format = "flat",    Category = "Offensive",
                        Description = "Увеличивает урон физических атак." },
    MagicalPower    = { Name = "Магическая сила",             Base = 10,   Format = "flat",    Category = "Offensive",
                        Description = "Увеличивает урон магических способностей." },
    PhysCritChance  = { Name = "Шанс физ. крита",            Base = 0.05, Format = "percent", Category = "Offensive",
                        Description = "Вероятность нанести критический физический удар." },
    MagicCritChance = { Name = "Шанс маг. крита",            Base = 0.05, Format = "percent", Category = "Offensive",
                        Description = "Вероятность нанести критический магический удар." },
    PhysCritDamage  = { Name = "Урон физ. крита",            Base = 1.50, Format = "percent", Category = "Offensive",
                        Description = "Множитель урона при критическом физическом ударе." },
    MagicCritDamage = { Name = "Урон маг. крита",            Base = 1.50, Format = "percent", Category = "Offensive",
                        Description = "Множитель урона при критическом магическом ударе." },
    AttackSpeed     = { Name = "Скорость атаки",             Base = 1.00, Format = "percent", Category = "Offensive",
                        Description = "Множитель скорости атаки. Уменьшает задержку между ударами." },
    MoveSpeed       = { Name = "Скорость передвижения",      Base = 1.00, Format = "percent", Category = "Utility",
                        Description = "Множитель скорости передвижения персонажа." },
    WeaponCDSpeed   = { Name = "Перезарядка оружия",         Base = 1.00, Format = "percent", Category = "Utility",
                        Description = "Множитель скорости перезарядки оружейных навыков. Выше = быстрее." },
    MagicCDSpeed    = { Name = "Перезарядка магии",          Base = 1.00, Format = "percent", Category = "Utility",
                        Description = "Множитель скорости перезарядки магических навыков. Выше = быстрее." },
    FamiliarDamage  = { Name = "Урон фамильяра",            Base = 1.00, Format = "percent", Category = "Offensive",
                        Description = "Множитель урона призванного слуги." },
    BloodDrainRate  = { Name = "Расход крови",               Base = 1.00, Format = "percent", Category = "Utility",
                        Description = "Множитель скорости расхода крови. Ниже = медленнее расход." },
    BloodBonusPower = { Name = "Сила бонусов крови",         Base = 1.00, Format = "percent", Category = "Utility",
                        Description = "Множитель эффективности бонусов от типа крови." },
    ResourceDamage  = { Name = "Урон по ресурсам",           Base = 1.00, Format = "percent", Category = "Utility",
                        Description = "Множитель урона по ресурсным жилам (деревья, камни)." },
    ResourceYield   = { Name = "Получение ресурсов",         Base = 1.00, Format = "percent", Category = "Utility",
                        Description = "Множитель количества добываемых ресурсов." },
    PhysResistance  = { Name = "Физическое сопротивление",   Base = 0,    Format = "percent", Category = "Defensive",
                        Description = "Уменьшает входящий физический урон на данный процент." },
    MagicResistance = { Name = "Магическое сопротивление",   Base = 0,    Format = "percent", Category = "Defensive",
                        Description = "Уменьшает входящий магический урон на данный процент." },
    HealthRegen     = { Name = "Регенерация здоровья",       Base = 1.00, Format = "percent", Category = "Defensive",
                        Description = "Скорость восстановления HP вне боя. 100% = полное восстановление за 60 секунд." },
    HealingReceived = { Name = "Получение исцеления",        Base = 1.00, Format = "percent", Category = "Defensive",
                        Description = "Множитель эффективности всех источников исцеления." },
}

-- Порядок отображения в UI (Attributes tab)
StatsConfig.DisplayOrder = {
    "MaxHP",
    "PhysicalPower", "MagicalPower",
    "PhysCritChance", "MagicCritChance",
    "PhysCritDamage", "MagicCritDamage",
    "AttackSpeed", "MoveSpeed",
    "WeaponCDSpeed", "MagicCDSpeed",
    "FamiliarDamage",
    "BloodDrainRate", "BloodBonusPower",
    "ResourceDamage", "ResourceYield",
    "PhysResistance", "MagicResistance",
    "HealthRegen", "HealingReceived",
}

-- Какие статы может давать экипировка (для валидации)
StatsConfig.EquipmentStats = {
    "MaxHP", "PhysicalPower", "MagicalPower",
    "PhysCritChance", "MagicCritChance",
    "PhysCritDamage", "MagicCritDamage",
    "AttackSpeed", "MoveSpeed",
    "WeaponCDSpeed", "MagicCDSpeed",
    "PhysResistance", "MagicResistance",
    "HealthRegen", "HealingReceived",
}

return StatsConfig
Copy
1.2 StatsManager.luau
Файл: src/server/modules/StatsManager.luau

Copylocal ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local StatsManager = {}

-- Кеш статов по игроку
local playerStats = {}  -- [player] = { StatId = finalValue, ... }

-- Источники бонусов
-- Equipment: flat bonuses (Stats поле предмета)
-- Blood: percent bonuses (из BloodManager)
-- Buffs: percent bonuses (из BuffManager)

function StatsManager.getBaseStat(statId)
    local def = Config.Stats[statId]
    return def and def.Base or 0
end

function StatsManager.recalculate(player)
    local InventoryManager = require(modules:WaitForChild("InventoryManager"))
    local BloodManager = require(modules:WaitForChild("BloodManager"))
    local BuffManager = require(modules:WaitForChild("BuffManager"))
    local LevelManager = require(modules:WaitForChild("LevelManager"))

    local stats = {}
    local character = player.Character

    -- 1. Base values
    for statId, def in Config.Stats do
        stats[statId] = { base = def.Base, flat = 0, percent = 0 }
    end

    -- 2. MaxHP special: base from level
    local levelMaxHP = LevelManager.getPlayerMaxHP(player)
    stats.MaxHP.base = levelMaxHP

    -- 3. Equipment flat bonuses
    local equipment = InventoryManager.getEquipment(player)
    for slotId, item in equipment do
        if item and item.Stats then
            for statId, value in item.Stats do
                if stats[statId] then
                    if statId == "MaxHP" or statId == "PhysicalPower"
                        or statId == "MagicalPower" or statId == "PhysResistance"
                        or statId == "MagicResistance" then
                        -- Flat bonuses
                        stats[statId].flat += value
                    else
                        -- Percent bonuses from equipment
                        stats[statId].percent += value
                    end
                end
            end
        end
    end

    -- 4. Blood percent bonuses
    if character then
        local bloodBonuses = BloodManager.getStatBonuses(character)
        for statId, value in bloodBonuses do
            if stats[statId] then
                stats[statId].percent += value
            end
        end
    end

    -- 5. Buff percent bonuses
    if character then
        local buffBonuses = BuffManager.getAllStatModifiers(character)
        for statId, value in buffBonuses do
            if stats[statId] then
                stats[statId].percent += value
            end
        end
    end

    -- 6. Calculate finals
    local final = {}
    for statId, data in stats do
        local def = Config.Stats[statId]
        if def.Format == "flat" then
            -- Flat stats: (base + flat) * (1 + percent)
            final[statId] = (data.base + data.flat) * (1 + data.percent)
        else
            -- Percent/multiplier stats: base * (1 + flat + percent)
            -- flat here is from equipment percent bonuses stored as flat
            final[statId] = data.base * (1 + data.flat + data.percent)
        end
    end

    playerStats[player] = final

    -- 7. Apply side effects
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16 * (final.MoveSpeed or 1)
        end
        character:SetAttribute("MaxHP", math.floor(final.MaxHP or 100))
    end

    -- 8. Send to client
    Remotes.UpdateStats:FireClient(player, final)

    return final
end

function StatsManager.get(player, statId)
    local stats = playerStats[player]
    if not stats then
        stats = StatsManager.recalculate(player)
    end
    return stats[statId] or 0
end

function StatsManager.getAll(player)
    return playerStats[player] or StatsManager.recalculate(player)
end

function StatsManager.cleanup(player)
    playerStats[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
    StatsManager.cleanup(player)
end)

return StatsManager
Copy
1.3 Интеграция — WeaponManager (пример)
В WeaponManager.server.luau заменяем прямой урон на StatsManager:

Copylocal StatsManager = require(modules:WaitForChild("StatsManager"))

-- В блоке расчёта урона:
local physPower = StatsManager.get(player, "PhysicalPower")
local baseDamage = weaponConfig.Damage
local attackSpeed = StatsManager.get(player, "AttackSpeed")

-- Урон = базовый урон оружия * (physPower / 10) — нормализуем к базе 10
local rawDamage = baseDamage * (physPower / 10)

-- Крит
local critChance = StatsManager.get(player, "PhysCritChance")
local critDamage = StatsManager.get(player, "PhysCritDamage")
local isCrit = math.random() < critChance
if isCrit then
    rawDamage = rawDamage * critDamage
end

-- Level modifier (уже есть)
rawDamage = rawDamage * (1 + dmgMod)

-- Resistance цели
local targetResist = 0
if target:GetAttribute("PhysResistance") then
    targetResist = target:GetAttribute("PhysResistance")
end
local finalDamage = math.max(1, math.floor(rawDamage * (1 - targetResist)))

-- Cooldown с учётом attack speed
local actualCooldown = weaponConfig.AttackCooldown / attackSpeed
Copy
1.4 Интеграция — HealthManager (Regen + HealingReceived)
Copy-- Новый блок в HealthManager: проверка "вне боя" + реген
-- "Вне боя" = не получал урон последние 5 секунд

local COMBAT_TIMEOUT = 5  -- секунд
local lastDamageTime = {}  -- [entity] = tick()

-- В takeDamage:
lastDamageTime[entity] = tick()

-- Новый RunService loop (1 секунда):
task.spawn(function()
    while true do
        task.wait(1)
        for _, player in Players:GetPlayers() do
            local char = player.Character
            if char and not healthData[char]?.IsDead then
                local lastHit = lastDamageTime[char] or 0
                if tick() - lastHit >= COMBAT_TIMEOUT then
                    local regenRate = StatsManager.get(player, "HealthRegen")
                    local maxHP = char:GetAttribute("MaxHP") or 100
                    local regenPerSec = maxHP * regenRate / 60
                    if regenPerSec > 0 then
                        heal(char, regenPerSec)
                    end
                end
            end
        end
    end
end)

-- В heal: учёт HealingReceived
function HealthManager.heal(entity, amount)
    local player = Players:GetPlayerFromCharacter(entity)
    local healMod = 1
    if player then
        healMod = StatsManager.get(player, "HealingReceived")
    end
    local finalHeal = amount * healMod
    -- ... остальная логика
end
Copy
Фаза 2 — Blood Tiers
2.1 BloodConfig.luau (расширенный)
Copylocal BloodConfig = {}

BloodConfig.DrainRate = 0.1
BloodConfig.MaxAmount = 10

BloodConfig.TierThresholds = {
    I   = 1,
    II  = 50,
    MAX = 100,
}

BloodConfig.Types = {
    Outcast = {
        Name = "Изгой",
        Tiers = {},  -- Нет бонусов
    },

    Warrior = {
        Name = "Воин",
        Tiers = {
            I = {
                Stat = "PhysicalPower",
                Min = 0.10,   -- 10%
                Max = 0.20,   -- 20%
                QualityRange = { 1, 100 },
                Description = "Увеличивает физическую силу на %s%%",
            },
            II = {
                Stat = "WeaponCDSpeed",
                Min = 0.10,
                Max = 0.20,
                QualityRange = { 50, 100 },
                Description = "Увеличивает скорость перезарядки оружия на %s%%",
            },
            MAX = {
                Type = "BoostAll",
                Multiplier = 1.20,
                Description = "Усиливает все бонусы крови на 20%",
            },
        },
    },

    Creature = {
        Name = "Существо",
        Tiers = {
            I = {
                Stat = "MoveSpeed",
                Min = 0.10,
                Max = 0.20,
                QualityRange = { 1, 100 },
                Description = "Увеличивает скорость передвижения на %s%%",
            },
            II = {
                Stat = "HealingReceived",
                Min = 0.12,
                Max = 0.24,
                QualityRange = { 50, 100 },
                Description = "Увеличивает получаемое исцеление на %s%%",
            },
            MAX = {
                Type = "BoostAll",
                Multiplier = 1.20,
                Description = "Усиливает все бонусы крови на 20%",
            },
        },
    },
}

return BloodConfig
Copy
2.2 BloodManager — расчёт бонусов
Copy-- Новая функция в BloodManager:
function BloodManager.getStatBonuses(character)
    local bonuses = {}
    local bloodType = character:GetAttribute("BloodType")
    local quality = character:GetAttribute("BloodQuality") or 0

    if not bloodType or quality <= 0 then return bonuses end

    local typeConfig = Config.Blood.Types[bloodType]
    if not typeConfig or not typeConfig.Tiers then return bonuses end

    local thresholds = Config.Blood.TierThresholds
    local hasMAX = (quality >= thresholds.MAX)

    -- Collect tier bonuses
    for tierKey, tierData in typeConfig.Tiers do
        if tierKey == "MAX" then continue end

        local threshold = thresholds[tierKey]
        if quality >= threshold and tierData.Stat then
            local qMin = tierData.QualityRange[1]
            local qMax = tierData.QualityRange[2]
            local t = math.clamp((quality - qMin) / (qMax - qMin), 0, 1)
            local bonus = tierData.Min + (tierData.Max - tierData.Min) * t

            if hasMAX then
                local maxTier = typeConfig.Tiers.MAX
                if maxTier and maxTier.Type == "BoostAll" then
                    bonus = bonus * maxTier.Multiplier
                end
            end

            bonuses[tierData.Stat] = (bonuses[tierData.Stat] or 0) + bonus
        end
    end

    return bonuses
end
Copy
Фаза 3 — Character Window UI
3.1 Новые вкладки
CharacterWindow.client.luau уже имеет табы Equipment и Crafting. Добавляем: "Blood Pool", "Attributes".

3.2 AttributesPanel.luau
Таблица строк: [Stat Name]...........[Value]. При наведении — тултип справа от окна с Description из StatsConfig. Значения обновляются через Remotes.UpdateStats.

Формат отображения:

flat → число (например "135")
percent → процент (например "120%" для MoveSpeed, "5%" для PhysCritChance)
3.3 BloodPoolPanel.luau
Верхняя часть: иконка крови + Blood Type name, объём "5.0 / 10 Liters". Шкала качества: полоска с метками I, II, MAX. Заполнение красным до текущего %. Текст качества: "79%". Список бонусов: для каждого активного тира — римская цифра + описание с подставленным значением.

Фаза 4 — DataStore
4.1 DataService.luau
Структура сохранения:

Copy{
    Level = 1,
    XP = 0,
    Inventory = { slots = {}, equipment = {}, activeWeaponSlot = nil, unlockedSlots = 24 },
    Blood = { Type = nil, Quality = 0, Amount = 0 },
    BossEssence = { BloodWarrior = 0 },     -- [bossId] = killCount
    UnlockedTechs = { "BloodWarrior" },      -- список bossId чьи технологии открыты
    Servants = { captured = {}, activeId = nil },
}
Фаза 5 — Boss System
5.1 BossConfig.luau
Copylocal BossConfig = {}

BossConfig.DownedDuration = 10  -- секунд в состоянии Повержен

BossConfig.Acts = {
    [1] = { Name = "Акт 1", Bosses = { "BloodWarrior" } },
}

BossConfig.Bosses = {
    BloodWarrior = {
        Name = "Кровавый воин",
        Level = 6,
        Act = 1,
        MaxHP = 500,
        Damage = 15,
        AttackRange = 6,
        AggroRange = 30,
        AttackCooldown = 1.2,
        WalkSpeed = 14,
        RespawnTime = 60,
        EssenceRequired = 2,
        BloodType = nil,
        XPReward = 150,
        Location = "Кровавый лес",
        Description = "Могущественный воин, познавший силу крови.",
        Image = "rbxassetid://0",
        Unlocks = {
            Icon = "rbxassetid://0",
            TooltipTitle = "Кровавая ковка",
            TooltipDescription = "Кровавое кольцо\nКровавое ожерелье",
            Recipes = { "blood_ring", "blood_necklace" },
        },
        Loot = {
            { ItemId = "blood_essence", MinAmount = 10, MaxAmount = 20, Chance = 100 },
        },
        Abilities = { "Q", "E" },
    },
}

return BossConfig
Copy
5.2 BossManager — состояния
[Normal Combat] → HP reaches 1 → [Downed]
    [Downed] + F → die() + grantTech + grantEssence + XP
    [Downed] + T (if essence full) → captureServant + XP
    [Downed] + 10s timeout → die() (no rewards)
5.3 Ring equip logic
EquipSlot = "Ring" → resolveEquipSlot проверяет Ring1, Ring2:

Copyif slot == "Ring" then
    if not eq.Ring1 then return "Ring1" end
    if not eq.Ring2 then return "Ring2" end
    return "Ring1"  -- замена
end
Фаза 6 — Boss Journal UI + MenuBar
6.1 MenuBar
Нижний правый угол. Горизонтальный ряд 40×40 иконок, padding 4. Первая кнопка: Boss Journal. Тултип при наведении "Журнал боссов".

6.2 BossJournal
Полноэкранный overlay. Табы актов. Scroll-список карточек. Каждая карточка: Defeated badge, Image, Name, Level, Location, Description, иконки технологий (с тултипом списка рецептов), шкала Essence (секции).

Фаза 7 — Minimap
Круглая ImageLabel. Тек