--!strict

local Players = game:GetService("Players")
local DataService = require(script.Parent.DataService)

local Leaderstats = {}

local function ensure(player: Player)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "leaderstats"
		created.Parent = player
		folder = created
	end

	local coins = folder:FindFirstChild("Coins")
	if not coins then
		local value = Instance.new("IntValue")
		value.Name = "Coins"
		value.Parent = folder
		coins = value
	end

	local best = folder:FindFirstChild("Best Distance")
	if not best then
		local value = Instance.new("IntValue")
		value.Name = "Best Distance"
		value.Parent = folder
		best = value
	end

	return coins :: IntValue, best :: IntValue
end

local function refresh(player: Player)
	local coins, best = ensure(player)
	local profile = DataService.get(player)
	if not profile then
		coins.Value = 0
		best.Value = 0
		return
	end
	coins.Value = profile.data.coins
	best.Value = profile.data.bestDistance
end

function Leaderstats.start()
	DataService.onChanged(refresh)
	for _, player in Players:GetPlayers() do
		refresh(player)
	end
end

return Leaderstats
