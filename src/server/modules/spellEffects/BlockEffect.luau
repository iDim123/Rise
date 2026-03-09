local ServerScriptService = game:GetService("ServerScriptService")

local modules = ServerScriptService:WaitForChild("modules")
local StatsManager = require(modules:WaitForChild("StatsManager"))

return function(ctx, effect, spellConfig)
    local character = ctx.character

    print("[BlockEffect] starting block, duration =", effect.Duration, "melee =", effect.BlockMelee, "proj =",
        effect.BlockProjectile)

    character:SetAttribute("Blocking", true)
    character:SetAttribute("BlockMelee", effect.BlockMelee or false)
    character:SetAttribute("BlockProjectile", effect.BlockProjectile or false)
    character:SetAttribute("BlockSpellId", spellConfig.Id)

    -- Slow during block
    if effect.MovementMode == "Slowed" then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = humanoid.WalkSpeed * (effect.SpeedMult or 0.5)
            print("[BlockEffect] slowed to", humanoid.WalkSpeed)
        end
    end

    -- Listen for block trigger
    local triggered = false
    local blockConn
    blockConn = character:GetAttributeChangedSignal("BlockTriggered"):Connect(function()
        if character:GetAttribute("BlockTriggered") and not triggered then
            triggered = true
            character:SetAttribute("BlockTriggered", false)
            print("[BlockEffect] BLOCK TRIGGERED! executing", effect.OnBlockTriggered and #effect.OnBlockTriggered or 0,
                "sub-effects")

            if effect.OnBlockTriggered then
                -- Dynamically load sub-effect handlers
                local effectsFolder = modules:WaitForChild("spellEffects")
                for _, subEffect in effect.OnBlockTriggered do
                    local subModule = effectsFolder:FindFirstChild(subEffect.Type .. "Effect")
                    if subModule then
                        local handler = require(subModule)
                        handler(ctx, subEffect, spellConfig)
                        print("[BlockEffect] executed sub-effect:", subEffect.Type)
                    else
                        warn("[BlockEffect] unknown sub-effect:", subEffect.Type)
                    end
                end
            end
        end
    end)

    task.delay(effect.Duration or 1.5, function()
        print("[BlockEffect] block expired, triggered =", triggered)
        character:SetAttribute("Blocking", false)
        character:SetAttribute("BlockMelee", false)
        character:SetAttribute("BlockProjectile", false)
        character:SetAttribute("BlockSpellId", nil)
        StatsManager.recalculate(ctx.player)
        if blockConn then
            blockConn:Disconnect()
        end
    end)
end
