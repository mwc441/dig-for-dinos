local GamepadService = game:GetService("GamepadService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local ServerLuckBuildUpSound = Sounds:WaitForChild("ServerLuckBuildUp")
local ServerLuckSmashSound = Sounds:WaitForChild("ServerLuckSmash")
local External = ReplicatedStorage:WaitForChild("External")
local Components = ReplicatedStorage:WaitForChild("Components")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local BoostsEnum = require(Enums:WaitForChild("Boosts"))
local BoostsDef = require(ReplicatedConfigs:WaitForChild("BoostsDef"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local IapDef = require(ReplicatedConfigs:WaitForChild("IapDef"))
local IapTypesEnum = require(Enums:WaitForChild("IapTypes"))
local IapsEnum = require(Enums:WaitForChild("Iaps"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local GuiObject = require(GuiModules:WaitForChild("Object"))
local Device = require(External:WaitForChild("Device"))
local Knit = require(External:WaitForChild("Knit"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))
local TableUtils = require(External:WaitForChild("TableUtils"))

local PremiumController = {
	Name = "PremiumController",
	_IapController = nil,
	_IapSignComponent = nil,
	_IapVendorComponent = nil,
	_HudController = nil,
	_BoostController = nil,
	_LimitedController = nil,
	_PendingServerLuckPurchase = nil
}

function PremiumController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local shopFrame = mainGui:WaitForChild("PremiumShopFrame")
	local hud = mainGui:WaitForChild("Hud")
	local mainButtons = hud:WaitForChild("MainButtons")

	self._Gui = {
		Frame = shopFrame,
		ScrollFrame = shopFrame:WaitForChild("IapList"):WaitForChild("IapList"),
		ShopButton = mainButtons:WaitForChild("ShopButton"):WaitForChild("ShopButton"),
		CashGamepassButton = hud:WaitForChild("CashGamepassButton"),
		ExitButton = shopFrame:WaitForChild("ExitButton"),
		CurrencyFrame = shopFrame:WaitForChild("CurrencyFrame")
	}

	local cashButton = GuiButton.new(self._Gui.CashGamepassButton)
	cashButton:SetCallback(function()
		self._IapController:PurchaseIap(IapsEnum.Cash2x)
	end)

	local shopButton = GuiButton.new(self._Gui.ShopButton)
	local iconObject = shopButton:GetIconObject()
	shopButton:SetCallback(function()
		self:SetVisibility(not self._Gui.Frame.Visible, true)
		iconObject:GrowAndFade(1.75, TweenInfo.new(0.35), 10000)
	end)
	shopButton:SetMakeIconScaleWhenHovered(true)
	shopButton:SetMakeIconRotateLeftRightWhenHovered(true)

	self._NotificationBubbleObject = GuiObject.new(self._Gui.ShopButton.NotificationBubble)
	self._Gui.ShopButton.NotificationBubble.Visible = true
	self._NotificationBubbleObject:StartPulse(function()
		self._NotificationBubbleObject:GrowFrameOutlineAndFade(2.5, nil, nil)
	end, 1.4, 0.2, 0.1, 1)

	local exitButton = GuiButton.new(self._Gui.ExitButton)
	exitButton:SetCallback(function()
		self:SetVisibility(false, true)
	end)

	local currencyExitButton = GuiButton.new(self._Gui.CurrencyFrame.ExitButton)
	currencyExitButton:SetCallback(function()
		self:_CloseCurrencyFrame()
	end)

	task.delay(3 * 60, function()
		game:GetService("AvatarEditorService"):PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)

	task.delay(3.5 * 60, function()
		self:_PromptCurrentEvent()
	end)
end

function PremiumController:KnitStart()
	self._IapController = require(ReplicatedStorage.Controllers.Iaps.IapController)
	self._IapSignComponent = require(Components.IapSign)
	self._IapVendorComponent = require(Components.IapVendor)
	self._HudController = require(ReplicatedStorage.Controllers.Hud.HudController)
	self._BoostController = require(ReplicatedStorage.Controllers.Boosts.BoostController)
	self._LimitedController = require(ReplicatedStorage.Controllers.Limited.LimitedController)

	self._IapController.IapCacheChanged:Connect(function()
		self:_UpdateIaps()
		self:_UpdateServerLuck()
	end)

	self._BoostController.BoostsUpdatedSignal:Connect(function()
		self:_UpdateServerLuck()
	end)
	self._LimitedController.LimitedCacheUpdatedSignal:Connect(function()
		self:_UpdateIaps()
	end)

	self._IapController.IapPurchasedSignal:Connect(function(iapId)
		if table.find(Constants.ServerLuckOrder, iapId) then
			while self._IapController:IsPurchasePromptOpen() do
				task.wait()
			end

			self:_AnimateServerLuckAmount()
		end
	end)

	self._IapController.IapsUpdatedSignal:Connect(function()
		self:_UpdateIaps()
	end)

	self:_SetupUi()
	self:_SetupIapSigns()
	self:_SetupIapVendors()
	self:_UpdateIaps()

	self:_SetupServerLuck()
end

function PremiumController:PromptToPurchaseRobloxPlus()
	MarketplaceService:PromptRobloxSubscriptionPurchase(Player)
end

function PremiumController:SetVisibility(visible, toTween)
	local hideTrack = require(self._Gui.Frame.Animator).Hide
	local openTrack = require(self._Gui.Frame.Animator).Open

	if visible then
		self._Gui.Frame.Visible = visible
		self._HudController:SetCurrentlyActiveFrame(self)
		if Device.GetUserDevice() == "Controller" and not GamepadService.GamepadCursorEnabled then
			GamepadService:EnableGamepadCursor(nil)
		end
		self._NotificationBubbleObject:StopPulse()
		self._Gui.ShopButton.NotificationBubble.Visible = false
		hideTrack:Stop()
		self._Hiding = false
		openTrack:Play()
	else
		local function clear()
			self._Gui.Frame.Visible = visible
			self._HudController:ClearCurrentlyActiveFrame(self)
			self._Gui.ScrollFrame.CanvasPosition = Vector2.zero
			self:_CloseCurrencyFrame()
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

function PremiumController:_SetupUi()
	for _, descendant in pairs(self._Gui.ScrollFrame:GetDescendants()) do
		local iapInfo = IapDef.GetIapInfo(descendant.Name)
		if iapInfo then
			self:_SetupIap(descendant)
		end
	end
end

function PremiumController:_SetupIapSigns()
	for _, iapSign in pairs(self._IapSignComponent:GetAll()) do
		self:_SetupIapSign(iapSign)
	end

	self._IapSignComponent.Started:Connect(function(iapSign)
		self:_SetupIapSign(iapSign)
	end)
end

function PremiumController:_SetupIapSign(iapSign)
	local iapId = iapSign.Instance.Name
	if not IapDef.GetIapInfo(iapId) then return end

	iapSign.Interacted:Connect(function()
		self._IapController:PurchaseIap(iapId)
	end)

	self:_UpdateIapSign(iapSign)
end

function PremiumController:_SetupIapVendors()
	for _, iapVendor in pairs(self._IapVendorComponent:GetAll()) do
		self:_SetupIapVendor(iapVendor)
	end

	self._IapVendorComponent.Started:Connect(function(iapVendor)
		self:_SetupIapVendor(iapVendor)
	end)
end

function PremiumController:_SetupIapVendor(iapVendor)
	local iapId = iapVendor.Instance.Name
	if not IapDef.GetIapInfo(iapId) then return end

	iapVendor.Interacted:Connect(function()
		self._IapController:PurchaseIap(iapId)
	end)

	self:_UpdateIapVendor(iapVendor)
end

function PremiumController:_SetupIap(frame)
	local iapId = frame.Name

	iapId = self._IapController:GetOrderedIap(iapId) or iapId

	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return
	end

	local nameText = frame:FindFirstChild("NameText", true)
	if nameText then
		nameText.Text = iapInfo.Name or ""
	end

	local descriptionText = frame:FindFirstChild("DescriptionText", true)
	if descriptionText then
		descriptionText.Text = iapInfo.Description or ""
	end

	local costInRobux = self._IapController:GetPriceOfIap(iapId)
	local robuxButton = frame:FindFirstChild("Robux", true)
	if robuxButton then
		if costInRobux then
			robuxButton.Visible = true
			robuxButton.AmountText.Text = string.format("%d", costInRobux)
		else
			robuxButton.Visible = false
		end

		local button = GuiButton.new(robuxButton)
		button:SetCallback(function()
			if iapInfo.Prices then
				self:_OpenCurrencyFrame(iapId, nil, function(currency)
					self._IapController:PurchaseIap(iapId, currency, nil)
				end)
			else
				self._IapController:PurchaseIap(iapId)
			end
		end)
		button:SetButtonScaleSize(1.025)
		button:SetButtonBounceScaleSize(0.975)
		button:SetMakeIconRotateLeftRightWhenHovered(true)
		button:SetMakeIconScaleWhenHovered(true)
		button:SetIconHoverScale(1.05)
		button:SetMakeShineWhenHovered(true)
	end

	local giftButton = frame:FindFirstChild("Gift", true)
	if giftButton then
		if iapInfo.Giftable then
			giftButton.Visible = true
		else
			giftButton.Visible = false
		end

		local button = GuiButton.new(giftButton)
		button:SetCallback(function()
			self._IapController:GiftIap(iapId, function(userId)
				if iapInfo.Prices then
					self:_OpenCurrencyFrame(iapId, userId, function(currency)
						self._IapController:PurchaseIap(iapId, currency, userId)
					end)
				else
					self._IapController:PurchaseIap(iapId, nil, userId)
				end
			end)
		end)
		button:SetButtonScaleSize(1.025)
		button:SetButtonBounceScaleSize(0.975)
		button:SetMakeIconRotateLeftRightWhenHovered(true)
		button:SetMakeIconScaleWhenHovered(true)
		button:SetIconHoverScale(1.05)
		button:SetMakeShineWhenHovered(true)
	end

	local previousPrice = frame:FindFirstChild("PreviousPrice", true)
	if previousPrice then
		if iapInfo.PreviousPrice then
			previousPrice.AmountText.Text = tostring(iapInfo.PreviousPrice)
		elseif iapInfo.PriceMultiple then
			local priceMultiple = iapInfo.PriceMultiple
			local robuxCost = self._IapController:GetPriceOfIap(priceMultiple.Id) or 0
			previousPrice.AmountText.Text = robuxCost * priceMultiple.Multiplier
		elseif costInRobux then
			previousPrice.Visible = false
		end
	end

	for costType, cost in pairs(iapInfo.Prices or {}) do
		local costButton = frame:FindFirstChild(costType, true)
		if not costButton then continue end
		if not costButton:IsA("GuiButton") then continue end

		local amountText = costButton:FindFirstChild("AmountText", true)
		if amountText then
			amountText.Text = BigNumbers.GetNumberDisplay(cost)
		end

		local button = GuiButton.new(costButton)
		button:SetCallback(function()
			self._IapController:PurchaseIap(iapId, costType, nil)
		end)
		button:SetButtonScaleSize(1.025)
		button:SetButtonBounceScaleSize(0.975)
		button:SetMakeIconRotateLeftRightWhenHovered(true)
		button:SetMakeIconScaleWhenHovered(true)
		button:SetIconHoverScale(1.05)
		button:SetMakeShineWhenHovered(true)
	end
end

function PremiumController:_UpdateIaps()
	for _, descendant in pairs(self._Gui.ScrollFrame:GetDescendants()) do
		local iapInfo = IapDef.GetIapInfo(descendant.Name)
		if iapInfo then
			self:_UpdateIap(descendant)
		end
	end
	for _, iapSign in pairs(self._IapSignComponent:GetAll()) do
		self:_UpdateIapSign(iapSign)
	end
	for _, iapVendor in pairs(self._IapVendorComponent:GetAll()) do
		self:_UpdateIapVendor(iapVendor)
	end
	self:_UpdateCashGamepassButton()
end

function PremiumController:_UpdateIapSign(iapSign)
	local iapId = self._IapController:GetOrderedIap(iapSign.Instance.Name) or iapSign.Instance.Name
	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then return end

	iapSign.NameText.Text = iapInfo.Name or ""
	iapSign.Icon.Image = self._IapController:GetIconOfIap(iapId) or ""

	local price = self._IapController:GetPriceOfIap(iapId)
	iapSign.PriceText.Text = price and tostring(price) or "..."
end

function PremiumController:_UpdateIapVendor(iapVendor)
	local iapId = self._IapController:GetOrderedIap(iapVendor.Instance.Name) or iapVendor.Instance.Name
	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then return end

	iapVendor.NameText.Text = iapInfo.Name or ""

	if iapVendor.LimitedFrame then
		local limitedId = iapInfo.Limited
		iapVendor.LimitedFrame.Visible = limitedId ~= nil
		if limitedId then
			local limit = self._LimitedController:GetLimitedLimit(limitedId)
			local remainingCount = self._LimitedController:GetLimitedRemainingCount(limitedId)
			local amountText = remainingCount ~= nil and tostring(remainingCount) or "..."
			iapVendor.LimitedAmountText.Text = string.format("%s / %d Left", amountText, limit)
		end
	end

	local price = self._IapController:GetPriceOfIap(iapId)
	iapVendor.PriceText.Text = price and string.format("%d", price) or "..."
end

function PremiumController:_UpdateCashGamepassButton()
	local iapId = self._IapController:GetOrderedIap(IapsEnum.Cash2x)

	if self._IapController:OwnsIap(iapId) then
		self._Gui.CashGamepassButton.Visible = false
		return
	end

	local price = self._IapController:GetPriceOfIap(iapId) or 0
	self._Gui.CashGamepassButton.Visible = true

	local iapInfo = IapDef.GetIapInfo(iapId)
	self._Gui.CashGamepassButton.PriceText.Text = string.format("Only %d", price)
	self._Gui.CashGamepassButton.AmountText.Text = string.format("x%s Cash", iapInfo.Name:match("%d+"))
end

function PremiumController:_UpdateIap(frame)
	local iapId = frame.Name

	iapId = self._IapController:GetOrderedIap(iapId) or iapId

	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return
	end

	local nameText = frame:FindFirstChild("NameText", true)
	if nameText then
		nameText.Text = iapInfo.Name or ""
	end

	local descriptionText = frame:FindFirstChild("DescriptionText", true)
	if descriptionText then
		descriptionText.Text = iapInfo.Description or ""
	end

	local costInRobux = self._IapController:GetPriceOfIap(iapId)
	local robuxButton = frame:FindFirstChild("Robux", true)
	if robuxButton then
		if costInRobux then
			robuxButton.Visible = true
			robuxButton.AmountText.Text = string.format("%d", costInRobux)
		else
			robuxButton.Visible = false
		end
	end

	local previousPrice = frame:FindFirstChild("PreviousPrice", true)
	if previousPrice then
		if iapInfo.PreviousPrice then
			previousPrice.AmountText.Text = tostring(iapInfo.PreviousPrice)
		elseif iapInfo.PriceMultiple then
			local priceMultiple = iapInfo.PriceMultiple
			local robuxCost = self._IapController:GetPriceOfIap(priceMultiple.Id) or 0
			previousPrice.AmountText.Text = robuxCost * priceMultiple.Multiplier
		elseif costInRobux then
			previousPrice.Visible = false
		end
	end
end

function PremiumController:_OpenCurrencyFrame(iapId, giftedUserId, callback)
	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then return end

	local prices = TableUtils.Copy(iapInfo.Prices or {})
	local robuxPrice = self._IapController:GetPriceOfIap(iapId)
	if robuxPrice then
		prices["Robux"] = robuxPrice
	end

	self._Gui.CurrencyFrame.CurrencyText.Text = string.format("Pick a currency to pay for %s", iapInfo.Name or "")
	self._Gui.CurrencyFrame.GiftingText.Text = ""

	task.spawn(function()
		if not giftedUserId then return end

		local giftedPlayer = Players:GetPlayerByUserId(giftedUserId or -1000)
		local nameText = ""
		if giftedPlayer then
			nameText = giftedPlayer.DisplayName
		else
			pcall(function()
				nameText = Players:GetNameFromUserIdAsync(giftedUserId)
			end)
		end

		self._Gui.CurrencyFrame.GiftingText.Text = string.format("Gifting: %s", nameText)
	end)

	for _, currencyButton in pairs(self._Gui.CurrencyFrame.ButtonsFrame:GetChildren()) do
		if not currencyButton:IsA("GuiButton") then continue end

		local currency = currencyButton.Name
		local price = prices[currency]

		currencyButton.Visible = price ~= nil
		if not currencyButton.Visible then continue end

		currencyButton.AmountText.Text = (currency == "Robux") and tostring(price) or BigNumbers.GetNumberDisplay(price)

		local button = GuiButton.new(currencyButton)
		button:SetCallback(function()
			local currencySelected = currency
			if currencySelected == "Robux" then
				currencySelected = nil
			end

			if callback then
				callback(currencySelected)
			end

			self:_CloseCurrencyFrame()
		end)
	end

	self._Gui.CurrencyFrame.Visible = true
end

function PremiumController:_CloseCurrencyFrame()
	for _, currencyButton in pairs(self._Gui.CurrencyFrame.ButtonsFrame:GetChildren()) do
		if not currencyButton:IsA("GuiButton") then continue end

		local button = GuiButton.GetButtonFromInstance(currencyButton)
		if button then button:Destroy() end
		currencyButton.Visible = false
	end

	self._Gui.CurrencyFrame.Visible = false
end

function PremiumController:OpenToFrame(frameName)
	local frame = self._Gui.ScrollFrame:FindFirstChild(frameName)
	if not frame then
		return
	end

	if not self._Gui.Frame.Visible then
		self:SetVisibility(true, true)

		local openTrack = require(self._Gui.Frame.Animator).Open
		openTrack.Completed:Wait()
	end

	local x = 0
	local y = 0

	if (self._Gui.ScrollFrame.ScrollingDirection == Enum.ScrollingDirection.X) or (self._Gui.ScrollFrame.ScrollingDirection == Enum.ScrollingDirection.XY) then
		x = self._Gui.ScrollFrame.CanvasPosition.X + frame.AbsolutePosition.X - self._Gui.ScrollFrame.AbsolutePosition.X
	end

	if (self._Gui.ScrollFrame.ScrollingDirection == Enum.ScrollingDirection.Y) or (self._Gui.ScrollFrame.ScrollingDirection == Enum.ScrollingDirection.XY) then
		y = self._Gui.ScrollFrame.CanvasPosition.Y + frame.AbsolutePosition.Y - self._Gui.ScrollFrame.AbsolutePosition.Y
	end

	local tweenInfo = TweenInfo.new(0.5)
	local tween = TweenService:Create(self._Gui.ScrollFrame, tweenInfo, {
		CanvasPosition = Vector2.new(x, y)
	})

	tween:Play()
end

function PremiumController:_PromptCurrentEvent()
	local success, eventsOrError
	while not success do
		success, eventsOrError = pcall(function()
			return SocialService:GetUpcomingExperienceEventsAsync()
		end)

		if success then
			break
		end

		task.wait(1)
	end

	if not success then
		warn("Failed to load upcoming events:", eventsOrError)
		return
	end

	local upcomingEvents = eventsOrError

	local selectedEvent
	for _, event in ipairs(upcomingEvents) do
		if not event.HasStarted and not event.HasEnded then
			selectedEvent = event
			break
		end
	end

	if selectedEvent then
		pcall(function()
			local status = SocialService:GetEventRsvpStatusAsync(selectedEvent.Id)

			if status ~= Enum.RsvpStatus.Going then
				return SocialService:PromptRsvpToEventAsync(selectedEvent.Id)
			end
		end)
	end
end

-- SERVER LUCK IAP FRAME
function PremiumController:_SetupServerLuck()
	local serverLuck = self._Gui.ScrollFrame.ServerLuck
	self._ServerLuckAmountObject = GuiObject.new(serverLuck.AmountFrame)

	local robuxButton = GuiButton.new(serverLuck.Robux)
	robuxButton:SetCallback(function()
		if self._IsAnimatingServerLuck then return end

		local boost = self._BoostController:GetBoostFromId(BoostsEnum.ServerLuckBoost) or {}
		local currentLevel = boost.Level or 0
		local nextLevel = currentLevel + 1
		local iapId = Constants.ServerLuckOrder[math.min(nextLevel, #Constants.ServerLuckOrder)]
		local iapInfo = IapDef.GetIapInfo(iapId)
		if not iapInfo then return end

		if iapInfo.Prices then
			self:_OpenCurrencyFrame(iapId, nil, function(currency)
				if currency then
					self._IapController:PurchaseIap(iapId, currency, nil)
				else
					self._IapController:PurchaseIap(iapId)
				end
			end)
		else
			self._IapController:PurchaseIap(iapId)
		end
	end)
	robuxButton:SetButtonScaleSize(1.025)
	robuxButton:SetButtonBounceScaleSize(0.975)
	robuxButton:SetMakeIconRotateLeftRightWhenHovered(true)
	robuxButton:SetMakeIconScaleWhenHovered(true)
	robuxButton:SetIconHoverScale(1.05)
	robuxButton:SetMakeShineWhenHovered(true)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function()
		self:_UpdateServerLuck()
	end)

	self:_UpdateServerLuck()
end

function PremiumController:_AnimateServerLuckAmount()
	self._IsAnimatingServerLuck = true

	local amountFrame = self._Gui.ScrollFrame.ServerLuck.AmountFrame
	local originalSize = amountFrame.Size
	local originalPosition = amountFrame.Position

	local multiplier = 2.5
	local expandedSize = UDim2.new(
		originalSize.X.Scale * multiplier, originalSize.X.Offset * multiplier,
		originalSize.Y.Scale * multiplier, originalSize.Y.Offset * multiplier
	)

	local growTween = TweenService:Create(amountFrame, TweenInfo.new(ServerLuckBuildUpSound.TimeLength, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = expandedSize,
		Position = originalPosition + UDim2.fromOffset(0, -12)
	})
	local slamTween = TweenService:Create(amountFrame, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = originalSize,
		Position = originalPosition
	})

	UtilFunctions.PlayCopyOfSound(ServerLuckBuildUpSound)
	growTween:Play()
	growTween.Completed:Wait()

	UtilFunctions.PlayCopyOfSound(ServerLuckSmashSound)
	slamTween:Play()
	slamTween.Completed:Wait()

	self._IsAnimatingServerLuck = false
	self:_UpdateServerLuck()
	self._ServerLuckAmountObject:MakeShake(0.025, 0.5)
	self._ServerLuckAmountObject:GrowAndFade(2, TweenInfo.new(1))
end

function PremiumController:_UpdateServerLuck()
	local serverLuck = self._Gui.ScrollFrame.ServerLuck

	local boost = self._BoostController:GetBoostFromId(BoostsEnum.ServerLuckBoost) or {}
	local currentLevel = boost.Level or 0
	local nextLevel = currentLevel + 1
	local maxLevel = math.min(BoostsDef.GetMaxLevelForBoost(BoostsEnum.ServerLuckBoost), #Constants.ServerLuckOrder)
	local iapToBuy = Constants.ServerLuckOrder[math.min(nextLevel, #Constants.ServerLuckOrder)]

	local currentAmount = BoostsDef.GetTotalAmountForBoostForLevel(BoostsEnum.ServerLuckBoost, currentLevel)
	local nextAmount = BoostsDef.GetTotalAmountForBoostForLevel(BoostsEnum.ServerLuckBoost, nextLevel)

	local amountText = ""
	local darkAmountText = ""
	if nextLevel <= maxLevel then
		amountText = string.format("%dx -> <font color=\"#FFF582\">%dx</font>", currentAmount, nextAmount)
		darkAmountText = string.format("%dx -> %dx", currentAmount, nextAmount)
	else
		amountText = string.format("<font color=\"#FFF582\">%dx</font>", currentAmount)
		darkAmountText = amountText
	end

	if not self._IapController:IsPurchasePromptOpen() and not self._IsAnimatingServerLuck then
		serverLuck.AmountFrame.AmountText.Text = amountText
		serverLuck.AmountFrame.DarkAmountText.Text = darkAmountText
	end
	serverLuck.Robux.AmountText.Text = self._IapController:GetPriceOfIap(iapToBuy) or 0
end

return PremiumController
