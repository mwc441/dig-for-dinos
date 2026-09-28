local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local IapDef = require(ReplicatedConfigs:WaitForChild("IapDef"))
local Knit = require(External:WaitForChild("Knit"))

local CommerceService = {
	Name = "CommerceService",
	Client = {},
	_PlayerStatsService = nil,
	_IapService = nil,
	_AnalyticsService = nil,
}

function CommerceService:KnitStart()
	self._PlayerStatsService = require(ServerScriptService.Services.PlayerStats.PlayerStatsService)
	self._IapService = require(ServerScriptService.Services.Iaps.IapService)
	self._AnalyticsService = require(ServerScriptService.Services.Analytics.AnalyticsService)
end

function CommerceService:Spend(player, costType : string, cost : number, analyticsTable)
	local success
	if costType == PlayerStatsEnum.Bricks then
		--success = self:_SpendBricksForPlayer(player, cost, analyticsTable)
	end

	return success
end

return CommerceService
