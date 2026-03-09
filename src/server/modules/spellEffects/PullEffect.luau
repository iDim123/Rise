return function(ctx, effect, spellConfig)
    local ServerScriptService = game:GetService("ServerScriptService")
    local TargetFinder = require(ServerScriptService:WaitForChild("combat"):WaitForChild("TargetFinder"))

    local radius = effect.Radius or 8
    local force = effect.Force or 40
    local duration = effect.Duration or 0.5
    local center = ctx.rootPart.Position

    local targets = TargetFinder.inRadius(center, radius, ctx.character)

    print("[PullEffect] center =", center, "radius =", radius, "force =", force, "targets =", #targets)

    for _, target in targets do
        local targetRoot = target:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local pullDir = (center - targetRoot.Position)
            if pullDir.Magnitude > 1 then
                pullDir = pullDir.Unit
            end
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(force, 0, force) * 1000
            bv.Velocity = pullDir * force
            bv.Parent = targetRoot
            task.delay(duration, function()
                bv:Destroy()
            end)
            print("[PullEffect] pulling", target.Name)
        end
    end
end
