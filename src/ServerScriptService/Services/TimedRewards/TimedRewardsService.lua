local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local TimersEnum = require(Enums:WaitForChild("Timers"))
local Knit = require(External:WaitForChild("Knit"))

local GROUP_REWARD_COOLDOWN = 24 * 60 * 60

local TimedRewardsService = {
	Name = "TimedRewardsService",
	Client = {},
	_TimerService = nil,
	_RewardsService = nil,
}

function TimedRewardsService:KnitStart()
	self._TimerService = require(ServerScriptService.Services.Timers.TimerService)
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)
end

function TimedRewardsService:_ClaimGroupRewardForPlayer(player : Player)
	local success, isInGroup = pcall(function()
		return player:IsInGroupAsync(Constants.GroupId)
	end)
	if (not success) or (not isInGroup) then return end

	local lastClaimed = self._TimerService:GetTimerForPlayer(player, TimersEnum.GroupReward) or 0
	if os.time() < (lastClaimed + GROUP_REWARD_COOLDOWN) then
		local timeLeft = (lastClaimed + GROUP_REWARD_COOLDOWN) - os.time()
		local message = string.format("❌ Claim again in %s", UtilFunctions.GetTimeStringFromTime(timeLeft))
		self._RewardsService:AnnounceMessageToPlayer(player, message, Color3.fromRGB(255, 0, 0))

		return
	end

	self._TimerService:SetTimerForPlayer(player, TimersEnum.GroupReward, os.time())

	for rewardType, reward in pairs(Constants.GroupReward) do
		self._RewardsService:RewardPlayer(player, rewardType, reward, true, {
			TransactionType = Enum.AnalyticsEconomyTransactionType.TimedReward.Name,
			Sku = "GroupReward"
		})
	end

	self._RewardsService:AnnounceMessageToPlayer(player, "⭐ Group Reward Claimed ⭐", Color3.fromRGB(254, 203, 35))

	return true
end

function TimedRewardsService.Client:ClaimGroupReward(player)
	return self.Server:_ClaimGroupRewardForPlayer(player)
end

return TimedRewardsService