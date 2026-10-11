return function(T, Loader)
	local DigValidation = Loader.load("src/shared/DigValidation")
	local RateLimiter = Loader.load("src/server/Util/RateLimiter")

	local function input(overrides: { [string]: number }?)
		local base = {
			targetX = 10,
			targetY = -3,
			targetZ = 70,
			rootX = 4,
			rootY = 3,
			rootZ = 64,
			zoneMinX = -32,
			zoneMinZ = 48,
			zoneSize = 64,
			zoneBottomY = -20,
			zoneTopY = 0,
			reach = 14,
			tolerance = 4,
			maxVerticalOffset = 24,
		}
		for key, value in overrides or {} do
			base[key] = value
		end
		return base
	end

	T.suite("DigValidation", function()
		T.test("accepts a normal swing", function()
			local ok, reason = DigValidation.check(input())
			T.truthy(ok)
			T.equal(reason, nil)
		end)

		T.test("rejects NaN, infinity and absurd numbers", function()
			for _, bad in { 0 / 0, math.huge, -math.huge, 1e9 } do
				local ok, reason = DigValidation.check(input({ targetX = bad }))
				T.truthy(not ok)
				T.equal(reason, "BadInput")
			end
			local _, reason = DigValidation.check(input({ targetZ = 0 / 0 }))
			T.equal(reason, "BadInput")
		end)

		T.test("rejects points outside the zone, edges are half-open", function()
			T.equal(select(2, DigValidation.check(input({ targetX = -32.01 }))), "OutsideZone")
			T.equal(select(2, DigValidation.check(input({ targetX = 32, rootX = 30 }))), "OutsideZone")
			T.equal(select(2, DigValidation.check(input({ targetZ = 112, rootZ = 110 }))), "OutsideZone")
			T.truthy((DigValidation.check(input({ targetX = -32, rootX = -30 }))), "min edge is inside")
		end)

		T.test("rejects points in the sky or under the bedrock", function()
			T.equal(select(2, DigValidation.check(input({ targetY = 4.5 }))), "BadHeight")
			T.equal(select(2, DigValidation.check(input({ targetY = -22.5 }))), "BadHeight")
		end)

		T.test("enforces reach plus tolerance", function()
			-- 18 studs away along X: exactly reach (14) + tolerance (4)
			T.truthy((DigValidation.check(input({ rootX = -8, rootZ = 70 }))))
			T.equal(select(2, DigValidation.check(input({ rootX = -8.1, rootZ = 70 }))), "TooFar")
			T.equal(select(2, DigValidation.check(input({ rootX = -8, rootZ = 70, tolerance = 0 }))), "TooFar")
		end)

		T.test("rejects a character far above the dig point", function()
			T.equal(select(2, DigValidation.check(input({ rootY = 40 }))), "TooHigh")
		end)
	end)

	T.suite("RateLimiter", function()
		T.test("allows a burst of `capacity`, then blocks", function()
			local limiter = RateLimiter.new(3, 1 / 0.27, 0)
			T.truthy(limiter:tryConsume(0))
			T.truthy(limiter:tryConsume(0))
			T.truthy(limiter:tryConsume(0))
			T.truthy(not limiter:tryConsume(0))
			T.truthy(limiter:tryConsume(0.28), "one token refilled")
		end)

		T.test("an honest client with network jitter is never rejected", function()
			local cooldown = 0.3
			local limiter = RateLimiter.new(3, 1 / (cooldown * 0.9), 0)
			local rng = T.rng(3)
			local rejected = 0
			for swing = 1, 400 do
				local arrival = swing * cooldown + rng:NextNumber(-0.12, 0.12)
				if not limiter:tryConsume(arrival) then
					rejected += 1
				end
			end
			T.equal(rejected, 0)
		end)

		T.test("a spamming client is held to the refill rate", function()
			local limiter = RateLimiter.new(3, 1 / 0.27, 0)
			local accepted = 0
			for step = 0, 999 do
				if limiter:tryConsume(step / 100) then -- 100 requests per second for 10 s
					accepted += 1
				end
			end
			T.truthy(accepted <= 3 + math.ceil(10 / 0.27), "accepted " .. accepted)
			T.truthy(accepted >= 3 + math.floor(10 / 0.27) - 1, "accepted " .. accepted)
		end)

		T.test("time going backwards never grants tokens", function()
			local limiter = RateLimiter.new(1, 1, 10)
			T.truthy(limiter:tryConsume(10))
			T.truthy(not limiter:tryConsume(5))
			T.truthy(not limiter:tryConsume(10.5))
		end)

		T.test("setRate keeps earned tokens and applies the new rate", function()
			local limiter = RateLimiter.new(2, 1, 0)
			limiter:tryConsume(0)
			limiter:tryConsume(0)
			limiter:setRate(4, 0)
			T.truthy(not limiter:tryConsume(0.2))
			T.truthy(limiter:tryConsume(0.26))
		end)
	end)
end
