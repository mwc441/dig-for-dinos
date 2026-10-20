local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local IapsEnum = require(Enums:WaitForChild("Iaps"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))
local Knit = require(External:WaitForChild("Knit"))

local OFFLINE_EARNINGS_MULTIPLIER = 0.25
local SECONDS_PER_HOUR = 60 * 60

local OfflineRewardsController = {
	Name = "OfflineRewardsController",
	_PlotController = nil,
	_DinosaurController = nil,
	_BoostController = nil,
	_IapController = nil,
	_OfflineRewardsService = nil,
	_Pending = 0,
	_Revision = -1,
	_Claiming = false,
	_PlayerGui = nil,
	_Floor = nil,
	_CashPile = nil,
	_CashPileGui = nil,
	_Gui = nil,
	_TouchConnection = nil,
	_FloorCFrameConnection = nil,
	_FloorSizeConnection = nil
}

function OfflineRewardsController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local offlineRewardsFrame = mainGui:WaitForChild("OfflineRewardsFrame")

	self._Gui = {
		Frame = offlineRewardsFrame,
		HourButton = offlineRewardsFrame:WaitForChild("ButtonsFrame"):WaitForChild("HourButton"),
		DayButton = offlineRewardsFrame:WaitForChild("ButtonsFrame"):WaitForChild("DayButton"),
		AmountText = offlineRewardsFrame:WaitForChild("EarningsFrame"):WaitForChild("AmountsFrame"):WaitForChild("AmountFrame"):WaitForChild("AmountText")
	}

	local hourButton = GuiButton.new(self._Gui.HourButton)
	hourButton:SetCallback(function()
		self._IapController:PurchaseIap(IapsEnum.OfflineRewards1Hour)
	end)

	local dayButton = GuiButton.new(self._Gui.DayButton)
	dayButton:SetCallback(function()
		self._IapController:PurchaseIap(IapsEnum.OfflineRewards24Hours)
	end)
end

function OfflineRewardsController:KnitStart()
	self._PlotController = require(ReplicatedStorage.Controllers.Plots.PlotController)
	self._DinosaurController = require(ReplicatedStorage.Controllers.Dinosaurs.DinosaurController)
	self._BoostController = require(ReplicatedStorage.Controllers.Boosts.BoostController)
	self._IapController = require(ReplicatedStorage.Controllers.Iaps.IapController)
	self._OfflineRewardsService = Knit.GetService("OfflineRewardsService")
	self._PlayerGui = Player:WaitForChild("PlayerGui")

	self._OfflineRewardsService.EarningsUpdated:Connect(function(state)
		self:_UpdateEarnings(state)
	end)
	self._PlotController.PlotsChanged:Connect(function()
		self:_ReconcileCashPile()
	end)
	self._DinosaurController.DinosaurDataUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)
	self._BoostController.BoostsUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)
	self._IapController.IapCacheChanged:Connect(function()
		self:_UpdateUi()
	end)
	self._IapController.IapsUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)

	self:_UpdateUi()

	RunService.Heartbeat:Connect(function()
		local isInside = self._PlotController:IsInsidePlot()
		self._Gui.Frame.Visible = isInside
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

	self._CashPileGui.AmountText.Text = string.format("$%s", BigNumbers.GetNumberDisplay(self._Pending))
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
	self._CashPileGui = gui
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
	if self._CashPileGui then
		self._CashPileGui:Destroy()
		self._CashPileGui = nil
	end
	if self._CashPile then
		self._CashPile:Destroy()
		self._CashPile = nil
	end
	self._Floor = nil
end

-- UI STUFF
function OfflineRewardsController:_UpdateUi()
	local iapMultiplier = self._IapController:OwnsIap(IapsEnum.OfflineCash2x) and 2 or 1
	local hourAmount = math.round(self._DinosaurController:GetIncomePerSecond() * SECONDS_PER_HOUR * OFFLINE_EARNINGS_MULTIPLIER * iapMultiplier)

	self._Gui.AmountText.Text = string.format("%s / HR", BigNumbers.GetNumberDisplay(hourAmount))
	self._Gui.HourButton.PriceText.Text = string.format(" %d", self._IapController:GetPriceOfIap(IapsEnum.OfflineRewards1Hour) or 0)
	self._Gui.DayButton.PriceText.Text = string.format(" %d", self._IapController:GetPriceOfIap(IapsEnum.OfflineRewards24Hours) or 0)
end

return OfflineRewardsController
