--!strict
--[[
	DigController — aiming and swinging.

	  PC       hold left mouse: dig where the cursor points (works with shift-lock too)
	  Touch    hold the DIG button: dig the spot in front of the character,
	           or the last spot you tapped on the sand (tap = aim, drag = camera)
	  Gamepad  hold R2: dig the spot in front of the character

	Every frame the target is validated locally with the same DigValidation rules
	the server uses (zero tolerance), and shown with the aim ring. A swing sends
	one RemoteEvent, then plays the swing animation, debris and sound immediately;
	the terrain change itself arrives from the server a moment later.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DigValidation = require(ReplicatedStorage.Shared.DigValidation)
local Zone = require(ReplicatedStorage.Shared.Zone)

local AimIndicator = require(script.Parent.AimIndicator)
local PlotWatcher = require(script.Parent.PlotWatcher)

export type InputMode = "Mouse" | "Touch" | "Gamepad"

export type Hooks = {
	onSwing: (target: Vector3, tool: GameConfig.ToolStats) -> (),
	onInputModeChanged: (mode: InputMode) -> (),
}

local DigController = {}

local player = Players.LocalPlayer
local digRequest: RemoteEvent
local hooks: Hooks
local raycastParams = RaycastParams.new()

local mouseHeld = false
local touchHeld = false
local gamepadHeld = false
local tapAim: Vector3? = nil
local tapAimTime = 0
local nextSwingTime = 0
local inputMode: InputMode = "Mouse"

local function detectInputMode(): InputMode
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.find(last.Name, "Gamepad", 1, true) then
		return "Gamepad"
	elseif
		last == Enum.UserInputType.MouseButton1
		or last == Enum.UserInputType.MouseMovement
		or last == Enum.UserInputType.Keyboard
	then
		return "Mouse"
	end
	return if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then "Touch" else "Mouse"
end

-- Held flags are not cleared here: each one is released by its own InputEnded,
-- and clearing them would drop the first press on a device that switches modes.
local function setInputMode(mode: InputMode)
	if mode ~= inputMode then
		inputMode = mode
		hooks.onInputModeChanged(mode)
	end
end

local function currentTool(): GameConfig.ToolStats
	local level = player:GetAttribute("ToolLevel")
	local tool = if type(level) == "number" then GameConfig.Tools[level] else nil
	return tool or GameConfig.Tools[1]
end

local function raycast(origin: Vector3, direction: Vector3): Vector3?
	local result = Workspace:Raycast(origin, direction, raycastParams)
	return if result then result.Position else nil
end

local function isValid(target: Vector3, root: BasePart, zone: Zone.Zone, tool: GameConfig.ToolStats): boolean
	local rootPosition = root.Position
	local ok = DigValidation.check({
		targetX = target.X,
		targetY = target.Y,
		targetZ = target.Z,
		rootX = rootPosition.X,
		rootY = rootPosition.Y,
		rootZ = rootPosition.Z,
		zoneMinX = zone.minX,
		zoneMinZ = zone.minZ,
		zoneSize = zone.size,
		zoneBottomY = zone.bottomY,
		zoneTopY = zone.topY,
		reach = tool.Reach,
		tolerance = 0,
		maxVerticalOffset = GameConfig.Network.MaxVerticalOffset,
	})
	return ok
end

-- The sand point a little in front of the character.
local function frontTarget(root: BasePart): Vector3?
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		return nil
	end
	local probe = root.Position + flat.Unit * GameConfig.Feel.FrontTargetDistance
	return raycast(probe + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0))
end

local function chooseTarget(root: BasePart, zone: Zone.Zone, tool: GameConfig.ToolStats, camera: Camera): Vector3?
	if inputMode == "Mouse" then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		return raycast(ray.Origin, ray.Direction * 400)
	end
	local aim = tapAim
	if aim then
		if os.clock() - tapAimTime < GameConfig.Feel.TapAimLifetime and isValid(aim, root, zone, tool) then
			return aim
		end
		tapAim = nil
	end
	return frontTarget(root)
end

-- Uses the default Animate script's tool-slash animation (no custom animation asset yet).
local function playSwing(character: Model)
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		local cue = Instance.new("StringValue")
		cue.Name = "toolanim"
		cue.Value = "Slash"
		cue.Parent = tool
	end
end

local function faceTarget(root: BasePart, humanoid: Humanoid, target: Vector3)
	if humanoid.MoveDirection.Magnitude > 0.1 then
		return
	end
	local position = root.Position
	local flat = Vector3.new(target.X, position.Y, target.Z)
	if (flat - position).Magnitude > 1.5 then
		root.CFrame = CFrame.lookAt(position, flat)
	end
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	local zone = PlotWatcher.getZone()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not camera
		or not zone
		or not character
		or not humanoid
		or humanoid.Health <= 0
		or not root
		or not root:IsA("BasePart")
	then
		AimIndicator.hide()
		return
	end

	local tool = currentTool()
	local target = chooseTarget(root, zone, tool, camera)
	if not target then
		AimIndicator.hide()
		return
	end

	local valid = isValid(target, root, zone, tool)
	AimIndicator.update(target, tool.Radius, valid, dt, GameConfig.Feel.AimSmoothing)

	local held = mouseHeld or touchHeld or gamepadHeld
	local now = os.clock()
	if held and valid and now >= nextSwingTime and character:FindFirstChildOfClass("Tool") then
		nextSwingTime = now + tool.Cooldown
		digRequest:FireServer(target)
		playSwing(character)
		faceTarget(root, humanoid, target)
		AimIndicator.pulse()
		hooks.onSwing(target, tool)
	end
end

function DigController.setTouchHeld(held: boolean)
	if held then
		setInputMode("Touch")
	end
	touchHeld = held
end

function DigController.init(newHooks: Hooks)
	hooks = newHooks
	digRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DigRequest") :: RemoteEvent

	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { Workspace.Terrain, Workspace:WaitForChild("Plots") }
	raycastParams.IgnoreWater = true

	AimIndicator.init(AimIndicator.defaultParent())

	inputMode = detectInputMode()
	hooks.onInputModeChanged(inputMode)
	UserInputService.LastInputTypeChanged:Connect(function()
		setInputMode(detectInputMode())
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			setInputMode("Mouse")
			mouseHeld = true
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			setInputMode("Gamepad")
			gamepadHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseHeld = false
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			gamepadHeld = false
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		mouseHeld, touchHeld, gamepadHeld = false, false, false
	end)

	-- Touch: a quick tap on the sand sets the aim point; drags stay camera controls.
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if processedByUI then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local ray = camera:ScreenPointToRay(position.X, position.Y)
		local hit = raycast(ray.Origin, ray.Direction * 400)
		if hit then
			tapAim = hit
			tapAimTime = os.clock()
		end
	end)

	RunService:BindToRenderStep("DigAim", Enum.RenderPriority.Camera.Value + 1, update)
end

return DigController
