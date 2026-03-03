local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local modules = ReplicatedStorage:WaitForChild("modules")
local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local HealthManager = require(modules:WaitForChild("HealthManager"))
local InventorySync = require(modules:WaitForChild("InventorySync"))

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