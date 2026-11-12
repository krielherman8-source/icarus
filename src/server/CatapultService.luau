--!strict
-- One slingshot. The server owns the pull and the launch impulse; the client
-- only reports whether the player is still holding.

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterUtil = require(script.Parent.CharacterUtil)
local DataService = require(script.Parent.DataService)
local RunManager = require(script.Parent.RunManager)
local Remotes = require(script.Parent.Remotes)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local FlightModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FlightModel"))
local UpgradeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeMath"))

local CatapultService = {}

type Seat = {
	player: Player,
	charge: number,
	holding: boolean,
	lastHold: number,
}

local world: WorldBuilder.World? = nil
local restCFrame: CFrame = CFrame.identity
local occupant: Seat? = nil

local function seatOf(player: Player): Seat?
	local seat = occupant
	if seat and seat.player == player then
		return seat
	end
	return nil
end

local function pouchCFrame(charge: number): CFrame
	local pull = Config.Catapult.MaxPullStuds * math.clamp(charge, 0, 1)
	return restCFrame * CFrame.new(-pull, -0.18 * pull, 0)
end

local function applyCharge(seat: Seat)
	local built = world
	if not built then
		return
	end
	local cf = pouchCFrame(seat.charge)
	built.pouch.CFrame = cf
	for _, child in built.pouch:GetChildren() do
		if child:IsA("Beam") then
			child.Width0 = 0.22 + seat.charge * 0.2
			child.Width1 = 0.14 + seat.charge * 0.1
		end
	end

	local rig = CharacterUtil.get(seat.player)
	if not rig then
		return
	end
	-- Hip height, plus a little air so a pitched launch does not catch the deck.
	local stand = cf.Position + Vector3.new(0, 4.4, 0)
	rig.root.Anchored = true
	rig.root.AssemblyLinearVelocity = Vector3.zero
	rig.root.AssemblyAngularVelocity = Vector3.zero
	rig.root.CFrame = CFrame.lookAt(stand, stand + Vector3.xAxis)
end

local function setPromptEnabled(enabled: boolean)
	local built = world
	if not built then
		return
	end
	built.catapultPrompt.Enabled = enabled
	local cue = built.pouch:FindFirstChild("Cue")
	if cue and cue:IsA("Highlight") then
		cue.Enabled = enabled
	end
end

local function clearSeat(launching: boolean)
	local seat = occupant
	occupant = nil
	setPromptEnabled(true)
	local built = world
	if built then
		built.pouch.CFrame = restCFrame
	end
	if not seat then
		return
	end
	if seat.player.Parent ~= nil then
		seat.player:SetAttribute("InCatapult", false)
	end
	if launching then
		return
	end
	local rig = CharacterUtil.get(seat.player)
	if rig then
		rig.root.Anchored = false
		CharacterUtil.release(rig.humanoid)
		rig.root.CFrame = rig.root.CFrame * CFrame.new(0, 0, 4)
	end
end

local function launch(seat: Seat)
	local player = seat.player
	local charge = math.clamp(seat.charge, 0, 1)
	local profile = DataService.get(player)
	local built = world
	if not profile or not profile.ready or not built then
		clearSeat(false)
		return
	end

	occupant = nil
	setPromptEnabled(true)
	built.pouch.CFrame = restCFrame
	player:SetAttribute("InCatapult", false)

	local launched = FlightModel.launchState(profile.data.upgrades, charge)
	local params = UpgradeMath.flightParams(profile.data.upgrades)
	local heat = UpgradeMath.heatParams(profile.data.upgrades)
	local rig = CharacterUtil.get(player)
	if not rig then
		return
	end

	rig.root.Anchored = false
	CharacterUtil.prepareForFlight(rig.humanoid)
	pcall(function()
		rig.root:SetNetworkOwner(player)
	end)
	local position = rig.root.Position
	rig.root.CFrame = FlightModel.orientation(position, launched.pitch, launched.yaw, 0)
	rig.root.AssemblyAngularVelocity = Vector3.zero
	rig.root.AssemblyLinearVelocity = launched.velocity

	RunManager.begin(player, built.launchOrigin.X)
	Remotes.event("LaunchBegan"):FireClient(player, {
		speed = launched.speed,
		pitch = launched.pitch,
		yaw = launched.yaw,
		originX = built.launchOrigin.X,
		drag = params.drag,
		stallSpeed = params.stallSpeed,
		sinkDivisor = params.sinkDivisor,
		climbMultiplier = params.climbMultiplier,
		heatStart = heat.startAltitude,
		heatMax = heat.maxHeat,
		heatRiseScale = heat.riseScale,
	})
end

local function enter(player: Player)
	if occupant ~= nil or RunManager.isFlying(player) then
		return
	end
	local profile = DataService.get(player)
	if not profile or not profile.ready then
		return
	end
	local rig = CharacterUtil.get(player)
	if not rig then
		return
	end

	local seat: Seat = {
		player = player,
		charge = 0,
		holding = false,
		lastHold = 0,
	}
	occupant = seat
	setPromptEnabled(false)
	CharacterUtil.prepareForFlight(rig.humanoid)
	player:SetAttribute("InCatapult", true)
	applyCharge(seat)
end

function CatapultService.start(built: WorldBuilder.World)
	world = built
	restCFrame = built.pouch.CFrame

	built.catapultPrompt.Triggered:Connect(function(player)
		enter(player)
	end)

	Remotes.event("ExitCatapult").OnServerEvent:Connect(function(player)
		local seat = seatOf(player)
		if not seat then
			return
		end
		clearSeat(false)
	end)

	Remotes.event("ChargeHeld").OnServerEvent:Connect(function(player, held: any)
		local seat = seatOf(player)
		if not seat or typeof(held) ~= "boolean" then
			return
		end
		if held then
			seat.holding = true
			seat.lastHold = os.clock()
			return
		end
		seat.holding = false
		if seat.charge >= Config.Catapult.MinCharge then
			launch(seat)
		else
			seat.charge = 0
			applyCharge(seat)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local seat = occupant
		if not seat or not seat.holding then
			return
		end
		if os.clock() - seat.lastHold > Config.Catapult.HoldTimeout then
			seat.holding = false
			seat.charge = 0
			applyCharge(seat)
			return
		end
		seat.charge = math.min(1, seat.charge + dt / Config.Catapult.ChargeSeconds)
		applyCharge(seat)
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		if seatOf(player) then
			clearSeat(false)
		end
	end)
end

return CatapultService
