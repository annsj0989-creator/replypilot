--!strict
--[[
	ArtifactFactory — produces artifact models.

	If ServerStorage.ArtifactTemplates contains a Model with the artifact's Id, that
	model is used (drop in a Creator Store or custom model with its pivot at the
	bottom centre and its front facing -Z). Otherwise a stylised placeholder is
	built from parts so PHASE 0 works with zero external assets.

	Optional parts the game looks for by name: "Gem" (switched to Neon on discovery)
	containing a PointLight (lit on discovery).
]]

local ServerStorage = game:GetService("ServerStorage")

local ArtifactFactory = {}

local GOLD = Color3.fromRGB(232, 178, 58)
local DARK_GOLD = Color3.fromRGB(196, 140, 38)
local STONE = Color3.fromRGB(214, 196, 160)
local TEAL = Color3.fromRGB(40, 205, 190)

local function addPart(
	model: Model,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = offset
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Golden Sun Idol: pedestal, body, head, sun disc and a teal gem. 6.4 studs tall.
local function buildSunIdol(): Model
	local model = Instance.new("Model")
	model.Name = "SunIdol"

	local pedestal =
		addPart(model, "Pedestal", Vector3.new(3.4, 1.2, 3.4), CFrame.new(0, 0.6, 0), STONE, Enum.Material.Limestone)
	addPart(model, "Trim", Vector3.new(3, 0.3, 3), CFrame.new(0, 1.35, 0), DARK_GOLD, Enum.Material.Metal)
	addPart(model, "Body", Vector3.new(2, 2.4, 1.4), CFrame.new(0, 2.7, 0), GOLD, Enum.Material.Metal)
	addPart(
		model,
		"Head",
		Vector3.new(1.7, 1.7, 1.7),
		CFrame.new(0, 4.75, 0),
		GOLD,
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	-- Cylinders run along X, so turn the disc to face forward (-Z).
	addPart(
		model,
		"SunDisc",
		Vector3.new(0.3, 3.6, 3.6),
		CFrame.new(0, 4.6, 0.6) * CFrame.Angles(0, math.rad(90), 0),
		DARK_GOLD,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	local gem = addPart(
		model,
		"Gem",
		Vector3.new(0.7, 0.7, 0.7),
		CFrame.new(0, 3, -0.72),
		TEAL,
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	gem.Transparency = 0.15

	local light = Instance.new("PointLight")
	light.Color = TEAL
	light.Range = 12
	light.Brightness = 0
	light.Shadows = false
	light.Parent = gem

	model.PrimaryPart = pedestal
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

local BUILDERS: { [string]: () -> Model } = {
	SunIdol = buildSunIdol,
}

function ArtifactFactory.create(id: string): Model
	local templates = ServerStorage:FindFirstChild("ArtifactTemplates")
	local template = templates and templates:FindFirstChild(id)
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
		-- Never trust scripts inside imported models.
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				warn(`[ArtifactFactory] removed {descendant:GetFullName()} from template {id}`)
				descendant:Destroy()
			end
		end
	else
		local builder = BUILDERS[id]
		assert(builder, `[ArtifactFactory] no template or builder for artifact {id}`)
		model = builder()
	end
	model.Name = id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("ArtifactId", id)
	return model
end

-- Discovery look: the gem lights up.
function ArtifactFactory.activate(model: Model)
	local gem = model:FindFirstChild("Gem", true)
	if gem and gem:IsA("BasePart") then
		gem.Material = Enum.Material.Neon
		gem.Transparency = 0
		local light = gem:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 1.6
		end
	end
end

return ArtifactFactory
