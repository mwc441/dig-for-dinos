local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local UpgradeSound = Sounds:WaitForChild("Upgrade")
local ErrorSound = Sounds:WaitForChild("Error")
local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Components = ReplicatedStorage:WaitForChild("Components")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local UpgradesDef = require(ReplicatedConfigs:WaitForChild("UpgradesDef"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local GuiObject = require(GuiModules:WaitForChild("Object"))
local Knit = require(External:WaitForChild("Knit"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))

local UpgradesUiController = {
	Name = "UpgradesUiController",
	_HudController = nil,
	_UpgradeController = nil,
	_RewardsController = nil,
	_UpgradeService = nil,
	_IapController = nil,
}

function UpgradesUiController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local upgradesFrame = mainGui:WaitForChild("UpgradesFrame")

	self._Gui = {
		Frame = upgradesFrame,
		UpgradesList = upgradesFrame:WaitForChild("UpgradesList"),
		UpgradeTemplate = upgradesFrame:WaitForChild("Templates"):WaitForChild("UpgradeTemplate"),
		ExitButton = upgradesFrame:WaitForChild("ExitButton")
	}

	local exitButton = GuiButton.new(self._Gui.ExitButton)
	exitButton:SetCallback(function()
		self:SetVisibility(false, true)
	end)
end

function UpgradesUiController:KnitStart()
	self._HudController = require(ReplicatedStorage.Controllers.Hud.HudController)
	self._UpgradeController = require(ReplicatedStorage.Controllers.Upgrades.UpgradeController)
	self._IapController = require(ReplicatedStorage.Controllers.Iaps.IapController)
	self._RewardsController = require(ReplicatedStorage.Controllers.Rewards.RewardsController)
	self._UpgradeStoreComponent = require(Components.UpgradeStore)
	self._UpgradeService = Knit.GetService("UpgradeService")

	self:_SetupUi()

	self._UpgradeController.UpgradesUpdated:Connect(function()
		self:_UpdateUi()
	end)

	self._IapController.IapCacheChanged:Connect(function()
		self:_UpdateUi()
	end)

	self:_SetupUpgradeStores()
end

function UpgradesUiController:SetVisibility(visible, toTween)
	local hideTrack = require(self._Gui.Frame.Animator).Hide
	local openTrack = require(self._Gui.Frame.Animator).Open

	if visible then
		self._Gui.Frame.Visible = visible
		self._HudController:SetCurrentlyActiveFrame(self)
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

function UpgradesUiController:_SetupUi()
	local sortedUpgrades = {}
	for upgradeId, info in pairs(UpgradesDef.GetAllUpgrades()) do
		table.insert(sortedUpgrades, {
			Id = upgradeId,
			Info = info
		})
	end

	table.sort(sortedUpgrades, function(a, b)
		return a.Id < b.Id
	end)

	for order, upgradeTable in pairs(sortedUpgrades) do
		local upgradeId = upgradeTable.Id
		local info = UpgradesDef.GetUpgradeInfo(upgradeId)
		if not info then continue end

		local newUpgradeTemplate = self._Gui.UpgradeTemplate:Clone() :: Frame

		newUpgradeTemplate.NameText.Text = info.Name or ""
		newUpgradeTemplate.Icon.Image = info.Icon or ""

		local amountsFrameObject = GuiObject.new(newUpgradeTemplate.AmountsFrame)

		local buyButton = GuiButton.new(newUpgradeTemplate.BuyButtons.BuyButton)
		buyButton:SetCallback(function()
			local currentLevel = self._UpgradeController:GetUpgradeLevel(upgradeId)

			local maxLevel = UpgradesDef.GetMaxLevelForUpgrade(upgradeId)
			if currentLevel >= maxLevel then return end

			self._UpgradeService:BuyUpgrade(upgradeId, currentLevel + 1):andThen(function(success)
				if success then
					UtilFunctions.PlayCopyOfSound(UpgradeSound)
					amountsFrameObject:MakeThrob(1.25, 0.25)
				else
					UtilFunctions.PlayCopyOfSound(ErrorSound)
					self._RewardsController:AnnounceMessage("❌ Can't Afford", Color3.fromRGB(255, 0, 0))
				end
			end)
		end)

		local robuxButton = GuiButton.new(newUpgradeTemplate.BuyButtons.RobuxButton)
		robuxButton:SetCallback(function()
			self._IapController:PurchaseIap(info.IapId)
		end)
		newUpgradeTemplate.BuyButtons.RobuxButton.Visible = info.IapId ~= nil

		local iconObject = GuiObject.new(newUpgradeTemplate.Icon)
		newUpgradeTemplate.MouseEnter:Connect(function()
			iconObject:TweenScale(1.1, TweenInfo.new(0.25))
			iconObject:MakeRotateLeftRight()
		end)

		newUpgradeTemplate.MouseLeave:Connect(function()
			iconObject:TweenScale(1, TweenInfo.new(0.25))
			iconObject:StopRotateLeftRight(true)
		end)

		newUpgradeTemplate.Name = upgradeId
		newUpgradeTemplate.LayoutOrder = order
		newUpgradeTemplate.Visible = true
		newUpgradeTemplate.Parent = self._Gui.UpgradesList
	end

	self:_UpdateUi()
end

function UpgradesUiController:_UpdateUi()
	for _, template in pairs(self._Gui.UpgradesList:GetChildren()) do
		if not template:IsA(self._Gui.UpgradeTemplate.ClassName) then continue end

		local id = template.Name
		local info = UpgradesDef.GetUpgradeInfo(id)
		if not info then continue end

		local level = self._UpgradeController:GetUpgradeLevel(id)
		local nextLevel = level + 1
		local maxLevel = UpgradesDef.GetMaxLevelForUpgrade(id)

		local currentAmount = UpgradesDef.GetAmountForUpgrade(id, level)
		local nextAmount = UpgradesDef.GetAmountForUpgrade(id, math.min(nextLevel, maxLevel))

		local cost = UpgradesDef.GetCostOfUpgrade(id, nextLevel)

		template.LevelText.Text = string.format("Level %d", level)

		local amountsFrame = template.AmountsFrame :: Frame

		amountsFrame.CurrentAmount.AmountText.Text = string.format("%s", BigNumbers.GetNumberDisplay(currentAmount))
		if level < maxLevel then
			amountsFrame.NextAmount.AmountText.Text = string.format("%s", BigNumbers.GetNumberDisplay(nextAmount))
		end

		amountsFrame.NextAmount.Visible = level < maxLevel
		amountsFrame.Arrow.Visible = level < maxLevel

		local buyButtons = template.BuyButtons

		buyButtons.Visible = level < maxLevel

		local iapId = info.IapId
		if iapId then
			buyButtons.RobuxButton.Contents.AmountFrame.AmountText.Text = string.format("%d", self._IapController:GetPriceOfIap(iapId) or 0)
		end

		buyButtons.BuyButton.Contents.AmountFrame.AmountText.Text = BigNumbers.GetNumberDisplay(cost)
	end
end

function UpgradesUiController:_SetupUpgradeStores()
	for _, upgradeStore in pairs(self._UpgradeStoreComponent:GetAll()) do
		self:_SetupUpgradeStore(upgradeStore)
	end

	self._UpgradeStoreComponent.Started:Connect(function(upgradeStore)
		self:_SetupUpgradeStore(upgradeStore)
	end)
end

function UpgradesUiController:_SetupUpgradeStore(upgradeStore)
	upgradeStore.Interacted:Connect(function()
		if self._Gui.Frame.Visible then return end

		self:SetVisibility(true, true)
	end)
end

return UpgradesUiController