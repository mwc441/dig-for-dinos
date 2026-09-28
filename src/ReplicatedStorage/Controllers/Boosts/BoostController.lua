local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local DefaultTooltip = ClientAssets:WaitForChild("DefaultTooltip")
local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local BoostUtils = require(Utils:WaitForChild("BoostUtils"))
local BoostsEnum = require(Enums:WaitForChild("Boosts"))
local BoostsDef = require(ReplicatedConfigs:WaitForChild("BoostsDef"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local Signal = require(External:WaitForChild("Signal"))
local TableUtils = require(External:WaitForChild("TableUtils"))

type Boost = BoostUtils.Boost
type Boosts = BoostUtils.Boosts

local FRIEND_BOOST = BoostsEnum.FriendBoost
local PLUS_BOOST = BoostsEnum.RobloxPlusBoost

local ALWAYS_SHOW_BOOSTS = {
	FRIEND_BOOST,
	PLUS_BOOST
}

local BoostController = {
	Name = "BoostController",
	_DataController = nil,
	_TimeController = nil,
	_FriendController = nil,
	_Boosts = {} :: Boosts,
	_Hidden = false,
	BoostsUpdatedSignal = Signal.new()
}

function BoostController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local temporaryBoostsFrame = mainGui:WaitForChild("TemporaryBoostsFrame")

	self._Gui = {
		Frame = temporaryBoostsFrame,
		BoostList = temporaryBoostsFrame:WaitForChild("BoostList"),
		TemporaryBoostTemplate = temporaryBoostsFrame:WaitForChild("Templates"):WaitForChild("TemporaryBoostTemplate"),
		HideButton = temporaryBoostsFrame:WaitForChild("HideButton")
	}

	local hideButton = GuiButton.new(self._Gui.HideButton)
	hideButton:SetCallback(function()
		self._Hidden = not self._Hidden

		self:_UpdateUi()
	end)
end

function BoostController:KnitStart()
	self._DataController = require(ReplicatedStorage.Controllers.Data.DataController)
	self._TimeController = require(ReplicatedStorage.Controllers.Time.TimeController)
	self._FriendController = require(ReplicatedStorage.Controllers.Friends.FriendController)

	self._Boosts = nil
	self:_SetBoosts({})

	self._DataController.ProfileUpdatedSignal:Connect(function(profileData)
		if profileData.Boosts then
			self:_SetBoosts(profileData.Boosts.Boosts)
		end
	end)

	local boosts = self._DataController:GetProfileData("Boosts")
	if boosts then
		self:_SetBoosts(boosts.Boosts)
	end

	self._TimeController.TimeUpdatedSignal:Connect(function()
		self:_UpdateUi()
	end)
end

function BoostController:_SetBoosts(boosts: Boosts)
	boosts = TableUtils.Copy(boosts or ({} :: Boosts))
	self:_AddAlwaysShowBoosts(boosts)

	if TableUtils.Equals(boosts, self._Boosts) then
		return
	end

	self._Boosts = boosts

	self.BoostsUpdatedSignal:Fire()

	self:_UpdateUi()
end

function BoostController:_AddAlwaysShowBoosts(boosts: Boosts)
	for index, boostId in ipairs(ALWAYS_SHOW_BOOSTS) do
		local boost, currentIndex = BoostUtils.GetBoostOfId(boosts, boostId)
		if not boost then
			table.insert(boosts, index, {
				Id = boostId,
				Level = 0
			})
		else
			table.remove(boosts, currentIndex)
			table.insert(boosts, index, boost)
		end
	end
end

function BoostController:GetBoostFromId(id) : (Boost, number)
	return BoostUtils.GetBoostOfId(self._Boosts, id)
end

function BoostController:GetBoostsOfType(boostType) : Boosts
	return BoostUtils.GetBoostsOfType(self._Boosts, boostType)
end

function BoostController:GetTotalAmountForBoostType(boostType)
	local addingBoostAmount = self:GetAddingBoostAmountOfType(boostType)
	local multiplyingBoostAmount = self:GetMultiplyingBoostAmountOfType(boostType)

	return (addingBoostAmount + 1) * multiplyingBoostAmount
end

function BoostController:GetAddingBoostAmountOfType(boostType) : number
	return BoostUtils.GetAddingBoostAmountOfType(self._Boosts, boostType)
end

function BoostController:GetMultiplyingBoostAmountOfType(boostType) : number
	return BoostUtils.GetMultiplyingBoostAmountOfType(self._Boosts, boostType)
end

function BoostController:_UpdateUi()
	-- Go through all templates and remove those
	-- that no longer have a boost
	for _, template in pairs(self._Gui.BoostList:GetChildren()) do
		if template:IsA("Frame") then
			local boost = self:GetBoostFromId(template.Name)
			if not boost then
				template:Destroy()
			end
		end
	end

	local maxBoostsVisible
	if self._Hidden then
		maxBoostsVisible = self._Gui.BoostList.UIGridLayout.FillDirectionMaxCells
		self._Gui.HideButton.TextLabel.Text = "+"
	else
		maxBoostsVisible = math.huge
		self._Gui.HideButton.TextLabel.Text = "-"
	end

	local totalTemplateBoosts = 0

	-- Update and create templates for all the boosts
	-- in the players boosts
	for order, boost in pairs(self._Boosts or {}) do
		local boostInfo = BoostsDef.GetBoostInfo(boost.Id)
		if not boostInfo then
			continue
		end

		if (not boostInfo.Icon) or (not boostInfo.Description) then
			continue
		end

		local timeLeft
		if boost.TimeLeft then
			timeLeft = boost.TimeLeft
		elseif boost.ExpiryTime then
			timeLeft = math.max((boost.ExpiryTime - os.time()), 0)
		end

		local template = self._Gui.BoostList:FindFirstChild(boost.Id)
		if not template then
			template = self._Gui.TemporaryBoostTemplate:Clone()

			local button = GuiButton.new(template.Button)
			button:SetTooltipEnabled(true)
			button:SetCallback(function()
				if boost.Id == FRIEND_BOOST then
					self._FriendController:InviteFriends()
				elseif boost.Id == PLUS_BOOST then
					MarketplaceService:PromptRobloxSubscriptionPurchase(Player)
				end
			end)

			button:SetMakeWiggleWhenHovered(template.Button.Active)
			button:SetBounce(template.Button.Active)
			button:SetHover(template.Button.Active)
			button:SetMakeNoiseWhenHover(template.Button.Active)
			if not template.Button.Active then
				button:SetPlaybackSound(nil)
			end

			local newToolTip = DefaultTooltip:Clone()
			newToolTip.AnchorPoint = Vector2.new(0, 1)
			button:SetTooltipGui(newToolTip, Player:WaitForChild("PlayerGui"):WaitForChild("Main"))
			button.OnHoverChanged:Connect(function(hovered)
				if not hovered then return end
				local tooltipGui = button:GetTooltip() :: typeof(DefaultTooltip)
				if not tooltipGui then return end

				local currentLevel = self:GetBoostFromId(boost.Id).Level

				tooltipGui.Content.TitleText.Text = boostInfo.Name or ""
				tooltipGui.Content.DescriptionText.Text = BoostsDef.GetDescriptionOfBoostAtLevel(boost.Id, currentLevel)
			end)

			template.Button.Image = boostInfo.Icon or ""

			if boostInfo.IconColour then
				template.Button.ImageColor3 = boostInfo.IconColour
			end

			template.Visible = true
			template.Name = boost.Id
			template.Parent = self._Gui.BoostList
		end

		totalTemplateBoosts += 1

		template.LayoutOrder = order
		template.ZIndex = 1_000_000 - order
		template.Visible = totalTemplateBoosts <= maxBoostsVisible

		if timeLeft then
			template.Button.TimeLeftText.Text = self._TimeController:GetTimeStringFromTime(timeLeft)
		else
			template.Button.TimeLeftText.Text = ""
		end

		if boostInfo.ShowLevel and (boost.Level > 1) then
			template.Button.LevelText.Text = tostring(boost.Level)
		else
			template.Button.LevelText.Text = ""
		end
	end

	self._Gui.HideButton.Visible = totalTemplateBoosts > self._Gui.BoostList.UIGridLayout.FillDirectionMaxCells
end

return BoostController
