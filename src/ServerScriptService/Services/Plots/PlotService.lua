local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Components = ServerScriptService:WaitForChild("Components")
local Knit = require(External:WaitForChild("Knit"))

local PlotService = {
	Name = "PlotService",
	Client = {},
	_Plots = {}
}

function PlotService:KnitStart()
	self._PlotComponent = require(Components.Plot)

	self._PlotComponent.Started:Connect(function(plotComponent)
		self:_AddPlot(plotComponent)
	end)

	for _, plotComponent in ipairs(self._PlotComponent:GetAll()) do
		self:_AddPlot(plotComponent)
	end
end

function PlotService:OnPlayerAdded(player)
	local emptyPlot
	for _, plotComponent in ipairs(self._Plots) do
		if not plotComponent:GetOwner() then
			emptyPlot = plotComponent
			break
		end
	end

	if emptyPlot then
		emptyPlot:SetOwner(player)
	else
		player:Kick("Please re-log, this server is experiencing issues!")
	end
end

function PlotService:OnPlayerRemoving(player)
	local plotComponent = self:GetPlotForPlayer(player)
	if plotComponent then
		plotComponent:SetOwner(nil)
	end
end

function PlotService:GetPlotForPlayer(player)
	for _, plotComponent in ipairs(self._Plots) do
		if plotComponent:GetOwner() == player then
			return plotComponent
		end
	end
end

function PlotService:_AddPlot(plotComponent)
	if table.find(self._Plots, plotComponent) then
		return
	end

	table.insert(self._Plots, plotComponent)
	table.sort(self._Plots, function(firstPlot, secondPlot)
		return tonumber(firstPlot.Instance.Name) < tonumber(secondPlot.Instance.Name)
	end)
end

return PlotService
