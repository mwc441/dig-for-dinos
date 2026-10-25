local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local IapDef = require(ReplicatedConfigs:WaitForChild("IapDef"))
local UpgradesDef = require(ReplicatedConfigs:WaitForChild("UpgradesDef"))
local ItemDef = require(ReplicatedConfigs:WaitForChild("ItemDef"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))

local GLOBAL_MESSAGE_START = "<font color=\"#ff6169\">[🌎GLOBAL]</font> %s"
local SYSTEM_MESSAGE_START = "<font color=\"#0040ff\">[SYSTEM]</font> %s"

local RewardsService = {
	Name = "RewardsService",
	Client = {
		MessageAnnounced = Knit.CreateSignal(),
		SystemMessageAnnounced = Knit.CreateSignal(),
		GlobalMessageAnnounced = Knit.CreateSignal(),
		AnnouncementMade = Knit.CreateSignal(),
		RewardShown = Knit.CreateSignal()
	},
	_DebugService = nil,
	_PlayerStatsService = nil,
	_IapService = nil,
	_AnalyticsService = nil,
	_RebirthService = nil,
	_InventoryService = nil,
	_UpgradeService = nil,
	_OfflineRewardsService = nil,
	CrossServerMessageReceived = Signal.new()
}

local DEFAULT_ANNOUNCEMENT_COLOR = Color3.fromRGB(255, 255, 255)

local function getCrossServerAnnouncementColor(data)
	if type(data.Effect) == "string" then
		return data.Effect
	end
	return Color3.fromHex(data.Color or DEFAULT_ANNOUNCEMENT_COLOR:ToHex())
end

local function addCrossServerAnnouncementColor(data, color)
	data.Color = (typeof(color) == "Color3" and color or DEFAULT_ANNOUNCEMENT_COLOR):ToHex()
	if type(color) == "string" then
		data.Effect = color
	end
	return data
end

function RewardsService:KnitInit()
	local channels = TextChatService:WaitForChild("TextChannels")
	local globalTextChannel = Instance.new("TextChannel")
	globalTextChannel.Name = "Announcements"
	globalTextChannel.Parent = channels
	self._GlobalTextChannel = globalTextChannel
end

function RewardsService:KnitStart()
	self._DebugService = require(ServerScriptService.Services.Debug.DebugService)
	self._PlayerStatsService = require(ServerScriptService.Services.PlayerStats.PlayerStatsService)
	self._IapService = require(ServerScriptService.Services.Iaps.IapService)
	self._AnalyticsService = require(ServerScriptService.Services.Analytics.AnalyticsService)
	self._RebirthService = require(ServerScriptService.Services.Rebirths.RebirthService)
	self._InventoryService = require(ServerScriptService.Services.Inventory.InventoryService)
	self._UpgradeService = require(ServerScriptService.Services.Upgrades.UpgradeService)
	self._OfflineRewardsService = require(ServerScriptService.Services.OfflineRewards.OfflineRewardsService)

	MessagingService:SubscribeAsync("CrossServerMessage", function(message)
		local text = message.Data.Message
		local colorTable = message.Data.Color
		local messageType = message.Data.Type

		local color
		if colorTable then
			color = Color3.new(colorTable[1], colorTable[2], colorTable[3])
		end

		if messageType then
			self.CrossServerMessageReceived:Fire(text, color, messageType)
			return
		end

		if not text then
			return
		end

		self:FinalizeCrossServerMessage(text, color)
	end)

	MessagingService:SubscribeAsync("CrossServerAnnouncement", function(message)
		local data = message.Data
		local text = data.Message
		self:MakeAnnouncement(text, getCrossServerAnnouncementColor(data))
	end)

	MessagingService:SubscribeAsync("CrossServerReward", function(message)
		local data = message.Data
		local rewardType = data.RewardType
		local reward = data.Reward
		local announcement = data.Message

		if announcement then
			self:MakeAnnouncement(announcement, getCrossServerAnnouncementColor(data))
		end

		for _, player in pairs(Players:GetPlayers()) do
			task.spawn(function()
				self:RewardPlayer(player, rewardType, reward, true, {
					TransactionType = Enum.AnalyticsEconomyTransactionType.TimedReward.Name,
					Sku = "AdminGift"
				})
			end)
		end
	end)
end

function RewardsService:OnPlayerAdded(player)
	task.spawn(function()
		local textSource = self._GlobalTextChannel:AddUserAsync(player.UserId) :: TextSource
		if textSource then
			textSource.CanSend = false
		end
	end)
end

function RewardsService:GetRewardMessage(rewardType, reward)
end

function RewardsService:RewardPlayer(player, rewardType, reward, showReward, analyticsTable)
	analyticsTable = analyticsTable or {}

	if rewardType == PlayerStatsEnum.Cash then
		reward = math.round(reward)

		self._PlayerStatsService:AddToStatForPlayer(player, PlayerStatsEnum.Cash, reward)

		self._AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			PlayerStatsEnum.Cash,
			reward,
			self._PlayerStatsService:GetStatValueForPlayer(player, PlayerStatsEnum.Cash),
			analyticsTable.TransactionType or Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			analyticsTable.Sku,
			analyticsTable.CustomFields
		)
	elseif rewardType == PlayerStatsEnum.DigPower then
		reward = math.round(reward)

		self._PlayerStatsService:AddToStatForPlayer(player, PlayerStatsEnum.DigPower, reward)

		self._AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			PlayerStatsEnum.DigPower,
			reward,
			self._PlayerStatsService:GetStatValueForPlayer(player, PlayerStatsEnum.DigPower),
			analyticsTable.TransactionType or Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			analyticsTable.Sku,
			analyticsTable.CustomFields
		)
	elseif ItemDef.GetItemInfo(rewardType) then
		self._InventoryService:AddItemsToPlayersInventory(player, {
			[rewardType] = reward
		})
	elseif UpgradesDef.GetUpgradeInfo(rewardType) then
		self._UpgradeService:AddLevelsToUpgradeForPlayer(player, rewardType, reward)
	elseif IapDef.GetIapInfo(rewardType) then
		self._IapService:RewardPlayer(player, rewardType)
	elseif rewardType == "SkipRebirth" then
		self._RebirthService:GiveRebirthToPlayer(player)
	elseif rewardType == "OfflineRewards" then
		self._OfflineRewardsService:GiveOfflineRewards(player, reward)
	end

	if showReward then
		self:ShowRewardToPlayer(player, rewardType, reward)
	end
end

function RewardsService:AnnounceMessageToPlayer(player, message, color)
	self.Client.MessageAnnounced:Fire(player, message, color)
end

function RewardsService:AnnounceMessageToAllPlayers(message, color)
	self.Client.MessageAnnounced:FireAll(message, color)
end

function RewardsService:ShowRewardToPlayer(player, rewardType, reward)
	self.Client.RewardShown:Fire(player, rewardType, reward)
end

function RewardsService:MakeSystemMessage(message, color)
	message = string.format(SYSTEM_MESSAGE_START, message)
	self.Client.SystemMessageAnnounced:FireAll(message, color)
end

function RewardsService:FinalizeCrossServerMessage(message, color)
	local globalMessage = string.format(GLOBAL_MESSAGE_START, message)
	self.Client.GlobalMessageAnnounced:FireAll(globalMessage, color)
end

-- color can be a Color3 or an EasyVisuals preset name such as "Zebra" or "Rainbow".
function RewardsService:MakeAnnouncement(message, color)
	self.Client.AnnouncementMade:FireAll(message, color)
end

-- Send a global announcement (at the top of the screen)
function RewardsService:MakeCrossServerAnnouncement(message, color)
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync("CrossServerAnnouncement", addCrossServerAnnouncementColor({
				Message = message
			}, color))
		end)
	end)
end

-- Send a global system message (in the chat window)
function RewardsService:MakeCrossServerMessage(message, color, type)
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync("CrossServerMessage", {
				Message = message,
				Color = { color.R, color.G, color.B },
				Type = type
			})
		end)
	end)
end

function RewardsService:GiveCrossServerReward(rewardType, reward, message, color)
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync("CrossServerReward", addCrossServerAnnouncementColor({
				RewardType = rewardType,
				Reward = reward,
				Message = message
			}, color))
		end)
	end)
end

return RewardsService
