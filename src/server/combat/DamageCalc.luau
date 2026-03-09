local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local StatsManager
local LevelManager

local DamageCalc = {}

-- ═══════════════════════════════════════════════════════════
-- Ленивая загрузка (избегаем циклических зависимостей)
-- ═══════════════════════════════════════════════════════════

local function getStatsManager()
    if not StatsManager then
        StatsManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("StatsManager"))
    end
    return StatsManager
end

local function getLevelManager()
    if not LevelManager then
        LevelManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("LevelManager"))
    end
    return LevelManager
end

-- ═══════════════════════════════════════════════════════════
-- Вспомогательные
-- ═══════════════════════════════════════════════════════════

-- Получить Player из character (или nil если это враг)
local function getPlayerFromCharacter(character)
    return Players:GetPlayerFromCharacter(character)
end

-- Уровень цели (враг или игрок)
local function getTargetLevel(target)
    return target:GetAttribute("Level") or target:GetAttribute("EnemyLevel") or 1
end

-- Сопротивление цели по типу урона
local function getTargetResistance(target, damageType)
    if damageType == "Magic" then
        return target:GetAttribute("MagicResistance") or 0
    end
    -- Physical и Ranged используют физическое сопротивление
    return target:GetAttribute("PhysResistance") or 0
end

-- ═══════════════════════════════════════════════════════════
-- Основной расчёт
-- ═══════════════════════════════════════════════════════════

-- params = {
--   player     : Player          — атакующий игрок
--   target     : Model           — цель (враг или персонаж игрока)
--   baseDamage : number          — базовый урон из конфига
--   damageType : "Physical"|"Magic"|"Ranged"
-- }
--
-- returns: finalDamage (number), isCrit (boolean)

function DamageCalc.calculate(params)
    local player = params.player
    local target = params.target
    local baseDamage = params.baseDamage
    local damageType = params.damageType or "Physical"

    local SM = getStatsManager()
    local LM = getLevelManager()

    -- ── 1. Сила атаки (power scaling) ─────────────────────
    -- Ranged использует PhysicalPower (как Physical)
    local power
    if damageType == "Magic" then
        power = SM.get(player, "MagicalPower")
    else
        power = SM.get(player, "PhysicalPower")
    end

    local damage = baseDamage * (power / 10)

    -- ── 2. Крит ───────────────────────────────────────────
    local critChance, critDamage
    if damageType == "Magic" then
        critChance = SM.get(player, "MagicCritChance")
        critDamage = SM.get(player, "MagicCritDamage")
    else
        critChance = SM.get(player, "PhysCritChance")
        critDamage = SM.get(player, "PhysCritDamage")
    end

    local isCrit = math.random() < critChance
    if isCrit then
        damage = damage * critDamage
    end

    -- ── 3. Сопротивление цели ─────────────────────────────
    local resist = getTargetResistance(target, damageType)
    damage = damage * (1 - resist / 100)

    -- ── 4. Модификатор уровня ─────────────────────────────
    local playerLevel = LM.getPlayerLevel(player)
    local targetLevel = getTargetLevel(target)
    local dmgMod = LM.getDamageModifier(playerLevel, targetLevel)
    damage = damage * (1 + dmgMod)

    -- ── 5. Минимум 1 ─────────────────────────────────────
    local finalDamage = math.max(1, math.floor(damage))

    return finalDamage, isCrit
end

return DamageCalc
