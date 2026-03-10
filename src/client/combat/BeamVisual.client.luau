local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

-- ═══ Constants ═══
local BEAM_UPDATE_RATE = 0.1 -- send cursor position every 100ms
local BEAM_COLOR_BLOOD = Color3.fromRGB(180, 20, 20)
local BEAM_COLOR_CHAOS = Color3.fromRGB(160, 40, 220)
local BEAM_COLOR_DEFAULT = Color3.fromRGB(200, 200, 255)

local SCHOOL_COLORS = {
    Blood = BEAM_COLOR_BLOOD,
    Chaos = BEAM_COLOR_CHAOS
}

-- ═══ State ═══
local activeBeams = {} -- [casterId] = { part, light, startTime, duration }
local isCastingBeam = false
local updateConnection = nil
local lastUpdateTime = 0

-- ═══ Mouse world position ═══
local function getMouseWorldPosition()
    local ray = Workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local character = localPlayer.Character
    if character then
        params.FilterDescendantsInstances = {character}
    end
    local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
    if result then
        return result.Position
    end
    return ray.Origin + ray.Direction * 500
end

-- ═══ Create beam visual ═══
local function createBeamPart(origin, direction, range, width, color)
    local beam = Instance.new("Part")
    beam.Name = "BeamVisual"
    beam.Anchored = true
    beam.CanCollide = false
    beam.Material = Enum.Material.Neon
    beam.Color = color
    beam.Transparency = 0.3
    beam.Size = Vector3.new(width, width * 0.3, range)
    beam.CFrame = CFrame.lookAt(origin + direction * (range / 2), origin + direction * range)
    beam.Parent = Workspace

    -- Inner glow
    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = 2
    light.Range = width * 4
    light.Parent = beam

    return beam
end

-- ═══ Update beam position ═══
local function updateBeamPart(beamData, origin, direction, range, width)
    if beamData and beamData.part and beamData.part.Parent then
        beamData.part.Size = Vector3.new(width, width * 0.3, range)
        beamData.part.CFrame = CFrame.lookAt(origin + direction * (range / 2), origin + direction * range)
    end
end

-- ═══ Destroy beam ═══
local function destroyBeam(casterId)
    local beamData = activeBeams[casterId]
    if beamData then
        if beamData.part and beamData.part.Parent then
            beamData.part:Destroy()
        end
        activeBeams[casterId] = nil
    end
end

-- ═══ BeamStart: server tells us a beam started ═══
Remotes.BeamStart.OnClientEvent:Connect(function(casterId, origin, direction, params)
    -- Destroy any existing beam for this caster
    destroyBeam(casterId)

    local range = params.Range or 30
    local width = params.Width or 3
    local duration = params.Duration or 3
    local school = params.School or "Blood"
    local color = SCHOOL_COLORS[school] or BEAM_COLOR_DEFAULT

    local beamPart = createBeamPart(origin, direction, range, width, color)

    activeBeams[casterId] = {
        part = beamPart,
        range = range,
        width = width,
        duration = duration,
        startTime = tick(),
        color = color
    }

    -- If this is our beam, start sending cursor updates
    if casterId == localPlayer.UserId then
        isCastingBeam = true
        lastUpdateTime = 0

        if updateConnection then
            updateConnection:Disconnect()
        end

        updateConnection = RunService.RenderStepped:Connect(function()
            if not isCastingBeam then
                if updateConnection then
                    updateConnection:Disconnect()
                    updateConnection = nil
                end
                return
            end

            local now = tick()
            if (now - lastUpdateTime) >= BEAM_UPDATE_RATE then
                lastUpdateTime = now
                local mousePos = getMouseWorldPosition()
                Remotes.BeamUpdate:FireServer(mousePos)
            end

            -- Update our own beam visual locally for responsiveness
            local character = localPlayer.Character
            if not character then
                return
            end
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if not rootPart then
                return
            end

            local mousePos = getMouseWorldPosition()
            local dir = Vector3.new(mousePos.X - rootPart.Position.X, 0, mousePos.Z - rootPart.Position.Z)
            if dir.Magnitude > 0.001 then
                dir = dir.Unit
            else
                dir = Vector3.new(0, 0, 1)
            end

            local beamData = activeBeams[casterId]
            if beamData then
                updateBeamPart(beamData, rootPart.Position + Vector3.new(0, 2, 0), dir, beamData.range, beamData.width)
            end
        end)

        -- Auto-stop after duration
        task.delay(duration + 0.5, function()
            if isCastingBeam and activeBeams[casterId] then
                isCastingBeam = false
                destroyBeam(casterId)
            end
        end)
    end
end)

-- ═══ SpellEffect: beam tick updates for OTHER players ═══
Remotes.SpellEffect.OnClientEvent:Connect(function(effectType, data)
    if effectType ~= "BeamTick" then
        return
    end

    local casterId = data.CasterId
    if casterId == localPlayer.UserId then
        -- We update our own beam locally, skip server echo
        return
    end

    local beamData = activeBeams[casterId]
    if not beamData then
        return
    end

    local origin = data.Origin + Vector3.new(0, 2, 0)
    local direction = data.Direction
    updateBeamPart(beamData, origin, direction, data.Range or beamData.range, data.Width or beamData.width)
end)

-- ═══ BeamEnd: server tells us beam stopped ═══
Remotes.BeamEnd.OnClientEvent:Connect(function(casterId)
    if casterId == localPlayer.UserId then
        isCastingBeam = false
    end
    destroyBeam(casterId)
end)

-- ═══ Cleanup on character removal ═══
localPlayer.CharacterRemoving:Connect(function()
    isCastingBeam = false
    for casterId, _ in activeBeams do
        destroyBeam(casterId)
    end
end)

print("[BeamVisual] Initialized")
