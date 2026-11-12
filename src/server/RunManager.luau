--!strict
-- Tracks an in-progress flight from the character's replicated position and pays
-- coins when it ends. The client can ask to settle early; the distance itself
-- is whatever the server actually saw, clamped to a generous speed cap.

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterUtil = require(script.Parent.CharacterUtil)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)
local WingsService = require(script.Parent.WingsService)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local RunManager = {}

type Run = {
	originX: number,
	startedAt: number,
	maxDistance: number,
	maxAltitude: number,
	settled: boolean,
	reason: string,
	melted: boolean,
	healthGuard: RBXScriptConnection?,
	diedGuard: RBXScriptConnection?,
}

local runs: { [Player]: Run } = {}
local worldSpawn: BasePart? = nil

local function forwardDistance(root: BasePart, originX: number): number
	return math.max(0, root.Position.X - originX)
end

local function rayHitsFeet(rig: CharacterUtil.Rig): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rig.character }
	local length = rig.humanoid.HipHeight + rig.root.Size.Y * 0.5 + 1.6
	local hit = workspace:Raycast(rig.root.Position, Vector3.new(0, -length, 0), params)
	if not hit then
		return false
	end
	local limit = rig.humanoid.HipHeight + rig.root.Size.Y * 0.5 + 0.85
	return hit.Distance <= limit
end

local function pushResult(player: Player, payload: { [string]: any })
	Remotes.event("RunResult"):FireClient(player, payload)
	Remotes.event("StatePush"):FireClient(player, DataService.snapshot(player))
end

local function settle(player: Player, reason: string)
	local run = runs[player]
	if not run or run.settled then
		return
	end
	run.settled = true
	run.reason = reason
	if run.healthGuard then
		run.healthGuard:Disconnect()
		run.healthGuard = nil
	end
	if run.diedGuard then
		run.diedGuard:Disconnect()
		run.diedGuard = nil
	end

	local rig = CharacterUtil.get(player)
	if rig then
		rig.root.Anchored = false
		CharacterUtil.release(rig.humanoid)
		if reason == "melt" then
			WingsService.melt(rig.character)
		end
	end
	player:SetAttribute("InRun", false)
	player:SetAttribute("InCatapult", false)

	local meters = math.floor(run.maxDistance + 0.5)
	local coinsEarned = 0
	if meters >= Config.Economy.MinDistance then
		coinsEarned = math.floor(meters * Config.Economy.CoinsPerMeter)
		DataService.addCoins(player, coinsEarned)
	end
	local isRecord = DataService.setBest(player, meters)
	DataService.save(player)

	local snapshot = DataService.snapshot(player)
	pushResult(player, {
		distance = meters,
		coinsEarned = coinsEarned,
		coins = snapshot.coins,
		bestDistance = snapshot.bestDistance,
		isRecord = isRecord,
		reason = reason,
		maxAltitude = math.floor(run.maxAltitude + 0.5),
	})
	runs[player] = nil
end

function RunManager.isFlying(player: Player): boolean
	local run = runs[player]
	return run ~= nil and not run.settled
end

function RunManager.begin(player: Player, originX: number)
	if RunManager.isFlying(player) then
		return
	end
	local rig = CharacterUtil.get(player)
	local run: Run = {
		originX = originX,
		startedAt = os.clock(),
		maxDistance = 0,
		maxAltitude = 0,
		settled = false,
		reason = "land",
		melted = false,
		healthGuard = nil,
		diedGuard = nil,
	}
	runs[player] = run
	player:SetAttribute("InRun", true)

	if rig then
		run.healthGuard = rig.humanoid.HealthChanged:Connect(function(health)
			-- The fall after a melt should ruin the wings, not the pilot.
			if runs[player] and health < rig.humanoid.MaxHealth and rig.humanoid.Health > 0 then
				rig.humanoid.Health = rig.humanoid.MaxHealth
			end
		end)
		run.diedGuard = rig.humanoid.Died:Connect(function()
			settle(player, if run.melted then "melt" else "died")
		end)
	end
end

function RunManager.noteMelt(player: Player)
	local run = runs[player]
	if not run or run.settled then
		return
	end
	run.melted = true
	run.reason = "melt"
	local rig = CharacterUtil.get(player)
	if rig then
		WingsService.melt(rig.character)
	end
end

function RunManager.clientEnded(player: Player, reason: string)
	local run = runs[player]
	if not run or run.settled then
		return
	end
	if reason == "melt" then
		run.reason = "melt"
		run.melted = true
	elseif reason == "land" or reason == "died" or reason == "timeout" then
		if not run.melted then
			run.reason = reason
		end
	end
	local rig = CharacterUtil.get(player)
	if reason == "died" or not rig then
		settle(player, if run.melted then "melt" else "died")
		return
	end
	local age = os.clock() - run.startedAt
	local distance = forwardDistance(rig.root, run.originX)
	local grounded = rayHitsFeet(rig) or rig.root.Position.Y <= Config.World.SeaLevel + 12
	if age >= Config.Run.MinAirTime and (grounded or distance < Config.Run.FailDistance) then
		settle(player, if run.melted then "melt" else run.reason)
	end
end

function RunManager.returnToPad(player: Player)
	if RunManager.isFlying(player) then
		settle(player, "land")
	end
	local pad = worldSpawn
	local rig = CharacterUtil.get(player)
	if pad and rig then
		CharacterUtil.placeOnPad(rig, pad)
		WingsService.regrow(rig.character)
	end
	player:SetAttribute("InCatapult", false)
	player:SetAttribute("InRun", false)
end

local function stepRun(player: Player, run: Run, dt: number)
	if run.settled then
		return
	end
	local rig = CharacterUtil.get(player)
	local age = os.clock() - run.startedAt
	if not rig then
		if age > 2 then
			settle(player, if run.melted then "melt" else "died")
		end
		return
	end

	local distance = forwardDistance(rig.root, run.originX)
	local allowed = run.maxDistance + Config.AntiCheat.MaxStepSpeed * dt + Config.AntiCheat.Slack
	if distance > allowed then
		distance = allowed
	end
	run.maxDistance = math.max(run.maxDistance, distance)
	local altitude = rig.root.Position.Y - Config.World.SeaLevel
	run.maxAltitude = math.max(run.maxAltitude, altitude)

	if age < Config.Run.MinAirTime then
		return
	end
	if age >= Config.Run.MaxSeconds then
		settle(player, if run.melted then "melt" else "timeout")
		return
	end

	local speed = rig.root.AssemblyLinearVelocity.Magnitude
	local grounded = rayHitsFeet(rig)
	if distance < Config.Run.FailDistance and grounded and speed < 12 then
		-- Still on the cliff. Put them down with no payout.
		run.maxDistance = 0
		settle(player, "land")
		return
	end
	if grounded and distance >= Config.Run.FailDistance and rig.root.AssemblyLinearVelocity.Y < 20 then
		settle(player, if run.melted then "melt" else run.reason)
	end
end

function RunManager.start(spawnPad: BasePart)
	worldSpawn = spawnPad

	Remotes.event("RunEndNotice").OnServerEvent:Connect(function(player, reason: any)
		if typeof(reason) ~= "string" then
			return
		end
		RunManager.clientEnded(player, reason)
	end)
	Remotes.event("Melted").OnServerEvent:Connect(function(player)
		RunManager.noteMelt(player)
	end)
	Remotes.event("ReturnToPad").OnServerEvent:Connect(function(player)
		RunManager.returnToPad(player)
	end)

	RunService.Heartbeat:Connect(function(dt)
		for player, run in runs do
			stepRun(player, run, dt)
		end
	end)

	DataService.beforeLeave(function(player)
		local run = runs[player]
		if run and not run.settled then
			run.settled = true
			if run.healthGuard then
				run.healthGuard:Disconnect()
			end
			if run.diedGuard then
				run.diedGuard:Disconnect()
			end
			local meters = math.floor(run.maxDistance + 0.5)
			if meters >= Config.Economy.MinDistance then
				DataService.addCoins(player, math.floor(meters * Config.Economy.CoinsPerMeter))
				DataService.setBest(player, meters)
			end
		end
		runs[player] = nil
	end)
end

return RunManager
