local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local modules = ReplicatedStorage:WaitForChild("modules")
local ServantManager = require(modules:WaitForChild("ServantManager"))
local HealthManager = require(modules:WaitForChild("HealthManager"))

-- Remote Events / Functions
local captureRequest = Instance.new("RemoteEvent")
captureRequest.Name = "CaptureRequest"
captureRequest.Parent = ReplicatedStorage

local captureResult = Instance.new("RemoteEvent")
captureResult.Name = "CaptureResult"
captureResult.Parent = ReplicatedStorage

local getServants = Instance.new("RemoteFunction")
getServants.Name = "GetServants"
getServants.Parent = ReplicatedStorage

local summonServant = Instance.new("RemoteEvent")
summonServant.Name = "SummonServant"
summonServant.Parent = ReplicatedStorage

local dismissServant = Instance.new("RemoteEvent")
dismissServant.Name = "DismissServant"
dismissServant.Parent = ReplicatedStorage

local setServantMode = Instance.new("RemoteEvent")
setServantMode.Name = "SetServantMode"
setServantMode.Parent = ReplicatedStorage

local servantCommand = Instance.new("RemoteEvent")
servantCommand.Name = "ServantCommand"
servantCommand.Parent = ReplicatedStorage

local renameServant = Instance.new("RemoteEvent")
renameServant.Name = "RenameServant"
renameServant.Parent = ReplicatedStorage

-- Захват: клиент запрашивает начало каста
local captureCooldowns = {}

captureRequest.OnServerEvent:Connect(function(player, action)
    if action == "start" then
        local character = player.Character
        if not character then return end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end

        -- Находим ближайшего врага с <30% HP
        local enemiesFolder = workspace:FindFirstChild("Enemies")
        if not enemiesFolder then
            captureResult:FireClient(player, false, "No enemies")
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
            captureResult:FireClient(player, false, "No valid target")
            return
        end

        -- Проверка направления взгляда
        local enemyRoot = bestEnemy:FindFirstChild("HumanoidRootPart")
        local dirToEnemy = (enemyRoot.Position - rootPart.Position).Unit
        local lookDir = rootPart.CFrame.LookVector
        local dot = Vector3.new(dirToEnemy.X, 0, dirToEnemy.Z).Unit:Dot(Vector3.new(lookDir.X, 0, lookDir.Z).Unit)

        if dot < 0.5 then
            captureResult:FireClient(player, false, "Not looking at target")
            return
        end

        -- Блокируем движение
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 0
        end

        -- Сохраняем данные каста
        captureCooldowns[player.UserId] = {
            enemy = bestEnemy,
            startTime = tick(),
            cancelled = false,
        }

        captureResult:FireClient(player, true, "casting")

        -- Ждём 3 секунды
        task.spawn(function()
            local castData = captureCooldowns[player.UserId]
            if not castData then return end

            task.wait(Config.Servants.CaptureTime)

            -- Проверяем что каст не отменён
            castData = captureCooldowns[player.UserId]
            if not castData or castData.cancelled then
                captureCooldowns[player.UserId] = nil
                return
            end

            -- Проверяем что игрок жив
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

            -- Проверяем что враг ещё существует
            local enemy = castData.enemy
            if not enemy or not enemy.Parent then
                captureResult:FireClient(player, false, "Target lost")
                captureCooldowns[player.UserId] = nil
                if hum then hum.WalkSpeed = 16 end
                return
            end

            -- Захватываем
            local success, result = ServantManager.captureEnemy(player, enemy)

            -- Восстанавливаем скорость
            if hum then hum.WalkSpeed = 16 end

            captureResult:FireClient(player, success, success and "captured" or result)
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

            captureResult:FireClient(player, false, "cancelled")
        end
    end
end)

-- Получить список слуг
getServants.OnServerInvoke = function(player)
    local data = ServantManager.getData(player)
    if not data then return { captured = {}, activeId = nil } end
    return { captured = data.captured, activeId = data.activeId }
end

-- Призвать слугу
summonServant.OnServerEvent:Connect(function(player, servantId)
    if type(servantId) ~= "string" then return end
    ServantManager.summon(player, servantId)
end)

-- Отозвать слугу
dismissServant.OnServerEvent:Connect(function(player)
    ServantManager.dismiss(player)
end)

-- Сменить режим
setServantMode.OnServerEvent:Connect(function(player, mode)
    if type(mode) ~= "string" then return end
    local validModes = Config.Servants.Modes
    local isValid = false
    for _, v in validModes do
        if v == mode then isValid = true break end
    end
    if not isValid then return end
    ServantManager.setMode(player, mode)
end)

-- Команда слуге
servantCommand.OnServerEvent:Connect(function(player, command)
    if type(command) ~= "string" then return end
    ServantManager.setCommand(player, command)
end)

-- Переименовать слугу
renameServant.OnServerEvent:Connect(function(player, servantId, newName)
    if type(servantId) ~= "string" or type(newName) ~= "string" then return end
    ServantManager.renameServant(player, servantId, newName)
end)

-- Инициализация
Players.PlayerAdded:Connect(function(player)
    ServantManager.init(player)

    player.CharacterAdded:Connect(function()
        -- Не пересоздаём данные, только отзываем активного слугу
        ServantManager.dismiss(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    ServantManager.remove(player)
end)