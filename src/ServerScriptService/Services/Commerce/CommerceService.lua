local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))

local CommerceService = {
	Name = "CommerceService",
	Client = {},
	_PlayerStatsService = nil,
	_AnalyticsService = nil
}

function CommerceService:KnitStart()
	self._PlayerStatsService = require(ServerScriptService.Services.PlayerStats.PlayerStatsService)
	self._AnalyticsService = require(ServerScriptService.Services.Analytics.AnalyticsService)
end

function CommerceService:Spend(player, costType : string, cost : number, analyticsTable)
	if costType == PlayerStatsEnum.Cash then
		return self:_SpendCashForPlayer(player, cost, analyticsTable)
	end

	return false
end

function CommerceService:_SpendCashForPlayer(player, cost : number, analyticsTable)
	if type(cost) ~= "number" or cost <= 0 or cost % 1 ~= 0 then
		return false
	end

	local cash = self._PlayerStatsService:GetStatValueForPlayer(player, PlayerStatsEnum.Cash)
	if type(cash) ~= "number" or not (cash >= cost) or cash == math.huge then
		return false
	end

	local endingBalance = cash - cost
	self._PlayerStatsService:SetStatValueForPlayer(player, PlayerStatsEnum.Cash, endingBalance)

	analyticsTable = analyticsTable or {}
	self._AnalyticsService:LogEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		PlayerStatsEnum.Cash,
		cost,
		endingBalance,
		analyticsTable.TransactionType or Enum.AnalyticsEconomyTransactionType.Shop.Name,
		analyticsTable.Sku,
		analyticsTable.CustomFields
	)

	return true
end

return CommerceService
