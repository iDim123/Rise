local EnemyStateManager = {}

local STATE = {
	IDLE = "Idle",
	PATROL = "Patrol",
	CHASE = "Chase",
	ATTACK = "Attack",
	RETURN = "Return",
}

EnemyStateManager.STATE = STATE

local enemyStates = {}

function EnemyStateManager.get(enemy)
	if not enemyStates[enemy] then
		enemyStates[enemy] = {
			State = STATE.IDLE,
			PatrolTarget = nil,
			IdleTimer = 0,
			LastAttack = 0,
			AggroTarget = nil,
			LastHP = nil,
		}
	end
	return enemyStates[enemy]
end

function EnemyStateManager.remove(enemy)
	enemyStates[enemy] = nil
end

function EnemyStateManager.checkTookDamage(enemy, state)
	local humanoid = enemy:FindFirstChild("Humanoid")
	if not humanoid then return false end

	local currentHP = humanoid.Health
	local tookDamage = false

	if state.LastHP and currentHP < state.LastHP then
		tookDamage = true
	end

	state.LastHP = currentHP
	return tookDamage
end

function EnemyStateManager.getRandomPatrolPoint(spawnPos, radius)
	local angle = math.random() * math.pi * 2
	local dist = math.random() * radius
	return Vector3.new(
		spawnPos.X + math.cos(angle) * dist,
		spawnPos.Y,
		spawnPos.Z + math.sin(angle) * dist
	)
end

return EnemyStateManager