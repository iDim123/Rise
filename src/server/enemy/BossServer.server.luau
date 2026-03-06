local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local BossManager = require(modules:WaitForChild("BossManager"))

-- ═══ Init players ═══
Players.PlayerAdded:Connect(function(player)
    BossManager.initPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
    BossManager.removePlayer(player)
end)

-- ═══ Spawn bosses from SpawnPoints ═══
local function initBossSpawnPoints()
    local spawnPoints = workspace:FindFirstChild("SpawnPoints")
    if not spawnPoints then return end

    for _, point in spawnPoints:GetChildren() do
        local bossId = point:GetAttribute("BossId")
        if not bossId then continue end

        local bossConfig = Config.Bosses[bossId]
        if not bossConfig then
            warn("[BossServer] No config for boss: " .. bossId)
            continue
        end

        BossManager.spawnBoss(bossId, point.Position)
    end
end

initBossSpawnPoints()

-- ═══ Client requests ═══
Remotes.BossFinish.OnServerEvent:Connect(function(player, bossId)
    if type(bossId) ~= "string" then return end
    local success, err = BossManager.finishBoss(player, bossId)
    if not success then
        print("[BossServer] Finish failed for " .. player.Name .. ": " .. tostring(err))
    end
end)

Remotes.BossCapture.OnServerEvent:Connect(function(player, bossId)
    if type(bossId) ~= "string" then return end
    local success, err = BossManager.captureBoss(player, bossId)
    if not success then
        print("[BossServer] Capture failed for " .. player.Name .. ": " .. tostring(err))
    end
end)

-- ═══ GetBossData ═══
Remotes.GetBossData.OnServerInvoke = function(player)
    return BossManager.getPlayerBossData(player)
end