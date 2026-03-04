local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

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
        local baseATK = enemyConfig.Damage or 10
        local baseHP = enemyConfig.MaxHP or 100

        local data = ServantManager.getData(player)
        if not data then return end

        if #data.captured >= Config.Servants.MaxCaptured then
            print("[UseItem] " .. player.Name .. " servant limit reached")
            return
        end

        -- Инициализируем экипировку
        local equipment = {}
        for _, slotConfig in Config.Servants.EquipmentSlots do
            equipment[slotConfig.Id] = false
        end

        local servantId = HttpService:GenerateGUID(false)
        local servantData = {
            id = servantId,
            name = chosenType .. " Servant",
            enemyType = chosenType,
            baseATK = baseATK,
            baseHP = baseHP,
            atk = 0,
            hp = 0,
            maxHP = 0,
            power = 0,
            expertise = bloodQuality,
            level = 1,
            experience = 0,
            mode = "Passive",
            favorite = false,
            equipment = equipment,
        }

        -- Пересчитываем статы (заполнит power, atk, maxHP)
        local powerBase = Config.Servants.PowerBase or 100
        servantData.power = math.floor(powerBase + powerBase * bloodQuality / 100)
        servantData.atk = math.floor(baseATK + servantData.power / 10)
        servantData.maxHP = math.floor(baseHP + servantData.power)
        servantData.hp = servantData.maxHP

        table.insert(data.captured, servantData)
        print("[UseItem] " .. player.Name .. " added debug servant: " .. servantData.name .. " (BQ " .. bloodQuality .. "%)")
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