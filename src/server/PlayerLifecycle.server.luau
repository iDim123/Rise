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
local CraftHandler -- lazy require (it's not a module in modules/)

-- ═══ Character spawned ═══
local function onCharacterAdded(player, character)
    character:WaitForChild("Humanoid")

    -- HP from level
    local maxHP = LevelManager.getPlayerMaxHP(player)
    HealthManager.init(character, maxHP)

    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.MaxHealth = maxHP
        humanoid.Health = maxHP
    end

    -- Restore blood attributes on character
    local bData = BloodManager.getData(player)
    if bData then
        character:SetAttribute("BloodType", bData.Type)
        character:SetAttribute("BloodQuality", bData.Quality)
        character:SetAttribute("BloodAmount", bData.Amount)
    end

    -- Dismiss active servant on respawn
    ServantManager.dismiss(player)

    -- Recalculate all stats
    StatsManager.recalculate(player)
end

-- ═══ Player joined ═══
local function onPlayerAdded(player)
    -- 1. Load all saved data (or create defaults)
    --    This calls init on ALL modules internally
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
        InventoryManager.addItemFromConfig(player, "rugged_hide", 900)
        InventoryManager.addItemFromConfig(player, "small_bag", 1)
        InventoryManager.addItemFromConfig(player, "blood_vial_warrior", 5)
        InventoryManager.addItemFromConfig(player, "blood_vial_creature", 5)

    end

    -- 3. CharacterAdded (fires for current + future spawns)
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)

    -- If character already exists (late join)
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end

-- ═══ Player leaving ═══
local function onPlayerRemoving(player)
    -- 1. Save FIRST (while data still exists)
    DataService.save(player)

    -- 2. Cleanup all modules
    ServantManager.remove(player)
    BloodManager.remove(player)
    BossManager.removePlayer(player)
    InventoryManager.remove(player)
    StatsManager.cleanup(player)
    DataService.cleanup(player)
    -- LevelManager cleanup happens in its own PlayerRemoving
end

-- ═══ Connect ═══
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players who joined before this script ran
for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end

-- ═══ Server shutdown — save everyone ═══
game:BindToClose(function()
    if not DataService.isSaveEnabled() then
        return
    end

    for _, player in Players:GetPlayers() do
        task.spawn(function()
            DataService.save(player)
        end)
    end
    task.wait(4)
end)
