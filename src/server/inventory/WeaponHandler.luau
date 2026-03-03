local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local modules = ReplicatedStorage:WaitForChild("modules")
local InventoryManager = require(modules:WaitForChild("InventoryManager"))

local WeaponHandler = {}

function WeaponHandler.onSetActiveWeapon(player, slotIndex)
    if type(slotIndex) ~= "number" then return end
    slotIndex = math.floor(slotIndex)
    InventoryManager.setActiveWeapon(player, slotIndex)

    local character = player.Character
    if not character then return end

    -- Убираем текущее оружие
    for _, tool in character:GetChildren() do
        if tool:IsA("Tool") then tool:Destroy() end
    end
    for _, tool in player.Backpack:GetChildren() do
        if tool:IsA("Tool") then tool:Destroy() end
    end

    -- Даём новое если есть
    local inv = InventoryManager.getInventory(player)
    if inv and inv.activeWeaponSlot then
        local item = inv.slots[inv.activeWeaponSlot]
        if item and item ~= false and item.Type == Config.ItemTypes.Weapon then
            local weaponsFolder = ServerStorage:FindFirstChild("weapons")
            if weaponsFolder then
                local weaponTemplate = weaponsFolder:FindFirstChild(item.Id)
                if weaponTemplate then
                    local weapon = weaponTemplate:Clone()
                    weapon.Parent = character
                end
            end
        end
    end
end

return WeaponHandler