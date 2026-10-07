local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local ServerConfigs = ServerScriptService:WaitForChild("ServerConfigs")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local UpgradesDef = require(ReplicatedConfigs:WaitForChild("UpgradesDef"))
local DataKeys = require(ServerConfigs:WaitForChild("DataKeys"))
local Knit = require(External:WaitForChild("Knit"))

local UPGRADES_KEY = DataKeys.Upgrades
local UPGRADES_DEFAULT_DATA = {
	Version = 1,
	Upgrades = {}
}

local UpgradeService = {
	Name = "UpgradeService",
	Client = {},
	_DataService = nil,
	_CommerceService = nil,
	_BoostsService = nil
}

function UpgradeService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
	self._CommerceService = require(ServerScriptService.Services.Commerce.CommerceService)
	self._BoostsService = require(ServerScriptService.Services.Boosts.BoostsService)
end

function UpgradeService:OnPlayerAdded(player)
	self:_UpdateBoostsForPlayer(player)
end

function UpgradeService:OnPlayerRemoving(player)
	self:_RemoveBoostsForPlayer(player)
end

function UpgradeService:GetUpgradeLevelForPlayer(player, upgradeId)
	local upgradeData = self._DataService:GetPlayerData(player, UPGRADES_KEY, UPGRADES_DEFAULT_DATA)

	return upgradeData.Upgrades[upgradeId] or 0
end

function UpgradeService:SetUpgradeLevelForPlayer(player, upgradeId, level)
	local info = UpgradesDef.GetUpgradeInfo(upgradeId)
	if not info then return end

	local maxLevel = UpgradesDef.GetMaxLevelForUpgrade(upgradeId)

	level = math.min(level, maxLevel)

	local upgradeData = self._DataService:GetPlayerData(player, UPGRADES_KEY, UPGRADES_DEFAULT_DATA)

	upgradeData.Upgrades[upgradeId] = level

	self._DataService:SetPlayerData(player, UPGRADES_KEY, upgradeData, true)

	self:_UpdateBoostsForPlayer(player)
end

function UpgradeService:AddLevelsToUpgradeForPlayer(player, upgradeId, levels)
	local info = UpgradesDef.GetUpgradeInfo(upgradeId)
	if not info then return end

	local currentLevel = self:GetUpgradeLevelForPlayer(player, upgradeId)
	local maxLevel = UpgradesDef.GetMaxLevelForUpgrade(upgradeId)

	local newLevel = currentLevel + levels

	newLevel = math.min(newLevel, maxLevel)

	self:SetUpgradeLevelForPlayer(player, upgradeId, newLevel)
end

function UpgradeService:_BuyUpgradeForPlayer(player, upgradeId, level)
	local info = UpgradesDef.GetUpgradeInfo(upgradeId)
	if not info then return end

	local cost = UpgradesDef.GetCostOfUpgrade(upgradeId, level)
	if not cost then return end

	local costType = info.CostType
	if not costType then return end

	local maxLevel = UpgradesDef.GetMaxLevelForUpgrade(upgradeId)
	if level > maxLevel then return end

	local currentLevel = self:GetUpgradeLevelForPlayer(player, upgradeId)
	if currentLevel >= level then return end

	if level ~= (currentLevel + 1) then return end

	local success = self._CommerceService:Spend(player, costType, cost, {
		TransactionType = Enum.AnalyticsEconomyTransactionType.Shop.Name,
		Sku = "Upgrade - " .. upgradeId
	})
	if not success then return end

	self:SetUpgradeLevelForPlayer(player, upgradeId, level)

	return true
end

function UpgradeService:_UpdateBoostsForPlayer(player)
	local upgradeData = self._DataService:GetPlayerData(player, UPGRADES_KEY, UPGRADES_DEFAULT_DATA)

	for upgradeId, level in pairs(upgradeData.Upgrades) do
		local info = UpgradesDef.GetUpgradeInfo(upgradeId)
		if not info then continue end

		local boostId = info.Boost
		if not boostId then continue end

		local boost = self._BoostsService:GetBoostOfIdForPlayer(player, boostId)
		if not boost then
			self._BoostsService:AddBoostForPlayer(player, {
				Id = boostId,
				Level = level
			})
		else
			self._BoostsService:UpdateBoostOfId(player, boostId, {
				Level = level
			})
		end
	end
end

function UpgradeService:_RemoveBoostsForPlayer(player)
	for _, info in pairs(UpgradesDef.GetAllUpgrades()) do
		local boostId = info.Boost
		if not boostId then continue end

		self._BoostsService:RemoveBoostForPlayer(player, boostId)
	end
end

function UpgradeService.Client:BuyUpgrade(player, upgradeId, level)
	if type(upgradeId) ~= "string" then return end
	if type(level) ~= "number" then return end
	if math.floor(level) ~= level then return end
	if level <= 0 then return end

	return self.Server:_BuyUpgradeForPlayer(player, upgradeId, level)
end

return UpgradeService