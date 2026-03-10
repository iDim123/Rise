local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local localPlayer = Players.LocalPlayer

-- ═══ Colors ═══
local SCHOOL_COLORS = {
    Blood = {
        primary = Color3.fromRGB(180, 20, 20),
        secondary = Color3.fromRGB(100, 0, 0),
        heal = Color3.fromRGB(50, 200, 50)
    },
    Chaos = {
        primary = Color3.fromRGB(160, 40, 220),
        secondary = Color3.fromRGB(80, 0, 140),
        heal = Color3.fromRGB(50, 200, 50)
    }
}

local DEFAULT_COLORS = {
    primary = Color3.fromRGB(200, 200, 255),
    secondary = Color3.fromRGB(100, 100, 150),
    heal = Color3.fromRGB(50, 200, 50)
}

local function getColors(school)
    return SCHOOL_COLORS[school] or DEFAULT_COLORS
end

-- ═══ Helpers ═══

local function createRing(position, radius, color, duration)
    local ring = Instance.new("Part")
    ring.Name = "VFX_Ring"
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.Color = color
    ring.Transparency = 0.5
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.2, 0.5, 0.5) -- height, diameter, diameter
    ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    ring.Parent = Workspace

    local targetSize = Vector3.new(0.2, radius * 2, radius * 2)
    local tween = TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = targetSize,
        Transparency = 1
    })
    tween:Play()

    Debris:AddItem(ring, duration + 0.1)
    return ring
end

local function createFlash(position, color, size, duration)
    local flash = Instance.new("Part")
    flash.Name = "VFX_Flash"
    flash.Anchored = true
    flash.CanCollide = false
    flash.Material = Enum.Material.Neon
    flash.Color = color
    flash.Transparency = 0.3
    flash.Shape = Enum.PartType.Ball
    flash.Size = Vector3.new(size, size, size)
    flash.Position = position
    flash.Parent = Workspace

    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = 3
    light.Range = size * 3
    light.Parent = flash

    local tween = TweenService:Create(flash, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(size * 2, size * 2, size * 2),
        Transparency = 1
    })
    tween:Play()

    TweenService:Create(light, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Brightness = 0
    }):Play()

    Debris:AddItem(flash, duration + 0.1)
end

local function createShield(character, color, duration)
    if not character then
        return
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    local shield = Instance.new("Part")
    shield.Name = "VFX_Shield"
    shield.Anchored = false
    shield.CanCollide = false
    shield.Material = Enum.Material.ForceField
    shield.Color = color
    shield.Transparency = 0.6
    shield.Shape = Enum.PartType.Ball
    shield.Size = Vector3.new(6, 6, 6)
    shield.Parent = Workspace

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = rootPart
    weld.Part1 = shield
    weld.Parent = shield

    shield.CFrame = rootPart.CFrame

    TweenService:Create(shield, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Transparency = 1
    }):Play()

    Debris:AddItem(shield, duration + 0.1)
end

local function getCharacterByUserId(userId)
    local player = Players:GetPlayerByUserId(userId)
    if player then
        return player.Character
    end
    return nil
end

-- ═══ Effect Handlers ═══

local handlers = {}

handlers["AoEDamage"] = function(position, data)
    local radius = data.Radius or 8
    local school = data.School
    local colors = getColors(school)

    createRing(position, radius, colors.primary, 0.6)
    createFlash(position, colors.primary, 3, 0.4)
end

handlers["AoEHeal"] = function(position, data)
    local radius = data.Radius or 10
    local colors = getColors(data.School)

    createRing(position, radius, colors.heal, 0.8)
    createFlash(position, colors.heal, 2, 0.5)
end

handlers["AoEBuff"] = function(position, data)
    local radius = data.Radius or 10
    local colors = getColors(data.School)

    -- Subtle golden ring for buffs
    createRing(position, radius, Color3.fromRGB(200, 180, 50), 0.7)
end

handlers["AoEPassive"] = function(position, data)
    local radius = data.Radius or 10
    local colors = getColors(data.School)

    createRing(position, radius, colors.secondary, 0.5)
end

handlers["AreaExplosion"] = function(position, data)
    local radius = data.Radius or 6
    local school = data.School
    local colors = getColors(school)

    createFlash(position, colors.primary, 4, 0.5)
    createRing(position, radius, colors.primary, 0.7)

    -- Second delayed ring
    task.delay(0.1, function()
        createRing(position, radius * 0.6, colors.secondary, 0.5)
    end)
end

handlers["Reflect"] = function(position, data)
    local colors = getColors(data.School)

    createFlash(position, colors.primary, 3, 0.3)
    createRing(position, 8, colors.primary, 0.4)
end

handlers["BlockStart"] = function(position, data)
    local casterId = data.CasterId
    local duration = data.Duration or 1.5
    local colors = getColors(data.School)
    local character = getCharacterByUserId(casterId)

    createShield(character, colors.secondary, duration)
end

handlers["FrontalBlockStart"] = function(position, data)
    local casterId = data.CasterId
    local duration = data.Duration or 2
    local colors = getColors(data.School)
    local character = getCharacterByUserId(casterId)

    createShield(character, colors.primary, duration)
end

handlers["BlockTriggered"] = function(position, data)
    local colors = getColors(data.School)

    createFlash(position, Color3.fromRGB(255, 255, 200), 5, 0.3)
    createRing(position, 8, colors.primary, 0.5)
end

handlers["Immaterial"] = function(position, data)
    local casterId = data.CasterId
    local duration = data.Duration or 1
    local character = getCharacterByUserId(casterId)

    createShield(character, Color3.fromRGB(220, 220, 255), duration)
end

-- ═══ Listen ═══

Remotes.SpellEffect.OnClientEvent:Connect(function(effectType, positionOrData, data)
    -- BeamTick handled in BeamVisual.client.luau
    if effectType == "BeamTick" then
        return
    end

    local handler = handlers[effectType]
    if handler then
        -- SpellEffect args: (effectType, position, data)
        -- position is Vector3, data is table
        if typeof(positionOrData) == "Vector3" then
            handler(positionOrData, data or {})
        else
            -- Some effects may pass data as second arg
            handler(Vector3.new(0, 0, 0), positionOrData or {})
        end
    else
        print("[SpellVFX] Unknown effect type:", effectType)
    end
end)

print("[SpellVFX] Initialized")
