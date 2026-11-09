--!strict
-- Arcade glide shared by the launch impulse and the client flight controller.
-- Pitch is the flight-path angle (positive = nose up). Speed is a scalar.
-- Yaw 0 faces +X, toward the sun. Lift does not add energy; it flattens descent
-- and steepens climbs so the upgrade changes the path, not a hidden thrust.

local Config = require(script.Parent.Config)
local UpgradeMath = require(script.Parent.UpgradeMath)

local FlightModel = {}

export type LaunchState = {
	speed: number,
	pitch: number,
	yaw: number,
	velocity: Vector3,
}

function FlightModel.lookVector(pitch: number, yaw: number): Vector3
	local cp = math.cos(pitch)
	return Vector3.new(cp * math.cos(yaw), math.sin(pitch), cp * math.sin(yaw))
end

function FlightModel.orientation(position: Vector3, pitch: number, yaw: number, roll: number): CFrame
	local flat = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	local cf = CFrame.lookAt(position, position + flat)
	return cf * CFrame.Angles(pitch, 0, 0) * CFrame.Angles(0, 0, roll)
end

function FlightModel.launchState(levels: UpgradeMath.UpgradeLevels, charge: number): LaunchState
	local speed = UpgradeMath.launchSpeed(levels, charge)
	local pitch = UpgradeMath.launchPitch(charge)
	local params = UpgradeMath.flightParams(levels)
	local scale = if math.sin(pitch) >= 0 then params.climbMultiplier else 1
	local velocity = Vector3.new(math.cos(pitch) * speed, math.sin(pitch) * speed * scale, 0)
	return {
		speed = speed,
		pitch = pitch,
		yaw = 0,
		velocity = velocity,
	}
end

-- `lifting` is false after the wings melt: real gravity, no lift shaping.
function FlightModel.step(
	speed: number,
	pitch: number,
	dt: number,
	params: UpgradeMath.FlightParams,
	lifting: boolean
): (number, number)
	local gravity = if lifting then Config.Flight.Gravity else workspace.Gravity
	local newPitch = pitch
	local along: number
	if lifting and speed < params.stallSpeed then
		newPitch -= Config.Flight.StallPitchRate * dt
		along = -gravity * math.sin(newPitch)
			- params.drag * speed * speed
			- gravity * Config.Flight.StallPenalty
	else
		along = -gravity * math.sin(newPitch) - params.drag * speed * speed
	end
	local newSpeed = math.clamp(speed + along * dt, 0, Config.Flight.MaxSpeed)
	return newSpeed, newPitch
end

function FlightModel.velocity(
	speed: number,
	pitch: number,
	yaw: number,
	params: UpgradeMath.FlightParams,
	lifting: boolean
): Vector3
	local sine = math.sin(pitch)
	local scale = 1
	if lifting then
		scale = if sine < 0 then (1 / params.sinkDivisor) else params.climbMultiplier
	end
	local horizontal = math.cos(pitch) * speed
	local vertical = sine * speed * scale
	local velocity = Vector3.new(horizontal * math.cos(yaw), vertical, horizontal * math.sin(yaw))
	if not lifting and velocity.Y < -Config.Flight.TerminalFallSpeed then
		velocity = Vector3.new(velocity.X, -Config.Flight.TerminalFallSpeed, velocity.Z)
	end
	return velocity
end

return FlightModel
