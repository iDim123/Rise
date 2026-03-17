local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local DataService = require(modules:WaitForChild("DataService"))
local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local InventorySync = require(modules:WaitForChild("InventorySync"))
local BloodManager = require(modules:WaitForChild("BloodManager"))
local LevelManager = require(modules:WaitForChild("LevelManager"))
local BossManager = require(modules:WaitForChild("boss"):WaitForChild("BossManager"))
local ServantManager = require(modules:WaitForChild("servant"):WaitForChild("ServantManager"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local StatsManager = require(modules:WaitForChild("StatsManager"))
local EventBus = require(modules:WaitForChild("EventBus"))

-- v1.9: Building
local BuildingManager = require(modules:WaitForChild("building"):WaitForChild("BuildingManager"))

local CraftHandler -- lazy require

-- ═══ Character spawned ═══
local function onCharacterAdded(player, character)
    character:WaitForChild("Humanoid")

    local maxHP = LevelManager.getPlayerMaxHP(player)
    HealthManager.init(character, maxHP)

    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.MaxHealth = maxHP
        humanoid.Health = maxHP
    end

    local bData = BloodManager.getData(player)
    if bData then
        character:SetAttribute("BloodType", bData.Type)
        character:SetAttribute("BloodQuality", bData.Quality)
        character:SetAttribute("BloodAmount", bData.Amount)
    end

    ServantManager.dismiss(player)
    StatsManager.recalculate(player)
end

-- ═══ Player joined ═══
local function onPlayerAdded(player)
    -- 1. Load all saved data (incl. BuildingData via DataService._applyData)
    DataService.load(player)

    -- 2. Starter items for new players
    local inv = InventoryManager.getInventory(player)
    local isEmpty = true
    if inv then
        for i = 1, inv.unlockedSlots do
            if inv.slots[i] and inv.slots[i] ~= false then
                isEmpty = false
                break
            end
        end
    end

    if isEmpty then
        InventoryManager.addItemFromConfig(player, "blood_essence", 150)
        InventoryManager.addItemFromConfig(player, "Sword", 1)
        InventoryManager.addItemFromConfig(player, "Bow", 1)
        InventoryManager.addItemFromConfig(player, "iron_helmet", 1)
        InventoryManager.addItemFromConfig(player, "debug_servant_egg", 10)
        InventoryManager.addItemFromConfig(player, "Axe", 1)
        InventoryManager.addItemFromConfig(player, "debug_buff_potion", 10)
        InventoryManager.addItemFromConfig(player, "rugged_hide", 500)
        InventoryManager.addItemFromConfig(player, "small_bag", 1)
        InventoryManager.addItemFromConfig(player, "blood_vial_warrior", 5)
        InventoryManager.addItemFromConfig(player, "blood_vial_creature", 5)
        InventoryManager.addItemFromConfig(player, "stone", 500)
        InventoryManager.addItemFromConfig(player, "wooden_plank", 50)
        InventoryManager.addItemFromConfig(player, "wood", 50)
    end

    -- 3. CharacterAdded
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)

    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end

-- ═══ Player leaving ═══
local function onPlayerRemoving(player)
    -- 1. Save FIRST (while all module data still exists)
    --    DataService.collect → BuildingManager.collect (сериализует замок)
    DataService.save(player)

    -- 2. Centralized cleanup event
    EventBus.fire("PlayerCleanup", player)

    -- 3. Core cleanup (ordered: data-dependent modules first)
    ServantManager.remove(player)
    BloodManager.remove(player)
    BossManager.removePlayer(player)
    InventoryManager.remove(player)
    StatsManager.cleanup(player)

    -- v1.9: Building cleanup (уничтожает Parts, folder, claim)
    -- ПОСЛЕ save, чтобы collect успел сериализовать данные
    BuildingManager.cleanup(player)

    local CoffinHandler = require(modules:WaitForChild("building"):WaitForChild("CoffinHandler"))
    CoffinHandler.cleanupPlayer(player.UserId)
    
    if player.Character then
        HealthManager.cleanup(player.Character)
    end

    DataService.cleanup(player)
end

-- ═══ Connect ═══
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end

-- ═══ Server shutdown — save everyone ═══
game:BindToClose(function()
    if not DataService.isSaveEnabled() then
        return
    end

    local SHUTDOWN_TIMEOUT = 25
    local players = Players:GetPlayers()
    local remaining = #players
    if remaining == 0 then
        return
    end

    local allDone = Instance.new("BindableEvent")

    for _, player in players do
        task.spawn(function()
            local ok, err = pcall(DataService.save, player)
            if not ok then
                warn("[BindToClose] save failed for " .. player.Name .. ": " .. tostring(err))
            end
            remaining -= 1
            if remaining <= 0 then
                allDone:Fire()
            end
        end)
    end

    local waitThread = task.delay(SHUTDOWN_TIMEOUT, function()
        if remaining > 0 then
            warn("[BindToClose] Timeout! " .. remaining .. " player(s) not saved")
            allDone:Fire()
        end
    end)

    allDone.Event:Wait()
    pcall(task.cancel, waitThread)
    allDone:Destroy()
end)