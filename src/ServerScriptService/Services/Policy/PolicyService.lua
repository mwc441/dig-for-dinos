local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RobloxPolicyService = game:GetService("PolicyService")

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))

local PolicyService = {
	Name = "PolicyService",
	Client = {},
	_PlayerPolicyInfos = {}
}

function PolicyService:OnPlayerAdded(player)
	task.spawn(function()
		pcall(function()
			local info = RobloxPolicyService:GetPolicyInfoForPlayerAsync(player)

			if player:IsDescendantOf(Players) then
				self._PlayerPolicyInfos[player] = info
			end
		end)
	end)
end

function PolicyService:OnPlayerRemoving(player)
	self._PlayerPolicyInfos[player] = nil
end

function PolicyService:CanPlayerTrade(player)
	local info = self._PlayerPolicyInfos[player]
	if not info then
		return
	end

	return info.IsPaidItemTradingAllowed
end

function PolicyService:CanPlayerBuyRandomPremium(player)
	local info = self._PlayerPolicyInfos[player]
	if not info then
		return
	end

	return (not info.ArePaidRandomItemsRestricted)
end

function PolicyService:IsPremiumCurrency(currencyType)
	return false
end

return PolicyService