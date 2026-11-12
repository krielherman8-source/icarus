--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HUD = require(script.Parent.HUD)
local WingsVisual = require(script.Parent.WingsVisual)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local FlightModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FlightModel"))
local UpgradeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeMath"))

local FlightController = {}

type Session = {
	speed: number,
	pitch: number,
	yaw: number,
	roll: number,
	originX: number,
	params: UpgradeMath.FlightParams,
	heatParams: UpgradeMath.HeatParams,
	heat: number,
	melted: boolean,
	meltTold: boolean,
	startedAt: number,
	notified: boolean,
	sawRun: boolean,
}

local session: Session? = nil
local cameraBound = false
local savedFov = 70

local keysDown: { [Enum.KeyCode]: boolean } = {}
local pointerPitch = 0
local pointerYaw = 0
local gamepadPitch = 0
local gamepadYaw = 0
local touchPos: { [InputObject]: Vector2 } = {}

local function finite(value: any, fallback: number): number
	if typeof(value) == "number" and value == value then
		return value
	end
	return fallback
end

local function axes(): (number, number)
	local pitchAxis = gamepadPitch
	local yawAxis = gamepadYaw
	if keysDown[Enum.KeyCode.W] or keysDown[Enum.KeyCode.Up] then
		pitchAxis += 1
	end
	if keysDown[Enum.KeyCode.S] or keysDown[Enum.KeyCode.Down] then
		pitchAxis -= 1
	end
	if keysDown[Enum.KeyCode.A] or keysDown[Enum.KeyCode.Left] then
		yawAxis -= 1
	end
	if keysDown[Enum.KeyCode.D] or keysDown[Enum.KeyCode.Right] then
		yawAxis += 1
	end
	return math.clamp(pitchAxis, -1, 1), math.clamp(yawAxis, -1, 1)
end

local function consumePointer(): (number, number)
	local maxStep = Config.Flight.MaxPointerStep
	local pitchStep = math.clamp(pointerPitch, -maxStep, maxStep)
	local yawStep = math.clamp(pointerYaw, -maxStep, maxStep)
	pointerPitch = 0
	pointerYaw = 0
	return pitchStep, yawStep
end

local function bindCamera()
	if cameraBound then
		return
	end
	cameraBound = true
	local camera = workspace.CurrentCamera
	if camera then
		savedFov = camera.FieldOfView
	end
	RunService:BindToRenderStep("ICARUSFlightCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local active = session
		local current = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not active or not current or not root or not root:IsA("BasePart") then
			return
		end
		current.CameraType = Enum.CameraType.Scriptable
		current.FieldOfView = 76
		local look = FlightModel.lookVector(active.pitch, active.yaw)
		local focus = root.Position + look * 14 + Vector3.new(0, 1.4, 0)
		local back = root.Position - look * 22 + Vector3.new(0, 6.5, 0)
		current.CFrame = CFrame.lookAt(back, focus)
	end)
end

local function unbindCamera()
	if not cameraBound then
		return
	end
	cameraBound = false
	RunService:UnbindFromRenderStep("ICARUSFlightCamera")
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = savedFov
	end
end

local function feetOnSurface(root: BasePart, humanoid: Humanoid): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = root.Parent
	if character then
		params.FilterDescendantsInstances = { character }
	end
	local length = humanoid.HipHeight + root.Size.Y * 0.5 + 1.6
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -length, 0), params)
	if not hit then
		return false
	end
	local limit = humanoid.HipHeight + root.Size.Y * 0.5 + 0.85
	return hit.Distance <= limit
end

local function stop(reason: string?)
	local active = session
	if not active then
		unbindCamera()
		return
	end
	local tell = reason
	if active.notified then
		tell = nil
	end
	active.notified = true
	session = nil
	unbindCamera()
	HUD.setFlightVisible(false)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
	end
	if tell then
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local remote = remotes and remotes:FindFirstChild("RunEndNotice")
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer(tell)
		end
	end
end

local function begin(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	session = {
		speed = finite(payload.speed, Config.Catapult.BaseSpeed),
		pitch = finite(payload.pitch, math.rad(Config.Catapult.BasePitchDegrees)),
		yaw = finite(payload.yaw, 0),
		roll = 0,
		originX = finite(payload.originX, 0),
		params = {
			drag = finite(payload.drag, Config.Flight.BaseDrag),
			stallSpeed = finite(payload.stallSpeed, Config.Flight.BaseStallSpeed),
			sinkDivisor = math.max(0.2, finite(payload.sinkDivisor, 1)),
			climbMultiplier = math.max(0.2, finite(payload.climbMultiplier, 1)),
		},
		heatParams = {
			startAltitude = finite(payload.heatStart, Config.Heat.StartAltitude),
			maxHeat = math.max(1, finite(payload.heatMax, Config.Heat.MaxHeat)),
			riseScale = math.max(0.05, finite(payload.heatRiseScale, 1)),
		},
		heat = 0,
		melted = false,
		meltTold = false,
		startedAt = os.clock(),
		notified = false,
		sawRun = Players.LocalPlayer:GetAttribute("InRun") == true,
	}
	pointerPitch = 0
	pointerYaw = 0
	HUD.setFlightVisible(true)
	if UserInputService.TouchEnabled then
		HUD.setHint("Drag the right side of the screen to steer")
	end
	bindCamera()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
	end
end

local function step(dt: number)
	local active = session
	if not active then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not root:IsA("BasePart") or not humanoid then
		stop("died")
		return
	end
	if Players.LocalPlayer:GetAttribute("InRun") == true then
		active.sawRun = true
	elseif active.sawRun then
		stop(nil)
		return
	end

	humanoid.PlatformStand = true
	local lifting = not active.melted
	if lifting then
		local pitchAxis, yawAxis = axes()
		local pointerP, pointerY = consumePointer()
		active.pitch += pitchAxis * Config.Flight.PitchRate * dt + pointerP
		active.yaw += yawAxis * Config.Flight.YawRate * dt + pointerY
		local targetRoll = math.clamp(-yawAxis * 0.6, -0.7, 0.7)
		active.roll += (targetRoll - active.roll) * math.min(1, dt * 8)
	else
		consumePointer()
		active.pitch += (math.rad(-68) - active.pitch) * math.min(1, dt * 2.4)
		active.roll += (0 - active.roll) * math.min(1, dt * 4)
	end
	active.pitch = math.clamp(active.pitch, Config.Flight.MinPitch, Config.Flight.MaxPitch)

	local newSpeed, newPitch = FlightModel.step(active.speed, active.pitch, dt, active.params, lifting)
	active.speed = newSpeed
	active.pitch = math.clamp(newPitch, Config.Flight.MinPitch, Config.Flight.MaxPitch)
	local velocity = FlightModel.velocity(active.speed, active.pitch, active.yaw, active.params, lifting)

	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = FlightModel.orientation(root.Position, active.pitch, active.yaw, active.roll)
	root.AssemblyLinearVelocity = velocity

	local altitude = root.Position.Y - Config.World.SeaLevel
	if lifting then
		active.heat = math.clamp(
			active.heat + UpgradeMath.heatRate(active.heatParams, altitude) * dt,
			0,
			active.heatParams.maxHeat
		)
		WingsVisual.apply(active.heat / active.heatParams.maxHeat)
		if active.heat >= active.heatParams.maxHeat then
			active.melted = true
			lifting = false
			WingsVisual.melt()
			if not active.meltTold then
				active.meltTold = true
				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
				local remote = remotes and remotes:FindFirstChild("Melted")
				if remote and remote:IsA("RemoteEvent") then
					remote:FireServer()
				end
			end
		end
	end

	local distance = math.max(0, root.Position.X - active.originX)
	local status = ""
	if active.melted then
		status = "WINGS MELTING"
	elseif altitude > active.heatParams.startAltitude then
		status = "THE WAX IS WARMING"
	elseif active.speed < active.params.stallSpeed * 1.15 then
		status = "STALL — NOSE DOWN"
	end
	HUD.setFlightReadout(
		distance,
		math.max(0, altitude),
		active.speed,
		active.heat,
		active.heatParams.maxHeat,
		status
	)

	local age = os.clock() - active.startedAt
	local grounded = feetOnSurface(root, humanoid) and velocity.Y < 25
	if age >= Config.Run.MinAirTime and grounded and distance >= Config.Run.FailDistance then
		stop(if active.melted then "melt" else "land")
	elseif age >= 2 and grounded and distance < Config.Run.FailDistance and active.speed < 18 then
		stop("land")
	end
end

function FlightController.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local launch = remotes:WaitForChild("LaunchBegan")
	assert(launch:IsA("RemoteEvent"))
	launch.OnClientEvent:Connect(begin)

	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		if player:GetAttribute("InRun") ~= true then
			stop(nil)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, _processed)
		if input.KeyCode then
			keysDown[input.KeyCode] = true
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			touchPos[input] = input.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode then
			keysDown[input.KeyCode] = nil
		end
		touchPos[input] = nil
	end)
	UserInputService.InputChanged:Connect(function(input, _processed)
		local active = session
		if not active or active.melted then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			pointerPitch += -input.Delta.Y * Config.Flight.MousePitch
			pointerYaw += input.Delta.X * Config.Flight.MouseYaw
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local previous = touchPos[input]
			local camera = workspace.CurrentCamera
			if previous and camera and input.Position.X > camera.ViewportSize.X * 0.32 then
				local delta = input.Position - previous
				pointerYaw += delta.X * Config.Flight.TouchYaw
				pointerPitch += -delta.Y * Config.Flight.TouchPitch
			end
			touchPos[input] = input.Position
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local x = input.Position.X
			local y = input.Position.Y
			gamepadYaw = if math.abs(x) < 0.18 then 0 else x
			gamepadPitch = if math.abs(y) < 0.18 then 0 else y
		end
	end)

	RunService.Heartbeat:Connect(step)
end

return FlightController
