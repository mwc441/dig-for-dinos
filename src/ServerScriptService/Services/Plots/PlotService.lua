local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Components = ServerScriptService:WaitForChild("Components")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local PlotLevelDef = require(ReplicatedConfigs:WaitForChild("PlotLevelDef"))
local Knit = require(External:WaitForChild("Knit"))

local PlotService = {
	Name = "PlotService",
	Client = {},
	_PlayerStatsService = nil,
	_CommerceService = nil,
	_LifecycleService = nil,
	_Plots = {}
}

function PlotService:KnitStart()
	self._PlayerStatsService = require(ServerScriptService.Services.PlayerStats.PlayerStatsService)
	self._CommerceService = require(ServerScriptService.Services.Commerce.CommerceService)
	self._LifecycleService = require(ServerScriptService.Services.LifeCycle.LifecycleService)
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

		local level = self._PlayerStatsService:GetStatValueForPlayer(player, PlayerStatsEnum.PlotLevel)
		emptyPlot:SetLevel(PlotLevelDef.GetLevel(level))
	else
		player:Kick("Please re-log, this server is experiencing issues!")
		warn("KICKING PLAYER OUT NO PLOT???")
	end
end

function PlotService:LevelUp(player)
	local plot = self:GetPlotForPlayer(player)
	if not plot then
		return
	end

	local level = PlotLevelDef.GetLevel(self._PlayerStatsService:GetStatValueForPlayer(player, PlayerStatsEnum.PlotLevel))
	local cost = PlotLevelDef.GetUpgradeCost(level)
	if not cost then return end

	local success = self._CommerceService:Spend(player, PlayerStatsEnum.Cash, cost, {
		Sku = "PlotLevelUpgrade"
	})
	if not success then return end

	self._PlayerStatsService:SetStatValueForPlayer(player, PlayerStatsEnum.PlotLevel, level + 1)
	plot:SetLevel(level + 1)

	return true
end

function PlotService.Client:LevelUp(player)
	return self.Server:LevelUp(player)
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

function PlotService:GetCapacityForPlayer(player)
	local plot = self:GetPlotForPlayer(player)
	local level = plot and plot.Instance:GetAttribute("Level")
	return PlotLevelDef.GetCapacity(level)
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
