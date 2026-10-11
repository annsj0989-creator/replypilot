--!strict
--[[
	WorldBuilder — the PHASE 0 test map: warm desert terrain, a small camp, a
	half-buried temple on the horizon and a staked-out frame around each dig slot.

	Everything here is placeholder set dressing built from terrain and parts so the
	dig test does not look like a grey baseplate. PHASE 2 replaces the props with
	proper models.

	If the place already contains terrain (someone sculpted it in Studio), the
	desert is not regenerated; dig zones are always written by PlotService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Zone = require(ReplicatedStorage.Shared.Zone)

local WorldBuilder = {}

local terrain = Workspace.Terrain
local SURFACE_Y = GameConfig.Dig.SurfaceY

local COLORS = {
	sand = Color3.fromRGB(229, 192, 126),
	packed = Color3.fromRGB(196, 136, 88),
	rock = Color3.fromRGB(160, 132, 104),
	limestone = Color3.fromRGB(226, 205, 160),
	wood = Color3.fromRGB(124, 92, 60),
	darkWood = Color3.fromRGB(92, 66, 44),
	canvas = Color3.fromRGB(236, 220, 186),
	rope = Color3.fromRGB(205, 180, 128),
	shadow = Color3.fromRGB(40, 30, 24),
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function cylinder(
	parent: Instance,
	name: string,
	length: number,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = part(parent, name, Vector3.new(length, diameter, diameter), cframe, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Distance on the ground from (x, z) to the nearest dig zone.
local function distanceToZones(x: number, z: number): number
	local best = math.huge
	for slot = 1, Zone.slotCount() do
		local zone = Zone.fromSlot(slot)
		if zone then
			local dx = math.max(zone.minX - x, 0, x - (zone.minX + zone.size))
			local dz = math.max(zone.minZ - z, 0, z - (zone.minZ + zone.size))
			best = math.min(best, math.sqrt(dx * dx + dz * dz))
		end
	end
	return best
end

-- A sand mound whose ground footprint stays clear of the dig zones.
local function dune(x: number, z: number, radius: number, heightRatio: number)
	local sink = radius * (1 - heightRatio)
	local footprint = math.sqrt(radius * radius - sink * sink)
	if distanceToZones(x, z) < footprint + 12 then
		return
	end
	terrain:FillBall(Vector3.new(x, SURFACE_Y - sink, z), radius, Enum.Material.Sand)
end

local function buildDesert()
	-- Base sand slab, top exactly at SurfaceY (voxel aligned).
	terrain:FillBlock(CFrame.new(0, SURFACE_Y - 16, 0), Vector3.new(1024, 32, 1024), Enum.Material.Sand)

	local random = Random.new(20261011)
	for _ = 1, 34 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(170, 350)
		dune(
			math.cos(angle) * distance,
			math.sin(angle) * distance,
			random:NextNumber(26, 64),
			random:NextNumber(0.25, 0.4)
		)
	end

	-- A few weathered boulders at the camp's edges.
	for _, boulder in { { -142, 4, 7 }, { 138, -8, 9 }, { -150, -64, 5 }, { 150, 70, 6 }, { 0, 150, 8 } } do
		terrain:FillBall(Vector3.new(boulder[1], SURFACE_Y - 1.5, boulder[2]), boulder[3], Enum.Material.Rock)
	end
end

-- A stepped temple far to the north, half swallowed by dunes: the long-term goal on the horizon.
local function buildDistantTemple(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "DistantTemple"
	folder.Parent = parent

	local center = Vector3.new(0, SURFACE_Y - 18, -380)
	local tiers =
		{ Vector3.new(140, 14, 100), Vector3.new(112, 14, 80), Vector3.new(84, 14, 60), Vector3.new(56, 14, 40) }
	local y = center.Y
	for index, size in tiers do
		part(
			folder,
			"Tier" .. index,
			size,
			CFrame.new(center.X, y + size.Y / 2, center.Z),
			COLORS.limestone,
			Enum.Material.Limestone
		)
		y += size.Y
	end
	local shrine = part(
		folder,
		"Shrine",
		Vector3.new(26, 16, 22),
		CFrame.new(center.X, y + 8, center.Z),
		COLORS.limestone,
		Enum.Material.Limestone
	)
	part(
		folder,
		"Doorway",
		Vector3.new(8, 11, 1),
		shrine.CFrame * CFrame.new(0, -2.5, 10.6),
		COLORS.shadow,
		Enum.Material.Slate
	)

	-- Columns in front of the temple, some broken and leaning.
	for index, column in { { -50, 34, 0 }, { -25, 22, 8 }, { 25, 30, -6 }, { 50, 16, 14 } } do
		local height = column[2]
		cylinder(
			folder,
			"Column" .. index,
			height,
			6,
			CFrame.new(center.X + column[1], SURFACE_Y + height / 2 - 4, center.Z + 70)
				* CFrame.Angles(math.rad(column[3]), 0, math.rad(90)),
			COLORS.limestone,
			Enum.Material.Limestone
		)
	end

	-- Dunes burying the flanks.
	terrain:FillBall(Vector3.new(-82, SURFACE_Y - 40, -350), 72, Enum.Material.Sand)
	terrain:FillBall(Vector3.new(88, SURFACE_Y - 44, -360), 78, Enum.Material.Sand)
end

local function buildCamp(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Camp"
	folder.Parent = parent

	-- Archaeologist's tent (open A-frame).
	local tentX, tentZ = -26, 0
	local halfWidth, height, length = 4.5, 7, 12
	local slant = math.sqrt(halfWidth * halfWidth + height * height)
	local lean = math.atan2(halfWidth, height)
	for side = -1, 1, 2 do
		local roof = part(
			folder,
			"TentRoof",
			Vector3.new(0.25, slant, length),
			CFrame.new(tentX + side * halfWidth / 2, SURFACE_Y + height / 2, tentZ) * CFrame.Angles(0, 0, side * lean),
			COLORS.canvas,
			Enum.Material.Fabric
		)
		roof.CastShadow = true
	end
	-- Cylinders run along X; turn the ridge pole to run along the tent (Z).
	cylinder(
		folder,
		"TentRidge",
		length + 1,
		0.35,
		CFrame.new(tentX, SURFACE_Y + height, tentZ) * CFrame.Angles(0, math.rad(90), 0),
		COLORS.wood,
		Enum.Material.Wood
	)
	for _, z in { -length / 2, length / 2 } do
		part(
			folder,
			"TentPole",
			Vector3.new(0.3, height, 0.3),
			CFrame.new(tentX, SURFACE_Y + height / 2, tentZ + z),
			COLORS.wood,
			Enum.Material.Wood
		)
	end

	-- Tool workbench with crates.
	local benchX, benchZ = 18, -4
	part(
		folder,
		"BenchTop",
		Vector3.new(8, 0.5, 4),
		CFrame.new(benchX, SURFACE_Y + 3, benchZ),
		COLORS.wood,
		Enum.Material.WoodPlanks
	)
	for _, leg in { { -3.5, -1.6 }, { 3.5, -1.6 }, { -3.5, 1.6 }, { 3.5, 1.6 } } do
		part(
			folder,
			"BenchLeg",
			Vector3.new(0.4, 2.8, 0.4),
			CFrame.new(benchX + leg[1], SURFACE_Y + 1.4, benchZ + leg[2]),
			COLORS.darkWood,
			Enum.Material.Wood
		)
	end
	part(
		folder,
		"Crate",
		Vector3.new(3, 3, 3),
		CFrame.new(25, SURFACE_Y + 1.5, -2) * CFrame.Angles(0, math.rad(12), 0),
		COLORS.wood,
		Enum.Material.WoodPlanks
	)
	part(
		folder,
		"Crate",
		Vector3.new(3, 3, 3),
		CFrame.new(24, SURFACE_Y + 1.5, 2) * CFrame.Angles(0, math.rad(-8), 0),
		COLORS.wood,
		Enum.Material.WoodPlanks
	)
	part(
		folder,
		"Crate",
		Vector3.new(2.4, 2.4, 2.4),
		CFrame.new(24.6, SURFACE_Y + 4.2, -0.2) * CFrame.Angles(0, math.rad(25), 0),
		COLORS.darkWood,
		Enum.Material.WoodPlanks
	)

	-- Half-buried columns hinting at the city below.
	for index, column in { { -64, 30, 18, 70 }, { 70, -28, 14, 60 }, { -96, -24, 10, 80 }, { 98, 34, 16, 65 } } do
		cylinder(
			folder,
			"BuriedColumn" .. index,
			column[3],
			5,
			CFrame.new(column[1], SURFACE_Y + 1, column[2])
				* CFrame.Angles(0, math.rad(column[4]), math.rad(column[4] - 50)),
			COLORS.limestone,
			Enum.Material.Limestone
		)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CampSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, SURFACE_Y + 0.5, 0)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder
end

-- Stakes and rope around a dig zone, plus the owner's sign. Returns the sign's label.
function WorldBuilder.buildPlotFrame(zone: Zone.Zone, parent: Instance): TextLabel
	local folder = Instance.new("Folder")
	folder.Name = "Frame"
	folder.Parent = parent

	local inset = -1.5 -- stakes sit just outside the zone so digging never leaves them floating
	local minX, minZ = zone.minX + inset, zone.minZ + inset
	local maxX, maxZ = zone.minX + zone.size - inset, zone.minZ + zone.size - inset
	local corners = {
		Vector3.new(minX, 0, minZ),
		Vector3.new(maxX, 0, minZ),
		Vector3.new(maxX, 0, maxZ),
		Vector3.new(minX, 0, maxZ),
	}
	local ropeY = SURFACE_Y + 2.2

	for index, from in corners do
		local to = corners[index % 4 + 1]
		local length = (to - from).Magnitude
		local stakes = math.max(1, math.floor(length / 16))
		for step = 0, stakes - 1 do
			local point = from:Lerp(to, step / stakes)
			part(
				folder,
				"Stake",
				Vector3.new(0.5, 3.4, 0.5),
				CFrame.new(point.X, SURFACE_Y + 1.1, point.Z),
				COLORS.wood,
				Enum.Material.Wood
			)
		end
		local rope = part(
			folder,
			"Rope",
			Vector3.new(0.14, 0.14, length),
			CFrame.lookAt(Vector3.new(from.X, ropeY, from.Z), Vector3.new(to.X, ropeY, to.Z))
				* CFrame.new(0, 0, -length / 2),
			COLORS.rope,
			Enum.Material.Fabric
		)
		rope.CanCollide = false
		rope.CanQuery = false
	end

	-- Owner sign beside the spawn point, facing the camp.
	local spawnX, _, spawnZ = Zone.spawnPoint(zone)
	local signPosition = Vector3.new(spawnX + 9, SURFACE_Y + 3.4, spawnZ - zone.campSide * 4)
	local board = part(
		folder,
		"SignBoard",
		Vector3.new(7, 2.6, 0.3),
		CFrame.lookAt(signPosition, signPosition + Vector3.new(0, 0, zone.campSide)),
		COLORS.wood,
		Enum.Material.WoodPlanks
	)
	for _, side in { -2.8, 2.8 } do
		part(
			folder,
			"SignPost",
			Vector3.new(0.35, 3.6, 0.35),
			board.CFrame * CFrame.new(side, -1.5, 0.3),
			COLORS.darkWood,
			Enum.Material.Wood
		)
	end

	-- The dig aim raycast should pass through the frame to the sand.
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanQuery = false
		end
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	label.TextColor3 = Color3.fromRGB(255, 240, 210)
	label.Text = ""
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.14, 0)
	padding.PaddingBottom = UDim.new(0.14, 0)
	padding.Parent = label

	return label
end

function WorldBuilder.build()
	terrain:SetMaterialColor(Enum.Material.Sand, COLORS.sand)
	terrain:SetMaterialColor(Enum.Material.Sandstone, COLORS.packed)
	terrain:SetMaterialColor(Enum.Material.Rock, COLORS.rock)

	if terrain:CountCells() == 0 then
		buildDesert()
	end

	local world = Instance.new("Folder")
	world.Name = "World"
	buildCamp(world)
	buildDistantTemple(world)
	world.Parent = Workspace
end

return WorldBuilder
