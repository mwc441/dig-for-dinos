local GamepadService = game:GetService("GamepadService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local RebirthSuccessSound = Sounds:WaitForChild("RebirthSuccess")
local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local RebirthDef = require(ReplicatedConfigs:WaitForChild("RebirthDef"))
local IapsEnum = require(Enums:WaitForChild("Iaps"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local GuiObject = require(GuiModules:WaitForChild("Object"))
local Device = require(External:WaitForChild("Device"))
local Knit = require(External:WaitForChild("Knit"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))

local RebirthController = {
	Name = "RebirthController",
	_HudController = nil,
	_PlayerStatsController = nil,
	_IapController = nil,
	_RewardsController = nil,
	_RebirthService = nil,
}

function RebirthController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local rebirthFrame = mainGui:WaitForChild("RebirthFrame")
	local hud = mainGui:WaitForChild("Hud")
	local mainButtons = hud:WaitForChild("MainButtons")

	self._Gui = {
		Frame = rebirthFrame,
		RebirthInfo = rebirthFrame:WaitForChild("RebirthInfo"),
		SkipCostText = rebirthFrame:WaitForChild("SkipCostText"),
		RebirthsText = rebirthFrame:WaitForChild("RebirthsText"),
		ProgressBar = rebirthFrame:WaitForChild("ProgressBar"),
		RebirthTexts = rebirthFrame:WaitForChild("RebirthTexts"),

		OpenRebirthButton = mainButtons:WaitForChild("RebirthButton"):WaitForChild("RebirthButton"),
		RebirthButton = rebirthFrame:WaitForChild("RebirthButton"),
		SkipRebirthButton = rebirthFrame:WaitForChild("SkipRebirthButton"),
		ExitButton = rebirthFrame:WaitForChild("ExitButton")
	}

	local openRebirthButton = GuiButton.new(self._Gui.OpenRebirthButton)
	openRebirthButton:SetMakeIconRotateLeftRightWhenHovered(true)
	openRebirthButton:SetMakeIconScaleWhenHovered(true)
	local iconObject = openRebirthButton:GetIconObject()
	openRebirthButton:SetCallback(function()
		self:SetVisibility(not self._Gui.Frame.Visible, true)
		iconObject:GrowAndFade(1.75, TweenInfo.new(0.35), 10000)
	end)

	local exitButton = GuiButton.new(self._Gui.ExitButton)
	exitButton:SetCallback(function()
		self:SetVisibility(false, true)
	end)

	local rebirthButton = GuiButton.new(self._Gui.RebirthButton)
	rebirthButton:SetCallback(function()
		self._RebirthService:Rebirth():andThen(function(success)
			if success then
				self:SetVisibility(false, false)
				UtilFunctions.PlayCopyOfSound(RebirthSuccessSound)
				self._RewardsController:AnnounceMessage("⭐ Rebirthed Successfully ⭐", Color3.fromRGB(255, 219, 60))
			end
		end)
	end)

	local skipRebirthButton = GuiButton.new(self._Gui.SkipRebirthButton)
	skipRebirthButton:SetCallback(function()
		local maxLevel = RebirthDef.GetMaxRebirth()
		local currentLevel = self:GetRebirths()
		if currentLevel >= maxLevel then return end

		self._IapController:PurchaseIap(IapsEnum.SkipRebirth)
	end)

	self._NotificationBubbleObject = GuiObject.new(self._Gui.OpenRebirthButton.NotificationBubble)
end

function RebirthController:KnitStart()
	self._HudController = require(ReplicatedStorage.Controllers.Hud.HudController)
	self._IapController = require(ReplicatedStorage.Controllers.Iaps.IapController)
	self._RewardsController = require(ReplicatedStorage.Controllers.Rewards.RewardsController)
	self._PlayerStatsController = require(ReplicatedStorage.Controllers.PlayerStats.PlayerStatsController)
	self._RebirthService = Knit.GetService("RebirthService")

	self._IapController.IapCacheChanged:Connect(function()
		self:_UpdateUi()
	end)

	self._PlayerStatsController.StatsUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)

	self:_UpdateUi()
end

-- DATA STUFF
function RebirthController:GetRebirths()
	return self._PlayerStatsController:GetStatValue(PlayerStatsEnum.Rebirths) or 0
end

function RebirthController:CanAffordNextRebirth()
	local currentRebirth = self:GetRebirths()
	local nextRebirth = currentRebirth + 1
	local nextRebirthInfo = RebirthDef.GetRebirthInfo(nextRebirth)
	if not nextRebirthInfo then return false end

	local cost = nextRebirthInfo.Cost
	if not cost then return false end

	local cash = self._PlayerStatsController:GetStatValue(PlayerStatsEnum.Cash) or 0
	return cash >= cost
end

-- UI STUFF
function RebirthController:SetVisibility(visible, toTween)
	local hideTrack = require(self._Gui.Frame.Animator).Hide
	local openTrack = require(self._Gui.Frame.Animator).Open

	if visible then
		self._Gui.Frame.Visible = visible
		self._HudController:SetCurrentlyActiveFrame(self)
		if Device.GetUserDevice() == "Controller" and not GamepadService.GamepadCursorEnabled then
			GamepadService:EnableGamepadCursor(nil)
		end
		self:_SetupUi()
		hideTrack:Stop()
		self._Hiding = false
		openTrack:Play()
	else
		local function clear()
			self._Gui.Frame.Visible = visible
			self._HudController:ClearCurrentlyActiveFrame(self)
		end

		if toTween then
			if self._Hiding then return end

			self._Hiding = true
			hideTrack:Play()
			hideTrack.Completed:Once(function()
				self._Hiding = false
				clear()
			end)
		else
			clear()
		end
	end
end

function RebirthController:_SetupUi()
	self:_UpdateUi()
end

function RebirthController:_UpdateUi()
	local canAffordNext = self:CanAffordNextRebirth()
	self._Gui.OpenRebirthButton.NotificationBubble.Visible = canAffordNext

	if canAffordNext then
		if not self._Pulsing then
			self._NotificationBubbleObject:StartPulse(function()
				self._NotificationBubbleObject:GrowFrameOutlineAndFade(2.5, nil, nil)
			end, 1.4, 0.2, 0.1, 1)
			self._Pulsing = true
		end
	else
		self._NotificationBubbleObject:StopPulse()
		self._Pulsing = false
	end

	if not self._Gui.Frame.Visible then return end

	local currentRebirths = self:GetRebirths()
	local nextRebirth = currentRebirths + 1
	local nextRebirthInfo = RebirthDef.GetRebirthInfo(nextRebirth)

	self._Gui.SkipCostText.Text = string.format("%d", self._IapController:GetPriceOfIap(IapsEnum.SkipRebirth) or 0)
	self._Gui.RebirthsText.Text = string.format("You have %d rebirths!", currentRebirths)

	local cashInfo = self._Gui.RebirthInfo.Cash
	local digPowerInfo = self._Gui.RebirthInfo.DigPower
	local rebirthTexts = self._Gui.RebirthTexts

	local currentCashAmount = RebirthDef.GetAmountForRebirth(currentRebirths, "Cash")
	local currentDigPowerAmount = RebirthDef.GetAmountForRebirth(currentRebirths, "DigPower")

	rebirthTexts.CurrentRebirth.Text = string.format("Rebirth %d", currentRebirths)
	cashInfo.LeftContainer.AmountText.Text = string.format("x%s", BigNumbers.GetNumberDisplay(currentCashAmount))
	digPowerInfo.LeftContainer.AmountText.Text = string.format("x%.2f", currentDigPowerAmount)

	if nextRebirthInfo then
		local nextCashAmount = RebirthDef.GetAmountForRebirth(nextRebirth, "Cash")
		local nextDigPowerAmount = RebirthDef.GetAmountForRebirth(nextRebirth, "DigPower")

		rebirthTexts.NextRebirth.Text = string.format("Rebirth %d", nextRebirth)
		cashInfo.RightContainer.AmountText.Text = string.format("x%s", BigNumbers.GetNumberDisplay(nextCashAmount))
		digPowerInfo.RightContainer.AmountText.Text = string.format("x%.2f", nextDigPowerAmount)
	else
		rebirthTexts.NextRebirth.Text = "MAX"
		cashInfo.RightContainer.AmountText.Text = "MAX"
		digPowerInfo.RightContainer.AmountText.Text = "MAX"
	end

	local progressBar = self._Gui.ProgressBar
	local cash = self._PlayerStatsController:GetStatValue(PlayerStatsEnum.Cash) or 0

	local progress
	if nextRebirthInfo then
		progress = math.clamp(cash / nextRebirthInfo.Cost, 0, 1)
		progressBar.AmountText.Text = string.format("%s / %s", BigNumbers.GetNumberDisplay(cash), BigNumbers.GetNumberDisplay(nextRebirthInfo.Cost))
	else
		progress = 1
		progressBar.AmountText.Text = "MAX"
	end

	local oldSize = progressBar.BarContainer.Bar.Size
	progressBar.BarContainer.Bar.Size = UDim2.new(progress, 0, oldSize.Y.Scale, oldSize.Y.Offset)
end

return RebirthController
