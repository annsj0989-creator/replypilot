--!strict
--[[
	AimIndicator — the ring on the sand that shows exactly where and how wide the
	next swing will dig. Warm white = valid, red = out of reach or outside your zone.
	Drawn on top of terrain so it stays readable on the slopes of a crater.
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AimIndicator = {}

local VALID_COLOR = Color3.fromRGB(255, 238, 196)
local INVALID_COLOR = Color3.fromRGB(255, 104, 84)
local RING_WIDTH = 0.35
local FLAT = CFrame.Angles(math.rad(90), 0, 0) -- cylinder adornments run along Z

local anchor: Part
local ring: CylinderHandleAdornment
local disc: CylinderHandleAdornment
local position: Vector3? = nil
local currentRadius = 0

function AimIndicator.init(parent: Instance)
	anchor = Instance.new("Part")
	anchor.Name = "AimAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = parent

	ring = Instance.new("CylinderHandleAdornment")
	ring.Name = "Ring"
	ring.Adornee = anchor
	ring.CFrame = FLAT
	ring.Height = 0.12
	ring.AlwaysOnTop = true
	ring.ZIndex = 2
	ring.Transparency = 0.2
	ring.Color3 = VALID_COLOR
	ring.Parent = anchor

	disc = Instance.new("CylinderHandleAdornment")
	disc.Name = "Fill"
	disc.Adornee = anchor
	disc.CFrame = FLAT
	disc.Height = 0.05
	disc.AlwaysOnTop = true
	disc.ZIndex = 1
	disc.Transparency = 0.86
	disc.Color3 = VALID_COLOR
	disc.Parent = anchor

	AimIndicator.hide()
end

function AimIndicator.hide()
	ring.Visible = false
	disc.Visible = false
	position = nil
end

function AimIndicator.update(target: Vector3, radius: number, valid: boolean, dt: number, smoothing: number)
	local previous = position
	local current: Vector3 = if previous and (previous - target).Magnitude <= 12
		then previous:Lerp(target, 1 - math.exp(-smoothing * dt))
		else target
	position = current
	anchor.CFrame = CFrame.new(current + Vector3.new(0, 0.15, 0))

	if radius ~= currentRadius then
		currentRadius = radius
		ring.Radius = radius
		ring.InnerRadius = math.max(0, radius - RING_WIDTH)
		disc.Radius = radius
	end

	local color = if valid then VALID_COLOR else INVALID_COLOR
	ring.Color3 = color
	disc.Color3 = color
	ring.Transparency = if valid then 0.2 else 0.45
	ring.Visible = true
	disc.Visible = valid
end

-- Small squeeze on every swing so the ring feels connected to the shovel.
function AimIndicator.pulse()
	if currentRadius <= 0 then
		return
	end
	ring.Radius = currentRadius * 0.82
	ring.InnerRadius = math.max(0, currentRadius * 0.82 - RING_WIDTH)
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Radius = currentRadius, InnerRadius = math.max(0, currentRadius - RING_WIDTH) })
		:Play()
end

-- Parent for client-only visuals; kept out of raycasts by the include list.
function AimIndicator.defaultParent(): Instance
	return Workspace.CurrentCamera or Workspace
end

return AimIndicator
