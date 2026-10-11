return function(T, Loader)
	local GameConfig = Loader.load("src/shared/Config/GameConfig")
	local Zone = Loader.load("src/shared/Zone")
	local DigGrid = Loader.load("src/shared/DigGrid")
	local Strings = Loader.load("src/shared/Strings")

	local dig = GameConfig.Dig

	local function isMultiple(value: number, of: number): boolean
		return value % of == 0
	end

	T.suite("Config", function()
		T.test("heightmap cells match the 4-stud terrain voxel grid", function()
			T.equal(dig.CellSize, 4)
			T.truthy(isMultiple(dig.SandDepth, dig.CellSize), "SandDepth")
			T.truthy(isMultiple(dig.BedrockThickness, dig.CellSize), "BedrockThickness")
			T.truthy(isMultiple(dig.SurfaceY, dig.CellSize), "SurfaceY")
		end)

		T.test("every slot is voxel-aligned, separate, and clear of the camp", function()
			local zones = {}
			for slot = 1, Zone.slotCount() do
				local zone = Zone.fromSlot(slot)
				T.truthy(zone, "slot " .. slot)
				T.truthy(isMultiple(zone.minX, dig.CellSize) and isMultiple(zone.minZ, dig.CellSize), "aligned")
				T.truthy(
					not (zone.minX <= 0 and 0 < zone.minX + zone.size and zone.minZ <= 0 and 0 < zone.minZ + zone.size),
					"camp"
				)
				table.insert(zones, zone)
			end
			for a = 1, #zones do
				for b = a + 1, #zones do
					local za, zb = zones[a], zones[b]
					local overlapX = za.minX < zb.minX + zb.size + 8 and zb.minX < za.minX + za.size + 8
					local overlapZ = za.minZ < zb.minZ + zb.size + 8 and zb.minZ < za.minZ + za.size + 8
					T.truthy(not (overlapX and overlapZ), string.format("slots %d and %d need an 8-stud gap", a, b))
				end
			end
			T.equal(Zone.fromSlot(Zone.slotCount() + 1), nil)
		end)

		T.test("owners spawn outside their zone on the camp side", function()
			for slot = 1, Zone.slotCount() do
				local zone = Zone.fromSlot(slot)
				local x, _, z, lookZ = Zone.spawnPoint(zone)
				local localX, localZ = Zone.toLocal(zone, x, z)
				T.truthy(localZ < 0 or localZ >= zone.size, "spawn outside zone, slot " .. slot)
				T.truthy(localX > 0 and localX < zone.size)
				T.truthy(math.abs(z) < math.abs(lookZ), "spawn is closer to the camp than the zone centre")
			end
		end)

		T.test("artifacts are buried inside the diggable interior", function()
			local grid = DigGrid.new({
				size = dig.ZoneCells,
				cellSize = dig.CellSize,
				sandDepth = dig.SandDepth,
				maxStep = dig.MaxSlopeStep,
			})
			for _, artifact in GameConfig.Artifacts do
				local half = artifact.FootprintHalf + artifact.RevealMargin
				local cells = DigGrid.cellsInRect(
					grid,
					artifact.LocalX - half,
					artifact.LocalZ - half,
					artifact.LocalX + half,
					artifact.LocalZ + half
				)
				T.truthy(#cells > 0)
				for _, index in cells do
					T.truthy(
						grid.minHeights[index] <= artifact.BaseHeight,
						artifact.Id .. " reachable down to its base"
					)
				end
				T.truthy(artifact.BaseHeight >= 0)
				T.truthy(artifact.BaseHeight + artifact.Height < dig.SandDepth, artifact.Id .. " starts fully buried")
				T.truthy(artifact.RevealThreshold > 0 and artifact.RevealThreshold <= 1)
			end
		end)

		T.test("each tool level is strictly better than the last", function()
			for level = 2, #GameConfig.Tools do
				local previous, tool = GameConfig.Tools[level - 1], GameConfig.Tools[level]
				T.equal(tool.Level, level)
				T.truthy(tool.Radius > previous.Radius, "radius")
				T.truthy(tool.Power > previous.Power, "power")
				T.truthy(tool.Cooldown < previous.Cooldown, "cooldown")
				T.truthy(tool.Reach >= previous.Reach, "reach")
			end
		end)

		T.test("both languages define every string and artifact name", function()
			local ko, en = Strings.forLocale("ko-kr"), Strings.forLocale("en-us")
			T.truthy(ko ~= en)
			T.equal(Strings.forLocale(nil), en)
			for key, value in en do
				T.truthy(ko[key] ~= nil, "ko missing " .. key)
				T.equal(type(ko[key]), type(value))
			end
			for _, artifact in GameConfig.Artifacts do
				T.truthy(ko.ArtifactNames[artifact.Id] and en.ArtifactNames[artifact.Id], artifact.Id)
			end
		end)
	end)
end
