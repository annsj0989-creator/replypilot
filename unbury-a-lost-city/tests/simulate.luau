--[[
	Pacing simulation + CPU benchmark for the dig system (runs the real modules).
	Run from the project folder:  lune run tests/simulate

	The simulated player is a simple stand-in for a human, not a replacement for
	play tests:
	  1. digs at the marker with up to ±1.5 studs of aim error
	  2. after the glimpse, aims at whichever uncovered-area cell still has the most sand
	It swings at exactly the tool cooldown and ignores walking time.
]]

local Loader = require("./Loader")
local TestKit = require("./TestKit")

local GameConfig = Loader.load("src/shared/Config/GameConfig")
local DigGrid = Loader.load("src/shared/DigGrid")
local TerrainVoxels = Loader.load("src/shared/TerrainVoxels")

local dig = GameConfig.Dig
local artifact = GameConfig.Artifacts[1]

local function newGrid()
	return DigGrid.new({
		size = dig.ZoneCells,
		cellSize = dig.CellSize,
		sandDepth = dig.SandDepth,
		maxStep = dig.MaxSlopeStep,
	})
end

local function artifactCells(grid)
	local half = artifact.FootprintHalf
	local revealHalf = half + artifact.RevealMargin
	local footprint = DigGrid.cellsInRect(
		grid,
		artifact.LocalX - half,
		artifact.LocalZ - half,
		artifact.LocalX + half,
		artifact.LocalZ + half
	)
	local reveal = DigGrid.cellsInRect(
		grid,
		artifact.LocalX - revealHalf,
		artifact.LocalZ - revealHalf,
		artifact.LocalX + revealHalf,
		artifact.LocalZ + revealHalf
	)
	DigGrid.setFloor(grid, footprint, artifact.BaseHeight)
	return footprint, reveal
end

local function runSession(tool, seed: number)
	local grid = newGrid()
	local footprint, reveal = artifactCells(grid)
	local top = artifact.BaseHeight + artifact.Height
	local rng = TestKit.rng(seed)
	local swings, glimpseAt, removedTotal = 0, nil, 0

	while swings < 500 do
		swings += 1
		local x, z
		if not glimpseAt then
			x = artifact.LocalX + rng:NextNumber(-1.5, 1.5)
			z = artifact.LocalZ + rng:NextNumber(-1.5, 1.5)
		else
			local best, bestHeight = reveal[1], -1
			for _, index in reveal do
				if grid.heights[index] > grid.minHeights[index] + 0.01 and grid.heights[index] > bestHeight then
					best, bestHeight = index, grid.heights[index]
				end
			end
			local i, j = DigGrid.cellOf(grid, best)
			x, z = DigGrid.cellCenter(grid, i, j)
			x += rng:NextNumber(-1, 1)
			z += rng:NextNumber(-1, 1)
		end
		local _, removed = DigGrid.dig(grid, x, z, tool.Radius, tool.Power)
		removedTotal += removed
		if
			not glimpseAt and (DigGrid.anyBelow(grid, footprint, top - 0.4) or DigGrid.anyBelow(grid, reveal, top - 2))
		then
			glimpseAt = swings
		end
		if DigGrid.exposure(grid, reveal, top, artifact.BaseHeight) >= artifact.RevealThreshold then
			return glimpseAt or swings, swings, removedTotal, grid
		end
	end
	error("artifact never revealed")
end

local function heightmapPicture(grid): string
	-- Depth below the surface per cell: . 0-2  : 2-5  - 5-8  = 8-11  # 11+
	local rows = {}
	for j = grid.size - 1, 0, -1 do
		local row = {}
		for i = 0, grid.size - 1 do
			local depth = grid.sandDepth - grid.heights[DigGrid.index(grid, i, j)]
			local glyph = if depth < 2
				then "."
				elseif depth < 5 then ":"
				elseif depth < 8 then "-"
				elseif depth < 11 then "="
				else "#"
			table.insert(row, glyph)
		end
		table.insert(rows, "    " .. table.concat(row, " "))
	end
	return table.concat(rows, "\n")
end

print("== Pacing: first artifact (" .. artifact.Id .. ") ==")
for _, tool in GameConfig.Tools do
	local glimpses, discoveries, removed = {}, {}, {}
	local sampleGrid
	for seed = 1, 25 do
		local glimpseAt, discoveredAt, removedTotal, grid = runSession(tool, seed)
		table.insert(glimpses, glimpseAt)
		table.insert(discoveries, discoveredAt)
		table.insert(removed, removedTotal)
		sampleGrid = sampleGrid or grid
	end
	table.sort(glimpses)
	table.sort(discoveries)
	local function median(list)
		return list[math.ceil(#list / 2)]
	end
	print(
		string.format(
			"Lv%d %-12s glimpse: %2d swings (%.1fs)   discovered: %2d swings (%.1fs, range %d-%d)",
			tool.Level,
			tool.Id,
			median(glimpses),
			median(glimpses) * tool.Cooldown,
			median(discoveries),
			median(discoveries) * tool.Cooldown,
			discoveries[1],
			discoveries[#discoveries]
		)
	)
	if tool.Level == 1 then
		print("  Lv1 dig site when the idol counts as found (depth: . <2  : <5  - <8  = <11  # 11+ studs):")
		print(heightmapPicture(sampleGrid))
	end
end

print("\n== CPU cost (Lune Luau VM, single thread) ==")
local function bench(label: string, iterations: number, body: () -> ())
	local start = os.clock()
	for _ = 1, iterations do
		body()
	end
	local elapsed = os.clock() - start
	print(string.format("%-46s %8.1f µs/op", label, elapsed / iterations * 1e6))
end

local palette = { air = 0, sand = 1, packed = 2, bedrock = 3 }
local options = {
	bedrockThickness = dig.BedrockThickness,
	strataDepth = dig.StrataDepth,
	minOccupancy = dig.MinOccupancy,
}

do
	local rng = TestKit.rng(99)
	local grid = newGrid()
	local count = 0
	bench("DigGrid.dig, Lv1, random spots (incl. slumping)", 20000, function()
		count += 1
		if count % 400 == 0 then
			DigGrid.reset(grid)
		end
		DigGrid.dig(grid, rng:NextNumber(0, 64), rng:NextNumber(0, 64), 5, 1.5)
	end)
	local grid2 = newGrid()
	bench("DigGrid.dig, Lv2, random spots (incl. slumping)", 20000, function()
		count += 1
		if count % 400 == 0 then
			DigGrid.reset(grid2)
		end
		DigGrid.dig(grid2, rng:NextNumber(0, 64), rng:NextNumber(0, 64), 7.5, 2.1)
	end)
	bench("TerrainVoxels.build, 5x5 cells (typical swing)", 20000, function()
		TerrainVoxels.build(grid, 6, 6, 10, 10, palette, options)
	end)
	bench("TerrainVoxels.build, 16x16 cells (whole zone)", 2000, function()
		TerrainVoxels.build(grid, 0, 0, 15, 15, palette, options)
	end)
	bench("DigGrid.encode (save string)", 20000, function()
		DigGrid.encode(grid)
	end)
end

-- Worst case: one swing that triggers the widest possible slump cascade.
do
	local grid = newGrid()
	local cx, cz = DigGrid.cellCenter(grid, 8, 8)
	for _ = 1, 12 do
		DigGrid.dig(grid, cx, cz, 5, 1.5)
	end
	local start = os.clock()
	local changed = DigGrid.dig(grid, cx, cz, 5, 1.5)
	print(
		string.format(
			"%-46s %8.1f µs (%d cells changed)",
			"Single deep swing, cascade",
			(os.clock() - start) * 1e6,
			#changed
		)
	)
end
