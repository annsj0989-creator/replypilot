--[[
	TestKit — a deliberately tiny test runner for Lune.
]]

local TestKit = {}

local passed = 0
local failures: { string } = {}
local currentSuite = ""

local function describeValue(value: any): string
	if type(value) == "number" then
		return string.format("%.6g", value)
	end
	return tostring(value)
end

function TestKit.suite(name: string, body: () -> ())
	currentSuite = name
	body()
	currentSuite = ""
end

function TestKit.test(name: string, body: () -> ())
	local ok, err = pcall(body)
	if ok then
		passed += 1
	else
		table.insert(failures, string.format("%s > %s\n    %s", currentSuite, name, tostring(err)))
	end
end

function TestKit.equal(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(
			string.format(
				"%sexpected %s, got %s",
				message and message .. ": " or "",
				describeValue(expected),
				describeValue(actual)
			),
			2
		)
	end
end

function TestKit.near(actual: number, expected: number, tolerance: number, message: string?)
	if math.abs(actual - expected) > tolerance then
		error(
			string.format(
				"%sexpected %s ± %s, got %s",
				message and message .. ": " or "",
				describeValue(expected),
				describeValue(tolerance),
				describeValue(actual)
			),
			2
		)
	end
end

function TestKit.truthy(value: any, message: string?)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

-- Deterministic RNG (Lune has no Roblox `Random`). Park–Miller minimal standard.
function TestKit.rng(seed: number)
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return {
		NextNumber = function(_, min: number, max: number): number
			state = (state * 16807) % 2147483647
			return min + (max - min) * (state - 1) / 2147483646
		end,
	}
end

function TestKit.summary(): boolean
	for _, failure in failures do
		print("FAIL " .. failure)
	end
	print(string.format("\n%d passed, %d failed", passed, #failures))
	return #failures == 0
end

return TestKit
