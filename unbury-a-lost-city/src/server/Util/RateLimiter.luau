--!strict
--[[
	RateLimiter — token bucket. A player may send `capacity` swings back-to-back
	(network jitter bunches requests together) but never more than
	`refillPerSecond` on average. The clock is passed in so tests control time.
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Fields = {
	capacity: number,
	tokens: number,
	refillPerSecond: number,
	last: number,
}

export type RateLimiter = typeof(setmetatable({} :: Fields, RateLimiter))

function RateLimiter.new(capacity: number, refillPerSecond: number, now: number): RateLimiter
	return setmetatable({
		capacity = capacity,
		tokens = capacity,
		refillPerSecond = refillPerSecond,
		last = now,
	}, RateLimiter)
end

function RateLimiter.refill(self: RateLimiter, now: number)
	-- `last` never moves backwards, so a clock that jumps back cannot mint tokens later.
	if now <= self.last then
		return
	end
	self.tokens = math.min(self.capacity, self.tokens + (now - self.last) * self.refillPerSecond)
	self.last = now
end

-- Changing tools changes the allowed rate; tokens already earned are kept.
function RateLimiter.setRate(self: RateLimiter, refillPerSecond: number, now: number)
	self:refill(now)
	self.refillPerSecond = refillPerSecond
end

function RateLimiter.tryConsume(self: RateLimiter, now: number): boolean
	self:refill(now)
	if self.tokens >= 1 then
		self.tokens -= 1
		return true
	end
	return false
end

return RateLimiter
