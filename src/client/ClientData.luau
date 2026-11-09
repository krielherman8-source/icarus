--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeMath"))

local ClientData = {}

export type Snapshot = {
	coins: number,
	bestDistance: number,
	upgrades: UpgradeMath.UpgradeLevels,
	sessionOnly: boolean,
	ready: boolean,
}

local current: Snapshot = {
	coins = 0,
	bestDistance = 0,
	upgrades = UpgradeMath.blankLevels(),
	sessionOnly = false,
	ready = false,
}

local listeners: { (Snapshot) -> () } = {}

local function emit()
	for _, listener in listeners do
		listener(current)
	end
end

function ClientData.current(): Snapshot
	return current
end

function ClientData.onChanged(listener: (Snapshot) -> ())
	table.insert(listeners, listener)
	listener(current)
end

function ClientData.apply(snapshot: any)
	if typeof(snapshot) ~= "table" then
		return
	end
	if typeof(snapshot.coins) == "number" then
		current.coins = snapshot.coins
	end
	if typeof(snapshot.bestDistance) == "number" then
		current.bestDistance = snapshot.bestDistance
	end
	if typeof(snapshot.sessionOnly) == "boolean" then
		current.sessionOnly = snapshot.sessionOnly
	end
	if typeof(snapshot.ready) == "boolean" then
		current.ready = snapshot.ready
	end
	if typeof(snapshot.upgrades) == "table" then
		local levels = UpgradeMath.blankLevels()
		for id, value in snapshot.upgrades do
			if
				(id == "LaunchPower" or id == "Lift" or id == "GlideEfficiency" or id == "HeatResistance")
				and typeof(value) == "number"
			then
				levels[id] = value
			end
		end
		current.upgrades = levels
	end
	emit()
end

local function pullAttributes(player: Player)
	ClientData.apply({
		coins = player:GetAttribute("Coins"),
		bestDistance = player:GetAttribute("BestDistance"),
		sessionOnly = player:GetAttribute("SessionOnly"),
		ready = player:GetAttribute("DataReady"),
		upgrades = {
			LaunchPower = player:GetAttribute("Upgrade_LaunchPower"),
			Lift = player:GetAttribute("Upgrade_Lift"),
			GlideEfficiency = player:GetAttribute("Upgrade_GlideEfficiency"),
			HeatResistance = player:GetAttribute("Upgrade_HeatResistance"),
		},
	})
end

function ClientData.start()
	local player = Players.LocalPlayer
	local names = {
		"Coins",
		"BestDistance",
		"SessionOnly",
		"DataReady",
		"Upgrade_LaunchPower",
		"Upgrade_Lift",
		"Upgrade_GlideEfficiency",
		"Upgrade_HeatResistance",
	}
	for _, name in names do
		player:GetAttributeChangedSignal(name):Connect(function()
			pullAttributes(player)
		end)
	end
	pullAttributes(player)
end

return ClientData
