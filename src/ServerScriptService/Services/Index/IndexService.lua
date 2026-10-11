local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local ServerConfigs = ServerScriptService:WaitForChild("ServerConfigs")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local IndexDef = require(ReplicatedConfigs:WaitForChild("IndexDef"))
local DataKeys = require(ServerConfigs:WaitForChild("DataKeys"))
local Knit = require(External:WaitForChild("Knit"))

type UnlockedItems = { string }
type Unlocked = { [string] : UnlockedItems }
type Claimed = { [string] : number }
type IndexData = {
	Version : number,
	Unlocked : Unlocked,
	Claimed : Claimed
}

local INDEX_KEY = DataKeys.Index
local INDEX_DEFAULT_DATA = {
	Version = 1,
	Unlocked = {},
	Claimed = {}
} :: IndexData

local IndexService = {
	Name = "IndexService",
	Client = {},
	_DataService = nil,
	_RewardsService = nil,
	_BoostsService = nil,
}

function IndexService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)
	self._BoostsService = require(ServerScriptService.Services.Boosts.BoostsService)
end

function IndexService:OnPlayerAdded(player)
	self:_UpdateBoostsForPlayer(player)
end

function IndexService:OnPlayerRemoving(player)
	self:_RemoveBoostsForPlayer(player)
end

function IndexService:UnlockForPlayer(player, category : string, itemId : string)
	local playerIndexData = self._DataService:GetPlayerData(player, INDEX_KEY, INDEX_DEFAULT_DATA) :: IndexData
	local categoryItemsUnlocked = playerIndexData.Unlocked[category]
	if not categoryItemsUnlocked then
		playerIndexData.Unlocked[category] = {}
		categoryItemsUnlocked = playerIndexData.Unlocked[category]
	end

	if table.find(categoryItemsUnlocked, itemId) then return end

	table.insert(categoryItemsUnlocked, itemId)

	self._DataService:SetPlayerData(player, INDEX_KEY, playerIndexData, true)
end

function IndexService:_ClaimIndexRewardForPlayer(player, category)
	local indexInfo = IndexDef.GetIndexInfo(category)
	if not indexInfo then return end

	local playerIndexData = self._DataService:GetPlayerData(player, INDEX_KEY, INDEX_DEFAULT_DATA) :: IndexData
	local unlockedItems = playerIndexData.Unlocked[category] or {} :: UnlockedItems
	local claimed = playerIndexData.Claimed
	local currentLevel = claimed[category] or 0
	local nextLevel = currentLevel + 1
	local totalUnlocked = #unlockedItems

	local nextLevelInfo = IndexDef.GetLevelInfoForIndex(category, nextLevel)
	if not nextLevelInfo then return end
	if totalUnlocked < nextLevelInfo.Required then return end

	claimed[category] = nextLevel

	self._DataService:SetPlayerData(player, INDEX_KEY, playerIndexData)

	for rewardType, reward in pairs(nextLevelInfo.Rewards or {}) do
		self._RewardsService:RewardPlayer(player, rewardType, reward, true, {
			TransactionType = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			Sku = "IndexRewards"
		})
	end

	self:_UpdateBoostsForPlayer(player)

	return true
end

function IndexService:_UpdateBoostsForPlayer(player)
	local playerIndexData = self._DataService:GetPlayerData(player, INDEX_KEY, INDEX_DEFAULT_DATA) :: IndexData
	local claimed = playerIndexData.Claimed

	local boostLevels = {}
	for category, level in pairs(claimed) do
		local indexInfo = IndexDef.GetIndexInfo(category)
		if not indexInfo then continue end

		local boostId = indexInfo.Boost
		if not boostId then continue end

		boostLevels[boostId] = (boostLevels[boostId] or 0) + level
	end

	for boostId, level in pairs(boostLevels) do
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

function IndexService:_RemoveBoostsForPlayer(player)
	for _, info in pairs(IndexDef.GetAllIndexes()) do
		if not info.Boost then continue end

		self._BoostsService:RemoveBoostForPlayer(player, info.Boost)
	end
end

function IndexService.Client:Claim(player, category)
	if type(category) ~= "string" then return end

	return self.Server:_ClaimIndexRewardForPlayer(player, category)
end

return IndexService