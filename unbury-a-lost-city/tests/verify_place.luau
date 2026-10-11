--[[
	Opens the place file produced by Rojo and checks that the structure and the
	settings the code depends on are really in it.
	Run from the project folder after building:
	  rojo build default.project.json -o build/UnburyALostCity_Phase0.rbxl
	  lune run tests/verify_place build/UnburyALostCity_Phase0.rbxl
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local TestKit = require("./TestKit")
local T = TestKit

local path = process.args[1] or "build/UnburyALostCity_Phase0.rbxl"
local game = roblox.deserializePlace(fs.readFile(path))

local function find(root: any, names: { string }): any
	local current = root
	for _, name in names do
		current = current:FindFirstChild(name)
		if current == nil then
			error("missing " .. table.concat(names, "."))
		end
	end
	return current
end

T.suite("Place file " .. path, function()
	T.test("remotes exist before any script runs", function()
		local remotes = find(game:GetService("ReplicatedStorage"), { "Remotes" })
		for _, name in { "DigRequest", "Notify", "DebugCommand" } do
			T.equal(find(remotes, { name }).ClassName, "RemoteEvent", name)
		end
	end)

	T.test("scripts have the right classes", function()
		local server = find(game:GetService("ServerScriptService"), { "Server" })
		T.equal(find(server, { "Main" }).ClassName, "Script")
		for _, name in
			{
				"WorldBuilder",
				"PlotService",
				"DigService",
				"ArtifactService",
				"TerrainRenderer",
				"ToolService",
				"PlayerService",
				"DebugService",
			}
		do
			T.equal(find(server, { "Services", name }).ClassName, "ModuleScript", name)
		end
		local client = find(game:GetService("StarterPlayer"), { "StarterPlayerScripts", "Client" })
		T.equal(find(client, { "Main" }).ClassName, "LocalScript")
		local shared = find(game:GetService("ReplicatedStorage"), { "Shared" })
		for _, name in { "DigGrid", "DigValidation", "TerrainVoxels", "Zone", "Strings" } do
			T.equal(find(shared, { name }).ClassName, "ModuleScript", name)
		end
	end)

	T.test("characters load only after the world is built", function()
		T.equal(game:GetService("Players").CharacterAutoLoads, false)
	end)

	T.test("streaming, lighting and atmosphere settings were applied", function()
		local workspace = game:GetService("Workspace")
		T.equal(workspace.StreamingEnabled, true)
		local lighting = game:GetService("Lighting")
		T.equal(lighting.Technology, roblox.Enum.Technology.ShadowMap)
		T.near(lighting.ClockTime, 15.4, 1e-4)
		T.truthy(lighting:FindFirstChildOfClass("Atmosphere"), "Atmosphere")
		T.truthy(lighting:FindFirstChildOfClass("ColorCorrectionEffect"), "ColorCorrection")
	end)

	T.test("the client scripts contain no placeholder asset ids", function()
		for _, descendant in game:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				local source = descendant.Source
				T.truthy(not string.find(source, "rbxassetid://%d"), descendant:GetFullName() .. " uses an rbxassetid")
			end
		end
	end)
end)

process.exit(if TestKit.summary() then 0 else 1)
