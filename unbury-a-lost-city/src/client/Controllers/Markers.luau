--!strict
--[[
	Markers — "dig here" beacons above buried artifacts that have not been
	glimpsed yet. The marker is the only tutorial pointer: one target, one action.
]]

local TweenService = game:GetService("TweenService")

local Markers = {}

local GOLD = Color3.fromRGB(242, 193, 78)
local INK = Color3.fromRGB(52, 34, 18)
local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

local folder: Folder
local markers: { [string]: Part } = {}

function Markers.init(parent: Instance)
	folder = Instance.new("Folder")
	folder.Name = "DigMarkers"
	folder.Parent = parent
end

function Markers.show(id: string, position: Vector3, surfaceY: number, label: string)
	if markers[id] then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "Marker_" .. id
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position.X, surfaceY + 3.5, position.Z)
	holder.Parent = folder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 96)
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 220
	billboard.Parent = holder

	local bob = Instance.new("Frame")
	bob.BackgroundTransparency = 1
	bob.Size = UDim2.fromScale(1, 1)
	bob.Parent = billboard

	local pill = Instance.new("TextLabel")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 30)
	pill.BackgroundColor3 = GOLD
	pill.TextColor3 = INK
	pill.FontFace = FONT
	pill.TextSize = 17
	pill.Text = label
	pill.Parent = bob
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = pill
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = pill

	-- Downward-pointing diamond under the label.
	local arrow = Instance.new("Frame")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.new(0.5, 0, 0, 52)
	arrow.Size = UDim2.fromOffset(22, 22)
	arrow.Rotation = 45
	arrow.BackgroundColor3 = GOLD
	arrow.Parent = bob
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = arrow

	local tween = TweenService:Create(
		bob,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromOffset(0, 10) }
	)
	tween:Play()

	markers[id] = holder
end

function Markers.hide(id: string)
	local holder = markers[id]
	if holder then
		markers[id] = nil
		holder:Destroy()
	end
end

return Markers
