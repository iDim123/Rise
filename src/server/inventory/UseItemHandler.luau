local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local InventorySync = require(modules:WaitForChild("InventorySync"))
local ServantManager = require(modules:WaitForChild("ServantManager"))

local UseItemHandler = {}

local useCooldowns = {} -- [UserId] = { [ItemId] = tick() }

function UseItemHandler.onUseItem(player, slotIndex)
    if type(slotIndex) ~= "number" then return end
    slotIndex = math.floor(slotIndex)

    local inv = InventoryManager.getInventory(player)
    if not inv then return end

    local item = inv.slots[slotIndex]
    if not item or item == false then return end
    if item.Type ~= "Consumable" then return end

    local itemDef = Config.Items[item.Id]
    if not itemDef or not itemDef.UseEffect then return end

    local effect = itemDef.UseEffect
    local userId = player.UserId

    -- Кулдаун
    if not useCooldowns[userId] then useCooldowns[userId] = {} end
    local lastUse = useCooldowns[userId][item.Id] or 0
    local now = tick()
    if now - lastUse < (effect.Cooldown or 0) then return end

    -- Применяем эффект
    if effect.Type == "Heal" then
        local character = player.Character
        if not character then return end
        HealthManager.heal(character, effect.Amount)

    elseif effect.Type == "AddServant" then
        local enemyTypes = {}
        for typeName, _ in Config.Enemies do
            if typeName ~= "TrainingDummy" then
                table.insert(enemyTypes, typeName)
            end
        end

        local chosenType = enemyTypes[math.random(1, #enemyTypes)]
        local enemyConfig = Config.Enemies[chosenType]
        local bloodQuality = math.random(
            enemyConfig.BloodQuality.Min,
            enemyConfig.BloodQuality.Max
        )

        local success, result = ServantManager.createFromEgg(player, chosenType, bloodQuality)
        if not success then
            print("[UseItem] " .. player.Name .. " egg failed: " .. tostring(result))
            return
        end
    end

    useCooldowns[userId][item.Id] = now

    -- Расходуем
    InventoryManager.removeItem(player, slotIndex, 1)
    print("[UseItem] " .. player.Name .. " used " .. item.Name)
    InventorySync.sendFullUpdate(player)
end

function UseItemHandler.cleanup(player)
    useCooldowns[player.UserId] = nil
end

return UseItemHandler