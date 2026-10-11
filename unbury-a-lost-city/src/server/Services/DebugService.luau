--!strict
--[[
	DebugService — Studio-only test helpers. Does nothing in a live server.

	  ToggleTool  switch the shovel between level 1 and 2 (to compare feel)
	  ResetPlot   refill your dig site and rebury its artifacts
	Every 2 seconds the server publishes dig cost to workspace attributes for the
	client stats overlay (F3).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local DigService = require(script.Parent.DigService)
local PlayerService = require(script.Parent.PlayerService)
local PlotService = require(script.Parent.PlotService)

local DebugService = {}

local function onCommand(player: Player, command: any)
	if command == "ToggleTool" then
		local level = player:GetAttribute("ToolLevel")
		local nextLevel = if level == 1 then 2 else 1
		if GameConfig.Tools[nextLevel] then
			player:SetAttribute("ToolLevel", nextLevel)
		end
	elseif command == "ResetPlot" then
		local plot = PlotService.getPlot(player)
		if plot then
			PlayerService.returnToSpawn(player)
			PlotService.resetPlot(plot)
		end
	end
end

function DebugService.init()
	if not RunService:IsStudio() then
		return
	end

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DebugCommand") :: RemoteEvent
	remote.OnServerEvent:Connect(onCommand)

	task.spawn(function()
		while true do
			task.wait(2)
			local digs, rejected, average, maximum = DigService.takeStats()
			Workspace:SetAttribute("DebugDigsPer2s", digs)
			Workspace:SetAttribute("DebugRejectedPer2s", rejected)
			Workspace:SetAttribute("DebugDigAvgMs", math.floor(average * 1e6) / 1e3)
			Workspace:SetAttribute("DebugDigMaxMs", math.floor(maximum * 1e6) / 1e3)
		end
	end)
end

return DebugService
