--!strict
--[[
	GameConfig — every number that shapes how digging *feels* lives here.

	This module has no requires and touches no Roblox API, so the Lune unit tests
	and the in-engine code read exactly the same values.
]]

export type ToolStats = {
	Id: string,
	Level: number,
	Radius: number, -- studs; cells whose centre is inside this radius lose sand
	Power: number, -- studs of sand removed at the centre of one swing
	Cooldown: number, -- seconds between swings
	Reach: number, -- max horizontal studs from the character to the dig point
}

export type ArtifactSpec = {
	Id: string,
	LocalX: number, -- centre, studs from the zone's min-X edge
	LocalZ: number, -- centre, studs from the zone's min-Z edge
	BaseHeight: number, -- studs above bedrock where the artifact's pedestal stands
	Height: number, -- studs from base to the top of the model
	FootprintHalf: number, -- half-width of the solid footprint (sand under it never goes below BaseHeight)
	RevealMargin: number, -- studs around the footprint that must also be cleared
	RevealThreshold: number, -- 0..1 exposure that counts as "discovered"
}

local GameConfig = {}

GameConfig.Dig = {
	CellSize = 4, -- studs per heightmap cell. MUST equal the terrain voxel resolution (4).
	ZoneCells = 16, -- cells per side of one dig zone (16 * 4 = 64 studs)
	SandDepth = 20, -- diggable sand above bedrock, studs (multiple of CellSize)
	BedrockThickness = 4, -- undiggable layer below the sand, studs (multiple of CellSize)
	MaxSlopeStep = 4, -- max height difference to a side neighbour before sand slumps (45°)
	StrataDepth = 8, -- deeper than this below the untouched surface, darker packed sand shows
	MinOccupancy = 0.04, -- voxels thinner than this are written as air (avoids slivers)
	SurfaceY = 0, -- world Y of the untouched desert surface (multiple of CellSize)
}

GameConfig.Tools = {
	{ Id = "BasicShovel", Level = 1, Radius = 5, Power = 1.5, Cooldown = 0.3, Reach = 14 },
	{ Id = "WideShovel", Level = 2, Radius = 7.5, Power = 2.1, Cooldown = 0.25, Reach = 17 },
} :: { ToolStats }

GameConfig.Network = {
	ReachTolerance = 4, -- extra studs the server accepts on top of Reach (latency, movement)
	BurstCapacity = 3, -- swings that may arrive back-to-back because of network jitter
	RefillSlack = 0.9, -- server refills one token every Cooldown * RefillSlack seconds
	MaxVerticalOffset = 24, -- max |character Y - target Y|
	RejectWarnThreshold = 30, -- rejected requests per minute before the server logs a warning
}

GameConfig.Plots = {
	-- Min-corner (X, Z) of each private dig zone, nearest to the spawn first.
	-- All values must be multiples of CellSize so terrain writes stay voxel-aligned.
	SlotOrigins = {
		{ X = -32, Z = 48 },
		{ X = -32, Z = -112 },
		{ X = -112, Z = 48 },
		{ X = 48, Z = 48 },
		{ X = -112, Z = -112 },
		{ X = 48, Z = -112 },
	},
	SpawnBackoff = 10, -- studs outside the camp-side edge where the owner spawns
}

GameConfig.Artifacts = {
	{
		Id = "SunIdol",
		LocalX = 34, -- centre of cell 8
		LocalZ = 30, -- centre of cell 7
		BaseHeight = 9, -- 11 studs below the surface
		Height = 6.4, -- top sits 4.6 studs below the surface
		FootprintHalf = 1.7,
		RevealMargin = 1,
		RevealThreshold = 0.8,
	},
} :: { ArtifactSpec }

GameConfig.Feel = {
	ImpactDelay = 0.06, -- seconds between pressing and the hit effect, lines up with the swing
	AimSmoothing = 25, -- higher = aim ring follows the cursor more tightly
	FrontTargetDistance = 6, -- touch/gamepad: dig this far in front of the character
	TapAimLifetime = 12, -- touch: seconds a tapped aim point is remembered
}

return GameConfig
