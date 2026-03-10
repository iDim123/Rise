local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local modules = ServerScriptService:WaitForChild("modules")
local combat = ServerScriptService:WaitForChild("combat")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local StatsManager = require(modules:WaitForChild("StatsManager"))
local CastManager = require(modules:WaitForChild("CastManager"))
local SpellProgressManager = require(modules:WaitForChild("SpellProgressManager"))

local SpellCastManager = {}

-- ═══ State ═══
local spellCooldowns = {}   -- [userId] = { [spellId] = lastUseTime }
local spellCharges = {}     -- [userId] = { [spellId] = { charges, lastRecharge } }
local activeChannels = {}   -- [userId] = { spellId, task, direction }
local lastMousePosition = {} -- [userId] = Vector3 (updated by SpellAim remote)

-- ═══ Auto-load effect handlers from spellEffects/ ═══
local effectHandlers = {}
local effectsFolder = modules:WaitForChild("spellEffects")
for _, module in effectsFolder:GetChildren() do
    if module:IsA("ModuleScript") then
        local effectType = module.Name:gsub("Effect$", "")
        effectHandlers[effectType] = require(module)
        print("[SpellCastManager] loaded effect handler:", effectType)
    end
end

-- ═══ Helpers ═══

local function getSpellPower(player)
    return StatsManager.get(player, "MagicalPower") or 1.0
end

local function validateCaster(player)
    local character = player.Character
    if not character then return nil end
    if character:GetAttribute("IsDead") then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    return {
        player = player,
        character = character,
        humanoid = humanoid,
        rootPart = rootPart,
        spellPower = getSpellPower(player),
        mousePosition = nil,
    }
end

-- ═══ Cooldown / Charges ═══

local function isOnCooldown(player, spellConfig)
    local userId = player.UserId
    if spellConfig.MaxCharges then
        local cd = spellCharges[userId] and spellCharges[userId][spellConfig.Id]
        if not cd then return false end
        return cd.charges <= 0
    end
    if not spellCooldowns[userId] then return false end
    local lastUse = spellCooldowns[userId][spellConfig.Id] or 0
    local cdSpeed = StatsManager.get(player, "MagicCDSpeed") or 1
    local actualCd = spellConfig.Cooldown / math.max(cdSpeed, 0.1)
    return (tick() - lastUse) < actualCd
end

local function applyCooldown(player, spellConfig)
    local userId = player.UserId
    local cdSpeed = StatsManager.get(player, "MagicCDSpeed") or 1

    if spellConfig.MaxCharges then
        if not spellCharges[userId] then spellCharges[userId] = {} end
        local cd = spellCharges[userId][spellConfig.Id]
        if not cd then
            cd = { charges = spellConfig.MaxCharges, lastRecharge = tick() }
            spellCharges[userId][spellConfig.Id] = cd
        end
        cd.charges = math.max(0, cd.charges - 1)
        local rechargeTime = (spellConfig.ChargeRechargeTime or spellConfig.Cooldown) / math.max(cdSpeed, 0.1)
        Remotes.SpellChargeUpdate:FireClient(player, spellConfig.Id, cd.charges, spellConfig.MaxCharges)
        if cd.charges < spellConfig.MaxCharges then
            Remotes.SpellCooldown:FireClient(player, spellConfig.Id, rechargeTime)
        end
        print("[SpellCastManager] charge used:", spellConfig.Id, "remaining =", cd.charges)
    else
        if not spellCooldowns[userId] then spellCooldowns[userId] = {} end
        spellCooldowns[userId][spellConfig.Id] = tick()
        local actualCd = spellConfig.Cooldown / math.max(cdSpeed, 0.1)
        Remotes.SpellCooldown:FireClient(player, spellConfig.Id, actualCd)
        print("[SpellCastManager] cooldown applied:", spellConfig.Id, "duration =", actualCd)
    end
end

-- ═══ Charge recharge loop ═══

task.spawn(function()
    while true do
        task.wait(0.5)
        for userId, spells in spellCharges do
            local player = Players:GetPlayerByUserId(userId)
            if not player then continue end
            for spellId, cd in spells do
                local cfg = Config.Spells[spellId]
                if not cfg or not cfg.MaxCharges then continue end
                if cd.charges >= cfg.MaxCharges then continue end
                local cdSpeed = StatsManager.get(player, "MagicCDSpeed") or 1
                local rechargeTime = (cfg.ChargeRechargeTime or cfg.Cooldown) / math.max(cdSpeed, 0.1)
                if (tick() - cd.lastRecharge) >= rechargeTime then
                    cd.charges = math.min(cd.charges + 1, cfg.MaxCharges)
                    cd.lastRecharge = tick()
                    Remotes.SpellChargeUpdate:FireClient(player, spellId, cd.charges, cfg.MaxCharges)
                    print("[SpellCastManager] charge recharged:", spellId, "charges =", cd.charges)
                    if cd.charges < cfg.MaxCharges then
                        Remotes.SpellCooldown:FireClient(player, spellId, rechargeTime)
                    end
                end
            end
        end
    end
end)

-- ═══ SpellAim: client sends cursor position during cast ═══
-- Rate-limited: max 20 updates per second per player (50 ms interval)

local SPELL_AIM_MIN_INTERVAL = 0.05
local lastSpellAimTime = {} -- [userId] = os.clock()

Remotes.SpellAim.OnServerEvent:Connect(function(player, mousePosition)
    if typeof(mousePosition) ~= "Vector3" then return end
    local userId = player.UserId
    local now = os.clock()
    if lastSpellAimTime[userId] and (now - lastSpellAimTime[userId]) < SPELL_AIM_MIN_INTERVAL then
        return -- throttled
    end
    lastSpellAimTime[userId] = now
    lastMousePosition[userId] = mousePosition
end)

-- ═══ Main entry ═══

function SpellCastManager.castSpell(player, spellId, mousePosition)
    print("[SpellCastManager] castSpell called:", player.Name, spellId)

    local ctx = validateCaster(player)
    if not ctx then
        print("[SpellCastManager] BLOCKED — invalid caster")
        return
    end

    -- Store initial mouse position
    local userId = player.UserId
    lastMousePosition[userId] = mousePosition

    -- Equipped?
    local slots = SpellProgressManager.getEquippedSlots(player)
    local equipped = false
    for _, id in slots do
        if id == spellId then equipped = true break end
    end
    if not equipped then
        print("[SpellCastManager] BLOCKED — spell not equipped:", spellId)
        return
    end

    local spellConfig = Config.Spells[spellId]
    if not spellConfig then
        print("[SpellCastManager] BLOCKED — unknown spell:", spellId)
        return
    end

    if isOnCooldown(player, spellConfig) then
        print("[SpellCastManager] BLOCKED — on cooldown:", spellId)
        return
    end

    if activeChannels[userId] then
        print("[SpellCastManager] BLOCKED — already channelling")
        return
    end

    if CastManager.isActive(player) then
        print("[SpellCastManager] BLOCKED — already casting")
        return
    end

    if spellConfig.CastTime and spellConfig.CastTime > 0.05 then
        print("[SpellCastManager] starting cast:", spellConfig.Name, "duration =", spellConfig.CastTime)
        local castId = CastManager.start(player, {
            Duration = spellConfig.CastTime,
            Label = spellConfig.Name,
            MovementMode = spellConfig.CastMovementMode or "Free",
            SpeedMult = spellConfig.CastSpeedMult or 0.5,
            CancelOnStun = true,
            CancelOnDamage = false,
            OnComplete = function()
                print("[SpellCastManager] cast complete, executing:", spellConfig.Name)
                -- Use latest mouse position from SpellAim, fallback to initial
                local finalMousePos = lastMousePosition[userId] or mousePosition
                SpellCastManager._execute(player, spellConfig, finalMousePos)
            end,
            OnCancel = function(_, reason)
                print("[SpellCastManager] cast cancelled:", spellConfig.Name, "reason =", reason)
            end,
        })
        if not castId then
            print("[SpellCastManager] BLOCKED — CastManager refused")
            return
        end
    else
        -- Instant cast — use current mouse position as-is
        SpellCastManager._execute(player, spellConfig, mousePosition)
    end
end

function SpellCastManager._execute(player, spellConfig, mousePosition)
    local ctx = validateCaster(player)
    if not ctx then
        print("[SpellCastManager] _execute BLOCKED — invalid caster")
        return
    end
    ctx.mousePosition = mousePosition

    applyCooldown(player, spellConfig)

    print("[SpellCastManager] executing effects for:", spellConfig.Name, "count =", #spellConfig.Effects)

    for i, effect in spellConfig.Effects do
        local handler = effectHandlers[effect.Type]
        if handler then
            print("[SpellCastManager] running effect", i, ":", effect.Type)
            handler(ctx, effect, spellConfig)
        else
            warn("[SpellCastManager] Unknown effect:", effect.Type)
        end
    end

    print("[Spell]", player.Name, "cast", spellConfig.Name)
end

-- ═══ Channel management (exposed for effect handlers) ═══

function SpellCastManager.getActiveChannels()
    return activeChannels
end

function SpellCastManager.cancelChannel(player)
    local userId = player.UserId
    local channel = activeChannels[userId]
    if not channel then return end
    print("[SpellCastManager] cancelling channel for", player.Name)
    if channel.task then pcall(task.cancel, channel.task) end
    activeChannels[userId] = nil
    Remotes.BeamEnd:FireAllClients(userId)
    StatsManager.recalculate(player)
end

-- ═══ Cleanup ═══

Players.PlayerRemoving:Connect(function(player)
    SpellCastManager.cancelChannel(player)
    spellCooldowns[player.UserId] = nil
    spellCharges[player.UserId] = nil
    lastMousePosition[player.UserId] = nil
    lastSpellAimTime[player.UserId] = nil
end)

return SpellCastManager