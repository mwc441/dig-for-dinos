local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local GuiButton = require(GuiModules:WaitForChild("Button"))
local CountingText = require(GuiModules:WaitForChild("CountingText"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local Knit = require(External:WaitForChild("Knit"))

local HudUiController = {
	Name = "HudUiController",
	_PlayerStatsController = nil,
}

function HudUiController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local hud = mainGui:WaitForChild("Hud")
	local cashFrame = hud:WaitForChild("CashFrame")

	self._Gui = {
		CashFrame = cashFrame,
		CashPlusButton = cashFrame:WaitForChild("PlusButton")
	}

	local amountFrame = cashFrame:WaitForChild("AmountFrame")
	self._CashAmountText = CountingText.new(amountFrame:WaitForChild("AmountText"))
	self._CashDarkAmountText = CountingText.new(amountFrame:WaitForChild("DarkAmountText"))

	local cashPlusButton = GuiButton.new(self._Gui.CashPlusButton)
	cashPlusButton:SetCallback(function()
		-- TODO: Cash iaps
	end)
end

function HudUiController:KnitStart()
	self._PlayerStatsController = require(ReplicatedStorage.Controllers.PlayerStats.PlayerStatsController)

	self._PlayerStatsController.StatsUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)

	self:_UpdateUi()
end

function HudUiController:_UpdateUi()
	self:_UpdateCashFrame()
end

function HudUiController:_UpdateCashFrame()
	local cash = self._PlayerStatsController:GetStatValue(PlayerStatsEnum.Cash) or 0

	self._CashAmountText:Animate(cash)
	self._CashDarkAmountText:Animate(cash)
end

return HudUiController
