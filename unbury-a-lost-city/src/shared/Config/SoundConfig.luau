--!strict
--[[
	SoundConfig — every sound the game plays, in one place.

	PHASE 0 STATUS: no licensed sound effects have been selected yet.
	  * An empty Id means "intentionally silent until a verified asset is chosen".
	  * Placeholder = true marks a sound that ships inside every Roblox client
	    (rbxasset://sounds/..., confirmed in the client file manifest) and is used
	    only as a stand-in so the timing can be tested. It is NOT the final sound.
	Replace these with audio from the Creator Store whose licence allows use in
	this experience, checked in Studio, before any public test.
]]

export type SoundSpec = {
	Id: string,
	Volume: number,
	PitchMin: number,
	PitchMax: number,
	Looped: boolean?,
	Placeholder: boolean,
	Purpose: string,
}

local SoundConfig: { [string]: SoundSpec } = {
	DigHit = {
		Id = "rbxasset://sounds/action_jump_land.mp3",
		Volume = 0.5,
		PitchMin = 0.7,
		PitchMax = 0.9,
		Placeholder = true,
		Purpose = "Shovel bites into sand (every swing)",
	},
	DigScrape = {
		Id = "",
		Volume = 0.35,
		PitchMin = 0.95,
		PitchMax = 1.1,
		Placeholder = false,
		Purpose = "Shovel scrapes a stone or metal surface",
	},
	ArtifactGlimpse = {
		Id = "rbxasset://sounds/volume_slider.ogg",
		Volume = 0.7,
		PitchMin = 1.5,
		PitchMax = 1.6,
		Placeholder = true,
		Purpose = "First glint of a buried artifact",
	},
	ArtifactDiscovered = {
		Id = "",
		Volume = 0.8,
		PitchMin = 1,
		PitchMax = 1,
		Placeholder = false,
		Purpose = "Artifact fully uncovered (reward sting)",
	},
	RareDiscovery = {
		Id = "",
		Volume = 0.9,
		PitchMin = 1,
		PitchMax = 1,
		Placeholder = false,
		Purpose = "Rare find (PHASE 1+)",
	},
	ToolUpgrade = {
		Id = "",
		Volume = 0.8,
		PitchMin = 1,
		PitchMax = 1,
		Placeholder = false,
		Purpose = "Tool upgraded (PHASE 1)",
	},
	TempleRestore = {
		Id = "",
		Volume = 1,
		PitchMin = 1,
		PitchMax = 1,
		Placeholder = false,
		Purpose = "Temple restoration (PHASE 1)",
	},
	DesertAmbience = {
		Id = "",
		Volume = 0.3,
		PitchMin = 1,
		PitchMax = 1,
		Looped = true,
		Placeholder = false,
		Purpose = "Quiet desert wind loop",
	},
}

return SoundConfig
