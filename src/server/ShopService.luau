--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UpgradeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeMath"))
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local ShopService = {}

local function parseId(value: any): UpgradeMath.UpgradeId?
	if
		value == "LaunchPower"
		or value == "Lift"
		or value == "GlideEfficiency"
		or value == "HeatResistance"
	then
		return value
	end
	return nil
end

function ShopService.purchase(player: Player, rawId: any): { [string]: any }
	local id = parseId(rawId)
	if not id then
		return { ok = false, error = "Unknown upgrade" }
	end
	local profile = DataService.get(player)
	if not profile or not profile.ready then
		return { ok = false, error = "Still warming the wax" }
	end

	local def = Config.Upgrades[id]
	local level = profile.data.upgrades[id]
	if level >= def.MaxLevel then
		return { ok = false, error = "Already as strong as the wax allows" }
	end
	local price = UpgradeMath.cost(id, level)
	if not price then
		return { ok = false, error = "Already as strong as the wax allows" }
	end
	if profile.data.coins < price then
		return { ok = false, error = "Need " .. tostring(price) .. " coins" }
	end
	if not DataService.trySpend(player, price) then
		return { ok = false, error = "Need " .. tostring(price) .. " coins" }
	end
	DataService.addLevel(player, id)
	DataService.save(player)
	return {
		ok = true,
		snapshot = DataService.snapshot(player),
	}
end

function ShopService.start()
	Remotes.func("Purchase").OnServerInvoke = function(player, rawId)
		local ok, result = pcall(ShopService.purchase, player, rawId)
		if not ok then
			warn("[ICARUS] Purchase failed:", result)
			return { ok = false, error = "The wingwright is busy" }
		end
		return result
	end

	Remotes.func("GetState").OnServerInvoke = function(player)
		return DataService.snapshot(player)
	end
end

return ShopService
