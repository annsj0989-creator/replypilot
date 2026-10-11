--!strict
--[[
	Effects — client-only VFX. Nothing here is replicated or simulated by physics:
	all debris is particles, so a swing costs a few dozen particles and zero parts.

	Textures are engine-bundled (rbxasset://textures/particles/...), confirmed in
	the Roblox client file manifest, so no external asset IDs are needed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Effects = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local SAND = Color3.fromRGB(229, 192, 126)
local SAND_DARK = Color3.fromRGB(205, 162, 98)
local PACKED = Color3.fromRGB(196, 136, 88)
local GOLD = Color3.fromRGB(255, 214, 120)
local TEAL = Color3.fromRGB(80, 230, 210)

local folder: Folder
local hitAnchor: Part
local hitAttachment: Attachment
local dust: ParticleEmitter
local chunks: ParticleEmitter
local sparkles: ParticleEmitter
local glints: { [string]: Part } = {}

local function numberSequence(points: { { number } }): NumberSequence
	local keypoints = {}
	for _, point in points do
		table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2], point[3] or 0))
	end
	return NumberSequence.new(keypoints)
end

local function anchorPart(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Parent = folder
	return part
end

local function makeDust(parent: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Dust"
	emitter.Texture = SMOKE
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(SAND, SAND_DARK)
	emitter.LightInfluence = 1
	emitter.Size = numberSequence({ { 0, 1.1, 0.3 }, { 1, 3.4, 0.6 } })
	emitter.Transparency = numberSequence({ { 0, 0.45 }, { 0.5, 0.65 }, { 1, 1 } })
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(3, 7)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Acceleration = Vector3.new(0, -3, 0)
	emitter.Drag = 3
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = parent
	return emitter
end

local function makeChunks(parent: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Chunks"
	emitter.Texture = SQUARE
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(SAND)
	emitter.LightInfluence = 1
	emitter.Size = numberSequence({ { 0, 0.32, 0.12 }, { 1, 0.22, 0.08 } })
	emitter.Transparency = numberSequence({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } })
	emitter.Lifetime = NumberRange.new(0.45, 0.75)
	emitter.Speed = NumberRange.new(11, 18)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Acceleration = Vector3.new(0, -60, 0)
	emitter.Drag = 0.6
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-260, 260)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = parent
	return emitter
end

local function makeSparkles(parent: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Texture = SPARKLE
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(GOLD, TEAL)
	emitter.LightEmission = 0.8
	emitter.LightInfluence = 0
	emitter.Size = numberSequence({ { 0, 0.7 }, { 0.3, 0.9 }, { 1, 0 } })
	emitter.Transparency = numberSequence({ { 0, 0.1 }, { 1, 1 } })
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(2, 6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 2
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Parent = parent
	return emitter
end

local function flash(position: Vector3, color: Color3, brightness: number, range: number, duration: number)
	local holder = anchorPart("Flash")
	holder.CFrame = CFrame.new(position)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 0
	light.Shadows = false
	light.Parent = holder
	local rise =
		TweenService:Create(light, TweenInfo.new(duration * 0.25, Enum.EasingStyle.Quad), { Brightness = brightness })
	local fall = TweenService:Create(light, TweenInfo.new(duration * 0.75, Enum.EasingStyle.Quad), { Brightness = 0 })
	rise.Completed:Connect(function()
		fall:Play()
	end)
	fall.Completed:Connect(function()
		holder:Destroy()
	end)
	rise:Play()
end

function Effects.init(parent: Instance)
	folder = Instance.new("Folder")
	folder.Name = "ClientEffects"
	folder.Parent = parent

	hitAnchor = anchorPart("HitAnchor")
	hitAttachment = Instance.new("Attachment")
	hitAttachment.Parent = hitAnchor
	dust = makeDust(hitAttachment)
	chunks = makeChunks(hitAttachment)
	sparkles = makeSparkles(hitAttachment)
end

-- Attachment that sits where the last swing landed (positional sounds use it).
function Effects.hitAttachment(): Attachment
	return hitAttachment
end

function Effects.digAt(position: Vector3, toolLevel: number)
	local dig = GameConfig.Dig
	local deep = position.Y < dig.SurfaceY - dig.StrataDepth
	hitAnchor.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0))
	chunks.Color = if deep then ColorSequence.new(PACKED, SAND_DARK) else ColorSequence.new(SAND, SAND_DARK)
	local scale = if toolLevel >= 2 then 1.6 else 1
	dust:Emit(math.floor(5 * scale))
	chunks:Emit(math.floor(9 * scale))
end

-- First sight of an artifact: a sparkle burst, a soft flash and a lingering glint.
function Effects.glimpse(id: string, position: Vector3)
	hitAnchor.CFrame = CFrame.new(position)
	sparkles:Emit(18)
	flash(position, GOLD, 2, 10, 0.8)
	Effects.startGlint(id, position)
end

-- A slow trickle of sparkles marking a half-buried artifact until it is found.
function Effects.startGlint(id: string, position: Vector3)
	if glints[id] then
		return
	end
	local holder = anchorPart("Glint_" .. id)
	holder.CFrame = CFrame.new(position)
	local emitter = makeSparkles(holder)
	emitter.Rate = 3
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Enabled = true
	glints[id] = holder
end

function Effects.stopGlint(id: string)
	local holder = glints[id]
	if holder then
		glints[id] = nil
		holder:Destroy()
	end
end

-- Artifact fully uncovered: the last sand bursts away, sparkles and a warm flash.
function Effects.discover(id: string, position: Vector3, model: Model?)
	Effects.stopGlint(id)
	local base = position - Vector3.new(0, 3, 0)
	hitAnchor.CFrame = CFrame.new(base)
	chunks.Color = ColorSequence.new(SAND, SAND_DARK)
	chunks:Emit(36)
	dust:Emit(22)
	hitAnchor.CFrame = CFrame.new(position)
	sparkles:Emit(50)
	flash(position, GOLD, 3, 18, 1.4)

	if model then
		local highlight = Instance.new("Highlight")
		highlight.Adornee = model
		highlight.FillColor = GOLD
		highlight.OutlineColor = Color3.fromRGB(255, 244, 214)
		highlight.FillTransparency = 0.55
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = folder
		local fade = TweenService:Create(
			highlight,
			TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ FillTransparency = 1, OutlineTransparency = 1 }
		)
		fade.Completed:Connect(function()
			highlight:Destroy()
		end)
		fade:Play()
	end
end

return Effects
