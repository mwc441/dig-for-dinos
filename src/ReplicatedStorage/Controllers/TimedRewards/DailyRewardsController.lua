local GamepadService = game:GetService("GamepadService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local DailyRewardSound = Sounds:WaitForChild("DailyReward")
local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local TimersEnum = require(Enums:WaitForChild("Timers"))
local DailyRewardsDef = require(ReplicatedConfigs:WaitForChild("DailyRewardsDef"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local GuiObject = require(GuiModules:WaitForChild("Object"))
local Device = require(External:WaitForChild("Device"))
local Knit = require(External:WaitForChild("Knit"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))

local DAILY_REWARD_COOLDOWN = 24 * 60 * 60

local DailyRewardsController = {
	Name = "DailyRewardsController",
	_HudController = nil,
	_TimeController = nil,
	_TimerController = nil,
	_RewardsController = nil,
	_TimedRewardsService = nil,
}

function DailyRewardsController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local dailyRewardsFrame = mainGui:WaitForChild("DailyRewardsFrame")
	local hud = mainGui:WaitForChild("Hud")
	local topRightButtons = hud:WaitForChild("TopRightButtons")

	self._Gui = {
		Frame = dailyRewardsFrame,
		RewardsList = dailyRewardsFrame:WaitForChild("RewardsList"),
		RewardTemplate = dailyRewardsFrame:WaitForChild("Templates"):WaitForChild("RewardTemplate"),
		DayTemplate = dailyRewardsFrame:WaitForChild("Templates"):WaitForChild("DayTemplate"),
		Day7 = dailyRewardsFrame:WaitForChild("Templates"):WaitForChild("Day7"),
		DailyRewardsButton = topRightButtons:WaitForChild("DailyRewardsButton"),
		ExitButton = dailyRewardsFrame:WaitForChild("ExitButton")
	}

	local dailyRewardsButton = GuiButton.new(self._Gui.DailyRewardsButton)
	local iconObject = dailyRewardsButton:GetIconObject()
	dailyRewardsButton:SetCallback(function()
		self:SetVisibility(not self._Gui.Frame.Visible, true)
		iconObject:GrowAndFade(1.75, TweenInfo.new(0.35), 10000)
	end)
	dailyRewardsButton:SetMakeIconRotateLeftRightWhenHovered(true)

	local exitButton = GuiButton.new(self._Gui.ExitButton)
	exitButton:SetCallback(function()
		self:SetVisibility(false, true)
	end)

	self._NotificationBubbleObject = GuiObject.new(self._Gui.DailyRewardsButton.NotificationBubble)
end

function DailyRewardsController:KnitStart()
	self._HudController = require(ReplicatedStorage.Controllers.Hud.HudController)
	self._TimeController = require(ReplicatedStorage.Controllers.Time.TimeController)
	self._TimerController = require(ReplicatedStorage.Controllers.Timers.TimerController)
	self._RewardsController = require(ReplicatedStorage.Controllers.Rewards.RewardsController)
	self._TimedRewardsService = Knit.GetService("TimedRewardsService")

	self:_SetupUi()

	self._TimeController.TimeUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)

	self._TimerController.TimersUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)
end

function DailyRewardsController:SetVisibility(visible, toTween)
	local hideTrack = require(self._Gui.Frame.Animator).Hide
	local openTrack = require(self._Gui.Frame.Animator).Open

	if visible then
		self._Gui.Frame.Visible = visible
		self:_UpdateUi()
		self._HudController:SetCurrentlyActiveFrame(self)
		if Device.GetUserDevice() == "Controller" and not GamepadService.GamepadCursorEnabled then
			GamepadService:EnableGamepadCursor(nil)
		end
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

function DailyRewardsController:_SetupUi()
	for day, info in pairs(DailyRewardsDef.GetAllRewards()) do
		local dayTemplate
		if day ~= 7 then
			dayTemplate = self._Gui.DayTemplate:Clone()
		else
			dayTemplate = self._Gui.Day7:Clone()
		end

		local button = dayTemplate.Button

		button.NameText.Text = string.format("Day %d", day)
		button.TimerText.Text = ""

		for order, rewardTable in pairs(info.Rewards or {}) do
			local rewardType = rewardTable.RewardType
			local reward = rewardTable.Reward

			local newRewardTemplate = self._Gui.RewardTemplate:Clone()
			newRewardTemplate.Image = self._RewardsController:GetIconFor(rewardType)
			newRewardTemplate.QuantityText.Text = string.format("x%s", BigNumbers.GetNumberDisplay(reward))
			newRewardTemplate.LayoutOrder = order
			newRewardTemplate.Visible = true
			newRewardTemplate.Name = order
			newRewardTemplate.Parent = button.RewardsFrame
		end

		local dayButton = GuiButton.new(button)
		dayButton:SetCallback(function()
			self._TimedRewardsService:ClaimDailyReward(day):andThen(function(success)
				if success then
					UtilFunctions.PlayCopyOfSound(DailyRewardSound)
					self:SetVisibility(false, true)
				end
			end)
		end)

		dayTemplate.Name = tostring(day)
		dayTemplate.Visible = true
		dayTemplate.LayoutOrder = day
		dayTemplate.Parent = self._Gui.RewardsList
	end

	self:_UpdateUi()
end

function DailyRewardsController:_UpdateUi()
	local lastClaimed = self._TimerController:GetTimeForTimer(TimersEnum.DailyRewardLastClaimed) or 0
	local lastDayClaimed = self._TimerController:GetTimeForTimer(TimersEnum.DailyRewardNum) or 0
	local timeLeft = (lastClaimed + DAILY_REWARD_COOLDOWN) - os.time()

	if timeLeft <= 0 then
		if not self._NotificationVisible then
			self._NotificationVisible = true
			self._Gui.DailyRewardsButton.NotificationBubble.Visible = true
			self._NotificationBubbleObject:StartPulse(function()
				self._NotificationBubbleObject:GrowFrameOutlineAndFade(2.5, nil, nil)
			end, 1.4, 0.2, 0.1, 1)
		end
	else
		self._NotificationVisible = false
		self._NotificationBubbleObject:StopPulse()
		self._Gui.DailyRewardsButton.NotificationBubble.Visible = false
	end

	if not self._Gui.Frame.Visible then return end

	for _, template in pairs(self._Gui.RewardsList:GetChildren()) do
		if (not template:IsA(self._Gui.DayTemplate.ClassName)) and (not template:IsA(self._Gui.Day7.ClassName)) then continue end

		local day = tonumber(template.Name)
		local info = DailyRewardsDef.GetDayInfo(day)
		if not info then continue end

		local timerText = ""

		if day <= lastDayClaimed then
			timerText = "CLAIMED"
		elseif day == (lastDayClaimed + 1) then
			if timeLeft > 0 then
				timerText = self._TimeController:GetTimeStringFromTime(timeLeft)
			else
				timerText = "CLAIM"
			end
		else
			timerText = ""
		end

		template.Button.TimerText.Text = timerText
	end
end

return DailyRewardsController
