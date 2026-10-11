return function(T, Loader)
	local DigGrid = Loader.load("src/shared/DigGrid")
	local TerrainVoxels = Loader.load("src/shared/TerrainVoxels")
	local GameConfig = Loader.load("src/shared/Config/GameConfig")

	local PALETTE = { air = "Air", sand = "Sand", packed = "Packed", bedrock = "Bedrock" }
	local OPTIONS = {
		bedrockThickness = GameConfig.Dig.BedrockThickness,
		strataDepth = GameConfig.Dig.StrataDepth,
		minOccupancy = GameConfig.Dig.MinOccupancy,
	}

	local function newGrid()
		local dig = GameConfig.Dig
		return DigGrid.new({
			size = dig.ZoneCells,
			cellSize = dig.CellSize,
			sandDepth = dig.SandDepth,
			maxStep = dig.MaxSlopeStep,
		})
	end

	T.suite("TerrainVoxels", function()
		T.test("array shape matches the requested cell rectangle", function()
			local grid = newGrid()
			local materials, occupancies = TerrainVoxels.build(grid, 2, 3, 5, 9, PALETTE, OPTIONS)
			T.equal(#materials, 4, "x")
			T.equal(#materials[1], 6, "y: 1 bedrock + 5 sand layers")
			T.equal(#materials[1][1], 7, "z")
			T.equal(#occupancies, 4)
			T.equal(#occupancies[4][6], 7)
		end)

		T.test("untouched column is full, with darker packed sand below the strata depth", function()
			local grid = newGrid()
			local materials, occupancies = TerrainVoxels.build(grid, 0, 0, 0, 0, PALETTE, OPTIONS)
			local expected = { "Bedrock", "Packed", "Packed", "Packed", "Sand", "Sand" }
			for y = 1, 6 do
				T.equal(materials[1][y][1], expected[y], "layer " .. y)
				T.equal(occupancies[1][y][1], 1, "layer " .. y)
			end
		end)

		T.test("partial column uses fractional occupancy and air above", function()
			local grid = newGrid()
			grid.heights[DigGrid.index(grid, 4, 4)] = 10.4
			local materials, occupancies = TerrainVoxels.build(grid, 4, 4, 4, 4, PALETTE, OPTIONS)
			T.equal(occupancies[1][2][1], 1, "[0,4]")
			T.equal(occupancies[1][3][1], 1, "[4,8]")
			T.near(occupancies[1][4][1], 0.6, 1e-9, "[8,12]")
			T.equal(materials[1][4][1], "Packed")
			T.equal(occupancies[1][5][1], 0, "[12,16]")
			T.equal(materials[1][5][1], "Air")
			T.equal(materials[1][6][1], "Air")
		end)

		T.test("slivers thinner than MinOccupancy become air", function()
			local grid = newGrid()
			grid.heights[1] = 0.1
			local materials, occupancies = TerrainVoxels.build(grid, 0, 0, 0, 0, PALETTE, OPTIONS)
			T.equal(materials[1][2][1], "Air")
			T.equal(occupancies[1][2][1], 0)
			T.equal(materials[1][1][1], "Bedrock", "bedrock is never removed")
		end)

		T.test("x and z axes map to grid i and j", function()
			local grid = newGrid()
			grid.heights[DigGrid.index(grid, 6, 2)] = 0 -- i = 6, j = 2
			local materials = TerrainVoxels.build(grid, 5, 1, 7, 3, PALETTE, OPTIONS)
			T.equal(materials[2][6][2], "Air", "x=2 -> i=6, z=2 -> j=2")
			T.equal(materials[1][6][2], "Sand", "neighbour untouched")
			T.equal(materials[2][6][1], "Sand", "neighbour untouched")
		end)
	end)
end
