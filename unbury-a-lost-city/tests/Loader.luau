--[[
	Loader — runs the game's ModuleScripts under Lune exactly as written.

	Roblox modules require each other with instance paths
	(`require(script.Parent.DigGrid)`). This loader gives every module a fake
	`script` object that maps those paths onto files, so modules can be tested
	without any edits.

	  Loader.load(path)          pure modules, default environment
	  Loader.create(options)     separate cache with extra globals (e.g. a fake
	                             `game`) and per-path module overrides (stubs)
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

export type Options = {
	globals: { [string]: any }?,
	overrides: { [string]: any }?,
}

export type Instance = {
	load: (path: string) -> any,
}

local Loader = {}

function Loader.scriptPath(path: string): any
	return setmetatable({ __path = path }, {
		__index = function(_, key: string)
			if key == "Parent" then
				local parent = string.match(path, "^(.*)/[^/]+$")
				assert(parent, "no parent for " .. path)
				return Loader.scriptPath(parent)
			end
			return Loader.scriptPath(path .. "/" .. key)
		end,
	})
end

function Loader.create(options: Options?): Instance
	local globals = (options and options.globals) or {}
	local overrides = (options and options.overrides) or {}
	local cache: { [string]: { value: any } } = {}
	local instance = {} :: Instance

	local function robloxRequire(target: any): any
		local path = type(target) == "table" and rawget(target, "__path")
		assert(type(path) == "string", "Loader only supports script-relative requires")
		return instance.load(path)
	end

	function instance.load(path: string): any
		if overrides[path] ~= nil then
			return overrides[path]
		end
		local cached = cache[path]
		if cached then
			return cached.value
		end
		local file = path .. ".luau"
		if not fs.isFile(file) then
			file = path .. "/init.luau"
		end
		assert(fs.isFile(file), "module not found: " .. path)
		local environment = table.clone(globals)
		environment.script = Loader.scriptPath(path)
		environment.require = robloxRequire
		local chunk = luau.load(fs.readFile(file), { debugName = file, environment = environment })
		local value = chunk()
		cache[path] = { value = value }
		return value
	end

	return instance
end

local default = Loader.create()

function Loader.load(path: string): any
	return default.load(path)
end

return Loader
