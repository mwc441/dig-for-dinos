local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local LimitedDef = require(ReplicatedConfigs:WaitForChild("LimitedDef"))
local Knit = require(External:WaitForChild("Knit"))
local Signal = require(External:WaitForChild("Signal"))
local TableUtils = require(External:WaitForChild("TableUtils"))

local LimitedController = {
	Name = "LimitedController",
	_LimitedService = nil,
	_LimitedCache = {},
	LimitedCacheUpdatedSignal = Signal.new()
}

function LimitedController:KnitStart()
	self._LimitedService = Knit.GetService("LimitedService")

	self._LimitedService.LimitedCacheProperty:Observe(function(cache)
		if TableUtils.Equals(cache, self._LimitedCache) then
			return
		end

		self._LimitedCache = TableUtils.Copy(cache)
		self.LimitedCacheUpdatedSignal:Fire()
	end)
end

function LimitedController:GetLimitedCache()
	return TableUtils.Copy(self._LimitedCache)
end

function LimitedController:GetLimitedSoldCount(limitedId)
	return self._LimitedCache[limitedId]
end

function LimitedController:GetLimitedLimit(limitedId)
	local limitedInfo = LimitedDef.GetLimitedInfo(limitedId)
	return limitedInfo and limitedInfo.Limit
end

function LimitedController:GetLimitedRemainingCount(limitedId)
	local limit = self:GetLimitedLimit(limitedId)
	local soldCount = self:GetLimitedSoldCount(limitedId)
	if not limit or soldCount == nil then
		return
	end

	return math.max(0, limit - soldCount)
end

function LimitedController:IsLimitedAvailable(limitedId)
	local remainingCount = self:GetLimitedRemainingCount(limitedId)
	if not remainingCount or remainingCount <= 0 then
		return false
	end

	local limitedInfo = LimitedDef.GetLimitedInfo(limitedId)
	return not limitedInfo.ExpiryTime or Workspace:GetServerTimeNow() < limitedInfo.ExpiryTime
end

return LimitedController
