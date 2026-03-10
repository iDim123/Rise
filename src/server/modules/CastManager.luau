-- API:
--   CastManager.start(player, params) → castId | nil
--   CastManager.cancel(player, reason?)
--   CastManager.isActive(player) → bool
--   CastManager.getCast(player) → castData | nil
--
-- params = {
--   Duration        : number
--   Label           : string
--   MovementMode    : string  -- "Locked"|"Slowed"|"Free"|"CancelOnMove"
--   SpeedMult       : number?
--   CancelKey       : string?
--   CancelOnStun    : bool?
--   CancelOnDamage  : bool?
--   OnComplete      : function(player)?
--   OnCancel        : function(player, reason)?
-- }

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes   = require(ReplicatedStorage:WaitForChild("Remotes"))
local EventBus  = require(ServerScriptService:WaitForChild("modules"):WaitForChild("EventBus"))

local MOVEMENT_MODE = {
    LOCKED          = "Locked",
    SLOWED          = "Slowed",
    FREE            = "Free",
    CANCEL_ON_MOVE  = "CancelOnMove",
}

local activeCasts = {}

local function makeCastId()
    return "cast_" .. tostring(math.floor(os.clock() * 10000)) .. "_" .. tostring(math.random(1000, 9999))
end

local function getHumanoid(player)
    local character = player.Character
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

local function getBaseSpeed(player)
    local ok, StatsManager = pcall(function()
        return require(ServerScriptService:WaitForChild("modules"):WaitForChild("StatsManager"))
    end)
    if ok and StatsManager then
        local moveSpeed = StatsManager.get(player, "MoveSpeed")
        return 16 * (moveSpeed or 1)
    end
    return 16
end

local function getRootPosition(player)
    local character = player.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

local function applyMovementRestriction(player, mode, speedMult, baseSpeed)
    local humanoid = getHumanoid(player)
    if not humanoid then return end
    if mode == MOVEMENT_MODE.LOCKED then
        humanoid.WalkSpeed = 0
    elseif mode == MOVEMENT_MODE.SLOWED then
        local mult = speedMult or 0.5
        humanoid.WalkSpeed = math.max(0, baseSpeed * mult)
    end
end

local function restoreMovement(player, baseSpeed)
    local humanoid = getHumanoid(player)
    if not humanoid then return end
    local ok, StatsManager = pcall(function()
        return require(ServerScriptService:WaitForChild("modules"):WaitForChild("StatsManager"))
    end)
    if ok and StatsManager then
        StatsManager.recalculate(player)
    else
        humanoid.WalkSpeed = baseSpeed or 16
    end
end

local CastManager = {}
CastManager.MOVEMENT_MODE = MOVEMENT_MODE

function CastManager.start(player, params)
    if activeCasts[player] then
        return nil, "already_casting"
    end
    assert(type(params.Duration) == "number" and params.Duration > 0,
        "[CastManager] Duration должен быть > 0")

    local castId    = makeCastId()
    local mode      = params.MovementMode or MOVEMENT_MODE.FREE
    local baseSpeed = getBaseSpeed(player)
    local rawPos    = getRootPosition(player)
    local startPos  = rawPos and Vector3.new(rawPos.X, 0, rawPos.Z) or nil

    local castData = {
        castId        = castId,
        player        = player,
        params        = params,
        startTime     = os.clock(),
        duration      = params.Duration,
        baseSpeed     = baseSpeed,
        startPosition = startPos,
        timerTask     = nil,
        cancelled     = false,
    }
    activeCasts[player] = castData

    applyMovementRestriction(player, mode, params.SpeedMult, baseSpeed)

    Remotes.CastStart:FireClient(player, {
        Duration        = params.Duration,
        Label           = params.Label or "Каст...",
        MovementMode    = mode,
        SpeedMult       = params.SpeedMult or 0.5,
        CancelKey       = params.CancelKey or "MMB",
        CancelOnStun    = params.CancelOnStun ~= false,
        CancelOnDamage  = params.CancelOnDamage or false,
        BaseSpeed       = baseSpeed,
    })

    castData.timerTask = task.delay(params.Duration, function()
        local current = activeCasts[player]
        if current and current.castId == castId and not current.cancelled then
            CastManager._complete(player, castId)
        end
    end)

    return castId
end

function CastManager._complete(player, castId)
    local castData = activeCasts[player]
    if not castData or castData.castId ~= castId then return end
    if castData.cancelled then return end
    activeCasts[player] = nil
    restoreMovement(player, castData.baseSpeed)
    if castData.params.OnComplete then
        task.spawn(castData.params.OnComplete, player)
    end
end

function CastManager.cancel(player, reason)
    local castData = activeCasts[player]
    if not castData then return end
    castData.cancelled = true
    activeCasts[player] = nil
    restoreMovement(player, castData.baseSpeed)
    Remotes.CastCancel:FireClient(player)
    if castData.params.OnCancel then
        task.spawn(castData.params.OnCancel, player, reason or "server")
    end
end

function CastManager.isActive(player)
    return activeCasts[player] ~= nil
end

function CastManager.getCast(player)
    return activeCasts[player]
end

-- ── Heartbeat: CancelOnMove + Stun/Knockdown ──
local MOVE_THRESHOLD = 2

RunService.Heartbeat:Connect(function()
    local toCancel = {}
    for player, castData in activeCasts do
        if not player.Parent then
            table.insert(toCancel, { player = player, reason = "disconnect" })
            continue
        end
        local character = player.Character
        if not character then
            table.insert(toCancel, { player = player, reason = "server" })
            continue
        end
        local mode = castData.params.MovementMode or MOVEMENT_MODE.FREE
        if mode == MOVEMENT_MODE.CANCEL_ON_MOVE then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp and castData.startPosition then
                local currentXZ = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
                if (currentXZ - castData.startPosition).Magnitude > MOVE_THRESHOLD then
                    table.insert(toCancel, { player = player, reason = "move" })
                    continue
                end
            end
        end
        if mode == MOVEMENT_MODE.LOCKED then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.WalkSpeed ~= 0 then
                humanoid.WalkSpeed = 0
            end
        end
        if castData.params.CancelOnStun ~= false then
            local isStunned = character:GetAttribute("Stunned")
                or character:GetAttribute("Knockdown")
            if isStunned then
                table.insert(toCancel, { player = player, reason = "stun" })
                continue
            end
        end
    end
    for _, entry in toCancel do
        CastManager.cancel(entry.player, entry.reason)
    end
end)

EventBus.on("PlayerDied", function(player, entity, attacker)
    if CastManager.isActive(player) then
        CastManager.cancel(player, "server")
    end
end)

Remotes.CastCancelRequest.OnServerEvent:Connect(function(player)
    local castData = activeCasts[player]
    if not castData then return end
    CastManager.cancel(player, "player")
end)

EventBus.on("EntityTookDamage", function(entity, damage, attacker)
    local player = Players:GetPlayerFromCharacter(entity)
    if not player then return end
    local castData = activeCasts[player]
    if not castData then return end
    if castData.params.CancelOnDamage then
        CastManager.cancel(player, "damage")
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if activeCasts[player] then
        activeCasts[player].cancelled = true
        activeCasts[player] = nil
    end
end)

return CastManager