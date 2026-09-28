local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local BoostsDef = require(ReplicatedConfigs:WaitForChild("BoostsDef"))
local DataKeys = require(ServerScriptService:WaitForChild("ServerConfigs"):WaitForChild("DataKeys"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local BoostUtils = require(Utils:WaitForChild("BoostUtils"))
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))

type Boost = BoostUtils.Boost
type Boosts = BoostUtils.Boosts

local BOOSTS_KEY = DataKeys.Boosts
local BOOSTS_DEFAULT_DATA = {
	Version = 1,
	Boosts = {} :: Boosts
}

local BoostsService = {
	Name = "BoostsService",
	Client = {},
	_DataService = nil,
	_TimeService = nil,
	_LifecycleService = nil,
	BoostsUpdated = Signal.new()
}

function BoostsService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
	self._TimeService = require(ServerScriptService.Services.Time.TimeService)
	self._LifecycleService = require(ServerScriptService.Services.LifeCycle.LifecycleService)

	self._TimeService.TimeUpdatedSignal:Connect(function()
		self:_CheckPlayersForExpiringBoosts()
	end)
end

function BoostsService:OnPlayerAdded(player)
	self:_InitializeBoostsForPlayer(player)
end

function BoostsService:_InitializeBoostsForPlayer(player)
	self:_CheckBoostsAndRemoveExpired(player)
end

function BoostsService:GetBoostDataForPlayer(player)
	return self._DataService:GetPlayerData(player, BOOSTS_KEY, BOOSTS_DEFAULT_DATA)
end

function BoostsService:SetBoostDataForPlayer(player)
	local playerBoostData = self:GetBoostDataForPlayer(player)
	self._DataService:SetPlayerData(player, BOOSTS_KEY, playerBoostData, true)

	self.BoostsUpdated:Fire(player)
end

function BoostsService:GetBoostsForPlayer(player) : Boosts
	local boostData = self._DataService:GetPlayerData(player, BOOSTS_KEY, BOOSTS_DEFAULT_DATA)
	return boostData.Boosts
end

function BoostsService:GetBoostsOfTypeForPlayer(player, boostType)
	local boostData = self:GetBoostsForPlayer(player)

	return BoostUtils.GetBoostsOfType(boostData, boostType)
end

function BoostsService:GetOneTimeBoostsOfTypeForPlayer(player, boostType)
	local boostData = self:GetBoostsForPlayer(player)

	return BoostUtils.GetOneTimeBoostsOfType(boostData, boostType)
end

function BoostsService:GetTotalBoostAmountForType(player, boostType)
	local addingBoostAmount = self:GetAddingBoostAmountOfType(player, boostType)
	local multiplyingBoostAmount = self:GetMultiplyingBoostAmountOfType(player, boostType)

	return (addingBoostAmount + 1) * multiplyingBoostAmount
end

function BoostsService:GetAddingBoostAmountOfType(player, boostType)
	local boostData = self:GetBoostsForPlayer(player)

	return BoostUtils.GetAddingBoostAmountOfType(boostData, boostType)
end

function BoostsService:GetMultiplyingBoostAmountOfType(player, boostType)
	local boostData = self:GetBoostsForPlayer(player)

	return BoostUtils.GetMultiplyingBoostAmountOfType(boostData, boostType)
end

function BoostsService:GetBoostOfIdForPlayer(player, boostId)
	local boostData = self:GetBoostsForPlayer(player)

	return BoostUtils.GetBoostOfId(boostData, boostId)
end

function BoostsService:AddBoostForPlayer(player, boost: Boost)
	local boostData = self:GetBoostsForPlayer(player)

	local success = BoostUtils.AddBoost(boostData, boost)
	if success then
		self:SetBoostDataForPlayer(player)
	end
end

function BoostsService:UpdateBoostOfId(player, boostId, newBoostData)
	local boostData = self:GetBoostsForPlayer(player)

	local changed = BoostUtils.UpdateBoost(boostData, boostId, newBoostData)
	if changed then
		self:SetBoostDataForPlayer(player)
	end
end

function BoostsService:RemoveBoostForPlayer(player, boostId)
	local boostData = self:GetBoostsForPlayer(player)

	local success = BoostUtils.RemoveBoost(boostData, boostId)
	if success then
		self:SetBoostDataForPlayer(player)
	end
end

function BoostsService:_CheckBoostsAndRemoveExpired(player)
	local boostDataCopy = TableUtils.Copy(self:GetBoostsForPlayer(player)) :: Boosts
	for _, boost in pairs(boostDataCopy) do
		if not boost.ExpiryTime then
			continue
		end

		if os.time() >= boost.ExpiryTime then
			self:RemoveBoostForPlayer(player, boost.Id)
		end
	end
end

function BoostsService:_CheckTimeLeftBoosts(player)
	local boosts = TableUtils.Copy(self:GetBoostsForPlayer(player)) :: Boosts
	for _, boost in pairs(boosts) do
		if not boost.TimeLeft then
			continue
		end

		local timeLeft = math.max((boost.TimeLeft - 1), 0)

		if timeLeft > 0 then
			self:UpdateBoostOfId(player, boost.Id, {
				TimeLeft = timeLeft
			})
		else
			self:RemoveBoostForPlayer(player, boost.Id)
		end
	end
end

function BoostsService:_CheckPlayersForExpiringBoosts()
	for _, initalizedPlayer in pairs(self._LifecycleService:GetInitializedPlayers()) do
		self:_CheckBoostsAndRemoveExpired(initalizedPlayer)
		self:_CheckTimeLeftBoosts(initalizedPlayer)
	end
end

return BoostsService