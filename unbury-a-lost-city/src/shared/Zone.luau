--!strict
--[[
	Zone — world-space geometry of a dig slot, derived only from GameConfig so the
	server and every client agree without sending it over the network.
]]

local GameConfig = require(script.Parent.Config.GameConfig)

local Zone = {}

export type Zone = {
	slot: number,
	minX: number, -- world X of the zone's min corner
	minZ: number, -- world Z of the zone's min corner
	size: number, -- studs per side
	topY: number, -- untouched surface
	bottomY: number, -- bedrock top (height 0 in DigGrid)
	centerX: number,
	centerZ: number,
	campSide: number, -- +1 if the camp (world origin) lies towards +Z, else -1
}

function Zone.slotCount(): number
	return #GameConfig.Plots.SlotOrigins
end

function Zone.fromSlot(slot: number): Zone?
	local origin = GameConfig.Plots.SlotOrigins[slot]
	if origin == nil then
		return nil
	end
	local dig = GameConfig.Dig
	local size = dig.ZoneCells * dig.CellSize
	local centerZ = origin.Z + size / 2
	return {
		slot = slot,
		minX = origin.X,
		minZ = origin.Z,
		size = size,
		topY = dig.SurfaceY,
		bottomY = dig.SurfaceY - dig.SandDepth,
		centerX = origin.X + size / 2,
		centerZ = centerZ,
		campSide = if centerZ > 0 then -1 else 1,
	}
end

-- World XZ of a point given in zone-local studs.
function Zone.toWorld(zone: Zone, localX: number, localZ: number): (number, number)
	return zone.minX + localX, zone.minZ + localZ
end

function Zone.toLocal(zone: Zone, worldX: number, worldZ: number): (number, number)
	return worldX - zone.minX, worldZ - zone.minZ
end

-- Where the owner spawns: just outside the camp-facing edge, looking at the zone.
function Zone.spawnPoint(zone: Zone): (number, number, number, number)
	local edgeZ = if zone.campSide > 0 then zone.minZ + zone.size else zone.minZ
	local spawnZ = edgeZ + zone.campSide * GameConfig.Plots.SpawnBackoff
	return zone.centerX, zone.topY, spawnZ, zone.centerZ
end

return Zone
