local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectileManager = require(script.Parent:WaitForChild("ProjectileManager"))
local CharacterUtil = require(ReplicatedStorage:WaitForChild("CharacterUtil"))

local CastManager
local StatsManager

local RangedHandler = {}

-- ═══════════════════════════════════════════════════════════
-- Ленивая загрузка
-- ═══════════════════════════════════════════════════════════

local function getCastManager()
    if not CastManager then
        CastManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("CastManager"))
    end
    return CastManager
end

local function getStatsManager()
    if not StatsManager then
        StatsManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("StatsManager"))
    end
    return StatsManager
end

-- ═══════════════════════════════════════════════════════════
-- Состояние
-- ═══════════════════════════════════════════════════════════

-- pendingCasts[player] = {
--     weaponConfig : table,
--     castId       : string,
--     timestamp    : number,
--     waitTask     : thread? — fallback таймер
-- }
local pendingCasts = {}

local attackCooldowns = {} -- [userId] = lastAttackTime

local FALLBACK_TIMEOUT = 1.0 -- секунд ожидания RangedRelease после каста

-- ═══════════════════════════════════════════════════════════
-- Внутренние хелперы
-- ═══════════════════════════════════════════════════════════

-- Проверить cooldown (без применения)
local function isOnCooldown(player, weaponConfig)
    local now = os.clock()
    local lastAttack = attackCooldowns[player.UserId] or 0
    local attackSpeed = getStatsManager().get(player, "AttackSpeed")
    local actualCooldown = weaponConfig.Cooldown / math.max(attackSpeed, 0.1)
    return (now - lastAttack) < actualCooldown
end

-- Применить cooldown
local function applyCooldown(player)
    attackCooldowns[player.UserId] = os.clock()
end

-- Базовая валидация персонажа
local function validateCharacter(player)
    local humanoid, rootPart = CharacterUtil.validatePlayer(player)
    if not humanoid or not rootPart then
        return nil, nil
    end
    return player.Character, rootPart
end
    end

    return character, rootPart
end

-- Выстрелить снарядом
local function fireProjectile(player, rootPart, direction, weaponConfig)
    local dir = direction
    if dir.Magnitude < 0.001 then
        dir = rootPart.CFrame.LookVector
    end

    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 0.001 then
        dir = rootPart.CFrame.LookVector
        dir = Vector3.new(dir.X, 0, dir.Z)
    end
    dir = dir.Unit

    ProjectileManager.fire({
        owner = player,
        origin = rootPart.Position + dir * 2,
        direction = dir,
        projectileId = weaponConfig.ProjectileId,
        baseDamage = weaponConfig.Damage,
        damageType = "Ranged"
    })
end

-- ═══════════════════════════════════════════════════════════
-- Фаза 1: Начать каст (вызывается из CombatManager по AttackRequest)
-- ═══════════════════════════════════════════════════════════

function RangedHandler.attack(player, mousePosition, weaponConfig)

    local character, rootPart = validateCharacter(player)
    if not character then
        return
    end

    if isOnCooldown(player, weaponConfig) then
        return
    end

    local CM = getCastManager()
    if CM.isActive(player) then
        return
    end

    if pendingCasts[player] then
        return
    end

    -- ── Запуск каста ──────────────────────────────────────
    local castId = CM.start(player, {
        Duration = weaponConfig.CastTime or 0.8,
        Label = "Натяжение...",
        MovementMode = weaponConfig.CastMovementMode or "Slowed",
        SpeedMult = weaponConfig.CastSpeedMult or 0.5,
        CancelOnDamage = true,

        OnComplete = function(completedPlayer)
            local pending = pendingCasts[completedPlayer]
            if not pending then
                return
            end

            pending.waitTask = task.delay(FALLBACK_TIMEOUT, function()
                if pendingCasts[completedPlayer] then
                    RangedHandler._fireWithLookVector(completedPlayer)
                else
                    print("[RangedHandler] pending is NIL, skipped")
                end
            end)
        end,

        OnCancel = function(cancelledPlayer, reason)
            local pending = pendingCasts[cancelledPlayer]
            if pending then
                if pending.waitTask then
                    task.cancel(pending.waitTask)
                end
                pendingCasts[cancelledPlayer] = nil
            end
        end
    })

    if not castId then
        return
    end

    -- Сохраняем pending
    pendingCasts[player] = {
        weaponConfig = weaponConfig,
        castId = castId,
        timestamp = os.clock(),
        waitTask = nil
    }
end

-- ═══════════════════════════════════════════════════════════
-- Фаза 2: Получить финальную mousePosition от клиента
-- (через RangedRelease remote, обрабатывается в CombatManager)
-- ═══════════════════════════════════════════════════════════

function RangedHandler.onRelease(player, mousePosition)
    local pending = pendingCasts[player]
    if not pending then
        return
    end

    -- Отменить fallback таймер
    if pending.waitTask then
        task.cancel(pending.waitTask)
    end

    local weaponConfig = pending.weaponConfig
    pendingCasts[player] = nil

    -- Валидация персонажа (мог умереть во время каста)
    local character, rootPart = validateCharacter(player)
    if not character then
        return
    end

    -- Рассчитать направление
    local direction = mousePosition - rootPart.Position

    -- Применить cooldown СЕЙЧАС (выстрел успешен)
    applyCooldown(player)

    -- Выстрелить
    fireProjectile(player, rootPart, direction, weaponConfig)
end

-- ═══════════════════════════════════════════════════════════
-- Fallback — стрелять по LookVector
-- ═══════════════════════════════════════════════════════════

function RangedHandler._fireWithLookVector(player)
    local pending = pendingCasts[player]
    if not pending then
        return
    end

    local weaponConfig = pending.weaponConfig
    pendingCasts[player] = nil

    local character, rootPart = validateCharacter(player)
    if not character then
        return
    end

    local direction = rootPart.CFrame.LookVector

    applyCooldown(player)
    fireProjectile(player, rootPart, direction, weaponConfig)
end

-- ═══════════════════════════════════════════════════════════
-- Cleanup (вызывается из CombatManager при PlayerRemoving)
-- ═══════════════════════════════════════════════════════════

function RangedHandler.cleanup(player)
    local pending = pendingCasts[player]
    if pending then
        if pending.waitTask then
            task.cancel(pending.waitTask)
        end
        pendingCasts[player] = nil
    end

    attackCooldowns[player.UserId] = nil
end

return RangedHandler
