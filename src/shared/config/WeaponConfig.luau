local ReplicatedStorage = game:GetService("ReplicatedStorage")
local configFolder = ReplicatedStorage:WaitForChild("config")
local weaponsFolder = configFolder:WaitForChild("weapons")

local Weapons = {}

-- Автоматически собираем все конфиги из подпапки weapons/
-- Имя оружия = имя модуля без суффикса "Config"
-- SwordConfig → Sword, AxeConfig → Axe, BowConfig → Bow
for _, module in weaponsFolder:GetChildren() do
    if module:IsA("ModuleScript") then
        local weaponName = module.Name:gsub("Config$", "")
        Weapons[weaponName] = require(module)
    end
end

return {
    Weapons = Weapons
}
