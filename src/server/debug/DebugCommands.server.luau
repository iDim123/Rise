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
local DayNightManager = require(modules:WaitForChild("DayNightManager"))
local BuffManager = require(modules:WaitForChild("BuffManager"))
local SpellProgressManager = require(modules:WaitForChild("SpellProgressManager"))
-- ════════════════════════════════════════════════════════════
-- Парсинг команды: "/settime 14" → cmd="/settime", args={"14"}
-- ════════════════════════════════════════════════════════════
local function parseCommand(input)
    local parts = {}
    for word in input:gmatch("%S+") do
        table.insert(parts, word)
    end
    local cmd = table.remove(parts, 1)
    return cmd, parts
end

-- ════════════════════════════════════════════════════════════
-- Команды
-- ════════════════════════════════════════════════════════════
local commands = {}

commands["/spellpoint"] = function(player, args)
    local school = args[1] or "Blood"
    local tier = args[2] or "1"
    local amount = tonumber(args[3]) or 1
    SpellProgressManager.addSpellPoints(player, school, tier, amount)
    return "Added " .. amount .. " " .. school .. " T" .. tier .. " spell point"
end

commands["/save"] = function(player, args)
    local success = DataService.save(player)
    return "Save " .. (success and "OK" or "FAILED")
end

commands["/data"] = function(player, args)
    local data = DataService.collect(player)
    return string.format("Level:%d XP:%d Blood:%s Q:%s Servants:%d", data.Level, data.XP, data.Blood.Type,
        data.Blood.Quality, #data.Servants.Captured)
end

commands["/addxp"] = function(player, args)
    local amount = tonumber(args[1]) or 500
    LevelManager.addPlayerXP(player, amount)
    return "Added " .. amount .. " XP"
end

commands["/additem"] = function(player, args)
    local id = args[1]
    local count = tonumber(args[2]) or 1
    if not id then
        return "Usage: /additem <id> [count]"
    end
    InventoryManager.addItemFromConfig(player, id, count)
    InventorySync.sendFullUpdate(player)
    return "Added " .. count .. "x " .. id
end

commands["/togglesave"] = function(player, args)
    local enabled = DataService.toggleSave()
    return "Save " .. (enabled and "ENABLED" or "DISABLED")
end

commands["/wipe"] = function(player, args)
    local ds = DataStoreService:GetDataStore("RisePlayerData_v1")
    pcall(function()
        ds:RemoveAsync("player_" .. player.UserId)
    end)
    return "Data wiped for " .. player.Name
end

-- ── Day/Night ──

commands["/settime"] = function(player, args)
    local hour = tonumber(args[1])
    if not hour then
        return "Usage: /settime <hour 0-24>"
    end
    DayNightManager.setTime(hour)
    return "Time set to " .. hour .. ":00"
end

commands["/timescale"] = function(player, args)
    local scale = tonumber(args[1])
    if not scale then
        return "Usage: /timescale <multiplier>"
    end
    DayNightManager.setTimeScale(scale)
    return "Time scale: x" .. scale
end

commands["/lunar"] = function(player, args)
    local phaseId = args[1]
    if not phaseId then
        return "Usage: /lunar <new_moon|waxing|full_moon|waning|blood_moon>"
    end
    DayNightManager.setLunarPhase(phaseId)
    return "Lunar phase: " .. phaseId
end

commands["/phase"] = function(player, args)
    local phase = DayNightManager.getPhase()
    local lunar = DayNightManager.getLunarPhase()
    return string.format("Phase: %s | Lunar: %s | Day: %s", phase, lunar, tostring(DayNightManager.isDay()))
end

-- ── Buffs ──

commands["/buff"] = function(player, args)
    local buffId = args[1]
    local duration = tonumber(args[2]) or 30
    if not buffId then
        return "Usage: /buff <buffId> [duration]"
    end
    local char = player.Character
    if not char then
        return "No character"
    end
    BuffManager.applyBuff(char, buffId, duration, "debug")
    return "Applied " .. buffId .. " for " .. duration .. "s"
end

commands["/clearbuffs"] = function(player, args)
    local char = player.Character
    if not char then
        return "No character"
    end
    BuffManager.clearBuffs(char)
    return "Buffs cleared"
end

-- ── Weapons ──

commands["/bow"] = function(player, args)
    InventoryManager.addItemFromConfig(player, "Bow", 1)
    InventorySync.sendFullUpdate(player)
    return "Bow added"
end

commands["/weapon"] = function(player, args)
    local id = args[1]
    if not id then
        return "Usage: /weapon <Sword|Axe|Bow>"
    end
    InventoryManager.addItemFromConfig(player, id, 1)
    InventorySync.sendFullUpdate(player)
    return "Weapon " .. id .. " added"
end

-- ── Help ──

commands["/help"] = function(player, args)
    local list = {}
    for cmd, _ in pairs(commands) do
        table.insert(list, cmd)
    end
    table.sort(list)
    return "Commands: " .. table.concat(list, ", ")
end

-- ── World ──

commands["/worldinfo"] = function(player, args)
    local WorldManager = require(modules:WaitForChild("world"):WaitForChild("WorldManager"))
    return WorldManager.getInfo()
end

commands["/templates"] = function(player, args)
    local WorldManager = require(modules:WaitForChild("world"):WaitForChild("WorldManager"))
    local found, missing, details = WorldManager.validateTemplates()
    print("[Debug] ServerStorage templates:")
    print(details)
    return string.format("Templates: %d found, %d missing", found, missing)
end

commands["/savecastle"] = function(player, args)
    -- Принудительно включаем сохранение (в Studio оно выключено по умолчанию)
    local wasEnabled = DataService.isSaveEnabled()
    if not wasEnabled then
        DataService.toggleSave()
    end

    local success = DataService.save(player)

    -- Вернуть обратно если было выключено
    if not wasEnabled then
        DataService.toggleSave()
    end

    if success then
        return "Castle saved to DataStore!"
    else
        return "FAILED to save castle"
    end
end

commands["/wipecastle"] = function(player, args)
    local BuildingManager = require(modules:WaitForChild("building"):WaitForChild("BuildingManager"))
    local castle = BuildingManager.getCastle(player.UserId)
    if not castle then
        return "No castle to wipe"
    end

    BuildingManager.destroyCastle(player)

    -- Сохраняем без замка
    local wasEnabled = DataService.isSaveEnabled()
    if not wasEnabled then
        DataService.toggleSave()
    end
    DataService.save(player)
    if not wasEnabled then
        DataService.toggleSave()
    end

    return "Castle wiped and saved"
end

-- ════════════════════════════════════════════════════════════
-- Обработчик
-- ════════════════════════════════════════════════════════════
Remotes.DebugCommand.OnServerEvent:Connect(function(player, input)
    if not RunService:IsStudio() then
        return
    end
    if type(input) ~= "string" then
        return
    end

    local cmd, args = parseCommand(input)
    if not cmd then
        return
    end

    local handler = commands[cmd]
    if not handler then
        print("[Debug] Unknown command:", cmd, "| /help for list")
        return
    end

    local result = handler(player, args)
    if result then
        print("[Debug]", result)
    end
end)

print("[Debug] Debug commands loaded. Use /help for list")

