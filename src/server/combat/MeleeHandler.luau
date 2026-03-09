local ServerScriptService = game:GetService("ServerScriptService")

local DamageCalc = require(script.Parent:WaitForChild("DamageCalc"))
local TargetFinder = require(script.Parent:WaitForChild("TargetFinder"))
local ResourceHit = require(script.Parent:WaitForChild("ResourceHit"))

local HealthManager
local StatsManager

local MeleeHandler = {}

-- ═══════════════════════════════════════════════════════════
-- Ленивая загрузка
-- ═══════════════════════════════════════════════════════════

local function getHealthManager()
    if not HealthManager then
        HealthManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("HealthManager"))
    end
    return HealthManager
end

local function getStatsManager()
    if not StatsManager then
        StatsManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("StatsManager"))
    end
    return StatsManager
end

-- ═══════════════════════════════════════════════════════════
-- Кулдауны
-- ═══════════════════════════════════════════════════════════

local attackCooldowns = {} -- [userId] = lastAttackTime

-- ═══════════════════════════════════════════════════════════
-- Основная атака
-- ═══════════════════════════════════════════════════════════

--- Обработка melee-атаки
--- @param player Player
--- @param mousePosition Vector3
--- @param comboIndex number
--- @param weaponConfig table
function MeleeHandler.attack(player, mousePosition, comboIndex, weaponConfig)
    -- ── 1. Валидация ──────────────────────────────────────
    local character = player.Character
    if not character then
        return
    end

    if character:GetAttribute("IsDead") then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then
        return
    end

    -- ── 2. Кулдаун ────────────────────────────────────────
    local SM = getStatsManager()
    local now = tick()
    local lastAttack = attackCooldowns[player.UserId] or 0
    local attackSpeed = SM.get(player, "AttackSpeed")
    local actualCooldown = weaponConfig.Cooldown / math.max(attackSpeed, 0.1)

    if now - lastAttack < actualCooldown then
        return
    end
    attackCooldowns[player.UserId] = now

    -- ── 3. Комбо и базовый урон ───────────────────────────
    local comboConfig = weaponConfig.Combo
    comboIndex = math.clamp(comboIndex or 1, 1, #comboConfig)
    local baseDamage = comboConfig[comboIndex].Damage

    -- ── 4. Направление атаки ──────────────────────────────
    local mouseDirection = (mousePosition - rootPart.Position)
    mouseDirection = Vector3.new(mouseDirection.X, 0, mouseDirection.Z)
    if mouseDirection.Magnitude < 0.001 then
        return
    end
    mouseDirection = mouseDirection.Unit

    -- ── 5. Поиск целей и нанесение урона ──────────────────
    local HM = getHealthManager()
    local targets = TargetFinder.inCone(rootPart.Position, mouseDirection, weaponConfig.Range, 0.3, character)

    for _, entry in targets do
        local finalDamage, isCrit = DamageCalc.calculate({
            player = player,
            target = entry.entity,
            baseDamage = baseDamage,
            damageType = "Physical"
        })

        HM.takeDamage(entry.entity, finalDamage, character)
        SM.markCombat(entry.entity)
    end

    -- ── 6. Удар по ресурсам ───────────────────────────────
    ResourceHit.hitInCone(player, rootPart, mouseDirection, weaponConfig)
end

--- Очистка данных игрока (вызывается из CombatManager при PlayerRemoving)
function MeleeHandler.cleanup(player)
    attackCooldowns[player.UserId] = nil
end

return MeleeHandler
