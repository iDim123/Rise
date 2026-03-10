local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local InventoryManager = require(script.Parent:WaitForChild("InventoryManager"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local LootManager = {}

local activeLoot = {} -- { [lootPart] = { itemId, itemName, amount, spawnTime } }

-- ═══════════════════════════════════════════════════════════
-- Приватные хелперы
-- ═══════════════════════════════════════════════════════════

--- Папка для лут-партов. Создаётся один раз.
local function getLootFolder()
    local folder = workspace:FindFirstChild("Loot")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "Loot"
        folder.Parent = workspace
    end
    return folder
end

--- Рассчитать смещение для нового лут-парта относительно basePosition.
--- Спиральное размещение: каждый следующий предмет сдвигается по спирали
--- с небольшим рандомом, чтобы кубики не накладывались.
---
--- НАМЕРЕННОЕ ИЗМЕНЕНИЕ ПОВЕДЕНИЯ (Phase 0):
--- Ранее dropLoot использовал детерминированную сетку (dropIndex % 3, floor(dropIndex / 3)).
--- Теперь все методы дропа используют единое спиральное размещение.
--- Визуально лучше при большом количестве дропов.
---
--- @param basePosition Vector3 — центральная точка дропа
--- @return Vector3 — смещение от basePosition
local function _calcLootOffset(basePosition)
    local nearby = 0
    for lootPart, _ in activeLoot do
        if lootPart and lootPart.Parent then
            local dist = (lootPart.Position - basePosition).Magnitude
            if dist < 5 then
                nearby += 1
            end
        end
    end

    local angle = (nearby * 1.2) + math.random() * 0.5
    local radius = 1.5 + nearby * 0.4
    local offsetX = math.cos(angle) * radius
    local offsetZ = math.sin(angle) * radius

    return Vector3.new(offsetX, 0.3, offsetZ)
end

--- Создать лут-парт и зарегистрировать в activeLoot.
--- Единственное место создания лут-партов в модуле.
---
--- @param position Vector3 — мировая позиция (уже с учётом смещения)
--- @param itemId string
--- @param itemName string
--- @param amount number
--- @return BasePart — созданный лут-парт
local function _createLootPart(position, itemId, itemName, amount)
    local lootPart = Instance.new("Part")
    lootPart.Name = "Loot_" .. itemId
    lootPart.Size = Vector3.new(0.8, 0.8, 0.8)
    lootPart.Shape = Enum.PartType.Block
    lootPart.Color = Color3.fromRGB(255, 255, 255)
    lootPart.Material = Enum.Material.SmoothPlastic
    lootPart.Anchored = true
    lootPart.CanCollide = false

    lootPart.Position = position

    lootPart:SetAttribute("ItemId", itemId)
    lootPart:SetAttribute("ItemName", itemName)
    lootPart:SetAttribute("Amount", amount)
    lootPart:SetAttribute("IsLoot", true)

    lootPart.Parent = getLootFolder()

    activeLoot[lootPart] = {
        itemId = itemId,
        itemName = itemName,
        amount = amount,
        spawnTime = os.clock(),
    }

    return lootPart
end

-- ═══════════════════════════════════════════════════════════
-- Публичное API
-- ═══════════════════════════════════════════════════════════

--- Дропнуть лут с убитого врага.
--- @param enemyEntity Model — враг (с HumanoidRootPart и атрибутом EnemyType)
--- @param customLoot table? — кастомная лут-таблица (опционально)
function LootManager.dropLoot(enemyEntity, customLoot)
    local lootTable = customLoot

    if not lootTable then
        local enemyType = enemyEntity:GetAttribute("EnemyType")
        if not enemyType then return end

        local enemyConfig = Config.Enemies[enemyType]
        if not enemyConfig or not enemyConfig.Loot then return end
        lootTable = enemyConfig.Loot
    end

    local rootPart = enemyEntity:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local basePosition = rootPart.Position

    for _, lootEntry in lootTable do
        -- Проверяем шанс
        if math.random() > lootEntry.Chance then continue end

        local itemConfig = Config.Items[lootEntry.ItemId]
        if not itemConfig then
            warn("[LootManager] Unknown item: " .. lootEntry.ItemId)
            continue
        end

        -- Случайное количество
        local amount = math.random(lootEntry.Amount.Min, lootEntry.Amount.Max)

        -- Позиция через единый _calcLootOffset
        local offset = _calcLootOffset(basePosition)
        local position = basePosition + offset

        local lootPart = _createLootPart(position, lootEntry.ItemId, itemConfig.Name, amount)
        print("[LootManager] Dropped " .. itemConfig.Name .. " x" .. amount .. " at " .. tostring(lootPart.Position))
    end
end

--- Подобрать лут.
--- @param player Player
--- @param lootPart BasePart
--- @return boolean, string?
function LootManager.tryPickup(player, lootPart)
    if not lootPart or not lootPart.Parent then return false, "Invalid loot" end

    local data = activeLoot[lootPart]
    if not data then return false, "Not loot" end

    -- Проверяем дистанцию
    local character = player.Character
    if not character then return false, "No character" end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false, "No root part" end

    local distance = (rootPart.Position - lootPart.Position).Magnitude
    if distance > Config.Loot.PickupRange then return false, "Too far" end

    -- Пытаемся добавить в инвентарь
    local itemConfig = Config.Items[data.itemId]
    if not itemConfig then return false, "Unknown item" end

    local success, slotIndex = InventoryManager.addItem(player, {
        Id = itemConfig.Id,
        Name = itemConfig.Name,
        Icon = itemConfig.Icon or "",
        Amount = data.amount,
        Stackable = itemConfig.Stackable or false,
        MaxStack = itemConfig.MaxStack or 1,
        Type = itemConfig.Type or "Misc",
        EquipSlot = itemConfig.EquipSlot,
        Stats = itemConfig.Stats,
        ItemLevel = itemConfig.ItemLevel or 0,
    })

    if not success then return false, "Inventory full" end

    -- Удаляем кубик
    activeLoot[lootPart] = nil
    lootPart:Destroy()

    print("[LootManager] " .. player.Name .. " picked up " .. data.itemName .. " x" .. data.amount)
    return true
end

--- Очистка старого лута.
function LootManager.cleanup()
    local now = os.clock()
    for lootPart, data in activeLoot do
        if now - data.spawnTime > Config.Loot.DropLifetime then
            activeLoot[lootPart] = nil
            if lootPart and lootPart.Parent then
                lootPart:Destroy()
            end
        end
    end
end

--- Дропнуть предмет от игрока (выброс из инвентаря).
--- @param player Player
--- @param slotIndex number
--- @param itemData table — { Id, Name, ... }
--- @param amount number
--- @return boolean
function LootManager.dropItemFromPlayer(player, slotIndex, itemData, amount)
    local character = player.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local itemConfig = Config.Items[itemData.Id]
    if not itemConfig then return false end

    local basePosition = rootPart.Position + rootPart.CFrame.LookVector * 3
    local offset = _calcLootOffset(basePosition)
    local position = basePosition + offset

    _createLootPart(position, itemData.Id, itemData.Name, amount)

    print("[LootManager] " .. player.Name .. " dropped " .. itemData.Name .. " x" .. amount)
    return true
end

--- Дропнуть предмет в указанную позицию (для разрушения сундуков и т.д.).
--- @param position Vector3 — центральная точка дропа
--- @param itemId string — Id предмета из Config.Items
--- @param amount number
--- @return boolean
function LootManager.dropItemAtPosition(position, itemId, amount)
    local itemConfig = Config.Items[itemId]
    if not itemConfig then
        warn("[LootManager] dropItemAtPosition: unknown item " .. tostring(itemId))
        return false
    end

    local offset = _calcLootOffset(position)
    local finalPosition = position + offset

    _createLootPart(finalPosition, itemId, itemConfig.Name, amount)

    print("[LootManager] Dropped " .. itemConfig.Name .. " x" .. amount .. " at " .. tostring(finalPosition))
    return true
end

-- ═══════════════════════════════════════════════════════════
-- EventBus подписки
-- ═══════════════════════════════════════════════════════════

EventBus.on("EntityDying", function(entity, attacker)
    LootManager.dropLoot(entity)
end)

-- Periodic loot cleanup (every 30 s)
task.spawn(function()
    while true do
        task.wait(30)
        LootManager.cleanup()
    end
end)

return LootManager