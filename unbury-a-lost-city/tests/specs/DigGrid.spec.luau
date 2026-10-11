return function(T, Loader)
	local DigGrid = Loader.load("src/shared/DigGrid")
	local GameConfig = Loader.load("src/shared/Config/GameConfig")

	local SQRT2 = math.sqrt(2)
	local EPS = 1e-6

	local function newGrid()
		local dig = GameConfig.Dig
		return DigGrid.new({
			size = dig.ZoneCells,
			cellSize = dig.CellSize,
			sandDepth = dig.SandDepth,
			maxStep = dig.MaxSlopeStep,
		})
	end

	-- Every pair of neighbours obeys the slope rule unless the higher one is
	-- held up by a raised floor (artifact pillar).
	local function assertSlopeRule(grid, pillars: { [number]: boolean }?)
		local size = grid.size
		for j = 0, size - 1 do
			for i = 0, size - 1 do
				local index = DigGrid.index(grid, i, j)
				local h = grid.heights[index]
				for dj = -1, 1 do
					for di = -1, 1 do
						local ni, nj = i + di, j + dj
						if (di ~= 0 or dj ~= 0) and ni >= 0 and nj >= 0 and ni < size and nj < size then
							local neighbour = DigGrid.index(grid, ni, nj)
							local factor = if di ~= 0 and dj ~= 0 then SQRT2 else 1
							local limit = h + grid.maxStep * factor + 1e-4
							if grid.heights[neighbour] > limit and not (pillars and pillars[neighbour]) then
								error(
									string.format(
										"slope broken between (%d,%d)=%.3f and (%d,%d)=%.3f",
										i,
										j,
										h,
										ni,
										nj,
										grid.heights[neighbour]
									)
								)
							end
						end
					end
				end
			end
		end
	end

	local function snapshot(grid): { number }
		return table.clone(grid.heights)
	end

	T.suite("DigGrid", function()
		T.test("starts as untouched sand with an edge slope floor", function()
			local grid = newGrid()
			for _, h in grid.heights do
				T.equal(h, 20)
			end
			T.equal(grid.minHeights[DigGrid.index(grid, 0, 0)], 16, "corner floor")
			T.equal(grid.minHeights[DigGrid.index(grid, 2, 5)], 8, "third ring floor")
			T.equal(grid.minHeights[DigGrid.index(grid, 8, 8)], 0, "centre floor")
		end)

		T.test("one swing on a cell centre removes Power there with quadratic falloff", function()
			local grid = newGrid()
			local cx, cz = DigGrid.cellCenter(grid, 8, 8)
			local changed, removed = DigGrid.dig(grid, cx, cz, 5, 1.5)
			T.near(grid.heights[DigGrid.index(grid, 8, 8)], 18.5, EPS, "centre")
			-- side neighbour 4 studs away: 1.5 * (1 - (4/5)^2) = 0.54
			T.near(grid.heights[DigGrid.index(grid, 9, 8)], 20 - 0.54, EPS, "side")
			T.equal(grid.heights[DigGrid.index(grid, 9, 9)], 20, "diagonal is outside the radius")
			T.equal(#changed, 5)
			T.near(removed, 1.5 + 4 * 0.54, EPS, "removed")
		end)

		T.test("never digs below a cell's floor", function()
			local grid = newGrid()
			for _ = 1, 200 do
				DigGrid.dig(grid, 34, 30, 5, 1.5)
				DigGrid.dig(grid, 2, 2, 5, 1.5)
			end
			for index, h in grid.heights do
				T.truthy(h >= grid.minHeights[index] - EPS, "below floor at " .. index)
			end
			T.near(grid.heights[DigGrid.index(grid, 8, 7)], 0, EPS, "centre reaches bedrock")
			T.near(grid.heights[DigGrid.index(grid, 0, 0)], 16, EPS, "corner stops at its floor")
		end)

		T.test("keeps the slope rule and only lowers sand under random digging", function()
			local grid = newGrid()
			local rng = T.rng(7)
			for _ = 1, 400 do
				local before = snapshot(grid)
				local changed = DigGrid.dig(grid, rng:NextNumber(-4, 68), rng:NextNumber(-4, 68), 5, 1.5)
				local reported = {}
				for _, index in changed do
					T.truthy(not reported[index], "duplicate index in changed")
					reported[index] = true
				end
				for index, h in grid.heights do
					T.truthy(h <= before[index] + EPS, "height went up")
					if h < before[index] - EPS then
						T.truthy(reported[index], "a changed cell was not reported")
					end
				end
			end
			assertSlopeRule(grid)
		end)

		T.test("slumping turns a deep hole into a funnel", function()
			local grid = newGrid()
			local cx, cz = DigGrid.cellCenter(grid, 8, 8)
			-- 13 swings: centre 20 - 13 * 1.5 = 0.5. Side cells are dug directly too,
			-- but slumping keeps them pinned at centre + 4 once the hole gets deep.
			for _ = 1, 13 do
				DigGrid.dig(grid, cx, cz, 5, 1.5)
			end
			T.near(grid.heights[DigGrid.index(grid, 8, 8)], 0.5, EPS, "centre")
			T.near(grid.heights[DigGrid.index(grid, 9, 8)], 4.5, EPS, "side, slumped")
			T.near(grid.heights[DigGrid.index(grid, 10, 8)], 8.5, EPS, "two cells out, never dug directly")
			T.near(grid.heights[DigGrid.index(grid, 9, 9)], 0.5 + 4 * SQRT2, EPS, "diagonal, slumped")
			assertSlopeRule(grid)
		end)

		T.test("relaxation does not depend on processing order", function()
			local a, b = newGrid(), newGrid()
			for _, grid in { a, b } do
				grid.heights[DigGrid.index(grid, 5, 5)] = 0
				grid.heights[DigGrid.index(grid, 9, 6)] = 2
			end
			DigGrid.relax(a, { DigGrid.index(a, 5, 5), DigGrid.index(a, 9, 6) })
			DigGrid.relax(b, { DigGrid.index(b, 9, 6), DigGrid.index(b, 5, 5) })
			for index = 1, #a.heights do
				T.near(a.heights[index], b.heights[index], EPS, "cell " .. index)
			end
		end)

		T.test("ignores digs outside the zone", function()
			local grid = newGrid()
			local changed = DigGrid.dig(grid, -50, 30, 5, 1.5)
			T.equal(#changed, 0)
			changed = DigGrid.dig(grid, 30, 200, 5, 1.5)
			T.equal(#changed, 0)
		end)

		T.test("cellsInRect covers every overlapped cell", function()
			local grid = newGrid()
			local cells = DigGrid.cellsInRect(grid, 35.3, 35.3, 40.7, 40.7)
			T.equal(#cells, 9)
			local exact = DigGrid.cellsInRect(grid, 36, 36, 40, 40)
			T.equal(#exact, 1, "rect exactly on a cell")
			T.equal(exact[1], DigGrid.index(grid, 9, 9))
			T.equal(#DigGrid.cellsInRect(grid, -10, -10, -2, -2), 0, "outside")
		end)

		T.test("a raised floor holds sand up as a pillar and relax still terminates", function()
			local grid = newGrid()
			local pillar = DigGrid.index(grid, 8, 7)
			DigGrid.setFloor(grid, { pillar }, 9)
			for _ = 1, 300 do
				for _, offset in { { 0, 0 }, { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 } } do
					DigGrid.dig(grid, 34 + offset[1], 30 + offset[2], 5, 1.5)
				end
			end
			T.near(grid.heights[pillar], 9, EPS, "pillar stays at its floor")
			T.truthy(grid.heights[DigGrid.index(grid, 9, 7)] < 9, "neighbour can go below the pillar")
			assertSlopeRule(grid, { [pillar] = true })
		end)

		T.test("exposure goes from 0 when buried to 1 when cleared to the base", function()
			local grid = newGrid()
			local cells = DigGrid.cellsInRect(grid, 31.3, 27.3, 36.7, 32.7)
			T.equal(DigGrid.exposure(grid, cells, 15.4, 9), 0)
			T.truthy(not DigGrid.anyBelow(grid, cells, 15.4))
			DigGrid.lowerTo(grid, cells, 9)
			T.near(DigGrid.exposure(grid, cells, 15.4, 9), 1, EPS)
			T.truthy(DigGrid.anyBelow(grid, cells, 15.4))
			assertSlopeRule(grid)
		end)

		T.test("bounds returns the inclusive cell rectangle", function()
			local grid = newGrid()
			local minI, minJ, maxI, maxJ = DigGrid.bounds(
				grid,
				{ DigGrid.index(grid, 3, 9), DigGrid.index(grid, 7, 2), DigGrid.index(grid, 5, 5) }
			)
			T.equal(minI, 3)
			T.equal(minJ, 2)
			T.equal(maxI, 7)
			T.equal(maxJ, 9)
		end)

		T.test("encode/decode round-trips within one save level", function()
			local grid = newGrid()
			local rng = T.rng(11)
			for _ = 1, 150 do
				DigGrid.dig(grid, rng:NextNumber(0, 64), rng:NextNumber(0, 64), 5, 1.5)
			end
			local data = DigGrid.encode(grid)
			T.equal(#data, 256, "one character per cell")
			T.truthy(string.match(data, "^[%w%-_]+$") ~= nil, "URL-safe characters only")
			local restored = newGrid()
			T.truthy(DigGrid.decode(restored, data))
			local step = 20 / 63
			for index = 1, #grid.heights do
				T.near(restored.heights[index], grid.heights[index], step * 0.5 + 1e-4, "cell " .. index)
			end
			assertSlopeRule(restored)
		end)

		T.test("decode rejects bad data and leaves the grid untouched", function()
			local grid = newGrid()
			T.truthy(not DigGrid.decode(grid, "abc"), "wrong length")
			T.truthy(not DigGrid.decode(grid, string.rep("A", 255) .. "!"), "bad character")
			for _, h in grid.heights do
				T.equal(h, 20)
			end
		end)

		T.test("reset restores sand but keeps floors", function()
			local grid = newGrid()
			DigGrid.setFloor(grid, { 1 }, 18)
			DigGrid.dig(grid, 34, 30, 5, 1.5)
			DigGrid.reset(grid)
			for _, h in grid.heights do
				T.equal(h, 20)
			end
			T.equal(grid.minHeights[1], 18)
		end)
	end)
end
