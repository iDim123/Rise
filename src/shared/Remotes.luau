local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local remoteNames = {
	"AttackRequest",     -- клиент → сервер: игрок атакует
	"DamageEvent",       -- сервер → клиент: кто-то получил урон
	"EntityDied",        -- сервер → клиент: кто-то умер
}

-- Создаём или находим RemoteEvents
for _, name in remoteNames do
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	Remotes[name] = remote
end

return Remotes