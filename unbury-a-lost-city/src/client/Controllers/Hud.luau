--!strict
--[[
	Hud — everything on screen, kept minimal:
	  * objective pill (top centre): always exactly one next action
	  * toast (under the objective): discoveries, one at a time
	  * reveal bar (bottom centre): only while an artifact is half uncovered
	  * input hint (bottom centre): disappears after the first few swings
	  * intro line at start
	  * mobile DIG button (separate ScreenGui so it lines up with Roblox's jump button)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Strings = require(ReplicatedStorage.Shared.Strings)

local Hud = {}

export type InputMode = "Mouse" | "Touch" | "Gamepad"

local COLORS = {
	panel = Color3.fromRGB(36, 26, 18),
	cream = Color3.fromRGB(255, 244, 222),
	gold = Color3.fromRGB(242, 193, 78),
	goldPressed = Color3.fromRGB(214, 160, 52),
	ink = Color3.fromRGB(52, 34, 18),
	teal = Color3.fromRGB(46, 196, 182),
	track = Color3.fromRGB(80, 64, 50),
}
local FONT_BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local FONT_HEAVY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local FONT_MEDIUM = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local FONT_TITLE = Font.new("rbxasset://fonts/families/FredokaOne.json")
local HINT_SWINGS = 6

local player = Players.LocalPlayer
local text = Strings.forLocale(player.LocaleId)

local screen: ScreenGui
local uiScale: UIScale
local objectivePill: Frame
local objectiveLabel: TextLabel
local objectiveScale: UIScale
local toastGroup: CanvasGroup
local toastLabel: TextLabel
local revealGroup: CanvasGroup
local revealName: TextLabel
local revealPercent: TextLabel
local revealFill: Frame
local hintLabel: TextLabel
local digButton: TextButton
local digButtonScale: UIScale

local toastQueue: { string } = {}
local toastBusy = false
local swings = 0
local inputMode: InputMode = "Mouse"
local revealVisible = false

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function padding(parent: Instance, horizontal: number, vertical: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, horizontal)
	p.PaddingRight = UDim.new(0, horizontal)
	p.PaddingTop = UDim.new(0, vertical)
	p.PaddingBottom = UDim.new(0, vertical)
	p.Parent = parent
end

local function label(parent: Instance, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = ""
	l.Parent = parent
	return l
end

local function buildObjective()
	local pill = Instance.new("Frame")
	objectivePill = pill
	pill.Name = "Objective"
	pill.Visible = false
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 10)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 40)
	pill.BackgroundColor3 = COLORS.panel
	pill.BackgroundTransparency = 0.2
	pill.Parent = screen
	corner(pill, 20)
	padding(pill, 18, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.gold
	stroke.Thickness = 1.5
	stroke.Transparency = 0.35
	stroke.Parent = pill
	objectiveScale = Instance.new("UIScale")
	objectiveScale.Parent = pill

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pill

	local diamond = Instance.new("Frame")
	diamond.Size = UDim2.fromOffset(10, 10)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = COLORS.gold
	diamond.LayoutOrder = 1
	diamond.Parent = pill

	objectiveLabel = label(pill, FONT_BOLD, 18, COLORS.cream)
	objectiveLabel.AutomaticSize = Enum.AutomaticSize.X
	objectiveLabel.Size = UDim2.fromScale(0, 1)
	objectiveLabel.LayoutOrder = 2
end

local function buildToast()
	toastGroup = Instance.new("CanvasGroup")
	toastGroup.Name = "Toast"
	toastGroup.AnchorPoint = Vector2.new(0.5, 0)
	toastGroup.Position = UDim2.new(0.5, 0, 0, 62)
	toastGroup.AutomaticSize = Enum.AutomaticSize.X
	toastGroup.Size = UDim2.fromOffset(0, 46)
	toastGroup.BackgroundColor3 = COLORS.gold
	toastGroup.GroupTransparency = 1
	toastGroup.Visible = false
	toastGroup.Parent = screen
	corner(toastGroup, 14)
	padding(toastGroup, 20, 0)

	toastLabel = label(toastGroup, FONT_HEAVY, 20, COLORS.ink)
	toastLabel.AutomaticSize = Enum.AutomaticSize.X
	toastLabel.Size = UDim2.fromScale(0, 1)
end

local function buildRevealBar()
	revealGroup = Instance.new("CanvasGroup")
	revealGroup.Name = "Reveal"
	revealGroup.AnchorPoint = Vector2.new(0.5, 1)
	revealGroup.Position = UDim2.new(0.5, 0, 1, -64)
	revealGroup.Size = UDim2.fromOffset(300, 54)
	revealGroup.BackgroundColor3 = COLORS.panel
	revealGroup.BackgroundTransparency = 0.2
	revealGroup.GroupTransparency = 1
	revealGroup.Visible = false
	revealGroup.Parent = screen
	corner(revealGroup, 14)
	padding(revealGroup, 14, 9)

	revealName = label(revealGroup, FONT_BOLD, 16, COLORS.cream)
	revealName.Size = UDim2.new(1, -60, 0, 18)
	revealName.TextXAlignment = Enum.TextXAlignment.Left
	revealName.TextTruncate = Enum.TextTruncate.AtEnd

	revealPercent = label(revealGroup, FONT_HEAVY, 16, COLORS.teal)
	revealPercent.AnchorPoint = Vector2.new(1, 0)
	revealPercent.Position = UDim2.fromScale(1, 0)
	revealPercent.Size = UDim2.fromOffset(60, 18)
	revealPercent.TextXAlignment = Enum.TextXAlignment.Right

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.fromScale(0, 1)
	track.Size = UDim2.new(1, 0, 0, 10)
	track.BackgroundColor3 = COLORS.track
	track.Parent = revealGroup
	corner(track, 5)

	revealFill = Instance.new("Frame")
	revealFill.Size = UDim2.fromScale(0, 1)
	revealFill.BackgroundColor3 = COLORS.teal
	revealFill.Parent = track
	corner(revealFill, 5)
end

local function buildHint()
	hintLabel = label(screen, FONT_MEDIUM, 15, COLORS.cream)
	hintLabel.Name = "Hint"
	hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	hintLabel.Position = UDim2.new(0.5, 0, 1, -20)
	hintLabel.AutomaticSize = Enum.AutomaticSize.X
	hintLabel.Size = UDim2.fromOffset(0, 30)
	hintLabel.BackgroundColor3 = COLORS.panel
	hintLabel.BackgroundTransparency = 0.35
	corner(hintLabel, 15)
	padding(hintLabel, 14, 0)
end

local function playIntro()
	local group = Instance.new("CanvasGroup")
	group.Name = "Intro"
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.36)
	group.Size = UDim2.fromOffset(640, 120)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = screen

	local title = label(group, FONT_TITLE, 44, COLORS.gold)
	title.Size = UDim2.new(1, 0, 0, 56)
	title.Text = text.Title
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = COLORS.ink
	titleStroke.Thickness = 3
	titleStroke.Parent = title

	local line = label(group, FONT_MEDIUM, 22, COLORS.cream)
	line.Position = UDim2.fromOffset(0, 64)
	line.Size = UDim2.new(1, 0, 0, 30)
	line.Text = text.Intro
	local lineStroke = Instance.new("UIStroke")
	lineStroke.Color = COLORS.ink
	lineStroke.Thickness = 2
	lineStroke.Transparency = 0.2
	lineStroke.Parent = line

	task.spawn(function()
		TweenService:Create(group, TweenInfo.new(0.6), { GroupTransparency = 0 }):Play()
		task.wait(3.6)
		local out = TweenService:Create(group, TweenInfo.new(0.8), { GroupTransparency = 1 })
		out:Play()
		out.Completed:Wait()
		group:Destroy()
	end)
end

local function showNextToast()
	if toastBusy or #toastQueue == 0 then
		return
	end
	toastBusy = true
	toastLabel.Text = table.remove(toastQueue, 1) :: string
	toastGroup.Visible = true
	toastGroup.Position = UDim2.new(0.5, 0, 0, 52)
	TweenService:Create(toastGroup, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
		GroupTransparency = 0,
		Position = UDim2.new(0.5, 0, 0, 62),
	}):Play()
	task.delay(2.6, function()
		local out = TweenService:Create(toastGroup, TweenInfo.new(0.3), { GroupTransparency = 1 })
		out:Play()
		out.Completed:Wait()
		toastGroup.Visible = false
		toastBusy = false
		showNextToast()
	end)
end

-- Mobile button: left of Roblox's jump button, sized for thumbs.
local function layoutDigButton()
	local camera = Workspace.CurrentCamera
	if not camera or not digButton then
		return
	end
	local viewport = camera.ViewportSize
	local small = math.min(viewport.X, viewport.Y) <= 500
	if small then
		-- jump button: 70px at (1, -95, 1, -90)
		digButton.Size = UDim2.fromOffset(84, 84)
		digButton.Position = UDim2.new(1, -112, 1, -26)
	else
		-- jump button: 120px at (1, -170, 1, -210)
		digButton.Size = UDim2.fromOffset(116, 116)
		digButton.Position = UDim2.new(1, -196, 1, -86)
	end
end

local function buildDigButton(onHeld: (held: boolean) -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = "DigButtonGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	digButton = Instance.new("TextButton")
	digButton.Name = "DigButton"
	digButton.AnchorPoint = Vector2.new(1, 1)
	digButton.AutoButtonColor = false
	digButton.BackgroundColor3 = COLORS.gold
	digButton.FontFace = FONT_HEAVY
	digButton.TextColor3 = COLORS.ink
	digButton.TextScaled = true
	digButton.Text = text.DigButton
	digButton.Visible = false
	digButton.Parent = gui
	corner(digButton, 999)
	padding(digButton, 14, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.ink
	stroke.Thickness = 3
	stroke.Transparency = 0.25
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = digButton
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = 30
	sizeLimit.Parent = digButton
	digButtonScale = Instance.new("UIScale")
	digButtonScale.Parent = digButton

	-- Track the exact touch that pressed the button, so releasing it anywhere stops digging
	-- and other fingers (joystick, camera) are never mistaken for it.
	local activeInput: InputObject? = nil
	local function setPressed(pressed: boolean)
		digButton.BackgroundColor3 = if pressed then COLORS.goldPressed else COLORS.gold
		digButtonScale.Scale = if pressed then 0.92 else 1
		onHeld(pressed)
	end
	digButton.InputBegan:Connect(function(input)
		if
			activeInput == nil
			and (
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			)
		then
			activeInput = input
			setPressed(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == activeInput then
			activeInput = nil
			setPressed(false)
		end
	end)

	layoutDigButton()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutDigButton)
	end
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(viewport.X, viewport.Y) / 640, 0.8, 1.25)
end

local function refreshHint()
	if swings >= HINT_SWINGS then
		hintLabel.Visible = false
		return
	end
	hintLabel.Visible = true
	hintLabel.Text = if inputMode == "Touch"
		then text.HintTouch
		elseif inputMode == "Gamepad" then text.HintGamepad
		else text.HintMouse
end

function Hud.init(onDigButtonHeld: (held: boolean) -> ())
	screen = Instance.new("ScreenGui")
	screen.Name = "Hud"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = player:WaitForChild("PlayerGui")

	uiScale = Instance.new("UIScale")
	uiScale.Parent = screen
	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	buildObjective()
	buildToast()
	buildRevealBar()
	buildHint()
	buildDigButton(onDigButtonHeld)
	refreshHint()
	playIntro()
end

function Hud.strings(): Strings.Table
	return text
end

function Hud.setInputMode(mode: InputMode)
	inputMode = mode
	digButton.Visible = mode == "Touch"
	refreshHint()
end

-- An empty message hides the pill (e.g. while the plot assignment is still replicating).
function Hud.setObjective(message: string)
	if objectiveLabel.Text == message then
		return
	end
	objectiveLabel.Text = message
	objectivePill.Visible = message ~= ""
	objectiveScale.Scale = 1.08
	TweenService:Create(objectiveScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function Hud.toast(message: string)
	table.insert(toastQueue, message)
	showNextToast()
end

function Hud.setReveal(name: string?, progress: number)
	if name == nil then
		if revealVisible then
			revealVisible = false
			local out = TweenService:Create(revealGroup, TweenInfo.new(0.4), { GroupTransparency = 1 })
			out:Play()
			out.Completed:Connect(function()
				if not revealVisible then
					revealGroup.Visible = false
				end
			end)
		end
		return
	end
	local clamped = math.clamp(progress, 0, 1)
	revealName.Text = name
	revealPercent.Text = string.format("%d%%", math.floor(clamped * 100 + 0.5))
	TweenService:Create(revealFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(clamped, 1) })
		:Play()
	if not revealVisible then
		revealVisible = true
		revealGroup.Visible = true
		TweenService:Create(revealGroup, TweenInfo.new(0.3), { GroupTransparency = 0 }):Play()
	end
end

function Hud.onSwing()
	swings += 1
	if swings == HINT_SWINGS then
		refreshHint()
	end
end

return Hud
