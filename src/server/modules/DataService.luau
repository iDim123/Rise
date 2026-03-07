local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modules = ServerScriptService:WaitForChild("modules")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local DataService = {}

-- ═══ Constants ═══
local DATASTORE_NAME = "RisePlayerData_v1"
local AUTOSAVE_INTERVAL = 120 -- seconds
local MAX_RETRIES = 3

local dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
local playerLoaded = {} -- [userId] = true when data is loaded
local saving = {} -- [userId] = true while saving (prevent double save)

local SAVE_ENABLED = false
-- ═══ Default data template ═══
local function getDefaultData()
    return {
        Version = 1,

        -- Level
        Level = 1,
        XP = 0,

        -- Inventory
        Inventory = {
            Slots = {}, -- [index] = item or false
            Equipment = {}, -- [slotId] = item or false
            ActiveWeaponSlot = nil,
            UnlockedSlots = Config.Inventory.DefaultRows * Config.Inventory.Columns
        },

        -- Blood
        Blood = {
            Type = "Outcast",
            Quality = 0,
            Amount = 50
        },

        -- Boss progression
        BossEssence = {}, -- [bossId] = { Kills = n, Captured = bool }
        UnlockedTechs = {}, -- [bossId] = true

        -- Servants
        Servants = {
            Captured = {}, -- array of servant data tables
            ActiveId = nil
        }
    }
end

-- ═══ Serialize helpers ═══

-- Inventory slots: convert false to JSON-safe nil marker
local function serializeSlots(slots)
    local result = {}
    for i, slot in slots do
        if slot and slot ~= false then
            result[tostring(i)] = slot
        end
    end
    return result
end

local function deserializeSlots(saved, maxSlots)
    local slots = {}
    for i = 1, maxSlots do
        slots[i] = false
    end
    if not saved then
        return slots
    end
    for k, v in saved do
        local idx = tonumber(k)
        if idx and idx >= 1 and idx <= maxSlots then
            slots[idx] = v
        end
    end
    return slots
end

local function serializeEquipment(equipment)
    local result = {}
    for slotId, item in equipment do
        if item and item ~= false then
            result[slotId] = item
        end
    end
    return result
end

local function deserializeEquipment(saved)
    local equipment = {}
    for _, slotConfig in Config.Equipment.Slots do
        equipment[slotConfig.Id] = false
    end
    if not saved then
        return equipment
    end
    for slotId, item in saved do
        equipment[slotId] = item
    end
    return equipment
end

local function serializeServants(captured)
    local result = {}
    for _, servant in captured do
        -- Strip entity reference (can't save instances)
        local s = {}
        for k, v in servant do
            if k ~= "entity" then
                s[k] = v
            end
        end
        -- Serialize servant equipment
        if s.equipment then
            s.equipment = serializeEquipment(s.equipment)
        end
        table.insert(result, s)
    end
    return result
end

local function deserializeServants(saved)
    if not saved then
        return {}
    end
    local result = {}
    for _, s in saved do
        -- Rebuild servant equipment
        if s.equipment then
            local eq = {}
            for _, slotConfig in Config.Servants.EquipmentSlots do
                eq[slotConfig.Id] = false
            end
            for slotId, item in s.equipment do
                eq[slotId] = item
            end
            s.equipment = eq
        end
        table.insert(result, s)
    end
    return result
end

-- ═══ Load ═══
function DataService.load(player)
    if not SAVE_ENABLED then
        DataService._applyData(player, getDefaultData())
        playerLoaded[player.UserId] = true
        print("[DataService] SAVE DISABLED — using defaults for " .. player.Name)
        return
    end
    local userId = player.UserId
    local key = "player_" .. userId

    local success, data
    for attempt = 1, MAX_RETRIES do
        success, data = pcall(function()
            return dataStore:GetAsync(key)
        end)
        if success then
            break
        end
        warn("[DataService] Load attempt " .. attempt .. " failed for " .. player.Name .. ": " .. tostring(data))
        if attempt < MAX_RETRIES then
            task.wait(2)
        end
    end

    if not success then
        warn("[DataService] Failed to load data for " .. player.Name .. " after " .. MAX_RETRIES ..
                 " attempts. Using defaults.")
        data = nil
    end

    if not data then
        data = getDefaultData()
        print("[DataService] New player: " .. player.Name .. " — using default data")
    else
        print("[DataService] Loaded data for " .. player.Name .. " (v" .. (data.Version or 0) .. ")")
    end

    -- Apply to modules
    DataService._applyData(player, data)
    playerLoaded[userId] = true
end

function DataService._applyData(player, data)
    local InventoryManager = require(modules:WaitForChild("InventoryManager"))
    local LevelManager = require(modules:WaitForChild("LevelManager"))
    local BloodManager = require(modules:WaitForChild("BloodManager"))
    local BossManager = require(modules:WaitForChild("boss"):WaitForChild("BossManager"))
    local ServantManager = require(modules:WaitForChild("servant"):WaitForChild("ServantManager"))

    -- Level (init first, then override)
    LevelManager.initPlayer(player)
    LevelManager._setPlayerData(player, data.Level or 1, data.XP or 0)

    -- Inventory
    InventoryManager.create(player)
    local inv = InventoryManager.getInventory(player)
    if inv and data.Inventory then
        local maxSlots = Config.Inventory.Rows * Config.Inventory.Columns
        inv.slots = deserializeSlots(data.Inventory.Slots, maxSlots)
        inv.equipment = deserializeEquipment(data.Inventory.Equipment)
        inv.activeWeaponSlot = data.Inventory.ActiveWeaponSlot
        inv.unlockedSlots = data.Inventory.UnlockedSlots or (Config.Inventory.DefaultRows * Config.Inventory.Columns)
        -- Recalc bag slots
        InventoryManager.recalcUnlockedSlots(player)
    end

    -- Blood
    BloodManager.init(player)
    if data.Blood then
        local bData = BloodManager.getData(player)
        if bData then
            bData.Type = data.Blood.Type or "Outcast"
            bData.Quality = data.Blood.Quality or 0
            bData.Amount = data.Blood.Amount or 50
        end
        local character = player.Character
        if character then
            character:SetAttribute("BloodType", data.Blood.Type or "Outcast")
            character:SetAttribute("BloodQuality", data.Blood.Quality or 0)
            character:SetAttribute("BloodAmount", data.Blood.Amount or 50)
        end
    end

    -- Boss essence + techs
    BossManager.initPlayer(player)
    BossManager._setPlayerEssence(player, data.BossEssence or {})
    BossManager._setPlayerTechs(player, data.UnlockedTechs or {})

    -- Servants
    ServantManager.init(player)
    ServantManager._setPlayerServants(player, deserializeServants(data.Servants and data.Servants.Captured))
end

-- ═══ Collect ═══
function DataService.collect(player)
    local InventoryManager = require(modules:WaitForChild("InventoryManager"))
    local LevelManager = require(modules:WaitForChild("LevelManager"))
    local BloodManager = require(modules:WaitForChild("BloodManager"))
    local BossManager = require(modules:WaitForChild("boss"):WaitForChild("BossManager"))
    local ServantManager = require(modules:WaitForChild("servant"):WaitForChild("ServantManager"))

    local inv = InventoryManager.getInventory(player)
    local bloodData = BloodManager.getData(player)
    local servantData = ServantManager.getData(player)

    local data = getDefaultData()

    -- Level
    data.Level = LevelManager.getPlayerLevel(player)
    data.XP = LevelManager.getPlayerXP(player)

    -- Inventory
    if inv then
        data.Inventory.Slots = serializeSlots(inv.slots)
        data.Inventory.Equipment = serializeEquipment(inv.equipment)
        data.Inventory.ActiveWeaponSlot = inv.activeWeaponSlot
        data.Inventory.UnlockedSlots = inv.unlockedSlots
    end

    -- Blood
    if bloodData then
        data.Blood.Type = bloodData.Type
        data.Blood.Quality = bloodData.Quality
        data.Blood.Amount = bloodData.Amount
    end

    -- Boss
    data.BossEssence = BossManager._getPlayerEssence(player)
    data.UnlockedTechs = BossManager._getPlayerTechs(player)

    -- Servants
    if servantData then
        data.Servants.Captured = serializeServants(servantData.captured or {})
        data.Servants.ActiveId = servantData.activeId
    end

    return data
end

-- ═══ Save ═══
function DataService.save(player)
    if not SAVE_ENABLED then
        print("[DataService] SAVE DISABLED — skip save for " .. (player.Name or "?"))
        return false
    end
    local userId = player.UserId
    if not playerLoaded[userId] then
        return false
    end
    if saving[userId] then
        return false
    end

    saving[userId] = true

    local data = DataService.collect(player)
    local key = "player_" .. userId

    local success, err
    for attempt = 1, MAX_RETRIES do
        success, err = pcall(function()
            dataStore:SetAsync(key, data)
        end)
        if success then
            break
        end
        warn("[DataService] Save attempt " .. attempt .. " failed for " .. (player.Name or userId) .. ": " ..
                 tostring(err))
        if attempt < MAX_RETRIES then
            task.wait(2)
        end
    end

    saving[userId] = nil

    if success then
        print("[DataService] Saved data for " .. (player.Name or tostring(userId)))
    else
        warn(
            "[DataService] FAILED to save data for " .. (player.Name or tostring(userId)) .. " after " .. MAX_RETRIES ..
                " attempts!")
    end

    return success
end

-- ═══ Cleanup ═══
function DataService.cleanup(player)
    local userId = player.UserId
    playerLoaded[userId] = nil
    saving[userId] = nil
end

function DataService.isLoaded(player)
    return playerLoaded[player.UserId] == true
end

function DataService.toggleSave()
    SAVE_ENABLED = not SAVE_ENABLED
    return SAVE_ENABLED
end

function DataService.isSaveEnabled()
    return SAVE_ENABLED
end
-- ═══ Autosave loop ═══
task.spawn(function()
    while true do
        task.wait(AUTOSAVE_INTERVAL)
        for _, player in Players:GetPlayers() do
            if playerLoaded[player.UserId] then
                task.spawn(function()
                    DataService.save(player)
                end)
            end
        end
    end
end)

return DataService
