--!strict
--[[
	PlayerService — join, spawn, respawn, leave.

	Characters are loaded manually (Players.CharacterAutoLoads = false) so nobody
	spawns before the terrain exists, and so each player appears at their own dig
	site, facing it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotService = require(script.Parent.PlotService)
local ToolService = require(script.Parent.ToolService)

local PlayerService = {}

local notify: RemoteEvent
local handled: { [Player]: boolean } = {}

local function spawnCharacter(player: Player)
	if player.Parent ~= Players then
		return
	end
	player:LoadCharacterAsync()
	local character = player.Character
	if character then
		character:PivotTo(PlotService.getSpawnCFrame(player))
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		task.delay(Players.RespawnTime, spawnCharacter, player)
	end)
	ToolService.give(player, character)
end

local function onPlayerAdded(player: Player)
	-- Both the PlayerAdded event and the start-up loop below can see the same player.
	if handled[player] then
		return
	end
	handled[player] = true
	player:SetAttribute("ToolLevel", 1)
	local plot = PlotService.assign(player)
	if not plot then
		notify:FireClient(player, "NoPlot")
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	spawnCharacter(player)
end

function PlayerService.init()
	Players.CharacterAutoLoads = false
	notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		handled[player] = nil
		PlotService.release(player)
	end)
	-- Players who joined while the server was still building the world.
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

-- Used by the Studio debug reset so the owner is not inside refilling sand.
function PlayerService.returnToSpawn(player: Player)
	local character = player.Character
	if character then
		character:PivotTo(PlotService.getSpawnCFrame(player))
	end
end

return PlayerService
