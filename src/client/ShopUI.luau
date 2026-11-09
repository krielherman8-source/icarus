--!strict

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiUtil = require(script.Parent.GuiUtil)
local ClientData = require(script.Parent.ClientData)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UpgradeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeMath"))

local ShopUI = {}

local palette = GuiUtil.Palette

local screen: ScreenGui
local list: ScrollingFrame
local statusLabel: TextLabel
local rows: { [UpgradeMath.UpgradeId]: { level: TextLabel, effect: TextLabel, buy: TextButton } } = {}
local busy = false

local function setStatus(text: string, bad: boolean)
	statusLabel.Text = text
	statusLabel.TextColor3 = if bad then palette.heat else palette.good
end

local function refreshBoard()
	local world = workspace:FindFirstChild(Config.Names.WorldFolder)
	local board = world and world:FindFirstChild(Config.Names.ShopBoard, true)
	if not board then
		return
	end
	local snapshot = ClientData.current()
	for _, id in Config.UpgradeOrder do
		local def = Config.Upgrades[id]
		local level = snapshot.upgrades[id]
		local price = UpgradeMath.cost(id, level)
		local text = def.DisplayName .. "   Lv " .. tostring(level)
		if price then
			text ..= "    " .. GuiUtil.formatInt(price)
		else
			text ..= "    MAX"
		end
		for _, desc in board:GetDescendants() do
			if desc:IsA("TextLabel") and desc.Name == "Row_" .. id then
				desc.Text = text
			end
		end
	end
end

local function refresh()
	local snapshot = ClientData.current()
	for _, id in Config.UpgradeOrder do
		local row = rows[id]
		local def = Config.Upgrades[id]
		local level = snapshot.upgrades[id]
		row.level.Text = "Lv " .. tostring(level) .. " / " .. tostring(def.MaxLevel)
		row.effect.Text = def.Blurb .. " " .. UpgradeMath.describe(id, level)
		local price = UpgradeMath.cost(id, level)
		if not snapshot.ready then
			row.buy.Text = "..."
			row.buy.AutoButtonColor = false
		elseif not price then
			row.buy.Text = "MAX"
			row.buy.BackgroundColor3 = palette.panel
			row.buy.TextColor3 = palette.dim
		elseif snapshot.coins < price then
			row.buy.Text = GuiUtil.formatInt(price)
			row.buy.BackgroundColor3 = palette.panel
			row.buy.TextColor3 = palette.dim
		else
			row.buy.Text = GuiUtil.formatInt(price)
			row.buy.BackgroundColor3 = palette.gold
			row.buy.TextColor3 = palette.ink
			row.buy.AutoButtonColor = true
		end
	end
	refreshBoard()
end

local function purchase(id: UpgradeMath.UpgradeId)
	if busy then
		return
	end
	local snapshot = ClientData.current()
	if not snapshot.ready then
		setStatus("Still warming the wax.", true)
		return
	end
	local price = UpgradeMath.cost(id, snapshot.upgrades[id])
	if not price then
		setStatus("That one is finished.", true)
		return
	end
	if snapshot.coins < price then
		setStatus("Need " .. GuiUtil.formatInt(price) .. " coins.", true)
		return
	end

	busy = true
	setStatus("Working the wax...", false)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local purchaseRemote = remotes:WaitForChild("Purchase")
	assert(purchaseRemote:IsA("RemoteFunction"))
	local ok, result = pcall(function()
		return purchaseRemote:InvokeServer(id)
	end)
	busy = false
	if not ok or typeof(result) ~= "table" then
		setStatus("The wingwright didn't answer.", true)
		return
	end
	if result.ok == true then
		ClientData.apply(result.snapshot)
		setStatus("Wax set.", false)
	else
		local message = result.error
		setStatus(if typeof(message) == "string" then message else "Couldn't buy that.", true)
	end
	refresh()
end

function ShopUI.open()
	screen.Enabled = true
	setStatus("", false)
	refresh()
end

function ShopUI.close()
	screen.Enabled = false
end

function ShopUI.start()
	local guiParent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = Instance.new("ScreenGui")
	screen.Name = "ICARUSShop"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.DisplayOrder = 20
	screen.Parent = guiParent

	local dimmer = Instance.new("TextButton")
	dimmer.Name = "Dimmer"
	dimmer.BackgroundColor3 = palette.ink
	dimmer.BackgroundTransparency = 0.35
	dimmer.BorderSizePixel = 0
	dimmer.Text = ""
	dimmer.Size = UDim2.fromScale(1, 1)
	dimmer.AutoButtonColor = false
	dimmer.Parent = screen
	dimmer.MouseButton1Click:Connect(function()
		ShopUI.close()
	end)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.92, 0.84)
	card.BackgroundColor3 = palette.panel
	card.BorderSizePixel = 0
	card.Parent = screen
	GuiUtil.corner(card, 16)
	GuiUtil.stroke(card, palette.gold, 1.5)
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(560, 640)
	cap.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 14)
	title.Size = UDim2.new(1, -80, 0, 32)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 26
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = palette.gold
	title.Text = "WINGWRIGHT"
	title.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(20, 44)
	subtitle.Size = UDim2.new(1, -40, 0, 20)
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 14
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = palette.dim
	subtitle.Text = "Spend what the flight brought back."
	subtitle.Parent = card

	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 12)
	closeButton.Size = UDim2.fromOffset(36, 36)
	closeButton.BackgroundColor3 = palette.ink
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 18
	closeButton.TextColor3 = palette.cream
	closeButton.Text = "X"
	closeButton.Parent = card
	GuiUtil.corner(closeButton, 8)
	closeButton.MouseButton1Click:Connect(function()
		ShopUI.close()
	end)

	list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(16, 76)
	list.Size = UDim2.new(1, -32, 1, -130)
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = palette.gold
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index, id in Config.UpgradeOrder do
		local def = Config.Upgrades[id]
		local row = Instance.new("Frame")
		row.Name = id
		row.LayoutOrder = index
		row.Size = UDim2.new(1, 0, 0, 108)
		row.BackgroundColor3 = palette.ink
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.Parent = list
		GuiUtil.corner(row, 10)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(12, 8)
		nameLabel.Size = UDim2.new(1, -130, 0, 22)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 18
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = palette.cream
		nameLabel.Text = def.DisplayName
		nameLabel.Parent = row

		local level = Instance.new("TextLabel")
		level.BackgroundTransparency = 1
		level.Position = UDim2.fromOffset(12, 30)
		level.Size = UDim2.new(1, -130, 0, 16)
		level.Font = Enum.Font.Gotham
		level.TextSize = 13
		level.TextXAlignment = Enum.TextXAlignment.Left
		level.TextColor3 = palette.gold
		level.Text = "Lv 0"
		level.Parent = row

		local effect = Instance.new("TextLabel")
		effect.BackgroundTransparency = 1
		effect.Position = UDim2.fromOffset(12, 48)
		effect.Size = UDim2.new(1, -120, 0, 52)
		effect.Font = Enum.Font.Gotham
		effect.TextSize = 13
		effect.TextXAlignment = Enum.TextXAlignment.Left
		effect.TextYAlignment = Enum.TextYAlignment.Top
		effect.TextWrapped = true
		effect.TextColor3 = palette.dim
		effect.Text = def.Blurb
		effect.Parent = row

		local buy = Instance.new("TextButton")
		buy.AnchorPoint = Vector2.new(1, 0)
		buy.Position = UDim2.new(1, -10, 0, 10)
		buy.Size = UDim2.fromOffset(96, 36)
		buy.Font = Enum.Font.GothamBold
		buy.TextSize = 16
		buy.TextColor3 = palette.ink
		buy.BackgroundColor3 = palette.gold
		buy.Text = "0"
		buy.Parent = row
		GuiUtil.corner(buy, 8)
		buy.MouseButton1Click:Connect(function()
			purchase(id)
		end)

		rows[id] = { level = level, effect = effect, buy = buy }
	end

	statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.AnchorPoint = Vector2.new(0, 1)
	statusLabel.Position = UDim2.new(0, 20, 1, -14)
	statusLabel.Size = UDim2.new(1, -40, 0, 22)
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 14
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = palette.cream
	statusLabel.Text = ""
	statusLabel.Parent = card

	ClientData.onChanged(function()
		if screen.Enabled then
			refresh()
		else
			refreshBoard()
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player ~= Players.LocalPlayer then
			return
		end
		if prompt.Name == Config.Names.ShopPrompt then
			if screen.Enabled then
				ShopUI.close()
			else
				ShopUI.open()
			end
		end
	end)

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
		if not remotes then
			return
		end
		local getState = remotes:WaitForChild("GetState", 10)
		if getState and getState:IsA("RemoteFunction") then
			local ok, snapshot = pcall(function()
				return getState:InvokeServer()
			end)
			if ok then
				ClientData.apply(snapshot)
			end
		end
		-- The board is streamed in with the server-built world.
		local world = workspace:WaitForChild(Config.Names.WorldFolder, 20)
		if world then
			world:WaitForChild(Config.Names.ShopBoard, 10)
			refreshBoard()
		end
	end)
end

return ShopUI
