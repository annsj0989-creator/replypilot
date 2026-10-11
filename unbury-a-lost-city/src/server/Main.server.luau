--!strict
-- Server entry point. Order matters: the world and every dig zone exist before
-- the first character is loaded.

local Services = script.Parent.Services

local WorldBuilder = require(Services.WorldBuilder)
local PlotService = require(Services.PlotService)
local ToolService = require(Services.ToolService)
local DigService = require(Services.DigService)
local PlayerService = require(Services.PlayerService)
local DebugService = require(Services.DebugService)

WorldBuilder.build()
PlotService.init()
ToolService.init()
DigService.init()
DebugService.init()
PlayerService.init()
