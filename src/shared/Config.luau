--!strict
-- Tunable numbers for ICARUS. Distances are in studs and shown to the player as meters
-- (1 stud = 1 displayed meter). Flight uses its own gravity so a catapult throw can
-- actually climb; walking still uses Workspace.Gravity.

local Config = {}

Config.Names = {
	WorldFolder = "ICARUS",
	ShopBoard = "ShopBoard",
	ShopPrompt = "ShopPrompt",
	CatapultPrompt = "CatapultPrompt",
	Pouch = "Pouch",
	Spawn = "LaunchSpawn",
	Debris = "Debris",
}

Config.Economy = {
	CoinsPerMeter = 1,
	-- Shorter than this pays nothing, but still ends the run so the summary can show.
	MinDistance = 8,
}

Config.World = {
	SeaLevel = 4,
	MarkerSpacing = 100,
	MarkerMaxDistance = 10000,
	OceanMinX = -500,
	OceanMaxX = 12000,
	OceanHalfWidth = 1600,
	LaunchDeckY = 40,
}

Config.Flight = {
	-- Studs/s^2 inside the glide integrator. Workspace gravity stays at the Roblox default
	-- for walking and for the post-melt fall.
	Gravity = 58,
	BaseDrag = 0.0022,
	-- Each Glide Efficiency level multiplies drag by this. Lower drag = longer flights.
	DragKeptPerGlideLevel = 0.93,
	MinDrag = 0.00035,
	BaseStallSpeed = 33,
	StallReductionPerLift = 0.6,
	MinStallSpeed = 16,
	-- While descending, vertical speed is divided by (1 + this * liftLevel).
	SinkDivisorPerLift = 0.055,
	-- While climbing, vertical speed is multiplied by (1 + this * liftLevel).
	ClimbMultiplierPerLift = 0.035,
	MaxPitch = math.rad(38),
	MinPitch = math.rad(-78),
	PitchRate = math.rad(68),
	YawRate = math.rad(78),
	StallPitchRate = math.rad(50),
	StallPenalty = 0.5,
	MaxSpeed = 520,
	TerminalFallSpeed = 90,
	MousePitch = 0.0024,
	MouseYaw = 0.0016,
	TouchPitch = 0.0044,
	TouchYaw = 0.0034,
	MaxPointerStep = math.rad(48),
}

Config.Heat = {
	-- Altitudes are studs above sea level. Heat starts once you climb into this band.
	StartAltitude = 68,
	BandHeight = 110,
	RisePerSecond = 34,
	MinRiseFraction = 0.28,
	CoolPerSecond = 40,
	CoolDepth = 40,
	MinCoolFraction = 0.6,
	MaxHeat = 100,
}

Config.Catapult = {
	BaseSpeed = 100,
	SpeedPerLevel = 6.2,
	-- A partial charge still has some punch; holding the full time reaches 1.0.
	MinSpeedFraction = 0.42,
	MinCharge = 0.18,
	ChargeSeconds = 1.15,
	MaxPullStuds = 9,
	BasePitchDegrees = 26,
	ExtraPitchDegrees = 8,
	-- Drop a stuck pull if the client stops reporting that the button is held.
	HoldTimeout = 0.75,
}

Config.Upgrades = {
	LaunchPower = {
		Id = "LaunchPower",
		DisplayName = "Launch Power",
		Blurb = "A harder throw. More speed, and a higher arc if you hold the pull.",
		MaxLevel = 30,
		BaseCost = 25,
		CostGrowth = 1.45,
	},
	Lift = {
		Id = "Lift",
		DisplayName = "Lift",
		Blurb = "Climb harder and sink slower. Easier to reach the sun — and the heat.",
		MaxLevel = 30,
		BaseCost = 30,
		CostGrowth = 1.47,
	},
	GlideEfficiency = {
		Id = "GlideEfficiency",
		DisplayName = "Glide Efficiency",
		Blurb = "Smoother feathers. You keep your speed instead of bleeding it to the air.",
		MaxLevel = 30,
		BaseCost = 40,
		CostGrowth = 1.48,
	},
	HeatResistance = {
		Id = "HeatResistance",
		DisplayName = "Heat Resistance",
		Blurb = "Thicker wax. The dangerous air starts higher, and the melt takes longer.",
		MaxLevel = 30,
		BaseCost = 35,
		CostGrowth = 1.46,
		AltitudePerLevel = 8,
		MaxHeatPerLevel = 6,
		RiseReduction = 0.045,
	},
}

Config.UpgradeOrder = { "LaunchPower", "Lift", "GlideEfficiency", "HeatResistance" }

Config.Run = {
	MaxSeconds = 90,
	MinAirTime = 1.05,
	-- Forward progress below this, once you've stopped, is a failed launch (no coins).
	FailDistance = 14,
}

Config.AntiCheat = {
	-- Max forward studs/s the server will credit. Generous versus the flight model.
	MaxStepSpeed = 640,
	Slack = 40,
}

Config.Data = {
	StoreName = "ICARUS_PlayerData_v1",
	Retries = 4,
	AutosaveSeconds = 90,
}

return Config
