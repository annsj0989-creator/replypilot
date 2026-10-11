--!strict
--[[
	DebugOverlay — Studio-only test keys and a stats line. Inert in live servers.
	  F2  toggle tool level 1 <-> 2
	  F3  show/hide stats (client FPS, memory, server dig cost)
	  F4  reset your dig site
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DebugOverlay = {}

local function attribute(name: string): number
	local value = Workspace:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

function DebugOverlay.init(helpText: string)
	if not RunService:IsStudio() then
		return
	end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DebugCommand") :: RemoteEvent
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugOverlay"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(8, 8)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 0.45
	label.TextColor3 = Color3.new(1, 1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json")
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = helpText
	label.Visible = false
	label.Parent = gui

	local frames, elapsed = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		frames += 1
		elapsed += dt
		if elapsed >= 0.5 then
			label.Text = string.format(
				"%s\nFPS %.0f | client mem %.0f MB | tool Lv%s\nserver dig avg %.3f ms max %.3f ms | %d digs, %d rejected / 2s",
				helpText,
				frames / elapsed,
				Stats:GetTotalMemoryUsageMb(),
				tostring(player:GetAttribute("ToolLevel")),
				attribute("DebugDigAvgMs"),
				attribute("DebugDigMaxMs"),
				attribute("DebugDigsPer2s"),
				attribute("DebugRejectedPer2s")
			)
			frames, elapsed = 0, 0
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F2 then
			remote:FireServer("ToggleTool")
		elseif input.KeyCode == Enum.KeyCode.F3 then
			label.Visible = not label.Visible
		elseif input.KeyCode == Enum.KeyCode.F4 then
			remote:FireServer("ResetPlot")
		end
	end)
end

return DebugOverlay
