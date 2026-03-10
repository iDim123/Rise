local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local ServantManager = require(modules:WaitForChild("servant"):WaitForChild("ServantManager"))
local HealthManager = require(modules:WaitForChild("HealthManager"))

local captureCooldowns = {}

Remotes.CaptureRequest.OnServerEvent:Connect(function(player, action)
    if action == "start" then
        local character = player.Character
        if not character then return end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end

        local enemiesFolder = workspace:FindFirstChild("Enemies")
        if not enemiesFolder then
            Remotes.CaptureResult:FireClient(player, false, "No enemies")
            return
        end

        local bestEnemy = nil
        local bestDistance = Config.Servants.CaptureRange + 1

        for _, enemy in enemiesFolder:GetChildren() do
            if enemy:GetAttribute("IsServant") then continue end

            local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
            if not enemyRoot then continue end

            local currentHP = enemy:GetAttribute("CurrentHP")
            local maxHP = enemy:GetAttribute("MaxHP")
            if not currentHP or not maxHP or maxHP == 0 then continue end

            if currentHP / maxHP <= Config.Servants.CaptureThreshold then
                local dist = (enemyRoot.Position - rootPart.Position).Magnitude
                if dist < bestDistance then
                    bestDistance = dist
                    bestEnemy = enemy
                end
            end
        end

        if not bestEnemy then
            Remotes.CaptureResult:FireClient(player, false, "No valid target")
            return
        end

        local enemyRoot = bestEnemy:FindFirstChild("HumanoidRootPart")
        local dirToEnemy = (enemyRoot.Position - rootPart.Position).Unit
        local lookDir = rootPart.CFrame.LookVector
        local dot = Vector3.new(dirToEnemy.X, 0, dirToEnemy.Z).Unit:Dot(Vector3.new(lookDir.X, 0, lookDir.Z).Unit)

        if dot < 0.5 then
            Remotes.CaptureResult:FireClient(player, false, "Not looking at target")
            return
        end

        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then humanoid.WalkSpeed = 0 end

        captureCooldowns[player.UserId] = {
            enemy = bestEnemy,
            startTime = os.clock(),
            cancelled = false,
        }

        Remotes.CaptureResult:FireClient(player, true, "casting")

        task.spawn(function()
            local castData = captureCooldowns[player.UserId]
            if not castData then return end

            task.wait(Config.Servants.CaptureTime)

            castData = captureCooldowns[player.UserId]
            if not castData or castData.cancelled then
                captureCooldowns[player.UserId] = nil
                return
            end

            local char = player.Character
            if not char then
                captureCooldowns[player.UserId] = nil
                return
            end
            local hum = char:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then
                captureCooldowns[player.UserId] = nil
                return
            end

            local enemy = castData.enemy
            if not enemy or not enemy.Parent then
                Remotes.CaptureResult:FireClient(player, false, "Target lost")
                captureCooldowns[player.UserId] = nil
                if hum then hum.WalkSpeed = 16 end
                return
            end

            local success, result = ServantManager.captureEnemy(player, enemy)

            if hum then hum.WalkSpeed = 16 end

            Remotes.CaptureResult:FireClient(player, success, success and "captured" or result)
            captureCooldowns[player.UserId] = nil
        end)

    elseif action == "cancel" then
        local castData = captureCooldowns[player.UserId]
        if castData then
            castData.cancelled = true
            captureCooldowns[player.UserId] = nil

            local character = player.Character
            if character then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid then humanoid.WalkSpeed = 16 end
            end

            Remotes.CaptureResult:FireClient(player, false, "cancelled")
        end
    end
end)

Remotes.GetServants.OnServerInvoke = function(player)
    local data = ServantManager.getData(player)
    if not data then return { captured = {}, activeId = nil } end
    return { captured = data.captured, activeId = data.activeId }
end

Remotes.SummonServant.OnServerEvent:Connect(function(player, servantId)
    if type(servantId) ~= "string" then return end
    ServantManager.summon(player, servantId)
end)

Remotes.DismissServant.OnServerEvent:Connect(function(player)
    ServantManager.dismiss(player)
end)

Remotes.SetServantMode.OnServerEvent:Connect(function(player, mode)
    if type(mode) ~= "string" then return end
    local isValid = false
    for _, v in Config.Servants.Modes do
        if v == mode then isValid = true break end
    end
    if not isValid then return end
    ServantManager.setMode(player, mode)
end)

Remotes.ServantCommand.OnServerEvent:Connect(function(player, command)
    if type(command) ~= "string" then return end
    ServantManager.setCommand(player, command)
end)

Remotes.RenameServant.OnServerEvent:Connect(function(player, servantId, newName)
    if type(servantId) ~= "string" or type(newName) ~= "string" then return end
    ServantManager.renameServant(player, servantId, newName)
end)


-- === Equip/Unequip servant items ===

local InventoryManager = require(modules:WaitForChild("InventoryManager"))
local InventorySync = require(modules:WaitForChild("InventorySync"))

Remotes.EquipServantItem.OnServerEvent:Connect(function(player, servantId, inventorySlotIndex, equipSlotId)
    if type(servantId) ~= "string" then return end
    if type(inventorySlotIndex) ~= "number" then return end
    if type(equipSlotId) ~= "string" then return end

    local slots = InventoryManager.getSlots(player)
    if not slots then return end

    local itemData = slots[inventorySlotIndex]
    if not itemData or itemData == false then return end

    -- Проверяем совместимость типа предмета со слотом
    local itemType = itemData.Type
    local slotAcceptsType = false

    if equipSlotId == "Head" and itemType == "Head" then slotAcceptsType = true
    elseif equipSlotId == "Chest" and itemType == "Chest" then slotAcceptsType = true
    elseif equipSlotId == "Legs" and itemType == "Legs" then slotAcceptsType = true
    elseif equipSlotId == "Feet" and itemType == "Feet" then slotAcceptsType = true
    elseif equipSlotId == "Hands" and itemType == "Hands" then slotAcceptsType = true
    elseif equipSlotId == "Amulet" and itemType == "Amulet" then slotAcceptsType = true
    elseif (equipSlotId == "Ring1" or equipSlotId == "Ring2") and itemType == "Ring" then slotAcceptsType = true
    elseif itemType == "Weapon" then slotAcceptsType = false -- оружие нельзя надеть на слугу
    end

    if not slotAcceptsType then return end

    local success, previousItem = ServantManager.equipItem(player, servantId, equipSlotId, itemData)
    if not success then return end

    -- Убираем предмет из инвентаря
    InventoryManager.removeItem(player, inventorySlotIndex)

    -- Если был предмет в слоте — возвращаем в инвентарь
    if previousItem then
        InventoryManager.addItem(player, previousItem)
    end

    InventorySync.sendFullUpdate(player)
end)

Remotes.UnequipServantItem.OnServerEvent:Connect(function(player, servantId, equipSlotId)
    if type(servantId) ~= "string" then return end
    if type(equipSlotId) ~= "string" then return end

    local success, item = ServantManager.unequipItem(player, servantId, equipSlotId)
    if not success or not item then return end

    local added = InventoryManager.addItem(player, item)
    if not added then
        -- Инвентарь полон — вернём предмет обратно на слугу
        ServantManager.equipItem(player, servantId, equipSlotId, item)
        return
    end

    InventorySync.sendFullUpdate(player)
end)

Remotes.ToggleServantFavorite.OnServerEvent:Connect(function(player, servantId)
    if type(servantId) ~= "string" then return end
    ServantManager.toggleFavorite(player, servantId)
end)
