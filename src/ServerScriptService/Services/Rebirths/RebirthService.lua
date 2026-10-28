local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local RebirthDef = require(ReplicatedConfigs:WaitForChild("RebirthDef"))
local IapDef = require(ReplicatedConfigs:WaitForChild("IapDef"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local Knit = require(External:WaitForChild("Knit"))

local RebirthService = {
	Name = "RebirthService",
	Client = {},
	_PlayerStatsService = nil,
	_UpgradeService = nil,
	_BoostsService = nil,
}

function RebirthService:KnitStart()
	self._PlayerStatsService = require(ServerScriptService.Services.PlayerStats.PlayerStatsService)
	self._BoostsService = require(ServerScriptService.Services.Boosts.BoostsService)
	self._UpgradeService = require(ServerScriptService.Services.Upgrades.UpgradeService)
end

function RebirthService:OnPlayerAdded(player)
	self:_UpdateBoostsForPlayer(player)
end

function RebirthService:OnPlayerRemoving(player)
	self:_RemoveBoostsForPlayer(player)
end

function RebirthService:GetRebirthsForPlayer(player)
	return self._PlayerStatsService:GetStatValueForPlayer(player, PlayerStatsEnum.Rebirths) or 0
end

function RebirthService:_RebirthForPlayer(player)
	local currentRebirth = self:GetRebirthsForPlayer(player)
	local nextRebirth = currentRebirth + 1

	local nextRebirthInfo = RebirthDef.GetRebirthInfo(nextRebirth)
	if not nextRebirthInfo then return end

	local cost = nextRebirthInfo.Cost
	if not cost then return end

	local playerCash = self._PlayerStatsService:GetStatValueForPlayer(player, PlayerStatsEnum.Cash)
	if playerCash < cost then return end

	self._PlayerStatsService:SetStatValueForPlayer(player, PlayerStatsEnum.Cash, 0)
	self._UpgradeService:SetUpgradeLevelForPlayer(player, "SpeedUpgrade", 0)

	task.spawn(function()
		pcall(function()
			player:LoadCharacter()
		end)
	end)

	self:GiveRebirthToPlayer(player)

	return true
end

function RebirthService:GiveRebirthToPlayer(player)
	local currentRebirth = self:GetRebirthsForPlayer(player)
	local maxRebirth = RebirthDef.GetMaxRebirth()
	if currentRebirth >= maxRebirth then return end

	self._PlayerStatsService:AddToStatForPlayer(player, PlayerStatsEnum.Rebirths, 1)
	self:_UpdateBoostsForPlayer(player)
	return true
end

function RebirthService:GiveSkippedRebirthToPlayer(player, purchasedLevel)
	local nextRebirth = self:GetRebirthsForPlayer(player) + 1
	local requiredIapId = RebirthDef.GetIapForRebirth(nextRebirth)
	if not requiredIapId then return end

	local requiredLevel = IapDef.GetIapInfo(requiredIapId).Rewards.SkipRebirth
	if type(purchasedLevel) ~= "number" or purchasedLevel < requiredLevel then return end

	return self:GiveRebirthToPlayer(player)
end

function RebirthService:_UpdateBoostsForPlayer(player)
	local currentRebirth = self:GetRebirthsForPlayer(player)
	if currentRebirth <= 0 then
		self:_RemoveBoostsForPlayer(player)
		return
	end

	for _, boostId in pairs(RebirthDef.Boosts) do
		local boost = self._BoostsService:GetBoostOfIdForPlayer(player, boostId)
		if not boost then
			self._BoostsService:AddBoostForPlayer(player, {
				Id = boostId,
				Level = currentRebirth
			})
		else
			self._BoostsService:UpdateBoostOfId(player, boostId, {
				Level = currentRebirth
			})
		end
	end
end

function RebirthService:_RemoveBoostsForPlayer(player)
	for _, boostId in pairs(RebirthDef.Boosts) do
		self._BoostsService:RemoveBoostForPlayer(player, boostId)
	end
end

function RebirthService.Client:Rebirth(player)
	return self.Server:_RebirthForPlayer(player)
end

return RebirthService
