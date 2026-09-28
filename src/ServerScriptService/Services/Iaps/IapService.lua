local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local ServerConfigs = ServerScriptService:WaitForChild("ServerConfigs")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local DataKeys = require(ServerConfigs:WaitForChild("DataKeys"))
local IapTypesEnum = require(Enums:WaitForChild("IapTypes"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local IapDef = require(ReplicatedConfigs:WaitForChild("IapDef"))
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))

local PLAYER_PURCHASED_MESSAGE =
"Wow! <font color=\"#268fff\">@%s</font> has purchased <font color=\"#cf8cff\">%s</font> for <font color=\"#1fe815\">%d</font>"
local PLAYER_PURCHASED_COLOR = Color3.fromRGB(255, 255, 255)
local PLAYER_PURCHASED_THRESHOLD = 1_000
local POLICY_RESTRICTED = "❌ Purchase Restricted"
local GIFTING_SUCCESSFUL_MESSAGE = "Gift successfully sent to %s, thank you for your support!"
local PURCHASE_SUCCESSFUL_MESSAGE = "🥳 Thank you for your purchase! 🥳"
local CANT_PURCHASE_MORE_MESSAGE = "❌ Can't purchase any more of that!"
local IAP_KEY = DataKeys.Iaps
local IAP_DEFAULT_DATA = {
	Version = 1,
	IapsPurchased = {}
}

local IapService = {
	Name = "IapService",
	Client = {
		BeenGifted = Knit.CreateSignal(),
		IapPrompted = Knit.CreateSignal(),
		IapPurchased = Knit.CreateSignal()
	},
	_DataService = nil,
	_RewardsService = nil,
	_PolicyService = nil,
	_AdminService = nil,
	_PlayerStatsService = nil,
	_AnalyticsService = nil,
	_LimitedService = nil,
	_LifecycleService = nil,
	_CommerceService = nil,
	_PlayerGamepassCache = {},
	_PlayerSubscriptionCache = {},
	_PlayersGifted = {},
	PlayerIapsUpdated = Signal.new()
}

function IapService:KnitInit()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(...)
		self:_GamepassPurchaseFinished(...)
	end)

	Players.UserSubscriptionStatusChanged:Connect(function(player, subscriptionId)
		self:_ForceUpdateSubscriptionStatus(player, subscriptionId)
	end)

	MarketplaceService.ProcessReceipt = function(...)
		return self:_ProcessReceipt(...)
	end
end

function IapService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)
	self._PolicyService = require(ServerScriptService.Services.Policy.PolicyService)
	self._AdminService = require(ServerScriptService.Services.Admin.AdminService)
	self._PlayerStatsService = require(ServerScriptService.Services.PlayerStats.PlayerStatsService)
	self._AnalyticsService = require(ServerScriptService.Services.Analytics.AnalyticsService)
	self._LimitedService = require(ServerScriptService.Services.Limited.LimitedService)
	self._LifecycleService = require(ServerScriptService.Services.LifeCycle.LifecycleService)
	self._CommerceService = require(ServerScriptService.Services.Commerce.CommerceService)

	self._RewardsService.CrossServerMessageReceived:Connect(function(text, color, type)
		if (type == "IapAnnouncement") then
			self._RewardsService:FinalizeCrossServerMessage(text, color)
		end
	end)
end

function IapService:OnPlayerAdded(player)
	-- Go through and cache all gamepasses and subscriptions for player
	for _, iapInfo in pairs(IapDef.GetAllIaps()) do
		local ids = iapInfo.Ids or {}

		if ids[IapTypesEnum.Gamepass] then
			task.spawn(function()
				self:_ForceUpdateGamepass(player, ids[IapTypesEnum.Gamepass])
			end)
		end

		if ids[IapTypesEnum.Subscription] then
			task.spawn(function()
				self:_ForceUpdateSubscriptionStatus(player, ids[IapTypesEnum.Subscription])
			end)
		end
	end
end

function IapService:OnPlayerRemoving(player)
	self._PlayerGamepassCache[player] = nil
	self._PlayersGifted[player] = nil
	self._PlayerSubscriptionCache[player] = nil
end

function IapService:_ProcessReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local iapInfo, iapId = IapDef.GetIapInfoFromProductId(receiptInfo.ProductId)
	if not iapInfo then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not iapInfo.Rewards then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local giftedUserId = self._PlayersGifted[player]
	local success = false
	if giftedUserId and iapInfo.Giftable then
		success = self:GiftIap(giftedUserId, iapId, player.UserId)

		if success then
			self._AnalyticsService:LogCustomEvent(player, "IapGifted", 1, {
				[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "IapId - " .. iapId,
				[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = "Currency - Robux"
			})
		end
	else
		success = self:RewardPlayer(player, iapId, true)

		if success then
			self._AnalyticsService:LogCustomEvent(player, "IapPurchased", 1, {
				[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "IapId - " .. iapId,
				[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = "Currency - Robux"
			})

			self._RewardsService:AnnounceMessageToPlayer(player, PURCHASE_SUCCESSFUL_MESSAGE, Color3.fromRGB(255, 255, 255))
		end
	end

	self._PlayersGifted[player] = nil

	if not success then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if iapInfo.Limited then
		task.spawn(function()
			self._LimitedService:IncrementLimited(iapInfo.Limited)
		end)
	end

	if RunService:IsStudio() then
		local productInfo = MarketplaceService:GetProductInfoAsync(receiptInfo.ProductId, Enum.InfoType.Product)
		receiptInfo.CurrencySpent = productInfo.PriceInRobux or 0
	end

	local announcementString = string.format(PLAYER_PURCHASED_MESSAGE, player.Name, iapInfo.Name, receiptInfo.CurrencySpent)
	if receiptInfo.CurrencySpent >= PLAYER_PURCHASED_THRESHOLD then
		self._RewardsService:MakeCrossServerMessage(announcementString, PLAYER_PURCHASED_COLOR, "IapAnnouncement")
	else
		self._RewardsService:MakeSystemMessage(announcementString, PLAYER_PURCHASED_COLOR)
	end

	self._PlayerStatsService:AddToStatForPlayer(player, PlayerStatsEnum.RobuxSpent, receiptInfo.CurrencySpent)
	self.Client.IapPurchased:Fire(player, iapId)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function IapService:RewardPlayer(player, iapId, forceSave)
	local profile = self._DataService:GetPlayerProfile(player)
	if not profile then
		profile = self._DataService:WaitForLoadingProfile(player)
	end

	while (not self._LifecycleService:IsPlayerInitialized(player)) and Players:IsAncestorOf(player) do
		task.wait()
	end

	if not Players:IsAncestorOf(player) then
		return
	end

	if not profile then
		return
	end

	local orderedIapId = self:_GetOrderedIapIdForPlayer(player, iapId) or iapId
	if orderedIapId ~= iapId then
		local orderedRank = self:_GetRankInOrder(orderedIapId)
		local iapRank = self:_GetRankInOrder(iapId)

		if iapRank >= orderedRank then
			iapId = orderedIapId
		else
			return true
		end
	end

	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return true
	end

	local totalPurchases = self:_GetQuantityOfIap(player, iapId)
	if iapInfo.MaxPurchases then
		if totalPurchases >= iapInfo.MaxPurchases then
			return true
		end
	end

	local playerIapData = self._DataService:GetPlayerData(player, IAP_KEY, IAP_DEFAULT_DATA)
	playerIapData.IapsPurchased[iapId] = (playerIapData.IapsPurchased[iapId] or 0) + 1

	self._DataService:SetPlayerData(player, IAP_KEY, playerIapData)

	if forceSave then
		local saveSuccess = self._DataService:ForceSave(player)
		if not saveSuccess then
			return
		end

		local iapData = profile.Data[IAP_KEY]
		if not iapData then
			return
		end

		local totalPurchased = iapData.IapsPurchased[iapId]
		if totalPurchased ~= playerIapData.IapsPurchased[iapId] then
			return
		end
	end

	self:_FirePlayerIapsUpdated(player)

	for rewardType, reward in pairs(iapInfo.Rewards) do
		self._RewardsService:RewardPlayer(player, rewardType, reward, true, {
			TransactionType = Enum.AnalyticsEconomyTransactionType.IAP.Name,
			Sku = iapId,
			CustomFields = nil
		})
	end

	return true, iapId
end

function IapService:GiftIap(userId, iapId, giftingPlayerUserId)
	local player = Players:GetPlayerByUserId(userId)
	local iapInfo
	if player then
		local orderedIapId = self:_GetOrderedIapIdForPlayer(player, iapId) or iapId
		if orderedIapId ~= iapId then
			local orderedRank = self:_GetRankInOrder(orderedIapId)
			local iapRank = self:_GetRankInOrder(iapId)

			if iapRank >= orderedRank then
				iapId = orderedIapId
			else
				return true
			end
		end

		iapInfo = IapDef.GetIapInfo(iapId)
		if not iapInfo then
			return true
		end

		if not iapInfo.Giftable then
			return true
		end

		---@diagnostic disable-next-line: undefined-global
		_, iapId = self:RewardPlayer(player, iapId)

		if iapId then
			self.Client.BeenGifted:Fire(player, iapId, giftingPlayerUserId)
		end
	else
		iapInfo = IapDef.GetIapInfo(iapId)
		if not iapInfo then
			return true
		end

		if not iapInfo.Giftable then
			return true
		end

		self._DataService:PushNewActiveUpdate(userId, {
			IapId = iapId,
			GiftingPlayerUserId = giftingPlayerUserId
		})
	end

	local giftingPlayer = Players:GetPlayerByUserId(giftingPlayerUserId)
	if giftingPlayer then
		task.spawn(function()
			pcall(function()
				self._RewardsService:AnnounceMessageToPlayer(giftingPlayer, string.format(GIFTING_SUCCESSFUL_MESSAGE, Players:GetNameFromUserIdAsync(userId)))
			end)
		end)
	end

	return true, iapId
end

function IapService:_GamepassPurchaseFinished(player, gamepassId, purchased)
	if not purchased then
		return
	end

	self:_ForceUpdateGamepass(player, gamepassId)
end

function IapService:_GetPlayerGamepassCache(player)
	if not Players:IsAncestorOf(player) then
		return {}
	end

	if not self._PlayerGamepassCache[player] then
		self._PlayerGamepassCache[player] = {}
	end

	return self._PlayerGamepassCache[player]
end

function IapService:_SetPlayerGamepassCache(player, gamepassId, owned)
	local playerGamepassCache = self:_GetPlayerGamepassCache(player)
	playerGamepassCache[gamepassId] = owned
end

function IapService:_CheckIfPlayerOwnsGamepass(player, iapId)
	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return
	end

	local playerGamepassCache = self:_GetPlayerGamepassCache(player)

	local gamepassId = iapInfo.Ids[IapTypesEnum.Gamepass]
	if not gamepassId then
		return
	end

	if playerGamepassCache[gamepassId] ~= nil then
		return playerGamepassCache[gamepassId]
	end
end

function IapService:_ForceUpdateGamepass(player, gamepassId)
	local success, playerOwnsGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)

	if not success then
		return
	end

	self:_SetPlayerGamepassCache(player, gamepassId, playerOwnsGamepass)

	self:_FirePlayerIapsUpdated(player)

	return playerOwnsGamepass
end

function IapService:_GetQuantityOfIap(player, iapId)
	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return
	end

	local quantity = 0

	local playerIapData = self._DataService:GetPlayerData(player, IAP_KEY, IAP_DEFAULT_DATA)
	local quantityOwned = playerIapData.IapsPurchased[iapId] or 0
	quantity += quantityOwned

	for iapType in pairs(iapInfo.Ids or {}) do
		if iapType == IapTypesEnum.Gamepass then
			local playerOwnsGamepass = self:_CheckIfPlayerOwnsGamepass(player, iapId)
			if playerOwnsGamepass then
				quantity += 1
			end
		elseif iapType == IapTypesEnum.Subscription then
			local playerOwnsSubscription = self:_CheckIfPlayerIsSubscribed(player, iapId)
			if playerOwnsSubscription then
				quantity += 1
			end
		end
	end

	return quantity
end

function IapService:PlayerOwnsProduct(player, iapId, quantity)
	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return
	end

	quantity = quantity or 1

	local quantityOwned = self:_GetQuantityOfIap(player, iapId) or 0
	return quantityOwned >= quantity
end

function IapService:_GetPlayerSubscriptionCache(player)
	if not Players:IsAncestorOf(player) then
		return {}
	end

	if not self._PlayerSubscriptionCache[player] then
		self._PlayerSubscriptionCache[player] = {}
	end

	return self._PlayerSubscriptionCache[player]
end

function IapService:_ForceUpdateSubscriptionStatus(player, subscriptionId)
	local success, subStatus = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(player, subscriptionId)
	end)

	if not success then
		return
	end

	local playerSubscriptionCache = self:_GetPlayerSubscriptionCache(player)
	playerSubscriptionCache[subscriptionId] = subStatus["IsSubscribed"]

	self:_FirePlayerIapsUpdated(player)

	return subStatus["IsSubscribed"]
end

function IapService:_CheckIfPlayerIsSubscribed(player, iapId)
	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return
	end

	local subscriptionId = iapInfo.Ids[IapTypesEnum.Subscription]
	if not subscriptionId then
		return
	end

	local playerSubscriptionCache = self:_GetPlayerSubscriptionCache(player)

	if playerSubscriptionCache[subscriptionId] ~= nil then
		return playerSubscriptionCache[subscriptionId]
	end
end

function IapService:_FirePlayerIapsUpdated(player)
	if not Players:IsAncestorOf(player) then
		return
	end

	self.PlayerIapsUpdated:Fire(player)
end

function IapService:_PromptPlayerIap(player, iapId)
	local iapInfo = IapDef.GetIapInfo(iapId)
	if not iapInfo then
		return
	end

	local id
	local ids = iapInfo.Ids or {}
	if ids[IapTypesEnum.DevProduct] then
		id = ids[IapTypesEnum.DevProduct]
		MarketplaceService:PromptProductPurchase(player, id)
		self.Client.IapPrompted:Fire(player)
	elseif ids[IapTypesEnum.Gamepass] then
		id = ids[IapTypesEnum.Gamepass]
		local playerOwnsGamepass = self:_CheckIfPlayerOwnsGamepass(player, iapId)
		if playerOwnsGamepass then
			return
		end

		MarketplaceService:PromptGamePassPurchase(player, id)
		self.Client.IapPrompted:Fire(player)
	elseif ids[IapTypesEnum.Subscription] then
		id = ids[IapTypesEnum.Subscription]

		local playerIsSubscribed = self:_CheckIfPlayerIsSubscribed(player, iapId)
		if playerIsSubscribed then
			return
		end

		MarketplaceService:PromptSubscriptionPurchase(player, id)
		self.Client.IapPrompted:Fire(player)
	end
end

function IapService:_GetRankInOrder(iapId)
	local orderedTable = IapDef.GetOrderOfPurchaseTable(iapId)
	if not orderedTable then
		return 1
	end

	return table.find(orderedTable, iapId)
end

function IapService:_GetOrderedIapIdForPlayer(player, iapId)
	-- This function takes an IapId, and checks if the iapId is part of an ordered list of
	-- iapids. This is in IapDef, the table OrderOfPurchase. It will only allow players
	-- to buy iaps in a certain order. For Example: A dev product that can be purchased
	-- multiple times, but increases in price every purchase. This will require multiple
	-- iapId's and dev products to accomplish.
	-- This function checks if the given IapId is a part of one of those ordered lists of
	-- ids, and returns the next iapId they can purchase in the list
	local orderedTable = IapDef.GetOrderOfPurchaseTable(iapId)
	if not orderedTable then
		return iapId
	end

	for _, orderedIapId in pairs(orderedTable) do
		local iapInfo = IapDef.GetIapInfo(orderedIapId)
		if not iapInfo then
			continue
		end

		local owned = self:PlayerOwnsProduct(player, orderedIapId, iapInfo.MaxPurchases or 1)
		if not owned then
			return orderedIapId
		end
	end
end

function IapService:PurchaseIap(player, iapId, costType, giftedPlayerId)
	local orderedTable = IapDef.GetOrderOfPurchaseTable(iapId)
	local giftedPlayer = Players:GetPlayerByUserId(giftedPlayerId or -1000)

	if giftedPlayer == player then
		return
	end

	if giftedPlayer then
		local profile = self._DataService:GetPlayerProfile(giftedPlayer)
		if not profile then
			return
		end

		iapId = self:_GetOrderedIapIdForPlayer(giftedPlayer, iapId) or iapId
	elseif (not giftedPlayer) and (giftedPlayerId) then
		-- If the IAP is part of a ordered list and the gifted player isnt online
		-- then dont allow the purchase
		if orderedTable then
			return
		end

		iapId = iapId
	elseif not giftedPlayerId then
		iapId = self:_GetOrderedIapIdForPlayer(player, iapId) or iapId
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

	if giftedPlayerId then
		if not iapInfo.Giftable then
			return
		end

		self._PlayersGifted[player] = giftedPlayerId
	elseif not giftedPlayerId then
		self._PlayersGifted[player] = nil
	end

	if iapInfo.Limited then
		if not self._LimitedService:IsLimitedAvailable(iapInfo.Limited, true, player) then
			return
		end
	end

	if iapInfo.PaidRandom then
		if not self._PolicyService:CanPlayerBuyRandomPremium(player) then
			self._RewardsService:AnnounceMessageToPlayer(player, POLICY_RESTRICTED)
			return
		end
	end

	if iapInfo.ExpiryTime then
		if os.time() >= iapInfo.ExpiryTime then
			return
		end
	end

	if iapInfo.MaxPurchases then
		local timesPurchased

		if giftedPlayer then
			timesPurchased = self:_GetQuantityOfIap(giftedPlayer, iapId)
		elseif giftedPlayerId and (not giftedPlayer) then
			timesPurchased = 0
		elseif not giftedPlayerId then
			timesPurchased = self:_GetQuantityOfIap(player, iapId)
		end

		if timesPurchased >= iapInfo.MaxPurchases then
			self._RewardsService:AnnounceMessageToPlayer(player, CANT_PURCHASE_MORE_MESSAGE)

			return
		end
	end

	local isAdmin = self._AdminService:IsPlayerAdmin(player)
	if isAdmin and (not RunService:IsStudio()) then
		pcall(function()
			if not iapInfo.Ids[IapTypesEnum.DevProduct] then
				return
			end

			self:_ProcessReceipt({
				PlayerId = player.UserId,
				ProductId = iapInfo.Ids[IapTypesEnum.DevProduct],
				CurrencySpent = 0
			})
		end)

		return
	end

	if not costType then
		-- Purchase for robux
		self:_PromptPlayerIap(player, iapId)
	else
		local cost = iapInfo.Prices[costType]
		local success = self._CommerceService:Spend(player, costType, cost)
		if success then
			if giftedPlayerId then
				self:GiftIap(giftedPlayerId, iapId, player.UserId)
				self._AnalyticsService:LogCustomEvent(player, "IapGifted", 1, {
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "IapId - " .. iapId,
					[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = "Currency - " .. costType
				})
			else
				self:RewardPlayer(player, iapId)
				self._AnalyticsService:LogCustomEvent(player, "IapPurchased", 1, {
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "IapId - " .. iapId,
					[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = "Currency - " .. costType
				})
			end

			self.Client.IapPurchased:Fire(player, iapId)
		end
	end

	return true
end

function IapService.Client:PurchaseIap(player, iapId, costType, giftedUserId)
	if type(iapId) ~= "string" then
		return
	end

	if costType ~= nil then
		if type(costType) ~= "string" then
			return
		end
	end

	if giftedUserId ~= nil then
		if type(giftedUserId) ~= "number" then
			return
		end
	end

	return self.Server:PurchaseIap(player, iapId, costType, giftedUserId)
end

function IapService.Client:PurchaseUGC(player, assetId)
	MarketplaceService:PromptPurchase(player, assetId, false)
end

return IapService