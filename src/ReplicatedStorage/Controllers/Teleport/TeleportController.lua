local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Components = ReplicatedStorage:WaitForChild("Components")
local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local GuiButton = require(GuiModules:WaitForChild("Button"))
local Signal = require(External:WaitForChild("Signal"))

local TeleportController = {
	Name = "TeleportController",
	_PlotController = nil,
	_TeleportSpotComponent = nil,
	_Zone2dComponent = nil,
	ShovelsTeleportClicked = Signal.new(),
	UpgradesTeleportClicked = Signal.new()
}

function TeleportController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local hud = mainGui:WaitForChild("Hud")
	local teleportButtons = hud:WaitForChild("TeleportButtons")
	self._TeleportButtons = teleportButtons
	teleportButtons.Visible = false

	local plotButton = GuiButton.new(teleportButtons:WaitForChild("PlotButton"))
	plotButton:SetCallback(function()
		self:_TeleportToPlot()
	end)
	plotButton:SetMakeIconRotateLeftRightWhenHovered(true)

	local upgradesButton = GuiButton.new(teleportButtons:WaitForChild("UpgradesButton"))
	upgradesButton:SetCallback(function()
		self._TeleportSpotComponent.TeleportPlayer(Player, "Upgrades")
		self.UpgradesTeleportClicked:Fire()
	end)
	upgradesButton:SetMakeIconRotateLeftRightWhenHovered(true)

	local shovelsButton = GuiButton.new(teleportButtons:WaitForChild("ShovelsButton"))
	shovelsButton:SetCallback(function()
		self._TeleportSpotComponent.TeleportPlayer(Player, "Shovels")
		self.ShovelsTeleportClicked:Fire()
	end)
	shovelsButton:SetMakeIconRotateLeftRightWhenHovered(true)
end

function TeleportController:KnitStart()
	self._PlotController = require(ReplicatedStorage.Controllers.Plots.PlotController)
	self._TeleportSpotComponent = require(Components.TeleportSpot)
	self._Zone2dComponent = require(Components.Zone2d)

	self._Zone2dComponent.ConnectToZone("SafeZone", function(isInside)
		self._TeleportButtons.Visible = isInside
	end)
	self._TeleportButtons.Visible = self._Zone2dComponent.IsPlayerInside("SafeZone")
end

function TeleportController:_TeleportToPlot()
	local plot = self._PlotController:GetPlot()
	local character = Player.Character
	if not plot or not character then return end

	local spawnPart = plot.Instance:FindFirstChild("_Spawn")
	if not spawnPart then return end

	local pivot = character:GetPivot()
	local boundingCFrame, boundingSize = character:GetBoundingBox()
	local bottomY = boundingCFrame.Position.Y - (boundingSize.Y / 2)
	local pivotToFeetOffset = pivot.Position.Y - bottomY

	character:PivotTo(spawnPart.CFrame * CFrame.new(0, pivotToFeetOffset, 0))
end

return TeleportController
