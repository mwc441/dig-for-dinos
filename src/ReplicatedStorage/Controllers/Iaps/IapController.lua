local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local IapPurchasedSound = Sounds:WaitForChild("IapPurchasedSound")
local IapPromptedSound = Sounds:WaitForChild("IapPromptedSound")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local IapRainImage = ClientAssets:WaitForChild("IapRainImage")
local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Fireworks = require(Utils:WaitForChild("Fireworks"))
local GuiObject = require(GuiModules:WaitForChild("Object"))
local IapTypesEnum = require(Enums:WaitForChild("IapTypes"))
local NotificationTypesEnum = require(Enums:WaitForChild("NotificationTypes"))
local IapDef = require(ReplicatedConfigs:WaitForChild("IapDef"))
local Signal = require(External:WaitForChild("Signal"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local Knit = require(External:WaitForChild("Knit"))

local hapticEffect = Instance.new("HapticEffect")
hapticEffect.Type = Enum.HapticEffectType.GameplayExplosion
hapticEffect.Parent = Workspace

local IapController = {
	Name = "IapController",
	_DataController = nil,
	_NotificationController = nil,
	_HudController = nil,
	_IapService = nil,
	_FriendController = nil,
	_Iaps = {},
	_IapCache = {},
	_GamepassCache = {},
	_SubscriptionCache = {},
	_PromptOpen = false,
	IapCacheChanged = Signal.new(),
	IapsUpdatedSignal = Signal.new(),
	IapPurchasedSignal = Signal.new()
}

function IapController:KnitInit()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function()
		self:_ClosePromptScreen()
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function()
		self:_ClosePromptScreen()
	end)

	MarketplaceService.PromptSubscriptionPurchaseFinished:Connect(function()
		self:_ClosePromptScreen()
	end)

	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")

	self._Gui = {
		IapRainFrame = mainGui:WaitForChild("IapRainFrame"),
		IapPromptFrame = mainGui:WaitForChild("IapPromptFrame")
	}

	self._RobuxIconObject = GuiObject.new(self._Gui.IapPromptFrame.RobuxIcon)
	self._RobuxIconObject:SetSpinAngularSpeed(270)

	self:_CacheAllProductInfos()
	self:_CacheAllOwned()
end

function IapController:KnitStart()
	self._IapService = Knit.GetService("IapService")
	self._DataController = require(ReplicatedStorage.Controllers.Data.DataController)
	self._NotificationController = require(ReplicatedStorage.Controllers.Notifications.NotificationController)
	self._HudController = require(ReplicatedStorage.Controllers.Hud.HudController)
	self._FriendController = require(ReplicatedStorage.Controllers.Friends.FriendController)

	self._IapService.BeenGifted:Connect(function(iapId, giftingPlayerUserId)
		self:_PromptWithGiftedScreen(iapId, giftingPlayerUserId)
	end)

	self._DataController.ProfileUpdatedSignal:Connect(function(profileData)
		debug.profilebegin("Iaps")
		if profileData.Iaps then
			self:_UpdateIaps(profileData.Iaps)
		end
		debug.profileend()
	end)

	self._IapService.IapPrompted:Connect(function()
		self:_PlayPromptScreen()
	end)

	self._IapService.IapPurchased:Connect(function(iapId)
		self.IapPurchasedSignal:Fire(iapId)
		self:_ClosePromptWindow()
		Fireworks.LaunchFireworks(Player.Character:GetPivot())
		hapticEffect:Play()
	end)

	local iaps = self._DataController:GetProfileData("Iaps")
	if iaps then
		self:_UpdateIaps(iaps)
	end
end

function IapController:_UpdateIaps(iapData)
	if not TableUtils.Equals(iapData.IapsPurchased, self._Iaps) then
		self._Iaps = iapData.IapsPurchased

		self.IapsUpdatedSignal:Fire()
	end
end

function IapController:_GetQuantityOfIap(iapId)
	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return
	end

	local quantity = 0

	local quantityOwned = self._Iaps[iapId] or 0
	quantity += quantityOwned

	for iapType in pairs(iapInfo.Ids or {}) do
		if iapType == IapTypesEnum.Gamepass then
			local playerOwnsGamepass = self:_CheckIfOwnsGamepass(iapId)
			if playerOwnsGamepass then
				quantity += 1
			end
		elseif iapType == IapTypesEnum.Subscription then
			local playerOwnsSubscription = self:_CheckIfIsSubscribed(iapId)
			if playerOwnsSubscription then
				quantity += 1
			end
		end
	end

	return quantity
end

function IapController:OwnsIap(iapId, quantity)
	quantity = quantity or 1

	local quantityOwned = self:_GetQuantityOfIap(iapId)

	return (quantityOwned >= quantity)
end

function IapController:GetTotalTimesPurchased(iapId)
	return (self._Iaps[iapId] or 0)
end

function IapController:GetOrderedIap(iapId)
	-- This function takes an IapId, and checks if the iapId is part of an ordered list of
	-- iapids. This is in IapDef, the table OrderOfPurchase. It will only allow players
	-- to buy iaps in a certain order. For Example: A dev product that can be purchased
	-- multiple times, but increases in price every purchase. This will require multiple
	-- iapId's and dev products to accomplish.
	-- This function checks if the given IapId is a part of one of those ordered lists of
	-- ids, and checks if the player can purchase the given iapid, or if they need to buy
	-- an ealier version
	local orderedTable = IapDef.GetOrderOfPurchaseTable(iapId)
	if not orderedTable then
		return iapId
	end

	local id = iapId
	for _, orderedIapId in pairs(orderedTable) do
		local iapInfo = IapDef.GetIapInfo(orderedIapId)
		if not iapInfo then
			return iapId
		end

		local owned = self:OwnsIap(orderedIapId, iapInfo.MaxPurchases or 1)
		if not owned then
			return orderedIapId
		end

		id = orderedIapId
	end

	return id
end

function IapController:PurchaseIap(iapId, costType, giftedPlayerId)
	if not giftedPlayerId then
		iapId = self:GetOrderedIap(iapId) or iapId
	end

	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return
	end

	if costType then
		if not iapInfo.Prices then
			return
		end

		if not iapInfo.Prices[costType] then
			return
		end
	end

	if giftedPlayerId and (not iapInfo.Giftable) then
		return
	end

	local giftedPlayer = Players:GetPlayerByUserId(giftedPlayerId or -1000)
	local orderedTable = IapDef.GetOrderOfPurchaseTable(iapId)

	if orderedTable and (giftedPlayerId and not giftedPlayer) then
		return
	end

	return self._IapService:PurchaseIap(iapId, costType, giftedPlayerId)
end

function IapController:GiftIap(iapId, callback)
	local orderedTable = IapDef.GetOrderOfPurchaseTable(iapId)

	local friends = self._FriendController:GetAllFriends()

	if orderedTable then
		friends = {}
	end

	local players = {}
	for _, player in pairs(Players:GetPlayers()) do
		table.insert(players, player.UserId)
	end

	for _, friendId in pairs(friends) do
		if not table.find(players, friendId) then
			table.insert(players, friendId)
		end
	end

	self._NotificationController:CreateNotification({
		NotificationType = NotificationTypesEnum.Players,
		Players = players,
		Callback = function(userId)
			if callback then
				callback(userId)
			else
				self:PurchaseIap(iapId, nil, userId)
			end
		end
	})
end

function IapController:PurchaseUGC(assetId)
	self._IapService:PurchaseUGC(assetId)
end

function IapController:GetPriceOfIap(iapId)
	iapId = self:GetOrderedIap(iapId) or iapId

	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return
	end

	local info = self._IapCache[iapId]
	if not info then
		return
	end

	if iapInfo.Ids[IapTypesEnum.DevProduct] or iapInfo.Ids[IapTypesEnum.Gamepass] then
		return info.PriceInRobux
	elseif iapInfo.Ids[IapTypesEnum.Subscription] then
		return info.DisplayPrice
	end
end

function IapController:_CacheAllProductInfos()
	local function cacheIap(iapId)
		local iapInfo = IapDef.GetIapInfo(iapId)
		if not iapInfo then
			return
		end

		local ids = iapInfo.Ids
		if not ids then
			return
		end

		local success, info
		while not success do
			success, info = pcall(function()
				if ids[IapTypesEnum.DevProduct] then
					return MarketplaceService:GetProductInfoAsync(ids[IapTypesEnum.DevProduct], Enum.InfoType.Product)
				elseif ids[IapTypesEnum.Gamepass] then
					return MarketplaceService:GetProductInfoAsync(ids[IapTypesEnum.Gamepass], Enum.InfoType.GamePass)
				elseif ids[IapTypesEnum.Subscription] then
					return MarketplaceService:GetSubscriptionProductInfoAsync(ids[IapTypesEnum.Subscription])
				else
					print(iapId)
					warn("NO IAPTYPE SET")
					return {}
				end
			end)
		end

		if success then
			self._IapCache[iapId] = info
			self.IapCacheChanged:Fire()
		end
	end

	for iapId in pairs(IapDef.GetAllIaps()) do
		task.spawn(function()
			cacheIap(iapId)
		end)
	end
end

function IapController:_CacheAllOwned()
	-- Go through and cache all gamepasses and subcriptions for player
	for _, iapInfo in pairs(IapDef.GetAllIaps()) do
		for iapType, productId in pairs(iapInfo.Ids or {}) do
			if iapType == IapTypesEnum.Gamepass then
				task.spawn(function()
					self:_ForceUpdateGamepass(productId)
				end)
			elseif (iapType == IapTypesEnum.Subscription) then
				task.spawn(function()
					self:_ForceUpdateSubscriptionStatus(productId)
				end)
			end
		end
	end
end

function IapController:_SetGamepassCache( gamepassId, owned)
	local playerGamepassCache = self._GamepassCache
	playerGamepassCache[gamepassId] = owned
end

function IapController:_CheckIfOwnsGamepass(iapId)
	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return
	end

	local playerGamepassCache = self._GamepassCache

	local gamepassId = iapInfo.Ids[IapTypesEnum.Gamepass]
	if not gamepassId then
		return
	end

	if playerGamepassCache[gamepassId] ~= nil then
		return playerGamepassCache[gamepassId]
	end
end

function IapController:_ForceUpdateGamepass(gamepassId)
	local success, playerOwnsGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, gamepassId)
	end)

	if not success then
		return
	end

	self:_SetGamepassCache(gamepassId, playerOwnsGamepass)

	self.IapsUpdatedSignal:Fire()

	return playerOwnsGamepass
end

function IapController:_ForceUpdateSubscriptionStatus(subscriptionId)
	local success, subStatus = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(Player, subscriptionId)
	end)

	if not success then
		return
	end

	local playerSubscriptionCache = self._SubscriptionCache
	playerSubscriptionCache[subscriptionId] = subStatus["IsSubscribed"]

	self.IapsUpdatedSignal:Fire()

	return subStatus["IsSubscribed"]
end

function IapController:_CheckIfIsSubscribed(iapId)
	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return
	end

	local subscriptionId = iapInfo.Ids[IapTypesEnum.Subscription]
	if not subscriptionId then
		return
	end

	local playerSubscriptionCache = self._SubscriptionCache

	if playerSubscriptionCache[subscriptionId] ~= nil then
		return playerSubscriptionCache[subscriptionId]
	end
end

function IapController:_PromptWithGiftedScreen(iapId, giftingPlayerUserId)
	local iapInfo = IapDef.GetIapInfo(iapId)

	local giftingPlayer = Players:GetPlayerByUserId(giftingPlayerUserId or -1000)
	local playerName
	if giftingPlayer then
		playerName = giftingPlayer.DisplayName
	else
		pcall(function()
			playerName = Players:GetNameFromUserIdAsync(giftingPlayerUserId)
		end)
	end

	self._NotificationController:CreateNotification({
		NotificationType = NotificationTypesEnum.Okay,
		Message = string.format("You have been gifted %s by %s", iapInfo.Name or "", playerName or "someone"),
		OkayText = "Thanks!"
	})
end

function IapController:_MakeIapRain()
	local randomAmount = math.random(125, 150)

	IapPurchasedSound:Play()

	local random = Random.new()

	for i = 1, randomAmount do
		local newIapRain = IapRainImage:Clone()

		local yPos = random:NextNumber(0, 1)
		local xPos = random:NextNumber(0, 1)
		newIapRain.Position = UDim2.new(xPos, 0, yPos, 0)
		newIapRain.Rotation = math.random(0, 360)
		newIapRain.ZIndex = i
		newIapRain.Parent = self._Gui.IapRainFrame

		local oldSize = newIapRain.Size

		newIapRain.Size = UDim2.fromOffset(0, 0)

		local spinSpeed = math.random(45, 180)
		local object = GuiObject.new(newIapRain)
		object:SetSpinAngularSpeed(spinSpeed)
		object:StartSpin()

		local tweenInfo = TweenInfo.new(random:NextNumber(0.35, 0.65), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(newIapRain, tweenInfo, {
			Size = oldSize
		})

		tween:Play()

		local connect
		connect = tween.Completed:Connect(function()
			connect:Disconnect()

			local randomTime = random:NextNumber(1.5, 2.5)
			tweenInfo = TweenInfo.new(randomTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween = TweenService:Create(newIapRain, tweenInfo, {
				Position = UDim2.new(newIapRain.Position.X.Scale, 0, 1 + yPos, 0),
				Size = UDim2.fromOffset(0, 0)
			})

			tween:Play()

			connect = tween.Completed:Connect(function()
				connect:Disconnect()
				newIapRain:Destroy()
			end)
		end)
	end
end

function IapController:_PlayPromptScreen()
	if self._PromptOpen then
		return
	end

	self._PromptOpen = true

	local animator = require(self._Gui.IapPromptFrame.Animator)

	local showTrack = animator.Show

	showTrack:Play()

	self._BlurTween = self._HudController:BlurScreen(0.25)

	self._RobuxIconObject:StartSpin()

	IapPromptedSound:Play()

	self._Gui.IapPromptFrame.Visible = true
end

function IapController:_ClosePromptScreen()
	if not self._PromptOpen then
		return
	end

	self._PromptOpen = false

	self:_ClosePromptWindow()
end

function IapController:IsPurchasePromptOpen()
	return self._PromptOpen
end

function IapController:_ClosePromptWindow()
	local animator = require(self._Gui.IapPromptFrame.Animator)

	local hideTrack = animator.Hide

	hideTrack:Play()

	if self._BlurTween then
		self._HudController:UnblurScreen(0.25)
	end
	self._BlurTween = nil

	local connection
	connection = hideTrack.Completed:Connect(function()
		self._Gui.IapPromptFrame.Visible = false
		connection:Disconnect()
		self._RobuxIconObject:StopSpin()
	end)
end

return IapController