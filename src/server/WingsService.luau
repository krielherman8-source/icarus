--!strict
-- Feather panels welded to the torso. The owning client recolors them as they heat;
-- the server detaches them when the wax gives way so the drop replicates.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(script.Parent.CharacterUtil)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WingsService = {}

local FEATHER = Color3.fromRGB(236, 226, 206)
local ASH = Color3.fromRGB(42, 24, 22)

local PANELS = {
	{ size = Vector3.new(6.6, 0.22, 2.15), offset = 3.7, y = 0.2, z = 0.2, roll = 7 },
	{ size = Vector3.new(5.3, 0.18, 1.65), offset = 3.15, y = 0.02, z = -0.6, roll = 12 },
	{ size = Vector3.new(4.3, 0.16, 1.3), offset = 2.6, y = 0.34, z = 0.75, roll = 4 },
}

local function weld(a: BasePart, b: BasePart)
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = a
	joint.Part1 = b
	joint.Parent = b
end

local function clearAttached(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, -4) == "Wing" then
			child:Destroy()
		end
	end
end

function WingsService.regrow(character: Model)
	clearAttached(character)
	local torso = CharacterUtil.torso(character)
	if not torso then
		return
	end

	for _, side in { -1, 1 } do
		local model = Instance.new("Model")
		model.Name = if side < 0 then "LeftWing" else "RightWing"
		model:SetAttribute("Side", side)

		local bone = Instance.new("Part")
		bone.Name = "Bone"
		bone.Size = Vector3.new(0.45, 0.45, 0.45)
		bone.Color = Color3.fromRGB(214, 176, 96)
		bone.Material = Enum.Material.SmoothPlastic
		bone.CanCollide = false
		bone.CanTouch = false
		bone.CanQuery = false
		bone.Massless = true
		bone.CFrame = torso.CFrame * CFrame.new(side * 1.15, 0.45, 0.15)
		bone.Parent = model
		weld(torso, bone)

		for index, spec in PANELS do
			local panel = Instance.new("Part")
			panel.Name = "Feather" .. tostring(index)
			panel.Size = spec.size
			panel.Color = FEATHER
			panel.Material = Enum.Material.SmoothPlastic
			panel.CanCollide = false
			panel.CanTouch = false
			panel.CanQuery = false
			panel.Massless = true
			panel.CFrame = bone.CFrame
				* CFrame.new(side * spec.offset, spec.y, spec.z)
				* CFrame.Angles(0, 0, math.rad(side * spec.roll))
			panel.Parent = model
			weld(bone, panel)

			if index == 1 then
				local drip = Instance.new("ParticleEmitter")
				drip.Name = "Drip"
				drip.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				drip.Rate = 0
				drip.Lifetime = NumberRange.new(0.35, 0.7)
				drip.Speed = NumberRange.new(1, 3)
				drip.Acceleration = Vector3.new(0, -48, 0)
				drip.SpreadAngle = Vector2.new(18, 18)
				drip.Rotation = NumberRange.new(0, 180)
				drip.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.38),
					NumberSequenceKeypoint.new(1, 0.04),
				})
				drip.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.15),
					NumberSequenceKeypoint.new(1, 1),
				})
				drip.Color = ColorSequence.new(Color3.fromRGB(255, 176, 70), Color3.fromRGB(90, 24, 12))
				drip.Enabled = true
				drip.Parent = panel
			end
		end

		model.Parent = character
	end
	character:SetAttribute("WingsMelted", false)
end

function WingsService.melt(character: Model)
	if character:GetAttribute("WingsMelted") == true then
		return
	end
	character:SetAttribute("WingsMelted", true)

	local world = workspace:FindFirstChild(Config.Names.WorldFolder)
	local debrisFolder = world and world:FindFirstChild(Config.Names.Debris)

	for _, child in character:GetChildren() do
		if not (child:IsA("Model") and string.sub(child.Name, -4) == "Wing") then
			continue
		end
		local side = child:GetAttribute("Side")
		local outward = if type(side) == "number" then side else 1
		local welds = {}
		local parts = {}
		local drips = {}
		for _, desc in child:GetDescendants() do
			if desc:IsA("WeldConstraint") or desc:IsA("Weld") then
				table.insert(welds, desc)
			elseif desc:IsA("BasePart") then
				table.insert(parts, desc)
			elseif desc:IsA("ParticleEmitter") and desc.Name == "Drip" then
				table.insert(drips, desc)
			end
		end
		for _, joint in welds do
			joint:Destroy()
		end
		for _, panel in parts do
			panel.Color = ASH
			panel.Material = Enum.Material.Slate
			panel.Massless = false
			panel.CanCollide = true
			panel.Anchored = false
			panel.AssemblyLinearVelocity = Vector3.new(outward * 8, 6, (math.random() - 0.5) * 6)
		end
		for _, drip in drips do
			drip.Rate = 80
			task.delay(0.45, function()
				if drip.Parent then
					drip.Rate = 8
				end
			end)
		end
		child.Parent = if debrisFolder and debrisFolder:IsA("Folder") then debrisFolder else workspace
		Debris:AddItem(child, 8)
	end
end

local function onCharacter(character: Model)
	-- The torso sometimes replicates a moment after the character.
	task.spawn(function()
		local torso = character:WaitForChild("UpperTorso", 8) or character:WaitForChild("Torso", 4)
		if torso and character.Parent then
			WingsService.regrow(character)
		end
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

function WingsService.start()
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return WingsService
