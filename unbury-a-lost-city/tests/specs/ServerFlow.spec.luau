--[[
	Integration test of the real server dig pipeline:
	DigService.handleRequest -> DigValidation / RateLimiter -> DigGrid
	-> TerrainRenderer (WriteVoxels) -> ArtifactService (state attributes).

	Runs the unmodified modules with Lune's Roblox datatypes and instances. Only
	things that need the engine are faked: Terrain (records every WriteVoxels call
	and checks the engine's array/region contract), the player's character, the
	clock, the artifact model, and PlotService (to hand DigService a test plot).
]]

local roblox = require("@lune/roblox")

return function(T, Loader)
	local Vector3, Region3, CFrame, Enum, Instance =
		roblox.Vector3, roblox.Region3, roblox.CFrame, roblox.Enum, roblox.Instance

	local function setup()
		local now = 1000
		local writes = {}
		local fakeTerrain = {}
		function fakeTerrain.WriteVoxels(_, region, resolution, materials, occupancies)
			-- Terrain:WriteVoxels contract: 4-stud resolution, grid-aligned region,
			-- [x][y][z] arrays exactly region.Size / 4, Air <=> zero occupancy.
			assert(resolution == 4, "resolution must be 4")
			local size = region.Size
			local min = region.CFrame.Position - size / 2
			for _, axis in { "X", "Y", "Z" } do
				assert(min[axis] % 4 == 0, "region min not aligned on " .. axis .. ": " .. tostring(min[axis]))
				assert(size[axis] % 4 == 0, "region size not aligned on " .. axis)
			end
			local nx, ny, nz = size.X / 4, size.Y / 4, size.Z / 4
			assert(#materials == nx and #occupancies == nx, "x size")
			for x = 1, nx do
				assert(#materials[x] == ny and #occupancies[x] == ny, "y size")
				for y = 1, ny do
					assert(#materials[x][y] == nz and #occupancies[x][y] == nz, "z size")
					for z = 1, nz do
						local material, occupancy = materials[x][y][z], occupancies[x][y][z]
						assert(occupancy >= 0 and occupancy <= 1, "occupancy out of range")
						assert((material == Enum.Material.Air) == (occupancy == 0), "air/occupancy mismatch")
					end
				end
			end
			table.insert(writes, { min = min, size = size })
		end

		local plots = {}
		local services = {
			ReplicatedStorage = { Shared = Loader.scriptPath("src/shared") },
			Workspace = { Terrain = fakeTerrain },
			Players = {},
			ServerStorage = {},
			RunService = {},
		}
		local fakeGame = {
			GetService = function(_, name)
				return assert(services[name], "service not faked: " .. name)
			end,
		}
		local activated = {}
		local env = Loader.create({
			globals = {
				game = fakeGame,
				Instance = Instance,
				Vector3 = Vector3,
				Region3 = Region3,
				CFrame = CFrame,
				Enum = Enum,
				os = {
					clock = function()
						return now
					end,
				},
				warn = function() end,
			},
			overrides = {
				["src/server/Services/ArtifactFactory"] = {
					create = function(id)
						return {
							Name = id,
							PivotTo = function(self, cframe)
								self.pivot = cframe
							end,
							Destroy = function() end,
						}
					end,
					activate = function(model)
						activated[model.Name] = true
					end,
				},
				["src/server/Services/PlotService"] = {
					getPlot = function(player)
						return plots[player]
					end,
				},
			},
		})

		local GameConfig = env.load("src/shared/Config/GameConfig")
		local DigGrid = env.load("src/shared/DigGrid")
		local Zone = env.load("src/shared/Zone")
		local ArtifactService = env.load("src/server/Services/ArtifactService")
		local DigService = env.load("src/server/Services/DigService")

		local function makePlot(slot: number)
			local dig = GameConfig.Dig
			local plot = {
				id = slot,
				zone = Zone.fromSlot(slot),
				grid = DigGrid.new({
					size = dig.ZoneCells,
					cellSize = dig.CellSize,
					sandDepth = dig.SandDepth,
					maxStep = dig.MaxSlopeStep,
				}),
				folder = Instance.new("Folder"),
				modelsFolder = Instance.new("Folder"),
				recordsFolder = Instance.new("Configuration"),
				artifacts = {},
				discoveries = {},
			}
			ArtifactService.setup(plot)
			return plot
		end

		local function makePlayer(plot, position)
			local state = {
				attributes = { ToolLevel = 1 },
				hasTool = true,
				humanoid = { Health = 100 },
				root = {
					Position = position,
					IsA = function(_, className)
						return className == "BasePart"
					end,
				},
			}
			local tool = {
				GetAttribute = function(_, key)
					return if key == "DigTool" then true else nil
				end,
			}
			local character = {
				FindFirstChildOfClass = function(_, className)
					if className == "Humanoid" then
						return state.humanoid
					elseif className == "Tool" then
						return if state.hasTool then tool else nil
					end
					return nil
				end,
				FindFirstChild = function(_, name)
					return if name == "HumanoidRootPart" then state.root else nil
				end,
			}
			local player = {
				Name = "Tester",
				UserId = 1,
				Character = character,
				GetAttribute = function(_, key)
					return state.attributes[key]
				end,
			}
			plots[player] = plot
			return player, state
		end

		return {
			GameConfig = GameConfig,
			DigGrid = DigGrid,
			Zone = Zone,
			DigService = DigService,
			makePlot = makePlot,
			makePlayer = makePlayer,
			writes = writes,
			activated = activated,
			advance = function(seconds: number)
				now += seconds
			end,
		}
	end

	local function sumHeights(grid): number
		local total = 0
		for _, h in grid.heights do
			total += h
		end
		return total
	end

	local function artifactTarget(ctx, plot)
		local spec = ctx.GameConfig.Artifacts[1]
		local x, z = ctx.Zone.toWorld(plot.zone, spec.LocalX, spec.LocalZ)
		return Vector3.new(x, plot.zone.topY, z)
	end

	local function standNear(ctx, plot)
		local target = artifactTarget(ctx, plot)
		return target + Vector3.new(0, 3, -6)
	end

	T.suite("Server dig flow (integration)", function()
		T.test("a valid swing changes the heightmap and writes aligned voxels", function()
			local ctx = setup()
			local plot = ctx.makePlot(1)
			local player = ctx.makePlayer(plot, standNear(ctx, plot))
			local before = sumHeights(plot.grid)
			ctx.DigService.handleRequest(player, artifactTarget(ctx, plot))
			T.truthy(sumHeights(plot.grid) < before, "sand removed")
			T.equal(#ctx.writes, 1, "one WriteVoxels call")
			local write = ctx.writes[1]
			T.equal(write.size.Y, 24, "bedrock + full sand column")
			T.truthy(write.size.X <= 16 and write.size.Z <= 16, "only the touched columns are rewritten")
		end)

		T.test("rejects payloads that are not a finite Vector3", function()
			local ctx = setup()
			local plot = ctx.makePlot(1)
			local player = ctx.makePlayer(plot, standNear(ctx, plot))
			local before = sumHeights(plot.grid)
			for _, payload in
				{ "34,0,30", nil, 5, { X = 1, Y = 2, Z = 3 }, Vector3.new(0 / 0, 0, 0), Vector3.new(math.huge, 0, 0) }
			do
				ctx.advance(1)
				ctx.DigService.handleRequest(player, payload)
			end
			T.equal(sumHeights(plot.grid), before)
			T.equal(#ctx.writes, 0)
		end)

		T.test("rejects digging another player's zone, far away, in the sky, dead or without a shovel", function()
			local ctx = setup()
			local plot = ctx.makePlot(1)
			local other = ctx.makePlot(2)
			local player, state = ctx.makePlayer(plot, standNear(ctx, plot))
			local before, otherBefore = sumHeights(plot.grid), sumHeights(other.grid)

			ctx.DigService.handleRequest(player, artifactTarget(ctx, other)) -- someone else's zone
			ctx.advance(1)
			ctx.DigService.handleRequest(player, artifactTarget(ctx, plot) + Vector3.new(0, 30, 0)) -- sky
			ctx.advance(1)
			state.root.Position = artifactTarget(ctx, plot) + Vector3.new(0, 3, -40) -- too far
			ctx.DigService.handleRequest(player, artifactTarget(ctx, plot))
			ctx.advance(1)
			state.root.Position = standNear(ctx, plot)
			state.hasTool = false
			ctx.DigService.handleRequest(player, artifactTarget(ctx, plot))
			ctx.advance(1)
			state.hasTool = true
			state.humanoid.Health = 0
			ctx.DigService.handleRequest(player, artifactTarget(ctx, plot))

			T.equal(sumHeights(plot.grid), before)
			T.equal(sumHeights(other.grid), otherBefore)
			T.equal(#ctx.writes, 0)
		end)

		T.test("rejects a target just outside your own zone even when it is within reach", function()
			local ctx = setup()
			local plot = ctx.makePlot(1)
			local edgeX = plot.zone.minX
			local z = plot.zone.minZ + 32
			-- 2 studs outside the edge: a radius-5 swing there would still bite the edge cells.
			local player = ctx.makePlayer(plot, Vector3.new(edgeX + 2, 3, z))
			local before = sumHeights(plot.grid)
			ctx.DigService.handleRequest(player, Vector3.new(edgeX - 2, plot.zone.topY, z))
			T.equal(sumHeights(plot.grid), before)
			T.equal(#ctx.writes, 0)
		end)

		T.test("rate limit allows a jitter burst of 3, then the tool's pace", function()
			local ctx = setup()
			local plot = ctx.makePlot(1)
			local player = ctx.makePlayer(plot, standNear(ctx, plot))
			local target = artifactTarget(ctx, plot) + Vector3.new(8, 0, 8)
			for _ = 1, 10 do
				ctx.DigService.handleRequest(player, target) -- 10 swings in the same instant
			end
			T.equal(#ctx.writes, 3, "burst")
			ctx.advance(0.3)
			ctx.DigService.handleRequest(player, target)
			T.equal(#ctx.writes, 4, "one more after a cooldown")
		end)

		T.test("uncovering the idol: Hidden -> Glimpsed -> Discovered, driven only by the server", function()
			local ctx = setup()
			local plot = ctx.makePlot(1)
			local player = ctx.makePlayer(plot, standNear(ctx, plot))
			local record = plot.recordsFolder:FindFirstChild("SunIdol")
			T.truthy(record, "state record exists")
			T.equal(record:GetAttribute("State"), "Hidden")

			local spec = ctx.GameConfig.Artifacts[1]
			local center = artifactTarget(ctx, plot)
			local states, progress = {}, {}
			local offsets =
				{ { 0, 0 }, { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 }, { 4, 4 }, { -4, -4 }, { 4, -4 }, { -4, 4 } }
			local swings = 0
			while record:GetAttribute("State") ~= "Discovered" and swings < 200 do
				local offset = offsets[swings % #offsets + 1]
				swings += 1
				ctx.advance(0.3)
				ctx.DigService.handleRequest(player, center + Vector3.new(offset[1], 0, offset[2]))
				local state = record:GetAttribute("State")
				if states[#states] ~= state then
					table.insert(states, state)
				end
				table.insert(progress, record:GetAttribute("Progress"))
			end

			T.equal(table.concat(states, ">"), "Hidden>Glimpsed>Discovered")
			for index = 2, #progress do
				T.truthy(progress[index] >= progress[index - 1], "progress never goes back")
			end
			T.equal(record:GetAttribute("Progress"), 1)
			T.truthy(ctx.activated.SunIdol, "model activated")
			T.truthy(plot.discoveries.SunIdol, "discovery recorded for saving")

			-- The last sand slid off: every reveal cell is at or below the idol's base.
			local half = spec.FootprintHalf + spec.RevealMargin
			local cells = ctx.DigGrid.cellsInRect(
				plot.grid,
				spec.LocalX - half,
				spec.LocalZ - half,
				spec.LocalX + half,
				spec.LocalZ + half
			)
			for _, index in cells do
				T.truthy(plot.grid.heights[index] <= spec.BaseHeight + 1e-6, "cell " .. index .. " cleared")
			end
			-- The pedestal never floats: the sand under it stays at the base.
			local footprint = ctx.DigGrid.cellsInRect(
				plot.grid,
				spec.LocalX - spec.FootprintHalf,
				spec.LocalZ - spec.FootprintHalf,
				spec.LocalX + spec.FootprintHalf,
				spec.LocalZ + spec.FootprintHalf
			)
			for _, index in footprint do
				T.near(plot.grid.heights[index], spec.BaseHeight, 1e-6, "pillar under the pedestal")
			end
		end)
	end)
end
