--!strict
--[[
	TerrainRenderer — the only code that writes dig-zone terrain.

	It always derives voxels from the DigGrid heightmap, so what the player sees and
	what the server uses for rewards cannot drift apart. Each swing rewrites only the
	bounding rectangle of the cells that changed (usually 3x3 to 6x6 columns).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DigGrid = require(ReplicatedStorage.Shared.DigGrid)
local TerrainVoxels = require(ReplicatedStorage.Shared.TerrainVoxels)
local Zone = require(ReplicatedStorage.Shared.Zone)

local TerrainRenderer = {}

local terrain = Workspace.Terrain

local PALETTE: TerrainVoxels.Palette<Enum.Material> = {
	air = Enum.Material.Air,
	sand = Enum.Material.Sand,
	packed = Enum.Material.Sandstone,
	bedrock = Enum.Material.Sandstone,
}

local OPTIONS: TerrainVoxels.Options = {
	bedrockThickness = GameConfig.Dig.BedrockThickness,
	strataDepth = GameConfig.Dig.StrataDepth,
	minOccupancy = GameConfig.Dig.MinOccupancy,
}

function TerrainRenderer.renderRect(zone: Zone.Zone, grid: DigGrid.Grid, i0: number, j0: number, i1: number, j1: number)
	local materials, occupancies = TerrainVoxels.build(grid, i0, j0, i1, j1, PALETTE, OPTIONS)
	local bedrockLayers, sandLayers = TerrainVoxels.layerCounts(grid, OPTIONS)
	local cellSize = grid.cellSize
	local regionMin =
		Vector3.new(zone.minX + i0 * cellSize, zone.bottomY - bedrockLayers * cellSize, zone.minZ + j0 * cellSize)
	local regionMax = Vector3.new(
		zone.minX + (i1 + 1) * cellSize,
		zone.bottomY + sandLayers * cellSize,
		zone.minZ + (j1 + 1) * cellSize
	)
	terrain:WriteVoxels(Region3.new(regionMin, regionMax), cellSize, materials, occupancies)
end

function TerrainRenderer.renderCells(zone: Zone.Zone, grid: DigGrid.Grid, cells: { number })
	if #cells == 0 then
		return
	end
	local i0, j0, i1, j1 = DigGrid.bounds(grid, cells)
	TerrainRenderer.renderRect(zone, grid, i0, j0, i1, j1)
end

function TerrainRenderer.renderAll(zone: Zone.Zone, grid: DigGrid.Grid)
	TerrainRenderer.renderRect(zone, grid, 0, 0, grid.size - 1, grid.size - 1)
end

return TerrainRenderer
