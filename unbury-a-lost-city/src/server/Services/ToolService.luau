--!strict
--[[
	ToolService — the shovel.

	The shovel is a normal Tool so other players see it in the character's hand,
	but its activation is ignored (ManualActivationOnly): digging input is handled
	by the client DigController so mouse, touch and gamepad all aim the same way.
	It is equipped automatically and re-equipped if it ever ends up in the backpack.

	Stats come from GameConfig.Tools[player:GetAttribute("ToolLevel")].
	The model is a placeholder built from parts; PHASE 2 swaps in a real mesh.
]]

local ToolService = {}

local WOOD = Color3.fromRGB(134, 96, 62)
local DARK_WOOD = Color3.fromRGB(96, 68, 44)
local STEEL = Color3.fromRGB(150, 156, 164)

local template: Tool

local function weldedPart(
	handle: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = handle.CFrame * offset
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = handle.Parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function buildShovel(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Shovel"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool:SetAttribute("DigTool", true)
	-- The shaft runs along the handle's Z axis. Held near the top end, pointing
	-- forward and 35 degrees down so the blade rests near the ground.
	tool.Grip = CFrame.new(0, 0, 1.6) * CFrame.Angles(math.rad(35), 0, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 4.4)
	handle.Color = WOOD
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool

	weldedPart(handle, "Blade", Vector3.new(1.25, 0.12, 1.5), CFrame.new(0, 0, -2.85), STEEL, Enum.Material.Metal)
	weldedPart(handle, "Collar", Vector3.new(0.45, 0.45, 0.5), CFrame.new(0, 0, -2.05), STEEL, Enum.Material.Metal)
	weldedPart(handle, "GripBar", Vector3.new(1, 0.25, 0.25), CFrame.new(0, 0, 2.25), DARK_WOOD, Enum.Material.Wood)
	return tool
end

function ToolService.init()
	template = buildShovel()
end

function ToolService.give(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local backpack = player:WaitForChild("Backpack")

	local tool = template:Clone()
	tool.Parent = backpack
	humanoid:EquipTool(tool)

	tool.Unequipped:Connect(function()
		task.defer(function()
			if tool.Parent == backpack and humanoid.Health > 0 and humanoid:IsDescendantOf(game) then
				humanoid:EquipTool(tool)
			end
		end)
	end)
end

return ToolService
