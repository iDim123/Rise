local ReplicatedStorage = game:GetService("ReplicatedStorage")
local configFolder = ReplicatedStorage:WaitForChild("config")
local itemsFolder = configFolder:WaitForChild("items")

local Items = {}

-- Собираем все предметы из подмодулей
for _, module in itemsFolder:GetChildren() do
    if module:IsA("ModuleScript") then
        local data = require(module)
        for id, item in data do
            item.Id = id
            Items[id] = item
        end
    end
end

local ItemTypes = {
    Weapon = "Weapon",
    HeadArmor = "Head",
    ChestArmor = "Chest",
    LegsArmor = "Legs",
    FeetArmor = "Feet",
    HandsArmor = "Hands",
    Amulet = "Amulet",
    Ring = "Ring",
    Consumable = "Consumable",
    Misc = "Misc",
    Resource = "Resource",
    Cloak = "Cloak",
    Bag = "Bag"
}

return {
    Items = Items,
    ItemTypes = ItemTypes
}
