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
local activeChannels = {}   -- [userId] = { spellId, task }

-- ═══ Auto-load effect handlers ═══
local effectHandlers = {}
local effectsFolder = modules:WaitForChild("spellEffects")
for _, module in effectsFolder:GetChildren() do
    if module:IsA("ModuleScript") then
        local effectType = module.Name:gsub("Effect$", "")
        effectHandlers[effectType] = require(module)
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
        mousePosition = nil, -- filled by caller
    }
end

-- ═══ Cooldown / Charges ═══

local function isOnCooldown(player, spellConfig)
    local userId = player.UserId
    if spellConfig.MaxCharges then
        local cd = spellCharges[userId] and spellCharges[userId][spellConfig.Id]
        return cd and cd.charges <= 0
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
    else
        if not spellCooldowns[userId] then spellCooldowns[userId] = {} end
        spellCooldowns[userId][spellConfig.Id] = tick()
        local actualCd = spellConfig.Cooldown / math.max(cdSpeed, 0.1)
        Remotes.SpellCooldown:FireClient(player, spellConfig.Id, actualCd)
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
                    if cd.charges < cfg.MaxCharges then
                        Remotes.SpellCooldown:FireClient(player, spellId, rechargeTime)
                    end
                end
            end
        end
    end
end)

-- ═══ Main entry ═══

function SpellCastManager.castSpell(player, spellId, mousePosition)
    local ctx = validateCaster(player)
    if not ctx then return end
    ctx.mousePosition = mousePosition

    -- Equipped?
    local slots = SpellProgressManager.getEquippedSlots(player)
    local equipped = false
    for _, id in slots do
        if id == spellId then equipped = true break end
    end
    if not equipped then return end

    local spellConfig = Config.Spells[spellId]
    if not spellConfig then return end
    if isOnCooldown(player, spellConfig) then return end
    if activeChannels[player.UserId] then return end
    if CastManager.isActive(player) then return end

    if spellConfig.CastTime and spellConfig.CastTime > 0.05 then
        local castId = CastManager.start(player, {
            Duration = spellConfig.CastTime,
            Label = spellConfig.Name,
            MovementMode = spellConfig.CastMovementMode or "Free",
            SpeedMult = spellConfig.CastSpeedMult or 0.5,
            CancelOnStun = true,
            CancelOnDamage = false,
            OnComplete = function()
                SpellCastManager._execute(player, spellConfig, mousePosition)
            end,
            OnCancel = function() end,
        })
        if not castId then return end
    else
        SpellCastManager._execute(player, spellConfig, mousePosition)
    end
end

function SpellCastManager._execute(player, spellConfig, mousePosition)
    local ctx = validateCaster(player)
    if not ctx then return end
    ctx.mousePosition = mousePosition

    applyCooldown(player, spellConfig)

    for _, effect in spellConfig.Effects do
        local handler = effectHandlers[effect.Type]
        if handler then
            handler(ctx, effect, spellConfig)
        else
            warn("[SpellCastManager] Unknown effect: " .. tostring(effect.Type))
        end
    end

    print("[Spell] " .. player.Name .. " cast " .. spellConfig.Name)
end

-- ═══ Channel management (exposed for handlers) ═══

function SpellCastManager.getActiveChannels()
    return activeChannels
end

function SpellCastManager.cancelChannel(player)
    local userId = player.UserId
    local channel = activeChannels[userId]
    if not channel then return end
    if channel.task then pcall(task.cancel, channel.task) end
    activeChannels[userId] = nil
    Remotes.BeamEnd:FireAllClients(userId)
    StatsManager.recalculate(player)
end

-- ═══ Remote ═══

Remotes.CastSpell.OnServerEvent:Connect(function(player, spellId, mousePosition)
    if type(spellId) ~= "string" then return end
    if typeof(mousePosition) ~= "Vector3" then return end
    SpellCastManager.castSpell(player, spellId, mousePosition)
end)

-- ═══ Cleanup ═══

Players.PlayerRemoving:Connect(function(player)
    SpellCastManager.cancelChannel(player)
    spellCooldowns[player.UserId] = nil
    spellCharges[player.UserId] = nil
end)

return SpellCastManager