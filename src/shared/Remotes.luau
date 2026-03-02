local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local remoteNames = {
	"AttackRequest",
	"DamageEvent",
	"EntityDied",
}

if RunService:IsServer() then
	-- Сервер: создаём RemoteEvents
	for _, name in remoteNames do
		local remote = ReplicatedStorage:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = ReplicatedStorage
		end
		Remotes[name] = remote
	end
else
	-- Клиент: ждём пока сервер создаст
	for _, name in remoteNames do
		Remotes[name] = ReplicatedStorage:WaitForChild(name)
	end
end

return Remotes