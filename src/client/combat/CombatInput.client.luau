local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local MeleeInput = require(script.Parent:WaitForChild("MeleeInput"))
local RangedInput = require(script.Parent:WaitForChild("RangedInput"))

local player = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════
-- Определение типа оружия
-- ═══════════════════════════════════════════════════════════

local function getWeaponType()
    local character = player.Character
    if not character then
        return nil
    end

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then
        return nil
    end

    local cfg = Config.Weapons[tool.Name]
    if not cfg then
        return nil
    end

    return cfg.Type or "Melee"
end

-- ═══════════════════════════════════════════════════════════
-- Ввод
-- ═══════════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local wType = getWeaponType()
        if not wType then
            return
        end

        if wType == "Ranged" then
            RangedInput.start()
        else
            MeleeInput.start()
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        MeleeInput.stop()
        RangedInput.stop()
    end
end)
