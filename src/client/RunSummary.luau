--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GuiUtil = require(script.Parent.GuiUtil)
local ClientData = require(script.Parent.ClientData)

local RunSummary = {}

local palette = GuiUtil.Palette

local screen: ScreenGui
local titleLabel: TextLabel
local bodyLabel: TextLabel
local recordLabel: TextLabel

local function reasonCopy(reason: string, distance: number): (string, string)
	if distance < 8 then
		return "STILL ON THE CLIFF", "The slingshot barely let go. Pull longer."
	end
	if reason == "melt" then
		return "THE WAX GAVE WAY", "The wings forgot how to be wings. The sea kept the coins."
	elseif reason == "died" then
		return "DOWN", "You left the sky faster than the wings did."
	elseif reason == "timeout" then
		return "THE WIND TIRED", "Even a long glide has to choose a place to stop."
	end
	return "FLIGHT COMPLETE", "The sea caught you. The distance is already counted."
end

local function show(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local distance = if typeof(payload.distance) == "number" then payload.distance else 0
	local coinsEarned = if typeof(payload.coinsEarned) == "number" then payload.coinsEarned else 0
	local best = if typeof(payload.bestDistance) == "number" then payload.bestDistance else 0
	local altitude = if typeof(payload.maxAltitude) == "number" then payload.maxAltitude else 0
	local reason = if typeof(payload.reason) == "string" then payload.reason else "land"
	local isRecord = payload.isRecord == true

	local heading, blurb = reasonCopy(reason, distance)
	titleLabel.Text = heading
	bodyLabel.Text = string.format(
		"%s\n\nDistance    %s m\nAltitude    %s m\nEarned      %s coins\nBest        %s m",
		blurb,
		GuiUtil.formatInt(distance),
		GuiUtil.formatInt(altitude),
		GuiUtil.formatInt(coinsEarned),
		GuiUtil.formatInt(best)
	)
	recordLabel.Visible = isRecord
	recordLabel.Text = if isRecord then "New best." else ""
	screen.Enabled = true
end

local function dismiss()
	if not screen.Enabled then
		return
	end
	screen.Enabled = false
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("ReturnToPad")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer()
	end
end

function RunSummary.start()
	local guiParent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = Instance.new("ScreenGui")
	screen.Name = "ICARUSSummary"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.DisplayOrder = 30
	screen.Parent = guiParent

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.new(0.88, 0, 0, 360)
	card.BackgroundColor3 = palette.panel
	card.BorderSizePixel = 0
	card.Parent = screen
	GuiUtil.corner(card, 16)
	GuiUtil.stroke(card, palette.gold, 1.5)
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(480, 400)
	cap.Parent = card

	titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(20, 16)
	titleLabel.Size = UDim2.new(1, -40, 0, 36)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = palette.gold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "FLIGHT COMPLETE"
	titleLabel.Parent = card

	bodyLabel = Instance.new("TextLabel")
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Position = UDim2.fromOffset(20, 60)
	bodyLabel.Size = UDim2.new(1, -40, 0, 200)
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextSize = 16
	bodyLabel.TextColor3 = palette.cream
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.TextWrapped = true
	bodyLabel.Text = ""
	bodyLabel.Parent = card

	recordLabel = Instance.new("TextLabel")
	recordLabel.BackgroundTransparency = 1
	recordLabel.Position = UDim2.fromOffset(20, 262)
	recordLabel.Size = UDim2.new(1, -40, 0, 20)
	recordLabel.Font = Enum.Font.GothamBold
	recordLabel.TextSize = 16
	recordLabel.TextXAlignment = Enum.TextXAlignment.Left
	recordLabel.TextColor3 = palette.good
	recordLabel.Text = ""
	recordLabel.Parent = card

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -16)
	button.Size = UDim2.new(1, -40, 0, 42)
	button.BackgroundColor3 = palette.gold
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = palette.ink
	button.Text = "Return to the cliff"
	button.Parent = card
	GuiUtil.corner(button, 10)
	button.MouseButton1Click:Connect(dismiss)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local result = remotes:WaitForChild("RunResult")
	assert(result:IsA("RemoteEvent"))
	result.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and typeof(payload.coins) == "number" then
			ClientData.apply({
				coins = payload.coins,
				bestDistance = payload.bestDistance,
				ready = true,
			})
		end
		show(payload)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not screen.Enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			dismiss()
		end
	end)
end

return RunSummary
