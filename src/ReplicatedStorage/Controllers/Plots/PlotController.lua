local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Signal = require(ReplicatedStorage:WaitForChild("External"):WaitForChild("Signal"))

local PlotController = {
	Name = "PlotController",
	_PlotComponent = nil,
	_PlotConnections = {},
	PlotsChanged = Signal.new()
}

function PlotController:KnitInit()
	self._PlotComponent = require(ReplicatedStorage.Components.Plot)
end

function PlotController:KnitStart()
	self._PlotComponent.Started:Connect(function(plotComponent)
		self:_WatchPlot(plotComponent)
	end)
	self._PlotComponent.Stopped:Connect(function(plotComponent)
		self:_StopWatchingPlot(plotComponent)
	end)

	for _, plotComponent in ipairs(self._PlotComponent:GetAll()) do
		self:_WatchPlot(plotComponent)
	end
end

function PlotController:_WatchPlot(plotComponent)
	if self._PlotConnections[plotComponent] then
		return
	end

	self._PlotConnections[plotComponent] = plotComponent.OwnerChanged:Connect(function()
		self.PlotsChanged:Fire()
	end)

	self.PlotsChanged:Fire()
end

function PlotController:_StopWatchingPlot(plotComponent)
	local connection = self._PlotConnections[plotComponent]
	if not connection then
		return
	end

	connection:Disconnect()
	self._PlotConnections[plotComponent] = nil
	self.PlotsChanged:Fire()
end

function PlotController:GetPlotForPlayer(player)
	if not player then
		return
	end

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
