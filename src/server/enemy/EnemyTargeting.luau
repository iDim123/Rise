local Players = game:GetService("Players")

local EnemyStateManager = require(script.Parent:WaitForChild("EnemyStateManager"))
local STATE = EnemyStateManager.STATE

local EnemyTargeting = {}

function EnemyTargeting.findNearestPlayer(position, range)
    local nearest = nil
    local nearestDist = range

    for _, player in Players:GetPlayers() do
        local character = player.Character
        if not character then continue end
        if character:GetAttribute("IsDead") then continue end  -- главная проверка

        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then continue end

        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local dist = (rootPart.Position - position).Magnitude
        if dist < nearestDist then
            nearest = character
            nearestDist = dist
        end
    end

    return nearest, nearestDist
end

function EnemyTargeting.alertPack(enemy, target, config)
	local packRadius = config.PackRadius
	if not packRadius then return end

	local rootPart = enemy:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local enemyType = enemy:GetAttribute("EnemyType")
	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if not enemiesFolder then return end

	for _, other in enemiesFolder:GetChildren() do
		if other == enemy then continue end
		if other:GetAttribute("EnemyType") ~= enemyType then continue end

		local otherRoot = other:FindFirstChild("HumanoidRootPart")
		if not otherRoot then continue end

		local otherHumanoid = other:FindFirstChild("Humanoid")
		if not otherHumanoid or otherHumanoid.Health <= 0 then continue end

		local dist = (otherRoot.Position - rootPart.Position).Magnitude
		if dist <= packRadius then
			local otherState = EnemyStateManager.get(other)
			if otherState.State == STATE.IDLE or otherState.State == STATE.PATROL or otherState.State == STATE.RETURN then
				otherState.AggroTarget = target
				otherState.State = STATE.CHASE
			end
		end
	end
end

return EnemyTargeting