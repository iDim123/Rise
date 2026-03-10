local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local BuffManager = require(ServerScriptService:WaitForChild("modules"):WaitForChild("BuffManager"))

return function(ctx, effect, spellConfig)
    local radius = effect.Radius or 10

    print("[AoEBuffEffect] radius =", radius, "buffs count =", #effect.Buffs)

    local targets = { ctx.character }
    for _, other in Players:GetPlayers() do
        if other == ctx.player then continue end
        local otherChar = other.Character
        if not otherChar then continue end
        local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
        if not otherRoot then continue end
        if (otherRoot.Position - ctx.rootPart.Position).Magnitude <= radius then
            table.insert(targets, otherChar)
        end
    end

    print("[AoEBuffEffect] targets found:", #targets)

    for _, target in targets do
        for _, buff in effect.Buffs do
            BuffManager.applyBuff(target, buff.BuffId, buff.Duration, spellConfig.Id)
            print("[AoEBuffEffect] applied", buff.BuffId, "to", target.Name)
        end
    end

    Remotes.SpellEffect:FireAllClients("AoEBuff", ctx.rootPart.Position, {
        Radius = radius,
        School = spellConfig.School,
    })
end