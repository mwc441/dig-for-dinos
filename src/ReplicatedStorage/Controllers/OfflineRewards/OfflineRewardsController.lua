local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local CashPile = ClientAssets:WaitForChild("CashPile")
local OfflineEarningsGui = ClientAssets:WaitForChild("OfflineEarningsGui")
local Sounds = Assets:WaitForChild("Sounds")
local MoneySound = Sounds:WaitForChild("MoneySound")
local Particles = Assets:WaitForChild("Particles")
local CashExplosionParticles = Particles:WaitForChild("CashExplosion")
local External = ReplicatedStorage:WaitForChild("External")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))
local Knit = require(External:WaitForChild("Knit"))

local OfflineRewardsController = {
	Name = "OfflineRewardsController",
	_PlotController = nil,
	_OfflineRewardsService = nil,
	_Pending = 0,
	_Revision = -1,
	_Claiming = false,
	_PlayerGui = nil,
	_Floor = nil,
	_CashPile = nil,
	_Gui = nil,
	_TouchConnection = nil,
	_FloorCFrameConnection = nil,
	_FloorSizeConnection = nil
}

function OfflineRewardsController:KnitStart()
	self._PlotController = require(ReplicatedStorage.Controllers.Plots.PlotController)
	self._OfflineRewardsService = Knit.GetService("OfflineRewardsService")
	self._PlayerGui = Player:WaitForChild("PlayerGui")

	self._OfflineRewardsService.EarningsUpdated:Connect(function(state)
		self:_UpdateEarnings(state)
	end)
	self._PlotController.PlotsChanged:Connect(function()
		self:_ReconcileCashPile()
	end)

	self._OfflineRewardsService:GetPendingEarnings():andThen(function(state)
		self:_UpdateEarnings(state)
	end)
end

function OfflineRewardsController:_UpdateEarnings(state)
	if state.Revision < self._Revision then return end

	self._Revision = state.Revision
	self._Pending = state.Amount
	self:_ReconcileCashPile()
end

function OfflineRewardsController:_PositionCashPile()
	local boundsCFrame, boundsSize = self._CashPile:GetBoundingBox()
	local pivotToBounds = self._CashPile:GetPivot():ToObjectSpace(boundsCFrame)
	local targetBounds = self._Floor.CFrame * CFrame.new(0, (self._Floor.Size.Y + boundsSize.Y) / 2, 0)
	self._CashPile:PivotTo(targetBounds * pivotToBounds:Inverse())
end

function OfflineRewardsController:_ReconcileCashPile()
	local plot = self._PlotController:GetPlot()
	local floor = plot and plot.Instance:FindFirstChild("_Floor")
	if self._Pending <= 0 or not floor or not floor:IsA("BasePart") then
		self:_DestroyCashPile()
		return
	end

	if self._Floor ~= floor then
		self:_DestroyCashPile()
		self:_CreateCashPile(floor)
	end

	self._Gui.AmountText.Text = string.format("$%s", BigNumbers.GetNumberDisplay(self._Pending))
end

function OfflineRewardsController:_CreateCashPile(floor)
	local cashPile = CashPile:Clone()
	for _, descendant in cashPile:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end

	cashPile.PrimaryPart.CanTouch = true
	cashPile.Parent = Workspace

	local gui = OfflineEarningsGui:Clone()
	gui.Adornee = cashPile.PrimaryPart
	gui.Parent = self._PlayerGui

	self._Floor = floor
	self._CashPile = cashPile
	self._Gui = gui
	self:_PositionCashPile()
	self._FloorCFrameConnection = floor:GetPropertyChangedSignal("CFrame"):Connect(function()
		self:_PositionCashPile()
	end)
	self._FloorSizeConnection = floor:GetPropertyChangedSignal("Size"):Connect(function()
		self:_PositionCashPile()
	end)
	self._TouchConnection = cashPile.PrimaryPart.Touched:Connect(function(hitPart)
		if self._Claiming or not Player.Character or not hitPart:IsDescendantOf(Player.Character) then
			return
		end

		self._Claiming = true
		self._OfflineRewardsService:ClaimOfflineEarnings():andThen(function(state)
			if state.Success then
				UtilFunctions.PlayCopyOfSound(MoneySound)

				local newCashExplosionParticles = CashExplosionParticles:Clone()
				newCashExplosionParticles.CFrame = cashPile:GetPivot()
				newCashExplosionParticles.Anchored = true
				newCashExplosionParticles.CanCollide = false
				newCashExplosionParticles.CanQuery = false
				newCashExplosionParticles.Transparency = 1
				newCashExplosionParticles.Parent = Workspace

				local _, longestEmitTime = UtilFunctions.GetLongestEmitter(newCashExplosionParticles)
				UtilFunctions.EmitParticles(newCashExplosionParticles)
				Debris:AddItem(newCashExplosionParticles, longestEmitTime)
			end

			self._Claiming = false
			self:_UpdateEarnings(state)
		end, function()
			self._Claiming = false
		end)
	end)
end

function OfflineRewardsController:_DestroyCashPile()
	if self._FloorCFrameConnection then
		self._FloorCFrameConnection:Disconnect()
		self._FloorCFrameConnection = nil
	end
	if self._FloorSizeConnection then
		self._FloorSizeConnection:Disconnect()
		self._FloorSizeConnection = nil
	end
	if self._TouchConnection then
		self._TouchConnection:Disconnect()
		self._TouchConnection = nil
	end
	if self._Gui then
		self._Gui:Destroy()
		self._Gui = nil
	end
	if self._CashPile then
		self._CashPile:Destroy()
		self._CashPile = nil
	end
	self._Floor = nil
end

return OfflineRewardsController
