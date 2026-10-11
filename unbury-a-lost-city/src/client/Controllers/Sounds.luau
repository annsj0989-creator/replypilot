--!strict
--[[
	Sounds — plays entries from SoundConfig. An entry with an empty Id is silent
	on purpose (no verified asset chosen yet), so missing sounds never error.
	Swing sounds use a small round-robin pool so fast digging never cuts itself off.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundConfig = require(ReplicatedStorage.Shared.Config.SoundConfig)

local Sounds = {}

local POOL_SIZE = 4

local pools: { [string]: { Sound } } = {}
local cursors: { [string]: number } = {}
local random = Random.new()

local function makeSound(name: string, spec: SoundConfig.SoundSpec, parent: Instance): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = spec.Id
	sound.Volume = spec.Volume
	sound.Looped = spec.Looped == true
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 80
	sound.Parent = parent
	return sound
end

-- positionalParent: an Attachment that is moved to each hit point (3D sound).
function Sounds.init(positionalParent: Instance)
	for name, spec in SoundConfig do
		if spec.Id ~= "" then
			local parent: Instance = if name == "DigHit" or name == "DigScrape" then positionalParent else SoundService
			local count = if parent == positionalParent then POOL_SIZE else 1
			local pool = {}
			for _ = 1, count do
				table.insert(pool, makeSound(name, spec, parent))
			end
			pools[name] = pool
			cursors[name] = 1
		end
	end

	local ambience = pools.DesertAmbience
	if ambience then
		ambience[1]:Play()
	end
end

function Sounds.play(name: string)
	local pool = pools[name]
	local spec = SoundConfig[name]
	if not pool or not spec then
		return
	end
	local cursor = cursors[name]
	cursors[name] = cursor % #pool + 1
	local sound = pool[cursor]
	sound.PlaybackSpeed = random:NextNumber(spec.PitchMin, spec.PitchMax)
	sound.TimePosition = 0
	sound:Play()
end

return Sounds
