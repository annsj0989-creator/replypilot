--!strict
--[[
	DigGrid — the authoritative dig state of one zone, as a heightmap.

	Pure Luau (no Roblox API) so it is unit-tested outside the engine.

	Coordinates: cell (i, j) is 0-based, i runs along +X and j along +Z.
	Heights are studs of sand above the bedrock top: 0 = bedrock, sandDepth = untouched.

	Rules:
	  * Heights only ever go down.
	  * Sand slumps: a cell may stand at most maxStep above a side neighbour
	    (maxStep * sqrt(2) above a diagonal one). Digging a hole therefore makes a
	    walkable funnel instead of a vertical shaft.
	  * minHeights is the floor of each cell. Near the zone edge it keeps the slope
	    against the undiggable desert outside; under an artifact it is the
	    artifact's base, so the sand under a pedestal acts as a supporting pillar.
]]

local DigGrid = {}

export type Params = {
	size: number,
	cellSize: number,
	sandDepth: number,
	maxStep: number,
}

export type Grid = {
	size: number,
	cellSize: number,
	sandDepth: number,
	maxStep: number,
	heights: { number },
	minHeights: { number },
}

local EPSILON = 1e-6
local SQRT2 = math.sqrt(2)

-- { di, dj, distance factor }
local NEIGHBOURS = {
	{ 1, 0, 1 },
	{ -1, 0, 1 },
	{ 0, 1, 1 },
	{ 0, -1, 1 },
	{ 1, 1, SQRT2 },
	{ 1, -1, SQRT2 },
	{ -1, 1, SQRT2 },
	{ -1, -1, SQRT2 },
}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local LEVELS = #ALPHABET - 1
local CHAR_TO_LEVEL: { [string]: number } = {}
for level = 0, LEVELS do
	CHAR_TO_LEVEL[string.sub(ALPHABET, level + 1, level + 1)] = level
end

local function edgeFloor(params: Params, i: number, j: number): number
	-- Cells outside the zone never change, so a cell `d` steps from the outside
	-- can be at most d * maxStep below the untouched surface.
	local size = params.size
	local edgeDistance = 1 + math.min(i, j, size - 1 - i, size - 1 - j)
	return math.max(0, params.sandDepth - params.maxStep * edgeDistance)
end

function DigGrid.new(params: Params): Grid
	assert(params.size > 0 and params.cellSize > 0, "DigGrid: size and cellSize must be positive")
	local size = params.size
	local heights = table.create(size * size, params.sandDepth)
	local minHeights = table.create(size * size, 0)
	for j = 0, size - 1 do
		for i = 0, size - 1 do
			minHeights[j * size + i + 1] = edgeFloor(params, i, j)
		end
	end
	return {
		size = size,
		cellSize = params.cellSize,
		sandDepth = params.sandDepth,
		maxStep = params.maxStep,
		heights = heights,
		minHeights = minHeights,
	}
end

function DigGrid.index(grid: Grid, i: number, j: number): number
	return j * grid.size + i + 1
end

function DigGrid.cellOf(grid: Grid, index: number): (number, number)
	local zeroBased = index - 1
	return zeroBased % grid.size, zeroBased // grid.size
end

-- Local XZ (studs from the zone min corner) of a cell centre.
function DigGrid.cellCenter(grid: Grid, i: number, j: number): (number, number)
	return (i + 0.5) * grid.cellSize, (j + 0.5) * grid.cellSize
end

function DigGrid.heightAt(grid: Grid, localX: number, localZ: number): number?
	local i = math.floor(localX / grid.cellSize)
	local j = math.floor(localZ / grid.cellSize)
	if i < 0 or j < 0 or i >= grid.size or j >= grid.size then
		return nil
	end
	return grid.heights[DigGrid.index(grid, i, j)]
end

--[[
	Lowers neighbours that stand too high above the cells in `changed`, cascading
	until the slope rule holds again. Newly lowered cells are appended to `changed`
	(no duplicates). Returns the summed height removed by slumping.

	Relaxation only ever lowers heights to `neighbour + step` (or the floor), so the
	result does not depend on processing order.
]]
function DigGrid.relax(grid: Grid, changed: { number }): number
	local size = grid.size
	local heights, minHeights = grid.heights, grid.minHeights
	local maxStep = grid.maxStep

	local seen: { [number]: boolean } = {}
	for _, index in changed do
		seen[index] = true
	end

	local queue = table.clone(changed)
	local head = 1
	local removed = 0

	while head <= #queue do
		local index = queue[head]
		head += 1
		local height = heights[index]
		local i, j = DigGrid.cellOf(grid, index)

		for _, offset in NEIGHBOURS do
			local ni, nj = i + offset[1], j + offset[2]
			if ni >= 0 and nj >= 0 and ni < size and nj < size then
				local neighbour = nj * size + ni + 1
				local current = heights[neighbour]
				local limit = height + maxStep * offset[3]
				if current > limit + EPSILON then
					local target = math.max(minHeights[neighbour], limit)
					if target < current - EPSILON then
						heights[neighbour] = target
						removed += current - target
						table.insert(queue, neighbour)
						if not seen[neighbour] then
							seen[neighbour] = true
							table.insert(changed, neighbour)
						end
					end
				end
			end
		end
	end

	return removed
end

--[[
	One shovel swing centred at local (x, z). Cells whose centre is within `radius`
	lose up to `power` studs with a quadratic falloff, then sand slumps.
	Returns the changed cell indices and the summed height removed.
]]
function DigGrid.dig(grid: Grid, x: number, z: number, radius: number, power: number): ({ number }, number)
	local cellSize, size = grid.cellSize, grid.size
	local heights, minHeights = grid.heights, grid.minHeights
	local changed: { number } = {}
	local removed = 0

	local i0 = math.max(0, math.floor((x - radius) / cellSize))
	local i1 = math.min(size - 1, math.floor((x + radius) / cellSize))
	local j0 = math.max(0, math.floor((z - radius) / cellSize))
	local j1 = math.min(size - 1, math.floor((z + radius) / cellSize))

	for j = j0, j1 do
		for i = i0, i1 do
			local cx = (i + 0.5) * cellSize
			local cz = (j + 0.5) * cellSize
			local distance = math.sqrt((cx - x) ^ 2 + (cz - z) ^ 2)
			if distance < radius then
				local t = distance / radius
				local amount = power * (1 - t * t)
				local index = j * size + i + 1
				local old = heights[index]
				local new = math.max(minHeights[index], old - amount)
				if new < old - EPSILON then
					heights[index] = new
					removed += old - new
					table.insert(changed, index)
				end
			end
		end
	end

	if #changed > 0 then
		removed += DigGrid.relax(grid, changed)
	end
	return changed, removed
end

-- Indices of every cell whose square overlaps the local rectangle.
function DigGrid.cellsInRect(grid: Grid, minX: number, minZ: number, maxX: number, maxZ: number): { number }
	local cellSize, size = grid.cellSize, grid.size
	local i0 = math.max(0, math.floor(minX / cellSize))
	local i1 = math.min(size - 1, math.floor((maxX - EPSILON) / cellSize))
	local j0 = math.max(0, math.floor(minZ / cellSize))
	local j1 = math.min(size - 1, math.floor((maxZ - EPSILON) / cellSize))
	local cells = {}
	for j = j0, j1 do
		for i = i0, i1 do
			table.insert(cells, j * size + i + 1)
		end
	end
	return cells
end

-- Raises the floor of the given cells (used for the sand under an artifact).
function DigGrid.setFloor(grid: Grid, cells: { number }, floor: number)
	for _, index in cells do
		grid.minHeights[index] = math.max(grid.minHeights[index], floor)
	end
end

-- Lowers the given cells to `target` (never below their floor), then slumps.
function DigGrid.lowerTo(grid: Grid, cells: { number }, target: number): ({ number }, number)
	local heights, minHeights = grid.heights, grid.minHeights
	local changed: { number } = {}
	local removed = 0
	for _, index in cells do
		local old = heights[index]
		local new = math.max(minHeights[index], math.min(old, target))
		if new < old - EPSILON then
			heights[index] = new
			removed += old - new
			table.insert(changed, index)
		end
	end
	if #changed > 0 then
		removed += DigGrid.relax(grid, changed)
	end
	return changed, removed
end

-- Mean exposure (0..1) of an object spanning [base, top] buried under `cells`.
function DigGrid.exposure(grid: Grid, cells: { number }, top: number, base: number): number
	if #cells == 0 or top <= base then
		return 0
	end
	local total = 0
	for _, index in cells do
		total += math.clamp((top - grid.heights[index]) / (top - base), 0, 1)
	end
	return total / #cells
end

function DigGrid.anyBelow(grid: Grid, cells: { number }, level: number): boolean
	for _, index in cells do
		if grid.heights[index] < level then
			return true
		end
	end
	return false
end

-- Inclusive cell rectangle that bounds a list of indices.
function DigGrid.bounds(grid: Grid, cells: { number }): (number, number, number, number)
	local minI, minJ = math.huge, math.huge
	local maxI, maxJ = -math.huge, -math.huge
	for _, index in cells do
		local i, j = DigGrid.cellOf(grid, index)
		minI, maxI = math.min(minI, i), math.max(maxI, i)
		minJ, maxJ = math.min(minJ, j), math.max(maxJ, j)
	end
	return minI, minJ, maxI, maxJ
end

-- Back to untouched sand. Floors (edge slope, artifact pillars) are kept.
function DigGrid.reset(grid: Grid)
	for index = 1, #grid.heights do
		grid.heights[index] = grid.sandDepth
	end
end

--[[
	Save format: one URL-safe character per cell (64 height levels, ~0.32 studs at
	SandDepth 20). A 16x16 zone is 256 characters, which is DataStore-safe text.
]]
function DigGrid.encode(grid: Grid): string
	local chars = table.create(#grid.heights, "")
	for index, height in grid.heights do
		local level = math.clamp(math.floor(height / grid.sandDepth * LEVELS + 0.5), 0, LEVELS)
		chars[index] = string.sub(ALPHABET, level + 1, level + 1)
	end
	return table.concat(chars)
end

-- Restores heights from `encode` output. Returns false (and leaves the grid
-- untouched) if the data does not fit this grid.
function DigGrid.decode(grid: Grid, data: string): boolean
	local count = #grid.heights
	if #data ~= count then
		return false
	end
	local decoded = table.create(count, 0)
	for index = 1, count do
		local level = CHAR_TO_LEVEL[string.sub(data, index, index)]
		if level == nil then
			return false
		end
		decoded[index] = level / LEVELS * grid.sandDepth
	end
	local all = table.create(count, 0)
	for index = 1, count do
		grid.heights[index] = math.clamp(decoded[index], grid.minHeights[index], grid.sandDepth)
		all[index] = index
	end
	-- Rounding can break the slope rule by a hair; settle it again.
	DigGrid.relax(grid, all)
	return true
end

return DigGrid
