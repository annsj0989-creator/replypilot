--!strict
-- Client entry point: wires input, HUD, effects and sounds to the replicated plot state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Controllers = script.Parent.Controllers
local AimIndicator = require(Controllers.AimIndicator)
local DebugOverlay = require(Controllers.DebugOverlay)
local DigController = require(Controllers.DigController)
local Effects = require(Controllers.Effects)
local Hud = require(Controllers.Hud)
local Markers = require(Controllers.Markers)
local PlotWatcher = require(Controllers.PlotWatcher)
local Sounds = require(Controllers.Sounds)

-- The shovel is always in hand; hide the hotbar so it cannot be put away.
task.spawn(function()
	for _ = 1, 10 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
			return
		end
		task.wait(0.5)
	end
end)

local visualsParent = AimIndicator.defaultParent()
Effects.init(visualsParent)
Markers.init(visualsParent)
Sounds.init(Effects.hitAttachment())
Hud.init(DigController.setTouchHeld)
local text = Hud.strings()
DebugOverlay.init(text.DebugHelp)

-- Objective and reveal bar always reflect the full set of artifacts in the plot.
local artifacts: { [string]: PlotWatcher.ArtifactView } = {}
local hasZone = false
local noFreePlot = false

local function refreshObjective()
	local active: PlotWatcher.ArtifactView? = nil
	local anyHidden = false
	local known = 0
	for _, view in artifacts do
		known += 1
		if view.state == "Glimpsed" then
			active = view
		elseif view.state == "Hidden" then
			anyHidden = true
		end
	end
	if not hasZone or known == 0 then
		-- Still replicating, unless the server told us there is no free plot.
		Hud.setObjective(if noFreePlot and not hasZone then text.ObjectiveNoPlot else "")
		Hud.setReveal(nil, 0)
		return
	end
	if active then
		Hud.setObjective(text.ObjectiveUncover)
		Hud.setReveal(text.ArtifactNames[active.id] or active.id, active.progress)
	elseif anyHidden then
		Hud.setObjective(text.ObjectiveFindSpot)
		Hud.setReveal(nil, 0)
	else
		Hud.setObjective(text.ObjectiveDone)
		Hud.setReveal(nil, 0)
	end
end

PlotWatcher.init({
	plotChanged = function(zone)
		hasZone = zone ~= nil
		for id in artifacts do
			Markers.hide(id)
			Effects.stopGlint(id)
		end
		table.clear(artifacts)
		refreshObjective()
	end,
	artifactChanged = function(view, previousState)
		artifacts[view.id] = view
		local name = text.ArtifactNames[view.id] or view.id

		if view.state == "Hidden" then
			Markers.show(view.id, view.position, GameConfig.Dig.SurfaceY, text.MarkerLabel)
			Effects.stopGlint(view.id)
		else
			Markers.hide(view.id)
		end

		if view.state ~= previousState then
			local isTransition = previousState ~= nil
			if view.state == "Glimpsed" then
				if isTransition then
					Effects.glimpse(view.id, view.position)
					Sounds.play("ArtifactGlimpse")
					Hud.toast(text.ToastGlimpse)
				else
					Effects.startGlint(view.id, view.position)
				end
			elseif view.state == "Discovered" then
				Effects.stopGlint(view.id)
				if isTransition then
					Effects.discover(view.id, view.position, view.model)
					Sounds.play("ArtifactDiscovered")
					Hud.toast(string.format(text.ToastDiscovered, name))
				end
			end
		end
		refreshObjective()
	end,
	artifactRemoved = function(id)
		artifacts[id] = nil
		Markers.hide(id)
		Effects.stopGlint(id)
		refreshObjective()
	end,
})

local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
notify.OnClientEvent:Connect(function(kind: any)
	if kind == "NoPlot" then
		noFreePlot = true
		refreshObjective()
	end
end)

DigController.init({
	onSwing = function(target, tool)
		Hud.onSwing()
		task.delay(GameConfig.Feel.ImpactDelay, function()
			Effects.digAt(target, tool.Level)
			Sounds.play("DigHit")
		end)
	end,
	onInputModeChanged = function(mode)
		Hud.setInputMode(mode)
	end,
})
