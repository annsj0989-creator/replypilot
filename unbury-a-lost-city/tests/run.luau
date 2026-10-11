--[[
	Unit tests for the engine-independent game logic.
	Run from the project folder:  lune run tests/run
]]

local process = require("@lune/process")

local Loader = require("./Loader")
local TestKit = require("./TestKit")

local specs = {
	require("./specs/DigGrid.spec"),
	require("./specs/TerrainVoxels.spec"),
	require("./specs/Validation.spec"),
	require("./specs/Config.spec"),
	require("./specs/ServerFlow.spec"),
}

for _, spec in specs do
	spec(TestKit, Loader)
end

process.exit(if TestKit.summary() then 0 else 1)
