--!strict
--[[
	TerrainVoxels — turns a rectangle of DigGrid columns into the arrays that
	Terrain:WriteVoxels expects (indexed [x][y][z], 1-based, y = bottom-up).

	Pure Luau: the material values are passed in, so tests can use strings and the
	engine passes Enum.Material items.

	Layer layout of every column, bottom-up:
	  bedrock layers  -> palette.bedrock, always full
	  sand layers     -> occupancy from the column height; material switches from
	                     palette.sand to palette.packed below `strataDepth`
]]

local DigGrid = require(script.Parent.DigGrid)

local TerrainVoxels = {}

export type Palette<M> = {
	air: M,
	sand: M,
	packed: M,
	bedrock: M,
}

export type Options = {
	bedrockThickness: number,
	strataDepth: number,
	minOccupancy: number,
}

function TerrainVoxels.layerCounts(grid: DigGrid.Grid, options: Options): (number, number)
	local bedrockLayers = math.ceil(options.bedrockThickness / grid.cellSize)
	local sandLayers = math.ceil(grid.sandDepth / grid.cellSize)
	return bedrockLayers, sandLayers
end

function TerrainVoxels.build<M>(
	grid: DigGrid.Grid,
	i0: number,
	j0: number,
	i1: number,
	j1: number,
	palette: Palette<M>,
	options: Options
): ({ { { M } } }, { { { number } } })
	local cellSize, size = grid.cellSize, grid.size
	local heights = grid.heights
	local bedrockLayers, sandLayers = TerrainVoxels.layerCounts(grid, options)
	local layers = bedrockLayers + sandLayers
	local sizeX, sizeZ = i1 - i0 + 1, j1 - j0 + 1

	local materials: { { { M } } } = table.create(sizeX)
	local occupancies: { { { number } } } = table.create(sizeX)

	for x = 1, sizeX do
		local materialColumn: { { M } } = table.create(layers)
		local occupancyColumn: { { number } } = table.create(layers)
		for y = 1, layers do
			local materialRow: { M } = table.create(sizeZ)
			local occupancyRow: { number } = table.create(sizeZ)
			for z = 1, sizeZ do
				local material: M
				local occupancy: number
				if y <= bedrockLayers then
					material, occupancy = palette.bedrock, 1
				else
					local height = heights[(j0 + z - 1) * size + (i0 + x - 1) + 1]
					local layerBottom = (y - bedrockLayers - 1) * cellSize
					local fill = math.clamp((height - layerBottom) / cellSize, 0, 1)
					if fill < options.minOccupancy then
						material, occupancy = palette.air, 0
					else
						local depthBelowSurface = grid.sandDepth - (layerBottom + cellSize * 0.5)
						material = if depthBelowSurface > options.strataDepth then palette.packed else palette.sand
						occupancy = fill
					end
				end
				materialRow[z] = material
				occupancyRow[z] = occupancy
			end
			materialColumn[y] = materialRow
			occupancyColumn[y] = occupancyRow
		end
		materials[x] = materialColumn
		occupancies[x] = occupancyColumn
	end

	return materials, occupancies
end

return TerrainVoxels
