--!strict
--[[
	DigService — the server authority for digging.

	One RemoteEvent call per shovel swing (at most 1 / Cooldown per player, about
	3-4 per second). Each request is checked in this order, cheapest first:
	  1. argument type            (exploiters can send anything)
	  2. owns a plot, alive, shovel equipped
	  3. token-bucket rate limit  (tool cooldown, small burst for jitter)
	  4. DigValidation            (inside own zone, sane height, within reach)
	Only then does the heightmap change. Terrain and artifact progress are derived
	from the heightmap on the server, so a client can never claim a reward.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DigGrid = require(ReplicatedStorage.Shared.DigGrid)
local DigValidation = require(ReplicatedStorage.Shared.DigValidation)
local Zone = require(ReplicatedStorage.Shared.Zone)

local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local ArtifactService = require(script.Parent.ArtifactService)
local PlotService = require(script.Parent.PlotService)
local TerrainRenderer = require(script.Parent.TerrainRenderer)

local DigService = {}

type Limiter = {
	bucket: RateLimiter.RateLimiter,
	level: number,
}

type RejectLog = {
	windowStart: number,
	count: number,
	warned: boolean,
}

local limiters: { [Player]: Limiter } = {}
local rejectLogs: { [Player]: RejectLog } = {}

local stats = {
	digs = 0,
	rejected = 0,
	totalSeconds = 0,
	maxSeconds = 0,
}

local function toolFor(player: Player): GameConfig.ToolStats
	local level = player:GetAttribute("ToolLevel")
	local tool = if type(level) == "number" then GameConfig.Tools[level] else nil
	return tool or GameConfig.Tools[1]
end

local function limiterFor(player: Player, tool: GameConfig.ToolStats, now: number): RateLimiter.RateLimiter
	local network = GameConfig.Network
	local refill = 1 / (tool.Cooldown * network.RefillSlack)
	local limiter = limiters[player]
	if not limiter then
		limiter = { bucket = RateLimiter.new(network.BurstCapacity, refill, now), level = tool.Level }
		limiters[player] = limiter
	elseif limiter.level ~= tool.Level then
		limiter.bucket:setRate(refill, now)
		limiter.level = tool.Level
	end
	return limiter.bucket
end

local function reject(player: Player, reason: string, now: number)
	stats.rejected += 1
	local existing = rejectLogs[player]
	local log: RejectLog = if existing and now - existing.windowStart <= 60
		then existing
		else { windowStart = now, count = 0, warned = false }
	rejectLogs[player] = log
	log.count += 1
	if log.count >= GameConfig.Network.RejectWarnThreshold and not log.warned then
		log.warned = true
		warn(
			`[DigService] {player.Name} ({player.UserId}) had {log.count} rejected dig requests in a minute, last: {reason}`
		)
	end
end

local function hasShovelEquipped(character: Model): boolean
	local tool = character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("DigTool") == true
end

-- Handles one DigRequest. Public so the integration tests can drive it directly.
function DigService.handleRequest(player: Player, target: any)
	local now = os.clock()

	if typeof(target) ~= "Vector3" then
		reject(player, "BadInput", now)
		return
	end

	local plot = PlotService.getPlot(player)
	local character = player.Character
	if not plot or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	if not hasShovelEquipped(character) then
		reject(player, "NoTool", now)
		return
	end

	local tool = toolFor(player)
	if not limiterFor(player, tool, now):tryConsume(now) then
		reject(player, "RateLimited", now)
		return
	end

	local zone = plot.zone
	local rootPosition = root.Position
	local ok, reason = DigValidation.check({
		targetX = target.X,
		targetY = target.Y,
		targetZ = target.Z,
		rootX = rootPosition.X,
		rootY = rootPosition.Y,
		rootZ = rootPosition.Z,
		zoneMinX = zone.minX,
		zoneMinZ = zone.minZ,
		zoneSize = zone.size,
		zoneBottomY = zone.bottomY,
		zoneTopY = zone.topY,
		reach = tool.Reach,
		tolerance = GameConfig.Network.ReachTolerance,
		maxVerticalOffset = GameConfig.Network.MaxVerticalOffset,
	})
	if not ok then
		reject(player, reason or "Invalid", now)
		return
	end

	local localX, localZ = Zone.toLocal(zone, target.X, target.Z)
	local changed = DigGrid.dig(plot.grid, localX, localZ, tool.Radius, tool.Power)
	if #changed > 0 then
		TerrainRenderer.renderCells(zone, plot.grid, changed)
		ArtifactService.onCellsChanged(plot, changed)
	end

	local elapsed = os.clock() - now
	stats.digs += 1
	stats.totalSeconds += elapsed
	stats.maxSeconds = math.max(stats.maxSeconds, elapsed)
end

function DigService.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local digRequest = remotes:WaitForChild("DigRequest") :: RemoteEvent
	digRequest.OnServerEvent:Connect(DigService.handleRequest)

	Players.PlayerRemoving:Connect(function(player)
		limiters[player] = nil
		rejectLogs[player] = nil
	end)
end

-- Server cost of accepted digs, for the Studio stats overlay.
function DigService.takeStats(): (number, number, number, number)
	local digs, rejected = stats.digs, stats.rejected
	local average = if digs > 0 then stats.totalSeconds / digs else 0
	local maximum = stats.maxSeconds
	stats.digs, stats.rejected, stats.totalSeconds, stats.maxSeconds = 0, 0, 0, 0
	return digs, rejected, average, maximum
end

return DigService
