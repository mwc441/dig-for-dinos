local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local Knit = require(External:WaitForChild("Knit"))

local MAX_OFFLINE_TIME = 8 * 60 * 60
local OFFLINE_EARNINGS_MULTIPLIER = 0.25

local OfflineRewardsService = {
	Name = "OfflineRewardsService",
	Client = {
		EarningsUpdated = Knit.CreateSignal()
	},
	_TimerService = nil,
	_PlayerStatsService = nil,
	_DinosaurService = nil,
	_PlotService = nil,
	_RewardsService = nil,
	_Revisions = {}
}

function OfflineRewardsService:KnitStart()
	self._TimerService = require(ServerScriptService.Services.Timers.TimerService)
	self._PlayerStatsService = require(ServerScriptService.Services.PlayerStats.PlayerStatsService)
	self._DinosaurService = require(ServerScriptService.Services.Dinosaurs.DinosaurService)
	self._PlotService = require(ServerScriptService.Services.Plots.PlotService)
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)

	self._TimerService.PlayerLoggedBackIn:Connect(function(player, offlineTime)
		self:_AddOfflineEarnings(player, offlineTime)
	end)
end

function OfflineRewardsService:OnPlayerAdded(player)
	self._Revisions[player] = 0
end

function OfflineRewardsService:OnPlayerRemoving(player)
	self._Revisions[player] = nil
end

function OfflineRewardsService:_GetPendingState(player)
	return {
		Amount = self._PlayerStatsService:GetStatValueForPlayer(player, PlayerStatsEnum.OfflineEarnings) or 0,
		Revision = self._Revisions[player] or 0
	}
end

function OfflineRewardsService:_PublishPendingState(player)
	self._Revisions[player] = (self._Revisions[player] or 0) + 1
	local state = self:_GetPendingState(player)
	self.Client.EarningsUpdated:Fire(player, state)
	return state
end

function OfflineRewardsService:_AddOfflineEarnings(player, offlineTime)
	self:GiveOfflineRewards(player, math.clamp(offlineTime, 0, MAX_OFFLINE_TIME))
end

function OfflineRewardsService:GiveOfflineRewards(player, seconds)
	if type(seconds) ~= "number" or seconds <= 0 or seconds == math.huge or seconds ~= seconds then return end

	local incomePerSecond = self._DinosaurService:GetIncomePerSecondForPlayer(player)
	local amount = math.round(incomePerSecond * seconds * OFFLINE_EARNINGS_MULTIPLIER)
	if amount <= 0 then return end

	self._PlayerStatsService:AddToStatForPlayer(player, PlayerStatsEnum.OfflineEarnings, amount)
	self:_PublishPendingState(player)
end

function OfflineRewardsService:ClaimOfflineEarnings(player)
	local amount = self._PlayerStatsService:GetStatValueForPlayer(player, PlayerStatsEnum.OfflineEarnings) or 0
	if amount <= 0 then
		local state = self:_GetPendingState(player)
		state.Success = false
		return state
	end

	self._PlayerStatsService:SetStatValueForPlayer(player, PlayerStatsEnum.OfflineEarnings, 0)
	self._RewardsService:RewardPlayer(player, PlayerStatsEnum.Cash, amount, false, {
		TransactionType = Enum.AnalyticsEconomyTransactionType.TimedReward.Name,
		Sku = "OfflineEarnings"
	})

	local state = self:_PublishPendingState(player)
	state.Success = true
	return state
end

function OfflineRewardsService.Client:GetPendingEarnings(player)
	return self.Server:_GetPendingState(player)
end

function OfflineRewardsService.Client:ClaimOfflineEarnings(player)
	return self.Server:ClaimOfflineEarnings(player)
end

return OfflineRewardsService
