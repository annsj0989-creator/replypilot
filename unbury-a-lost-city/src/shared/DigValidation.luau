--!strict
--[[
	DigValidation — the rules a dig request must pass.

	Shared by both sides: the client runs it with zero tolerance so it never sends
	a request the server would refuse, and the server runs it with ReachTolerance
	as the authority. Pure Luau (plain numbers in, reason code out).
]]

local DigValidation = {}

export type Input = {
	targetX: number,
	targetY: number,
	targetZ: number,
	rootX: number,
	rootY: number,
	rootZ: number,
	zoneMinX: number,
	zoneMinZ: number,
	zoneSize: number, -- studs per side
	zoneBottomY: number, -- bedrock top
	zoneTopY: number, -- untouched surface
	reach: number,
	tolerance: number,
	maxVerticalOffset: number,
}

export type Reason = "BadInput" | "OutsideZone" | "BadHeight" | "TooFar" | "TooHigh"

local LIMIT = 1e6

local function isSaneNumber(value: number): boolean
	-- NaN fails the equality check; infinities and absurd values fail the bound.
	return value == value and value > -LIMIT and value < LIMIT
end

function DigValidation.check(input: Input): (boolean, Reason?)
	if not isSaneNumber(input.targetX) or not isSaneNumber(input.targetY) or not isSaneNumber(input.targetZ) then
		return false, "BadInput"
	end

	local localX = input.targetX - input.zoneMinX
	local localZ = input.targetZ - input.zoneMinZ
	if localX < 0 or localZ < 0 or localX >= input.zoneSize or localZ >= input.zoneSize then
		return false, "OutsideZone"
	end

	-- The aimed point must lie on or near the sand body, not in the sky.
	if input.targetY < input.zoneBottomY - 2 or input.targetY > input.zoneTopY + 4 then
		return false, "BadHeight"
	end

	local dx = input.targetX - input.rootX
	local dz = input.targetZ - input.rootZ
	local maxReach = input.reach + input.tolerance
	if dx * dx + dz * dz > maxReach * maxReach then
		return false, "TooFar"
	end

	if math.abs(input.rootY - input.targetY) > input.maxVerticalOffset then
		return false, "TooHigh"
	end

	return true, nil
end

return DigValidation
