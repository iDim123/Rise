local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modules = ServerScriptService:WaitForChild("modules")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local DataService = require(modules:WaitForChild("DataService"))
local LevelManager = require(modules:WaitForChild("LevelManager"))
local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local InventorySync = require(modules:WaitForChild("InventorySync"))

Remotes.DebugCommand.OnServerEvent:Connect(function(player, command)
    if not RunService:IsStudio() then
        return
    end
    if type(command) ~= "string" then
        return
    end

    if command == "save" then
        local success = DataService.save(player)
        print("[Debug] Save " .. (success and "OK" or "FAILED"))

    elseif command == "data" then
        local data = DataService.collect(player)
        print("[Debug] Level:", data.Level, "XP:", data.XP)
        print("[Debug] Blood:", data.Blood.Type, "Q:", data.Blood.Quality)
        print("[Debug] Servants:", #data.Servants.Captured)

    elseif command == "addxp" then
        LevelManager.addPlayerXP(player, 500)
        print("[Debug] Added 500 XP")

    elseif command == "togglesave" then
        local enabled = DataService.toggleSave()
        print("[Debug] Save " .. (enabled and "ENABLED" or "DISABLED"))

    elseif command == "wipe" then
        local ds = DataStoreService:GetDataStore("RisePlayerData_v1")
        pcall(function()
            ds:RemoveAsync("player_" .. player.UserId)
        end)
        print("[Debug] Data wiped for " .. player.Name)
    end
end)

print("[Debug] Debug commands loaded (F5=save, F6=data, F7=+xp, F8=wipe)")
