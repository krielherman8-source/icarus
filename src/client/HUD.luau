--!strict

local GuiUtil = require(script.Parent.GuiUtil)
local ClientData = require(script.Parent.ClientData)

local HUD = {}

local palette = GuiUtil.Palette

local coinsLabel: TextLabel
local bestLabel: TextLabel
local sessionLabel: TextLabel
local distanceLabel: TextLabel
local altLabel: TextLabel
local hintLabel: TextLabel
local heatFill: Frame
local heatLabel: TextLabel
local heatGlowTop: Frame
local heatGlowBottom: Frame
local chargeFrame: Frame
local chargeFill: Frame
local chargeText: TextLabel
local flightCluster: Frame
local statusLabel: TextLabel

local function pill(parent: Instance, position: UDim2, size: UDim2, anchor: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = palette.panel
	frame.BackgroundTransparency = 0.18
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	frame.AnchorPoint = anchor
	frame.Parent = parent
	GuiUtil.corner(frame, 12)
	GuiUtil.stroke(frame, palette.gold, 1)
	return frame
end

function HUD.start()
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ICARUSHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local coinPill = pill(gui, UDim2.fromOffset(16, 12), UDim2.fromOffset(210, 58), Vector2.zero)
	coinsLabel = Instance.new("TextLabel")
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Position = UDim2.fromOffset(12, 4)
	coinsLabel.Size = UDim2.new(1, -20, 0, 28)
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.TextSize = 22
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinsLabel.TextColor3 = palette.gold
	coinsLabel.Text = "0 coins"
	coinsLabel.Parent = coinPill

	bestLabel = Instance.new("TextLabel")
	bestLabel.BackgroundTransparency = 1
	bestLabel.Position = UDim2.fromOffset(12, 30)
	bestLabel.Size = UDim2.new(1, -20, 0, 20)
	bestLabel.Font = Enum.Font.Gotham
	bestLabel.TextSize = 14
	bestLabel.TextXAlignment = Enum.TextXAlignment.Left
	bestLabel.TextColor3 = palette.dim
	bestLabel.Text = "Best 0 m"
	bestLabel.Parent = coinPill

	sessionLabel = Instance.new("TextLabel")
	sessionLabel.BackgroundTransparency = 1
	sessionLabel.Position = UDim2.fromOffset(16, 74)
	sessionLabel.Size = UDim2.fromOffset(280, 18)
	sessionLabel.Font = Enum.Font.Gotham
	sessionLabel.TextSize = 13
	sessionLabel.TextXAlignment = Enum.TextXAlignment.Left
	sessionLabel.TextColor3 = palette.gold
	sessionLabel.Text = ""
	sessionLabel.Visible = false
	sessionLabel.Parent = gui

	flightCluster = Instance.new("Frame")
	flightCluster.BackgroundTransparency = 1
	flightCluster.AnchorPoint = Vector2.new(0.5, 0)
	flightCluster.Position = UDim2.new(0.5, 0, 0, 6)
	flightCluster.Size = UDim2.fromOffset(360, 92)
	flightCluster.Visible = false
	flightCluster.Parent = gui

	distanceLabel = Instance.new("TextLabel")
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.Size = UDim2.new(1, 0, 0, 52)
	distanceLabel.Font = Enum.Font.GothamBold
	distanceLabel.TextScaled = true
	distanceLabel.TextColor3 = palette.cream
	distanceLabel.Text = "0 m"
	distanceLabel.Parent = flightCluster

	altLabel = Instance.new("TextLabel")
	altLabel.BackgroundTransparency = 1
	altLabel.Position = UDim2.fromOffset(0, 52)
	altLabel.Size = UDim2.new(1, 0, 0, 22)
	altLabel.Font = Enum.Font.Gotham
	altLabel.TextSize = 16
	altLabel.TextColor3 = palette.sea
	altLabel.Text = "ALT 0    AIR 0"
	altLabel.Parent = flightCluster

	statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromOffset(0, 74)
	statusLabel.Size = UDim2.new(1, 0, 0, 18)
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 14
	statusLabel.TextColor3 = palette.heat
	statusLabel.Text = ""
	statusLabel.Parent = flightCluster

	local heatHolder = Instance.new("Frame")
	heatHolder.Name = "Heat"
	heatHolder.AnchorPoint = Vector2.new(1, 0.5)
	heatHolder.Position = UDim2.new(1, -16, 0.58, 0)
	heatHolder.Size = UDim2.new(0, 36, 0.4, 0)
	heatHolder.BackgroundColor3 = palette.ink
	heatHolder.BackgroundTransparency = 0.25
	heatHolder.BorderSizePixel = 0
	heatHolder.Visible = false
	heatHolder.Parent = gui
	GuiUtil.corner(heatHolder, 10)
	GuiUtil.stroke(heatHolder, palette.gold, 1)

	heatFill = Instance.new("Frame")
	heatFill.Name = "Fill"
	heatFill.AnchorPoint = Vector2.new(0, 1)
	heatFill.Position = UDim2.new(0, 4, 1, -4)
	heatFill.Size = UDim2.new(1, -8, 0, 0)
	heatFill.BackgroundColor3 = palette.sea
	heatFill.BorderSizePixel = 0
	heatFill.Parent = heatHolder
	GuiUtil.corner(heatFill, 8)

	local heatTitle = Instance.new("TextLabel")
	heatTitle.Name = "HeatTitle"
	heatTitle.BackgroundTransparency = 1
	heatTitle.AnchorPoint = Vector2.new(0.5, 1)
	heatTitle.Position = UDim2.new(0.5, 0, 0, -4)
	heatTitle.Size = UDim2.fromOffset(70, 16)
	heatTitle.Font = Enum.Font.GothamBold
	heatTitle.TextSize = 13
	heatTitle.TextXAlignment = Enum.TextXAlignment.Center
	heatTitle.TextColor3 = palette.cream
	heatTitle.Text = "HEAT"
	heatTitle.Visible = false
	heatTitle.Parent = heatHolder
	heatLabel = heatTitle

	heatGlowTop = Instance.new("Frame")
	heatGlowTop.BackgroundColor3 = palette.heat
	heatGlowTop.BackgroundTransparency = 1
	heatGlowTop.BorderSizePixel = 0
	heatGlowTop.Size = UDim2.fromScale(1, 0.12)
	heatGlowTop.Visible = false
	heatGlowTop.Parent = gui

	heatGlowBottom = Instance.new("Frame")
	heatGlowBottom.BackgroundColor3 = palette.heat
	heatGlowBottom.BackgroundTransparency = 1
	heatGlowBottom.BorderSizePixel = 0
	heatGlowBottom.AnchorPoint = Vector2.new(0, 1)
	heatGlowBottom.Position = UDim2.fromScale(0, 1)
	heatGlowBottom.Size = UDim2.fromScale(1, 0.1)
	heatGlowBottom.Visible = false
	heatGlowBottom.Parent = gui

	chargeFrame = Instance.new("Frame")
	chargeFrame.AnchorPoint = Vector2.new(0.5, 1)
	chargeFrame.Position = UDim2.new(0.5, 0, 1, -24)
	chargeFrame.Size = UDim2.new(0.5, 0, 0, 22)
	chargeFrame.BackgroundColor3 = palette.ink
	chargeFrame.BackgroundTransparency = 0.2
	chargeFrame.BorderSizePixel = 0
	chargeFrame.Visible = false
	chargeFrame.Parent = gui
	GuiUtil.corner(chargeFrame, 8)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(420, 22)
	constraint.Parent = chargeFrame

	chargeFill = Instance.new("Frame")
	chargeFill.Size = UDim2.fromScale(0, 1)
	chargeFill.BackgroundColor3 = palette.gold
	chargeFill.BorderSizePixel = 0
	chargeFill.Parent = chargeFrame
	GuiUtil.corner(chargeFill, 8)

	chargeText = Instance.new("TextLabel")
	chargeText.BackgroundTransparency = 1
	chargeText.AnchorPoint = Vector2.new(0.5, 1)
	chargeText.Position = UDim2.new(0.5, 0, 1, -50)
	chargeText.Size = UDim2.fromOffset(320, 22)
	chargeText.Font = Enum.Font.GothamBold
	chargeText.TextSize = 16
	chargeText.TextColor3 = palette.cream
	chargeText.Text = "Hold to pull back"
	chargeText.Visible = false
	chargeText.Parent = gui

	hintLabel = Instance.new("TextLabel")
	hintLabel.BackgroundTransparency = 1
	hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	hintLabel.Position = UDim2.new(0.5, 0, 1, -8)
	hintLabel.Size = UDim2.new(0.9, 0, 0, 22)
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextSize = 14
	hintLabel.TextColor3 = palette.cream
	hintLabel.TextTransparency = 0.15
	hintLabel.Text = "Climb into the slingshot  ·  Hold to pull  ·  Release to fly"
	hintLabel.Parent = gui

	ClientData.onChanged(function(snapshot)
		coinsLabel.Text = GuiUtil.formatInt(snapshot.coins) .. " coins"
		bestLabel.Text = "Best " .. GuiUtil.formatInt(snapshot.bestDistance) .. " m"
		sessionLabel.Visible = snapshot.sessionOnly
		sessionLabel.Text = if snapshot.sessionOnly
			then "Studio session — progress stays on this server only"
			else ""
		if not snapshot.ready then
			hintLabel.Text = "Warming the wax..."
		elseif not flightCluster.Visible and not chargeFrame.Visible then
			hintLabel.Text = "Climb into the slingshot  ·  Hold to pull  ·  Release to fly"
		end
	end)
end

function HUD.setHint(text: string)
	hintLabel.Text = text
	hintLabel.Visible = true
end

function HUD.setCharge(visible: boolean, alpha: number)
	chargeFrame.Visible = visible
	chargeText.Visible = visible
	hintLabel.Visible = not visible
	if not visible then
		if not flightCluster.Visible then
			local snapshot = ClientData.current()
			hintLabel.Text = if snapshot.ready
				then "Climb into the slingshot  ·  Hold to pull  ·  Release to fly"
				else "Warming the wax..."
			hintLabel.Visible = true
		end
		return
	end
	local clamped = math.clamp(alpha, 0, 1)
	chargeFill.Size = UDim2.fromScale(clamped, 1)
	chargeFill.BackgroundColor3 = palette.gold:Lerp(palette.heat, clamped)
	if clamped < 0.18 then
		chargeText.Text = "Hold to pull back"
	elseif clamped < 1 then
		chargeText.Text = "Release to launch  " .. tostring(math.floor(clamped * 100 + 0.5)) .. "%"
	else
		chargeText.Text = "Full draw — release!"
	end
end

function HUD.setFlightVisible(visible: boolean)
	flightCluster.Visible = visible
	heatFill.Parent.Visible = visible
	heatLabel.Visible = visible
	heatGlowTop.Visible = visible
	heatGlowBottom.Visible = visible
	hintLabel.Visible = true
	if visible then
		hintLabel.Text = "W/S pitch   A/D turn   Mouse or drag to steer"
	else
		heatGlowTop.BackgroundTransparency = 1
		heatGlowBottom.BackgroundTransparency = 1
		local snapshot = ClientData.current()
		hintLabel.Text = if snapshot.ready
			then "Climb into the slingshot  ·  Hold to pull  ·  Release to fly"
			else "Warming the wax..."
	end
end

function HUD.setFlightReadout(
	distance: number,
	altitude: number,
	speed: number,
	heat: number,
	maxHeat: number,
	status: string
)
	distanceLabel.Text = GuiUtil.formatInt(distance) .. " m"
	altLabel.Text = string.format("ALT %d     AIR %d", math.floor(altitude + 0.5), math.floor(speed + 0.5))
	statusLabel.Text = status
	local alpha = if maxHeat <= 0 then 0 else math.clamp(heat / maxHeat, 0, 1)
	heatFill.Size = UDim2.new(1, -8, alpha, 0)
	heatFill.BackgroundColor3 = palette.sea:Lerp(palette.heat, alpha)
	local haze = if alpha < 0.62 then 1 else 0.45 + 0.35 * (1 - alpha)
	heatGlowTop.BackgroundTransparency = haze
	heatGlowBottom.BackgroundTransparency = math.clamp(haze + 0.1, 0, 1)
end

return HUD
