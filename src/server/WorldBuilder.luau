--!strict
-- Builds the launch cliff, slingshot, shop, ocean, and the run toward the sun.
-- The map exists only after the server starts (press Play), not in the empty place file.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WorldBuilder = {}

export type World = {
	folder: Folder,
	pouch: BasePart,
	spawnPad: SpawnLocation,
	launchOrigin: Vector3,
	shopPrompt: ProximityPrompt,
	catapultPrompt: ProximityPrompt,
}

local STONE = Color3.fromRGB(96, 94, 104)
local STONE_DARK = Color3.fromRGB(62, 60, 70)
local GRASS = Color3.fromRGB(86, 122, 72)
local SAND = Color3.fromRGB(196, 176, 128)
local WOOD = Color3.fromRGB(124, 86, 52)
local WOOD_DARK = Color3.fromRGB(84, 56, 36)
local GOLD = Color3.fromRGB(214, 172, 78)
local CREAM = Color3.fromRGB(236, 224, 196)
local INK = Color3.fromRGB(28, 24, 36)
local WATER = Color3.fromRGB(24, 74, 122)
local WATER_DEEP = Color3.fromRGB(14, 40, 78)

type PartOptions = {
	name: string?,
	size: Vector3,
	cframe: CFrame?,
	position: Vector3?,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	shape: Enum.PartType?,
	parent: Instance,
}

local function part(options: PartOptions): Part
	local created = Instance.new("Part")
	created.Name = options.name or "Part"
	created.Anchored = true
	created.Size = options.size
	if options.cframe then
		created.CFrame = options.cframe
	else
		created.Position = options.position or Vector3.zero
	end
	created.Color = options.color
	created.Material = options.material or Enum.Material.SmoothPlastic
	created.Transparency = options.transparency or 0
	local collides = if options.canCollide == nil then true else options.canCollide
	created.CanCollide = collides
	-- Decorative parts must not count as "the ground" for the landing ray.
	created.CanQuery = collides
	created.TopSurface = Enum.SurfaceType.Smooth
	created.BottomSurface = Enum.SurfaceType.Smooth
	if options.shape then
		created.Shape = options.shape
	end
	created.Parent = options.parent
	return created
end

local function surfaceText(
	host: BasePart,
	face: Enum.NormalId,
	text: string,
	textColor: Color3,
	textSize: number
)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = host

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.TextSize = textSize
	label.Parent = gui
	return label
end

local function applyLighting()
	Lighting.ClockTime = 16.35
	Lighting.Brightness = 2.3
	Lighting.GeographicLatitude = 8
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(56, 50, 46)
	Lighting.OutdoorAmbient = Color3.fromRGB(118, 104, 90)
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.6

	local function one(className: string): Instance
		local found = Lighting:FindFirstChild("ICARUS_" .. className)
		if found then
			return found
		end
		local created = Instance.new(className)
		created.Name = "ICARUS_" .. className
		created.Parent = Lighting
		return created
	end

	local atmosphere = one("Atmosphere") :: Atmosphere
	atmosphere.Density = 0.26
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(196, 210, 224)
	atmosphere.Decay = Color3.fromRGB(186, 156, 120)
	atmosphere.Glare = 0.32
	atmosphere.Haze = 1.15

	local bloom = one("BloomEffect") :: BloomEffect
	bloom.Intensity = 0.35
	bloom.Size = 18
	bloom.Threshold = 1.1

	local sunrays = one("SunRaysEffect") :: SunRaysEffect
	sunrays.Intensity = 0.08
	sunrays.Spread = 0.85

	local color = one("ColorCorrectionEffect") :: ColorCorrectionEffect
	color.TintColor = Color3.fromRGB(255, 236, 214)
	color.Saturation = 0.08
	color.Contrast = 0.04
	color.Brightness = 0.02
end

local function buildOcean(parent: Instance, sea: number)
	local geometry = Instance.new("Folder")
	geometry.Name = "Ocean"
	geometry.Parent = parent

	local chunk = 1800
	local thickness = 48
	local minX = Config.World.OceanMinX
	local maxX = Config.World.OceanMaxX
	local half = Config.World.OceanHalfWidth
	local x = minX
	while x < maxX do
		local sizeX = math.min(chunk, maxX - x)
		local z = -half
		while z < half do
			local sizeZ = math.min(chunk, half - z)
			local center = Vector3.new(x + sizeX * 0.5, sea - thickness * 0.5, z + sizeZ * 0.5)
			local tile = part({
				name = "Water",
				size = Vector3.new(sizeX, thickness, sizeZ),
				position = center,
				color = if (math.floor(x / chunk) + math.floor(z / chunk)) % 2 == 0
					then WATER
					else WATER_DEEP,
				material = Enum.Material.Glass,
				transparency = 0.35,
				parent = geometry,
			})
			tile.Reflectance = 0.18
			z += chunk
		end
		x += chunk
	end
end

local function buildIsland(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "LaunchIsland"
	folder.Parent = parent

	-- Column and cap stop at the grass line so the deck is the highest walkable surface.
	part({
		name = "Cliff",
		size = Vector3.new(64, 46, 52),
		position = Vector3.new(-8, 6, 0),
		color = STONE_DARK,
		material = Enum.Material.Slate,
		parent = folder,
	})
	part({
		name = "Cap",
		size = Vector3.new(80, 12, 68),
		position = Vector3.new(-10, 34, 0),
		color = STONE,
		material = Enum.Material.Slate,
		parent = folder,
	})
	part({
		name = "Grass",
		size = Vector3.new(54, 2, 58),
		position = Vector3.new(-18, Config.World.LaunchDeckY + 1, 0),
		color = GRASS,
		material = Enum.Material.Grass,
		parent = folder,
	})
	part({
		name = "Deck",
		size = Vector3.new(28, 1.4, 32),
		position = Vector3.new(22, Config.World.LaunchDeckY + 1.3, 0),
		color = WOOD,
		material = Enum.Material.WoodPlanks,
		parent = folder,
	})
	part({
		name = "DeckLip",
		size = Vector3.new(8, 1.4, 20),
		position = Vector3.new(40, Config.World.LaunchDeckY + 1.3, 0),
		color = WOOD_DARK,
		material = Enum.Material.WoodPlanks,
		parent = folder,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = Config.Names.Spawn
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(-24, Config.World.LaunchDeckY + 2.5, 12)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Color = WOOD_DARK
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	local plaque = part({
		name = "Plaque",
		size = Vector3.new(0.6, 4.5, 9),
		cframe = CFrame.new(-18, Config.World.LaunchDeckY + 6, -18),
		color = INK,
		material = Enum.Material.Wood,
		canCollide = false,
		parent = folder,
	})
	surfaceText(plaque, Enum.NormalId.Right, "Fly for the sun.\nDon't melt.", CREAM, 28)
	surfaceText(plaque, Enum.NormalId.Left, "Fly for the sun.\nDon't melt.", CREAM, 28)

	for index, z in { -8, 8 } do
		part({
			name = "Brazier" .. tostring(index),
			size = Vector3.new(1.4, 2.2, 1.4),
			position = Vector3.new(-2, Config.World.LaunchDeckY + 3.2, z),
			color = STONE,
			material = Enum.Material.Slate,
			canCollide = false,
			parent = folder,
		})
		local flame = part({
			name = "Flame",
			size = Vector3.new(0.8, 0.8, 0.8),
			position = Vector3.new(-2, Config.World.LaunchDeckY + 4.6, z),
			color = Color3.fromRGB(255, 150, 60),
			material = Enum.Material.Neon,
			canCollide = false,
			shape = Enum.PartType.Ball,
			parent = folder,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 90)
		light.Range = 16
		light.Brightness = 1.4
		light.Parent = flame
	end

	-- Chevrons on the deck, pointing +X.
	for step = 0, 2 do
		part({
			name = "Chevron",
			size = Vector3.new(1.6, 0.2, 3.2),
			cframe = CFrame.new(34 + step * 2.6, Config.World.LaunchDeckY + 2.15, 0)
				* CFrame.Angles(0, 0, math.rad(-18)),
			color = GOLD,
			material = Enum.Material.Neon,
			canCollide = false,
			parent = folder,
		})
	end

	return spawn
end

local function buildCatapult(parent: Instance): (BasePart, ProximityPrompt)
	local folder = Instance.new("Folder")
	folder.Name = "Catapult"
	folder.Parent = parent

	local deckTop = Config.World.LaunchDeckY + 2
	local pouch = part({
		name = Config.Names.Pouch,
		size = Vector3.new(4.2, 0.7, 4.2),
		position = Vector3.new(20, deckTop + 0.4, 0),
		color = Color3.fromRGB(58, 42, 32),
		material = Enum.Material.Wood,
		canCollide = false,
		parent = folder,
	})
	-- The pouch must not trip the flyer, but the prompt still needs a query hit.
	pouch.CanQuery = true

	local function post(name: string, z: number): Part
		return part({
			name = name,
			size = Vector3.new(1.3, 8.5, 1.3),
			position = Vector3.new(30, deckTop + 4.2, z),
			color = WOOD_DARK,
			material = Enum.Material.Wood,
			canCollide = false,
			parent = folder,
		})
	end

	-- Wide enough that the feather panels clear the forks on the way out.
	local leftPost = post("PostLeft", -12)
	local rightPost = post("PostRight", 12)

	local function band(from: BasePart, fromOffset: Vector3, toOffset: Vector3, name: string)
		local a0 = Instance.new("Attachment")
		a0.Name = name .. "Start"
		a0.Position = fromOffset
		a0.Parent = from
		local a1 = Instance.new("Attachment")
		a1.Name = name .. "End"
		a1.Position = toOffset
		a1.Parent = pouch
		local beam = Instance.new("Beam")
		beam.Name = name
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 0.28
		beam.Width1 = 0.18
		beam.FaceCamera = true
		beam.Segments = 10
		beam.Color = ColorSequence.new(Color3.fromRGB(36, 32, 30))
		beam.Transparency = NumberSequence.new(0.05)
		beam.Parent = pouch
	end

	band(leftPost, Vector3.new(0, 3.4, 0), Vector3.new(0, 0.45, -1.5), "BandLeft")
	band(rightPost, Vector3.new(0, 3.4, 0), Vector3.new(0, 0.45, 1.5), "BandRight")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Config.Names.CatapultPrompt
	prompt.ActionText = "Climb in"
	prompt.ObjectText = "Slingshot"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pouch

	local highlight = Instance.new("Highlight")
	highlight.Name = "Cue"
	highlight.FillColor = GOLD
	highlight.OutlineColor = GOLD
	highlight.FillTransparency = 0.82
	highlight.OutlineTransparency = 0.2
	highlight.Parent = pouch

	return pouch, prompt
end

local function buildShop(parent: Instance): ProximityPrompt
	local folder = Instance.new("Folder")
	folder.Name = "Shop"
	folder.Parent = parent

	local counter = part({
		name = "Counter",
		size = Vector3.new(8, 4, 3.2),
		position = Vector3.new(-10, Config.World.LaunchDeckY + 4, 22),
		color = WOOD,
		material = Enum.Material.WoodPlanks,
		parent = folder,
	})
	local board = part({
		name = Config.Names.ShopBoard,
		size = Vector3.new(10, 8, 0.6),
		cframe = CFrame.new(-10, Config.World.LaunchDeckY + 10, 24.6),
		color = INK,
		material = Enum.Material.Wood,
		parent = folder,
	})
	part({
		name = "Awning",
		size = Vector3.new(9, 0.4, 5),
		position = Vector3.new(-10, Config.World.LaunchDeckY + 14.4, 22.4),
		color = Color3.fromRGB(150, 54, 42),
		material = Enum.Material.Fabric,
		canCollide = false,
		parent = folder,
	})

	local function column(face: Enum.NormalId)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Prices"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 42
		gui.LightInfluence = 0.25
		gui.Parent = board

		local root = Instance.new("Frame")
		root.BackgroundTransparency = 1
		root.Size = UDim2.fromScale(1, 1)
		root.Parent = gui

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.22)
		title.Font = Enum.Font.GothamBold
		title.Text = "WINGWRIGHT"
		title.TextColor3 = GOLD
		title.TextScaled = true
		title.Parent = root

		for index, id in Config.UpgradeOrder do
			local row = Instance.new("TextLabel")
			row.Name = "Row_" .. id
			row.BackgroundTransparency = 1
			row.Position = UDim2.fromScale(0.06, 0.24 + (index - 1) * 0.16)
			row.Size = UDim2.fromScale(0.88, 0.14)
			row.Font = Enum.Font.Gotham
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextColor3 = CREAM
			row.TextScaled = true
			row.Text = Config.Upgrades[id].DisplayName
			row.Parent = root
		end
	end

	-- Thin along Z, so the faces toward and away from the counter are Front and Back.
	column(Enum.NormalId.Front)
	column(Enum.NormalId.Back)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Config.Names.ShopPrompt
	prompt.ActionText = "Browse upgrades"
	prompt.ObjectText = "Wingwright"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	return prompt
end

local function buildCourse(parent: Instance, originX: number, sea: number)
	local folder = Instance.new("Folder")
	folder.Name = "Course"
	folder.Parent = parent

	local distance = Config.World.MarkerSpacing
	while distance <= Config.World.MarkerMaxDistance do
		local x = originX + distance
		local pole = part({
			name = "Marker_" .. tostring(distance),
			size = Vector3.new(0.55, 18, 0.55),
			position = Vector3.new(x, sea + 9, 0),
			color = CREAM,
			material = Enum.Material.Wood,
			canCollide = false,
			parent = folder,
		})
		part({
			name = "Buoy",
			size = Vector3.new(1.2, 3.4, 3.4),
			cframe = CFrame.new(x, sea + 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			color = GOLD,
			material = Enum.Material.Wood,
			canCollide = false,
			shape = Enum.PartType.Cylinder,
			parent = folder,
		})
		local sign = part({
			name = "MarkerSign",
			size = Vector3.new(0.4, 2.6, 7),
			position = Vector3.new(x, sea + 16.2, 0),
			color = INK,
			material = Enum.Material.Wood,
			canCollide = false,
			parent = folder,
		})
		local label = tostring(distance) .. " m"
		surfaceText(sign, Enum.NormalId.Left, label, GOLD, 32)
		surfaceText(sign, Enum.NormalId.Right, label, GOLD, 32)
		pole.CastShadow = false
		distance += Config.World.MarkerSpacing
	end

	local islands = {
		{ 240, 110, 34, 5 },
		{ 520, -150, 46, 6 },
		{ 980, 70, 38, 5 },
		{ 1460, -90, 62, 8 },
		{ 2100, 160, 44, 6 },
		{ 2860, -30, 80, 7 },
		{ 3700, 120, 50, 6 },
		{ 4700, -140, 70, 9 },
		{ 5900, 40, 48, 6 },
		{ 7300, -80, 90, 8 },
		{ 8800, 90, 56, 7 },
	}
	for index, spot in islands do
		local x, z, radius, lift = spot[1], spot[2], spot[3], spot[4]
		local rockHeight = 8 + lift
		local rockCenterY = sea - 1
		local rockTop = rockCenterY + rockHeight * 0.5
		part({
			name = "IsleRock_" .. tostring(index),
			size = Vector3.new(radius, rockHeight, radius * 0.82),
			position = Vector3.new(originX + x, rockCenterY, z),
			color = STONE,
			material = Enum.Material.Slate,
			parent = folder,
		})
		part({
			name = "IsleSand_" .. tostring(index),
			size = Vector3.new(radius * 0.78, 2, radius * 0.62),
			position = Vector3.new(originX + x, rockTop + 1, z),
			color = SAND,
			material = Enum.Material.Sand,
			parent = folder,
		})
	end

	-- Distant rock silhouettes. They do not collide; they are only there to look at.
	for index = 1, 8 do
		local x = originX + 400 + index * 1100
		local side = if index % 2 == 0 then 1 else -1
		part({
			name = "Horizon",
			size = Vector3.new(180 + index * 20, 90 + (index % 3) * 40, 140),
			position = Vector3.new(x, sea + 20, side * (Config.World.OceanHalfWidth - 80)),
			color = Color3.fromRGB(78, 84, 102),
			material = Enum.Material.Slate,
			canCollide = false,
			parent = folder,
		})
	end
end

local function buildSun(parent: Instance, originX: number, sea: number)
	local folder = Instance.new("Folder")
	folder.Name = "Sun"
	folder.Parent = parent

	local center = Vector3.new(originX + 4200, sea + 620, 0)
	local sun = part({
		name = "Sun",
		size = Vector3.new(220, 220, 220),
		position = center,
		color = Color3.fromRGB(255, 176, 64),
		material = Enum.Material.Neon,
		canCollide = false,
		shape = Enum.PartType.Ball,
		parent = folder,
	})
	sun.CastShadow = false
	part({
		name = "SunHaze",
		size = Vector3.new(340, 340, 340),
		position = center,
		color = Color3.fromRGB(255, 214, 140),
		material = Enum.Material.Neon,
		transparency = 0.72,
		canCollide = false,
		shape = Enum.PartType.Ball,
		parent = folder,
	}).CastShadow =
		false

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SunLabel"
	billboard.Size = UDim2.fromOffset(240, 64)
	billboard.StudsOffset = Vector3.new(0, 150, 0)
	billboard.MaxDistance = 12000
	billboard.LightInfluence = 0
	billboard.Parent = sun

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "THE SUN"
	label.TextColor3 = Color3.fromRGB(255, 226, 170)
	label.TextStrokeTransparency = 0.6
	label.TextScaled = true
	label.Parent = billboard
end

function WorldBuilder.build(): World
	applyLighting()

	local existing = workspace:FindFirstChild(Config.Names.WorldFolder)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = Config.Names.WorldFolder
	folder.Parent = workspace

	local debris = Instance.new("Folder")
	debris.Name = Config.Names.Debris
	debris.Parent = folder

	local sea = Config.World.SeaLevel
	buildOcean(folder, sea)
	local spawnPad = buildIsland(folder)
	local pouch, catapultPrompt = buildCatapult(folder)
	local shopPrompt = buildShop(folder)
	-- Distance zero is the slingshot pouch, so the 100 m buoy matches the HUD.
	local origin = pouch.Position
	buildCourse(folder, origin.X, sea)
	buildSun(folder, origin.X, sea)

	print("[ICARUS] Launch platform ready. The sun is downrange.")

	return {
		folder = folder,
		pouch = pouch,
		spawnPad = spawnPad,
		launchOrigin = origin,
		shopPrompt = shopPrompt,
		catapultPrompt = catapultPrompt,
	}
end

return WorldBuilder
