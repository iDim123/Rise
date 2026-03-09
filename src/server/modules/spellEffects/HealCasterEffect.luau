local ServerScriptService = game:GetService("ServerScriptService")

local modules = ServerScriptService:WaitForChild("modules")
local HealthManager = require(modules:WaitForChild("HealthManager"))

return function(ctx, effect, spellConfig)
    local healAmount = 0

    if effect.HealPercent then
        healAmount = math.floor(ctx.spellPower * effect.HealPercent * 100)
    elseif effect.FlatHeal then
        healAmount = effect.FlatHeal
    end

    if healAmount > 0 then
        HealthManager.heal(ctx.character, healAmount)
        print("[HealCasterEffect] healed", ctx.player.Name, "for", healAmount)
    end
end
