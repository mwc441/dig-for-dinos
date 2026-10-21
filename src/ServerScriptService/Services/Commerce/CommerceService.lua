local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local IapDef = require(ReplicatedConfigs:WaitForChild("IapDef"))

local CommerceService = {
	Name = "CommerceService",
	Client = {},
	_PlayerStatsService = nil,
	_AnalyticsService = nil,
	_IapService = nil
}

function CommerceService:KnitStart()
	self._PlayerStatsService = require(ServerScriptService.Services.PlayerStats.PlayerStatsService)
	self._AnalyticsService = require(ServerScriptService.Services.Analytics.AnalyticsService)
	self._IapService = require(ServerScriptService.Services.Iaps.IapService)
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
	if type(cash) ~= "number" or cash == math.huge then
		return false
	end
	if not (cash >= cost) then
		if cash < cost then
			self:_PromptCashPack(player, cost - cash)
		end
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

function CommerceService:_PromptCashPack(player, shortfall)
	local selectedIapId = Constants.CashPacks[#Constants.CashPacks]
	for _, iapId in ipairs(Constants.CashPacks) do
		local amount = IapDef.GetIapInfo(iapId).Rewards[PlayerStatsEnum.Cash]
		if amount >= shortfall then
			selectedIapId = iapId
			break
		end
	end

	task.defer(function()
		self._IapService:PurchaseIap(player, selectedIapId)
	end)
end

return CommerceService
