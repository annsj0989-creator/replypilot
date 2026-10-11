--!strict
--[[
	PlotService — private dig zones.

	Every slot in GameConfig.Plots.SlotOrigins gets its own DigGrid, terrain and
	artifacts at server start. A joining player is given the first free slot; when
	they leave, the slot is reset to untouched sand for the next player.

	Replicated for clients:
	  Player attribute "PlotId"            slot number owned by that player
	  workspace.Plots.Plot<N>              folder per slot (attribute OwnerUserId)
	    .Artifacts                         artifact models
	    .ArtifactStates                    one Configuration per artifact (see ArtifactService)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DigGrid = require(ReplicatedStorage.Shared.DigGrid)
local Zone = require(ReplicatedStorage.Shared.Zone)

local Types = require(script.Parent.Parent.Types)
local ArtifactService = require(script.Parent.ArtifactService)
local TerrainRenderer = require(script.Parent.TerrainRenderer)
local WorldBuilder = require(script.Parent.WorldBuilder)

type Plot = Types.Plot

local PlotService = {}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}

local function updateSign(plot: Plot)
	local owner = plot.owner
	plot.signLabel.Text = if owner then `⛏ {owner.DisplayName}` else "⛏ —"
end

function PlotService.init()
	local root = Instance.new("Folder")
	root.Name = "Plots"
	root.Parent = Workspace

	local dig = GameConfig.Dig
	for slot = 1, Zone.slotCount() do
		local zone = assert(Zone.fromSlot(slot), "missing zone")

		local folder = Instance.new("Folder")
		folder.Name = "Plot" .. slot
		folder:SetAttribute("Slot", slot)

		local modelsFolder = Instance.new("Folder")
		modelsFolder.Name = "Artifacts"
		modelsFolder.Parent = folder

		local recordsFolder = Instance.new("Configuration")
		recordsFolder.Name = "ArtifactStates"
		recordsFolder.Parent = folder

		local signLabel = WorldBuilder.buildPlotFrame(zone, folder)
		folder.Parent = root

		local plot: Plot = {
			id = slot,
			zone = zone,
			grid = DigGrid.new({
				size = dig.ZoneCells,
				cellSize = dig.CellSize,
				sandDepth = dig.SandDepth,
				maxStep = dig.MaxSlopeStep,
			}),
			folder = folder,
			modelsFolder = modelsFolder,
			recordsFolder = recordsFolder,
			signLabel = signLabel,
			artifacts = {},
			discoveries = {},
			owner = nil,
		}
		-- Artifacts first: they raise the floor under their pedestals.
		ArtifactService.setup(plot)
		TerrainRenderer.renderAll(zone, plot.grid)
		updateSign(plot)
		plots[slot] = plot
	end
end

function PlotService.assign(player: Player): Plot?
	local existing = plotByPlayer[player]
	if existing then
		return existing
	end
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			plotByPlayer[player] = plot
			plot.folder:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("PlotId", plot.id)
			updateSign(plot)
			return plot
		end
	end
	return nil
end

function PlotService.resetPlot(plot: Plot)
	DigGrid.reset(plot.grid)
	ArtifactService.reset(plot)
	TerrainRenderer.renderAll(plot.zone, plot.grid)
end

function PlotService.release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	plot.owner = nil
	plot.folder:SetAttribute("OwnerUserId", nil)
	PlotService.resetPlot(plot)
	updateSign(plot)
end

function PlotService.getPlot(player: Player): Plot?
	return plotByPlayer[player]
end

-- Standing just outside the owner's zone, looking into it.
function PlotService.getSpawnCFrame(player: Player): CFrame
	local plot = plotByPlayer[player]
	if not plot then
		return CFrame.new(0, GameConfig.Dig.SurfaceY + 4, 0)
	end
	local x, y, z, lookZ = Zone.spawnPoint(plot.zone)
	local position = Vector3.new(x, y + 4, z)
	return CFrame.lookAt(position, Vector3.new(x, y + 4, lookZ))
end

return PlotService
