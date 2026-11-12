--!strict
-- Server-owned coins and upgrade levels. DataStores are tried with backoff;
-- Studio with API access off keeps the session in memory and says so.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UpgradeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeMath"))

local DataService = {}

export type ProfileData = {
	version: number,
	coins: number,
	bestDistance: number,
	upgrades: UpgradeMath.UpgradeLevels,
}

export type Profile = {
	data: ProfileData,
	ready: boolean,
	sessionOnly: boolean,
	dirty: boolean,
}

export type Snapshot = {
	coins: number,
	bestDistance: number,
	upgrades: UpgradeMath.UpgradeLevels,
	sessionOnly: boolean,
	ready: boolean,
}

local profiles: { [Player]: Profile } = {}
local listeners: { (Player) -> () } = {}
local leavingHooks: { (Player) -> () } = {}
local saving: { [Player]: boolean } = {}
local queued: { [Player]: ProfileData? } = {}
local store: DataStore? = nil
local warnedStudio = false

local function blankData(): ProfileData
	return {
		version = 1,
		coins = 0,
		bestDistance = 0,
		upgrades = UpgradeMath.blankLevels(),
	}
end

local function copyData(data: ProfileData): ProfileData
	local upgrades = UpgradeMath.blankLevels()
	for _, id in Config.UpgradeOrder do
		upgrades[id] = data.upgrades[id]
	end
	return {
		version = 1,
		coins = data.coins,
		bestDistance = data.bestDistance,
		upgrades = upgrades,
	}
end

local function finiteInt(value: any, default: number, maxValue: number): number
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return math.clamp(math.floor(value + 0.5), 0, maxValue)
end

local function reconcile(raw: any): ProfileData
	local data = blankData()
	if type(raw) ~= "table" then
		return data
	end
	data.coins = finiteInt(raw.coins, 0, 1_000_000_000)
	data.bestDistance = finiteInt(raw.bestDistance, 0, 10_000_000)
	local savedUpgrades = raw.upgrades
	if type(savedUpgrades) == "table" then
		for _, id in Config.UpgradeOrder do
			local def = Config.Upgrades[id]
			data.upgrades[id] = finiteInt(savedUpgrades[id], 0, def.MaxLevel)
		end
	end
	return data
end

local function keyFor(player: Player): string
	return "p_" .. tostring(player.UserId)
end

local function isPermanentStoreError(err: any): boolean
	local text = string.lower(tostring(err))
	return string.find(text, "studio access", 1, true) ~= nil
		or string.find(text, "api access", 1, true) ~= nil
		or string.find(text, "403", 1, true) ~= nil
		or string.find(text, "must publish", 1, true) ~= nil
		or string.find(text, "not enabled", 1, true) ~= nil
end

local function warnStudioOnce(err: any)
	if warnedStudio then
		return
	end
	warnedStudio = true
	if RunService:IsStudio() then
		warn(
			"[ICARUS] DataStore unavailable (",
			tostring(err),
			"). Enable Game Settings → Security → Enable Studio Access to API Services to persist progress. This session keeps coins in memory only."
		)
	else
		warn("[ICARUS] DataStore unavailable:", err)
	end
end

local function publishAttributes(player: Player, profile: Profile)
	player:SetAttribute("Coins", profile.data.coins)
	player:SetAttribute("BestDistance", profile.data.bestDistance)
	player:SetAttribute("DataReady", profile.ready)
	player:SetAttribute("SessionOnly", profile.sessionOnly)
	for _, id in Config.UpgradeOrder do
		player:SetAttribute("Upgrade_" .. id, profile.data.upgrades[id])
	end
end

local function emit(player: Player)
	local profile = profiles[player]
	if profile then
		publishAttributes(player, profile)
	end
	for _, listener in listeners do
		listener(player)
	end
end

function DataService.onChanged(listener: (Player) -> ())
	table.insert(listeners, listener)
end

-- Runs before the leaving save, so a flight in progress can still pay out.
function DataService.beforeLeave(hook: (Player) -> ())
	table.insert(leavingHooks, hook)
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.snapshot(player: Player): Snapshot
	local profile = profiles[player]
	if not profile then
		local empty = blankData()
		return {
			coins = 0,
			bestDistance = 0,
			upgrades = empty.upgrades,
			sessionOnly = true,
			ready = false,
		}
	end
	return {
		coins = profile.data.coins,
		bestDistance = profile.data.bestDistance,
		upgrades = copyData(profile.data).upgrades,
		sessionOnly = profile.sessionOnly,
		ready = profile.ready,
	}
end

local function tryUpdate(key: string, payload: ProfileData): (boolean, any)
	local dataStore = store
	if not dataStore then
		return false, "no datastore"
	end
	return pcall(function()
		dataStore:UpdateAsync(key, function(_old)
			return copyData(payload)
		end)
	end)
end

local function pumpSave(player: Player)
	if saving[player] then
		return
	end
	saving[player] = true
	task.spawn(function()
		while player.Parent ~= nil do
			local payload = queued[player]
			queued[player] = nil
			if not payload then
				break
			end
			local profile = profiles[player]
			if not profile or profile.sessionOnly then
				break
			end
			local key = keyFor(player)
			local saved = false
			for attempt = 1, Config.Data.Retries do
				local ok, err = tryUpdate(key, payload)
				if ok then
					saved = true
					break
				end
				if isPermanentStoreError(err) then
					profile.sessionOnly = true
					warnStudioOnce(err)
					emit(player)
					saved = true
					break
				end
				task.wait(2 ^ (attempt - 1))
			end
			if not saved and queued[player] == nil then
				queued[player] = payload
				warn("[ICARUS] Could not save data for", player.UserId)
				break
			end
		end
		saving[player] = false
	end)
end

function DataService.save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.ready or profile.sessionOnly then
		return
	end
	queued[player] = copyData(profile.data)
	pumpSave(player)
end

local function saveBlocking(player: Player)
	local profile = profiles[player]
	if not profile or not profile.ready or profile.sessionOnly then
		return
	end
	local payload = copyData(profile.data)
	local key = keyFor(player)
	for attempt = 1, Config.Data.Retries do
		local ok, err = tryUpdate(key, payload)
		if ok or isPermanentStoreError(err) then
			return
		end
		task.wait(0.4 * attempt)
	end
end

local function loadAsync(player: Player)
	local key = keyFor(player)
	local loaded: ProfileData? = nil
	local sessionOnly = false
	local dataStore = store
	if not dataStore then
		sessionOnly = true
	else
		for attempt = 1, Config.Data.Retries do
			local ok, result = pcall(function()
				return dataStore:GetAsync(key)
			end)
			if ok then
				loaded = reconcile(result)
				break
			end
			if isPermanentStoreError(result) then
				sessionOnly = true
				warnStudioOnce(result)
				break
			end
			if attempt == Config.Data.Retries then
				sessionOnly = true
				warn("[ICARUS] Giving up on load for", player.UserId, result)
				break
			end
			task.wait(2 ^ (attempt - 1))
		end
	end

	local profile = profiles[player]
	if not profile then
		return
	end

	if sessionOnly then
		profile.sessionOnly = true
		profile.ready = true
		emit(player)
		return
	end

	local fresh = loaded or blankData()
	if profile.dirty then
		profile.data.coins = math.max(profile.data.coins, fresh.coins)
		profile.data.bestDistance = math.max(profile.data.bestDistance, fresh.bestDistance)
		for _, id in Config.UpgradeOrder do
			profile.data.upgrades[id] = math.max(profile.data.upgrades[id], fresh.upgrades[id])
		end
		profile.ready = true
		profile.sessionOnly = false
		emit(player)
		DataService.save(player)
	else
		profile.data = fresh
		profile.ready = true
		profile.sessionOnly = false
		emit(player)
	end
end

function DataService.addCoins(player: Player, amount: number): number
	local profile = profiles[player]
	if not profile or amount <= 0 then
		return if profile then profile.data.coins else 0
	end
	profile.data.coins += math.floor(amount)
	profile.dirty = true
	emit(player)
	return profile.data.coins
end

function DataService.setBest(player: Player, distance: number): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local meters = math.max(0, math.floor(distance + 0.5))
	if meters <= profile.data.bestDistance then
		return false
	end
	profile.data.bestDistance = meters
	profile.dirty = true
	emit(player)
	return true
end

function DataService.trySpend(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or not profile.ready then
		return false
	end
	if profile.data.coins < amount then
		return false
	end
	profile.data.coins -= amount
	profile.dirty = true
	emit(player)
	return true
end

function DataService.addLevel(player: Player, id: UpgradeMath.UpgradeId): number?
	local profile = profiles[player]
	local def = Config.Upgrades[id]
	if not profile or not def then
		return nil
	end
	local nextLevel = profile.data.upgrades[id] + 1
	if nextLevel > def.MaxLevel then
		return nil
	end
	profile.data.upgrades[id] = nextLevel
	profile.dirty = true
	emit(player)
	return nextLevel
end

local function onPlayer(player: Player)
	profiles[player] = {
		data = blankData(),
		ready = false,
		sessionOnly = false,
		dirty = false,
	}
	emit(player)
	task.spawn(loadAsync, player)
end

function DataService.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
	else
		warnStudioOnce(result)
	end

	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		for _, hook in leavingHooks do
			hook(player)
		end
		saveBlocking(player)
		profiles[player] = nil
		queued[player] = nil
		saving[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for _, player in Players:GetPlayers() do
				DataService.save(player)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			saveBlocking(player)
		end
	end)
end

return DataService
