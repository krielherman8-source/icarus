--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GuiUtil = require(script.Parent.GuiUtil)
local HUD = require(script.Parent.HUD)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CatapultController = {}

local palette = GuiUtil.Palette

local held = false
local inSeat = false
local charge = 0
local lastSend = 0
local chargeEvent: RemoteEvent
local exitEvent: RemoteEvent

local holdButton: TextButton
local leaveButton: TextButton

local function sendHeld(isHeld: boolean)
	lastSend = os.clock()
	chargeEvent:FireServer(isHeld)
end

local function setHeld(nextHeld: boolean)
	if not inSeat then
		return
	end
	if held == nextHeld then
		return
	end
	held = nextHeld
	sendHeld(held)
	if not held and charge < Config.Catapult.MinCharge then
		charge = 0
	end
end

local function exitSeat()
	if not inSeat then
		return
	end
	-- Do not send a charge release here: the server treats that as a launch.
	held = false
	charge = 0
	exitEvent:FireServer()
end

local function bind()
	ContextActionService:BindActionAtPriority("ICARUS_Charge", function(_name, state, _input)
		if state == Enum.UserInputState.Begin then
			setHeld(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setHeld(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonR2)
end

local function unbind()
	ContextActionService:UnbindAction("ICARUS_Charge")
end

function CatapultController.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local chargeRemote = remotes:WaitForChild("ChargeHeld")
	local exitRemote = remotes:WaitForChild("ExitCatapult")
	assert(chargeRemote:IsA("RemoteEvent"))
	assert(exitRemote:IsA("RemoteEvent"))
	chargeEvent = chargeRemote
	exitEvent = exitRemote

	local gui = Instance.new("ScreenGui")
	gui.Name = "ICARUSCatapult"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	holdButton = Instance.new("TextButton")
	holdButton.Name = "Hold"
	holdButton.AnchorPoint = Vector2.new(0.5, 1)
	holdButton.Position = UDim2.new(0.5, 0, 1, -108)
	holdButton.Size = UDim2.fromOffset(220, 52)
	holdButton.BackgroundColor3 = palette.gold
	holdButton.Font = Enum.Font.GothamBold
	holdButton.TextSize = 18
	holdButton.TextColor3 = palette.ink
	holdButton.Text = "HOLD TO LAUNCH"
	holdButton.Visible = false
	holdButton.Parent = gui
	GuiUtil.corner(holdButton, 12)

	leaveButton = Instance.new("TextButton")
	leaveButton.Name = "Leave"
	leaveButton.AnchorPoint = Vector2.new(0.5, 1)
	leaveButton.Position = UDim2.new(0.5, 130, 1, -108)
	leaveButton.Size = UDim2.fromOffset(88, 52)
	leaveButton.BackgroundColor3 = palette.panel
	leaveButton.Font = Enum.Font.GothamBold
	leaveButton.TextSize = 16
	leaveButton.TextColor3 = palette.cream
	leaveButton.Text = "Leave"
	leaveButton.Visible = false
	leaveButton.Parent = gui
	GuiUtil.corner(leaveButton, 12)
	GuiUtil.stroke(leaveButton, palette.gold, 1)

	-- Shift the hold button left so it doesn't sit under Leave.
	holdButton.Position = UDim2.new(0.5, -50, 1, -108)

	holdButton.MouseButton1Down:Connect(function()
		setHeld(true)
	end)
	holdButton.MouseButton1Up:Connect(function()
		setHeld(false)
	end)
	leaveButton.MouseButton1Click:Connect(exitSeat)

	local player = Players.LocalPlayer
	local function refreshSeat()
		local seated = player:GetAttribute("InCatapult") == true
		if seated == inSeat then
			return
		end
		inSeat = seated
		held = false
		charge = 0
		local showTouch = seated and UserInputService.TouchEnabled
		holdButton.Visible = showTouch
		leaveButton.Visible = seated
		HUD.setCharge(seated, 0)
		if seated then
			bind()
		else
			unbind()
		end
	end
	player:GetAttributeChangedSignal("InCatapult"):Connect(refreshSeat)
	refreshSeat()

	UserInputService.InputBegan:Connect(function(input, processed)
		if not inSeat then
			return
		end
		if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.ButtonB then
			exitSeat()
			return
		end
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			setHeld(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			setHeld(false)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		if not inSeat then
			return
		end
		if held then
			charge = math.min(1, charge + dt / Config.Catapult.ChargeSeconds)
			if os.clock() - lastSend > 0.25 then
				sendHeld(true)
			end
		end
		HUD.setCharge(true, charge)
	end)
end

return CatapultController
