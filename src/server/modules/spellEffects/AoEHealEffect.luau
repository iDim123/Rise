local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local HealthManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("HealthManager"))

return function(ctx, effect, spellConfig)
    local radius = effect.Radius or 10
    local healAmount = math.floor(ctx.spellPower * (effect.HealPercent or 0.5) * 100)

    print("[AoEHealEffect] radius =", radius, "healAmount =", healAmount, "spellPower =", ctx.spellPower)

    -- Heal self
    HealthManager.heal(ctx.character, healAmount)
    print("[AoEHealEffect] healed self:", ctx.player.Name, "for", healAmount)

    -- Heal nearby players
    local healed = 1
    for _, other in Players:GetPlayers() do
        if other == ctx.player then continue end
        local otherChar = other.Character
        if not otherChar then continue end
        local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
        if not otherRoot then continue end
        if (otherRoot.Position - ctx.rootPart.Position).Magnitude <= radius then
            HealthManager.heal(otherChar, healAmount)
            healed = healed + 1
            print("[AoEHealEffect] healed ally:", other.Name)
        end
    end

    print("[AoEHealEffect] total healed:", healed)
    Remotes.SpellEffect:FireAllClients("AoEHeal", ctx.rootPart.Position, { Radius = radius })
end