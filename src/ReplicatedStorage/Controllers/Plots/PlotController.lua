local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local PurchaseSound = Sounds:WaitForChild("Purchase")
local ErrorSound = Sounds:WaitForChild("Error")
local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local PlotLevelDef = require(ReplicatedConfigs:WaitForChild("PlotLevelDef"))
local PartUtil = require(Utils:WaitForChild("Part"))
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))

local PlotController = {
	Name = "PlotController",
	_PlotComponent = nil,
	_PlotService = nil,
	_DinosaurController = nil,
	_RewardsController = nil,
	_LevelUpPending = false,
	PlotsChanged = Signal.new()
}

function PlotController:KnitInit()
	self._PlotComponent = require(ReplicatedStorage.Components.Plot)
end

function PlotController:KnitStart()
	self._PlotService = Knit.GetService("PlotService")
	self._DinosaurController = require(ReplicatedStorage.Controllers.Dinosaurs.DinosaurController)
	self._RewardsController = require(ReplicatedStorage.Controllers.Rewards.RewardsController)

	self._DinosaurController.DinosaurDataUpdatedSignal:Connect(function()
		self:_UpdateCapacity()
	end)

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
	plotComponent.OwnerChanged:Connect(function()
		if plotComponent:GetOwner() == Player then
			self:_UpdateCapacity()
		end
		self.PlotsChanged:Fire()
	end)

	plotComponent.LevelUpRequested:Connect(function()
		if plotComponent:GetOwner() ~= Player then return end

		self._PlotService:LevelUp():andThen(function(success)
			if success then
				PurchaseSound:Play()
				plotComponent:ThrobLevelSign()
			else
				ErrorSound:Play()
				self._RewardsController:AnnounceMessage("❌ Can't afford!", Color3.fromRGB(255, 0, 0))
			end
		end)
	end)

	if plotComponent:GetOwner() == Player then
		self:_UpdateCapacity()
	end
	self.PlotsChanged:Fire()
end

function PlotController:_StopWatchingPlot(plotComponent)
	self.PlotsChanged:Fire()
end

function PlotController:_UpdateCapacity()
	local plot = self:GetPlot()
	if plot then
		plot:SetCapacityUsed(self._DinosaurController:GetDinosaurCount())
	end
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

function PlotController:IsInsidePlot()
	local plot = self:GetPlot()
	local floor = plot and plot.Instance:FindFirstChild("_Floor")
	if not floor or not floor:IsA("BasePart") then
		return false
	end

	return PartUtil.new(floor):PlayerIsInsidePartArea(Player, math.huge)
end

function PlotController:GetCapacityForPlayer(player)
	local plot = self:GetPlotForPlayer(player)
	local level = plot and plot.Instance:GetAttribute("Level")
	return PlotLevelDef.GetCapacity(level)
end

function PlotController:GetCapacity()
	return self:GetCapacityForPlayer(Player)
end

return PlotController
