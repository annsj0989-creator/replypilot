--!strict
--[[
	ArtifactService — buried artifacts and when they count as found.

	Exposure is computed on the server from the DigGrid heightmap only; the client
	never reports progress. State is published as attributes on a Configuration per
	artifact (plot.recordsFolder), which replicates and also covers late joins:
	  State    "Hidden" | "Glimpsed" | "Discovered"
	  Progress 0..1 (sent in steps of ProgressStep)
	  Position world position of the artifact's top (for markers and effects)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DigGrid = require(ReplicatedStorage.Shared.DigGrid)
local Zone = require(ReplicatedStorage.Shared.Zone)

local Types = require(script.Parent.Parent.Types)
local ArtifactFactory = require(script.Parent.ArtifactFactory)
local TerrainRenderer = require(script.Parent.TerrainRenderer)

type Plot = Types.Plot
type ArtifactState = Types.ArtifactState

local ArtifactService = {}

local GLIMPSE_DEPTH = 0.4 -- studs of the top that must show above the sand under the footprint
local SIDE_GLIMPSE_DEPTH = 2 -- or this much beside it
local PROGRESS_STEP = 0.02

local function createState(plot: Plot, spec: GameConfig.ArtifactSpec): ArtifactState
	local grid = plot.grid
	local half = spec.FootprintHalf
	local revealHalf = half + spec.RevealMargin
	local footprint =
		DigGrid.cellsInRect(grid, spec.LocalX - half, spec.LocalZ - half, spec.LocalX + half, spec.LocalZ + half)
	local reveal = DigGrid.cellsInRect(
		grid,
		spec.LocalX - revealHalf,
		spec.LocalZ - revealHalf,
		spec.LocalX + revealHalf,
		spec.LocalZ + revealHalf
	)
	local revealSet = {}
	for _, index in reveal do
		revealSet[index] = true
	end

	-- The sand under the pedestal can never be dug away.
	DigGrid.setFloor(grid, footprint, spec.BaseHeight)

	local worldX, worldZ = Zone.toWorld(plot.zone, spec.LocalX, spec.LocalZ)
	local base = Vector3.new(worldX, plot.zone.bottomY + spec.BaseHeight, worldZ)
	local model = ArtifactFactory.create(spec.Id)
	model:PivotTo(CFrame.lookAt(base, base + Vector3.new(0, 0, plot.zone.campSide)))
	model.Parent = plot.modelsFolder

	local record = Instance.new("Configuration")
	record.Name = spec.Id
	record:SetAttribute("State", "Hidden")
	record:SetAttribute("Progress", 0)
	record:SetAttribute("Position", base + Vector3.new(0, spec.Height, 0))
	record.Parent = plot.recordsFolder

	return {
		spec = spec,
		model = model,
		record = record,
		footprintCells = footprint,
		revealCells = reveal,
		revealSet = revealSet,
		topHeight = spec.BaseHeight + spec.Height,
		glimpsed = false,
		discovered = false,
		lastSentProgress = 0,
	}
end

function ArtifactService.setup(plot: Plot)
	for _, spec in GameConfig.Artifacts do
		table.insert(plot.artifacts, createState(plot, spec))
	end
end

function ArtifactService.reset(plot: Plot)
	for _, state in plot.artifacts do
		state.model:Destroy()
		state.record:Destroy()
	end
	table.clear(plot.artifacts)
	table.clear(plot.discoveries)
	ArtifactService.setup(plot)
end

local function discover(plot: Plot, state: ArtifactState)
	state.discovered = true
	state.glimpsed = true
	plot.discoveries[state.spec.Id] = true

	-- The last of the sand slides off so the whole find is on show.
	local changed = DigGrid.lowerTo(plot.grid, state.revealCells, state.spec.BaseHeight)
	TerrainRenderer.renderCells(plot.zone, plot.grid, changed)

	ArtifactFactory.activate(state.model)
	state.record:SetAttribute("Progress", 1)
	state.record:SetAttribute("State", "Discovered")

	-- Clearing that sand may have uncovered something else.
	if #changed > 0 then
		ArtifactService.onCellsChanged(plot, changed)
	end
end

local function evaluate(plot: Plot, state: ArtifactState)
	local grid = plot.grid
	local spec = state.spec

	if
		not state.glimpsed
		and (
			DigGrid.anyBelow(grid, state.footprintCells, state.topHeight - GLIMPSE_DEPTH)
			or DigGrid.anyBelow(grid, state.revealCells, state.topHeight - SIDE_GLIMPSE_DEPTH)
		)
	then
		state.glimpsed = true
		state.record:SetAttribute("State", "Glimpsed")
	end

	local progress = DigGrid.exposure(grid, state.revealCells, state.topHeight, spec.BaseHeight)
	if progress >= spec.RevealThreshold then
		discover(plot, state)
		return
	end

	if state.glimpsed and math.abs(progress - state.lastSentProgress) >= PROGRESS_STEP then
		state.lastSentProgress = progress
		-- Shown to the player relative to the threshold, so the bar ends at 100%.
		state.record:SetAttribute("Progress", math.floor(progress / spec.RevealThreshold * 1000) / 1000)
	end
end

-- Called after every dig with the cells whose height changed.
function ArtifactService.onCellsChanged(plot: Plot, changed: { number })
	for _, state in plot.artifacts do
		if not state.discovered then
			for _, index in changed do
				if state.revealSet[index] then
					evaluate(plot, state)
					break
				end
			end
		end
	end
end

return ArtifactService
