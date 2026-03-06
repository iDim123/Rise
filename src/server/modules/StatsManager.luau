local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local modules = ServerScriptService:WaitForChild("modules")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local StatsManager = {}

local playerStats = {}   -- [player] = { StatId = finalValue }
local lastDamageTime = {} -- [character] = tick()  (для HealthRegen)

-- ══════════════════════════════════
--  Lazy requires (avoid circular)
-- ══════════════════════════════════

local _LevelManager, _InventoryManager, _BloodManager, _BuffManager

local function getLevelManager()
	if not _LevelManager then _LevelManager = require(modules:WaitForChild("LevelManager")) end
	return _LevelManager
end

local function getInventoryManager()
	if not _InventoryManager then _InventoryManager = require(modules:WaitForChild("InventoryManager")) end
	return _InventoryManager
end

local function getBloodManager()
	if not _BloodManager then _BloodManager = require(modules:WaitForChild("BloodManager")) end
	return _BloodManager
end

local function getBuffManager()
	if not _BuffManager then _BuffManager = require(modules:WaitForChild("BuffManager")) end
	return _BuffManager
end

-- ══════════════════════════════════
--  Flat stat IDs (base + flat) * (1 + percent)
--  All others: base * (1 + percent)
-- ══════════════════════════════════

local FLAT_STATS = {
	MaxHP = true,
	PhysicalPower = true,
	MagicalPower = true,
	PhysResistance = true,
	MagicResistance = true,
}

-- ══════════════════════════════════
--  Core: recalculate all stats
-- ══════════════════════════════════

function StatsManager.recalculate(player)
	local character = player.Character
	local statsDef = Config.Stats

	-- Init accumulator
	local acc = {}
	for statId, def in statsDef do
		acc[statId] = { base = def.Base, flat = 0, percent = 0 }
	end

	-- 1) MaxHP base from level system
	acc.MaxHP.base = getLevelManager().getPlayerMaxHP(player)

	-- 2) Equipment bonuses
	local equipment = getInventoryManager().getEquipment(player)
	for _, item in equipment do
		if item and item ~= false and item.Stats then
			for statId, value in item.Stats do
				if acc[statId] then
					if FLAT_STATS[statId] then
						acc[statId].flat += value
					else
						acc[statId].percent += value
					end
				end
			end
		end
	end

	-- 3) Blood bonuses (percent)
	if character then
		local bloodBonuses = getBloodManager().getStatBonuses(character)
		for statId, value in bloodBonuses do
			if acc[statId] then
				acc[statId].percent += value
			end
		end
	end

	-- 4) Buff bonuses (percent)
	if character then
		local buffBonuses = getBuffManager().getAllStatModifiers(character)
		for statId, value in buffBonuses do
			if acc[statId] then
				acc[statId].percent += value
			end
		end
	end

	-- 5) Compute finals
	local final = {}
	for statId, data in acc do
		if FLAT_STATS[statId] then
			final[statId] = (data.base + data.flat) * (1 + data.percent)
		else
			final[statId] = data.base * (1 + data.flat + data.percent)
		end
	end

	playerStats[player] = final

	-- 6) Apply side effects
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16 * (final.MoveSpeed or 1)
		end

		local newMaxHP = math.floor(final.MaxHP or 100)
		local HealthManager = require(modules:WaitForChild("HealthManager"))
		local hpData = HealthManager.getData(character)
		if hpData and hpData.MaxHP ~= newMaxHP then
			HealthManager.setMaxHP(character, newMaxHP)
		end
	end

	-- 7) Send to client
	Remotes.UpdateStats:FireClient(player, final)

	return final
end

-- ══════════════════════════════════
--  Getters
-- ══════════════════════════════════

function StatsManager.get(player, statId)
	local stats = playerStats[player]
	if not stats then
		stats = StatsManager.recalculate(player)
	end
	return stats[statId] or 0
end

function StatsManager.getAll(player)
	return playerStats[player] or StatsManager.recalculate(player)
end

-- ══════════════════════════════════
--  Combat timer (for HealthRegen)
-- ══════════════════════════════════

function StatsManager.markCombat(character)
	lastDamageTime[character] = tick()
end

function StatsManager.isInCombat(character)
	local last = lastDamageTime[character]
	if not last then return false end
	return (tick() - last) < (Config.Stats and Config.Stats.CombatTimeout or 5)
end

-- ══════════════════════════════════
--  HealthRegen tick (вызывается из Main или HealthManager)
-- ══════════════════════════════════

function StatsManager.tickRegen()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end

		local HealthManager = require(modules:WaitForChild("HealthManager"))
		local hpData = HealthManager.getData(character)
		if not hpData or hpData.IsDead then continue end
		if hpData.CurrentHP >= hpData.MaxHP then continue end

		if not StatsManager.isInCombat(character) then
			local regenRate = StatsManager.get(player, "HealthRegen")
			local maxHP = hpData.MaxHP
			-- 1% MaxHP за тик (тик = 10 сек)
			local regenAmount = math.max(1, math.floor(maxHP * 0.01 * regenRate))
			if regenAmount >= 1 then
				HealthManager.heal(character, regenAmount)
			end
		end
	end
end
-- ══════════════════════════════════
--  Cleanup
-- ══════════════════════════════════

function StatsManager.cleanup(player)
	playerStats[player] = nil
	if player.Character then
		lastDamageTime[player.Character] = nil
	end
end

Players.PlayerRemoving:Connect(function(player)
	StatsManager.cleanup(player)
end)

Remotes.GetPlayerStats.OnServerInvoke = function(player)
	return StatsManager.getAll(player)
end

return StatsManager