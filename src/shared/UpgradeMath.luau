--!strict
-- Pure upgrade curves. Server and client both require this so prices and flight
-- numbers cannot drift.

local Config = require(script.Parent.Config)

local UpgradeMath = {}

export type UpgradeId = "LaunchPower" | "Lift" | "GlideEfficiency" | "HeatResistance"

export type UpgradeLevels = {
	LaunchPower: number,
	Lift: number,
	GlideEfficiency: number,
	HeatResistance: number,
}

export type FlightParams = {
	drag: number,
	stallSpeed: number,
	sinkDivisor: number,
	climbMultiplier: number,
}

export type HeatParams = {
	startAltitude: number,
	maxHeat: number,
	riseScale: number,
}

local function levelOf(levels: UpgradeLevels, id: UpgradeId): number
	local value = levels[id]
	if type(value) ~= "number" then
		return 0
	end
	return math.max(0, value)
end

function UpgradeMath.cost(id: UpgradeId, currentLevel: number): number?
	local def = Config.Upgrades[id]
	if currentLevel >= def.MaxLevel then
		return nil
	end
	return math.floor(def.BaseCost * (def.CostGrowth ^ currentLevel) + 0.5)
end

function UpgradeMath.flightParams(levels: UpgradeLevels): FlightParams
	local lift = levelOf(levels, "Lift")
	local glide = levelOf(levels, "GlideEfficiency")
	local drag = math.max(
		Config.Flight.MinDrag,
		Config.Flight.BaseDrag * (Config.Flight.DragKeptPerGlideLevel ^ glide)
	)
	local stall = math.max(
		Config.Flight.MinStallSpeed,
		Config.Flight.BaseStallSpeed - Config.Flight.StallReductionPerLift * lift
	)
	return {
		drag = drag,
		stallSpeed = stall,
		sinkDivisor = 1 + Config.Flight.SinkDivisorPerLift * lift,
		climbMultiplier = 1 + Config.Flight.ClimbMultiplierPerLift * lift,
	}
end

function UpgradeMath.heatParams(levels: UpgradeLevels): HeatParams
	local level = levelOf(levels, "HeatResistance")
	local def = Config.Upgrades.HeatResistance
	return {
		startAltitude = Config.Heat.StartAltitude + def.AltitudePerLevel * level,
		maxHeat = Config.Heat.MaxHeat + def.MaxHeatPerLevel * level,
		riseScale = 1 / (1 + def.RiseReduction * level),
	}
end

-- Heat change per second. Positive heats, negative cools.
function UpgradeMath.heatRate(heat: HeatParams, altitude: number): number
	if altitude > heat.startAltitude then
		local alpha = math.clamp((altitude - heat.startAltitude) / Config.Heat.BandHeight, 0, 1)
		local fraction = Config.Heat.MinRiseFraction + (1 - Config.Heat.MinRiseFraction) * alpha
		return Config.Heat.RisePerSecond * heat.riseScale * fraction
	end
	local depth = math.clamp((heat.startAltitude - altitude) / Config.Heat.CoolDepth, 0, 1)
	local fraction = Config.Heat.MinCoolFraction + (1 - Config.Heat.MinCoolFraction) * depth
	return -Config.Heat.CoolPerSecond * fraction
end

function UpgradeMath.launchSpeed(levels: UpgradeLevels, charge: number): number
	local level = levelOf(levels, "LaunchPower")
	local full = Config.Catapult.BaseSpeed + Config.Catapult.SpeedPerLevel * level
	local shaped = Config.Catapult.MinSpeedFraction
		+ (1 - Config.Catapult.MinSpeedFraction) * math.clamp(charge, 0, 1)
	return full * shaped
end

function UpgradeMath.launchPitch(charge: number): number
	local degrees = Config.Catapult.BasePitchDegrees
		+ Config.Catapult.ExtraPitchDegrees * math.clamp(charge, 0, 1)
	return math.rad(degrees)
end

function UpgradeMath.blankLevels(): UpgradeLevels
	return {
		LaunchPower = 0,
		Lift = 0,
		GlideEfficiency = 0,
		HeatResistance = 0,
	}
end

function UpgradeMath.describe(id: UpgradeId, currentLevel: number): string
	local levels = UpgradeMath.blankLevels()
	levels[id] = currentLevel
	local nextLevels = UpgradeMath.blankLevels()
	nextLevels[id] = math.min(currentLevel + 1, Config.Upgrades[id].MaxLevel)

	if id == "LaunchPower" then
		local now = Config.Catapult.BaseSpeed + Config.Catapult.SpeedPerLevel * currentLevel
		local nxt = Config.Catapult.BaseSpeed + Config.Catapult.SpeedPerLevel * nextLevels.LaunchPower
		return string.format("Full-charge speed %d → %d", math.floor(now + 0.5), math.floor(nxt + 0.5))
	elseif id == "Lift" then
		local now = UpgradeMath.flightParams(levels).sinkDivisor
		local nxt = UpgradeMath.flightParams(nextLevels).sinkDivisor
		return string.format("Descent sink ×%.2f → ×%.2f", 1 / now, 1 / nxt)
	elseif id == "GlideEfficiency" then
		local now = UpgradeMath.flightParams(levels).drag
		local nxt = UpgradeMath.flightParams(nextLevels).drag
		return string.format("Drag %.5f → %.5f", now, nxt)
	else
		local now = UpgradeMath.heatParams(levels).startAltitude
		local nxt = UpgradeMath.heatParams(nextLevels).startAltitude
		return string.format("Heat begins at %d m → %d m", math.floor(now + 0.5), math.floor(nxt + 0.5))
	end
end

return UpgradeMath
