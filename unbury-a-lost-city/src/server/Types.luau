--!strict
-- Shared server-side types (kept separate so services do not require each other in a cycle).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DigGrid = require(ReplicatedStorage.Shared.DigGrid)
local Zone = require(ReplicatedStorage.Shared.Zone)

export type ArtifactState = {
	spec: GameConfig.ArtifactSpec,
	model: Model,
	record: Configuration, -- replicated state: attributes State, Progress, Position
	footprintCells: { number },
	revealCells: { number },
	revealSet: { [number]: boolean },
	topHeight: number,
	glimpsed: boolean,
	discovered: boolean,
	lastSentProgress: number,
}

export type Plot = {
	id: number,
	zone: Zone.Zone,
	grid: DigGrid.Grid,
	folder: Folder,
	modelsFolder: Folder,
	recordsFolder: Configuration,
	signLabel: TextLabel,
	artifacts: { ArtifactState },
	discoveries: { [string]: boolean },
	owner: Player?,
}

return nil
