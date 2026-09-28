local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local PlotController = {
	Name = "PlotController",
	_PlotComponent = nil
}

function PlotController:KnitStart()
	self._PlotComponent = require(ReplicatedStorage.Components.Plot)
end

function PlotController:GetPlotForPlayer(player)
	for _, plotComponent in ipairs(self._PlotComponent:GetAll()) do
		if plotComponent:GetOwner() == player then
			return plotComponent
		end
	end
end

function PlotController:GetPlot()
	return self:GetPlotForPlayer(Player)
end

return PlotController
