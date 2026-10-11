--!strict
--[[
	PlotWatcher — follows the local player's dig zone and its artifact records.

	All state comes from replicated attributes (Player.PlotId and the
	Configuration records under workspace.Plots.Plot<N>.ArtifactStates), so a
	respawn, a late join or a Studio reset all resolve to the same picture.

	artifactChanged(view, previousState):
	  previousState == nil       first time this record is seen (no effects)
	  previousState ~= view.state  a real transition (play effects)
	  previousState == view.state  progress update only
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Zone = require(ReplicatedStorage.Shared.Zone)

export type ArtifactView = {
	id: string,
	state: string,
	progress: number,
	position: Vector3,
	model: Model?,
}

export type Callbacks = {
	plotChanged: (zone: Zone.Zone?) -> (),
	artifactChanged: (view: ArtifactView, previousState: string?) -> (),
	artifactRemoved: (id: string) -> (),
}

local PlotWatcher = {}

local player = Players.LocalPlayer
local currentZone: Zone.Zone? = nil
local connections: { RBXScriptConnection } = {}
local generation = 0

function PlotWatcher.getZone(): Zone.Zone?
	return currentZone
end

local function disconnectAll()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function watchRecord(record: Configuration, folder: Instance, callbacks: Callbacks)
	local previous: string? = nil
	local function emit()
		local state = record:GetAttribute("State")
		local progress = record:GetAttribute("Progress")
		local position = record:GetAttribute("Position")
		if type(state) ~= "string" or typeof(position) ~= "Vector3" then
			return
		end
		local models = folder:FindFirstChild("Artifacts")
		local model = models and models:FindFirstChild(record.Name)
		callbacks.artifactChanged({
			id = record.Name,
			state = state,
			progress = if type(progress) == "number" then progress else 0,
			position = position,
			model = if model and model:IsA("Model") then model else nil,
		}, previous)
		previous = state
	end
	emit()
	table.insert(connections, record.AttributeChanged:Connect(emit))
	table.insert(
		connections,
		record.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				callbacks.artifactRemoved(record.Name)
			end
		end)
	)
end

local function bind(callbacks: Callbacks)
	generation += 1
	local myGeneration = generation
	disconnectAll()

	local plotId = player:GetAttribute("PlotId")
	currentZone = if type(plotId) == "number" then Zone.fromSlot(plotId) else nil
	callbacks.plotChanged(currentZone)
	if currentZone == nil then
		return
	end

	task.spawn(function()
		local plots = Workspace:WaitForChild("Plots")
		local folder = plots:WaitForChild("Plot" .. tostring(plotId))
		local records = folder:WaitForChild("ArtifactStates")
		if myGeneration ~= generation then
			return
		end
		for _, child in records:GetChildren() do
			if child:IsA("Configuration") then
				watchRecord(child, folder, callbacks)
			end
		end
		table.insert(
			connections,
			records.ChildAdded:Connect(function(child)
				if child:IsA("Configuration") then
					watchRecord(child, folder, callbacks)
				end
			end)
		)
	end)
end

function PlotWatcher.init(callbacks: Callbacks)
	player:GetAttributeChangedSignal("PlotId"):Connect(function()
		bind(callbacks)
	end)
	bind(callbacks)
end

return PlotWatcher
