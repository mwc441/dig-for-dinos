local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local BoostsDef = require(ReplicatedConfigs:WaitForChild("BoostsDef"))
local BoostUtils = require(Utils:WaitForChild("BoostUtils"))
local Knit = require(External:WaitForChild("Knit"))
local Signal = require(External:WaitForChild("Signal"))
local TableUtils = require(External:WaitForChild("TableUtils"))

local SERVER_BOOSTS_KEY = "Boosts"
local SERVER_BOOSTS_DEFAULT_DATA = {
	Version = 1,
	Boosts = {
		-- {
		-- 	Id = "ServerLuckBoost",
		-- 	Level = 1,
		-- 	ExpiryTime = os.time() -- unix
		-- }
	}
}

local ServerBoostsService = {
	Name = "ServerBoostsService",
	Client = {},
	_BoostsService = nil,
	_TimeService = nil,
	_LifecycleService = nil,
	_ServerDataService = nil,
	_ServerBoosts = {},
	_BoostsLoaded = false,
	ServerBoostsUpdated = Signal.new(),
	BoostsLoaded = Signal.new()
}

function ServerBoostsService:KnitStart()
	self._BoostsService = require(ServerScriptService.Services.Boosts.BoostsService)
	self._TimeService = require(ServerScriptService.Services.Time.TimeService)
	self._LifecycleService = require(ServerScriptService.Services.LifeCycle.LifecycleService)
	self._ServerDataService = require(ServerScriptService.Services.Data.ServerDataService)

	self._TimeService.TimeUpdatedSignal:Connect(function()
		for boostId in pairs(self._ServerBoosts) do
			self:_CheckServerBoost(boostId)
		end

		self:_CheckExpiringBoostsInData()
	end)

	self:_LoadServerBoosts()
	self._BoostsLoaded = true
	self.BoostsLoaded:Fire()
end

function ServerBoostsService:WaitForBoostsLoaded()
	if not self._BoostsLoaded then
		self.BoostsLoaded:Wait()
	end
end

function ServerBoostsService:OnPlayerAdded(player)
	for boostId in pairs(self._ServerBoosts) do
		self:_UpdateBoostForPlayer(player, boostId)
	end
end

function ServerBoostsService:OnPlayerRemoving(player)
	for boostId in pairs(self._ServerBoosts) do
		self._BoostsService:RemoveBoostForPlayer(player, boostId)
	end
end

function ServerBoostsService:_UpdateBoostForAllPlayers(boostId)
	for _, player in pairs(self._LifecycleService:GetInitializedPlayers()) do
		self:_UpdateBoostForPlayer(player, boostId)
	end
end

function ServerBoostsService:_UpdateBoostForPlayer(player, boostId)
	local serverBoost = self._ServerBoosts[boostId]
	if not serverBoost then
		return
	end

	if serverBoost.ExpiryTime then
		if (os.time() >= serverBoost.ExpiryTime) then
			self:_CheckServerBoost(boostId)
			return
		end
	end

	local currentBoost = self._BoostsService:GetBoostOfIdForPlayer(player, boostId)
	if currentBoost then
		self._BoostsService:UpdateBoostOfId(player, boostId, {
			Level = serverBoost.Level,
			ExpiryTime = serverBoost.ExpiryTime
		})
	else
		self._BoostsService:AddBoostForPlayer(player, {
			Id = boostId,
			Level = serverBoost.Level,
			ExpiryTime = serverBoost.ExpiryTime
		})
	end
end

function ServerBoostsService:_CheckServerBoost(boostId)
	local serverBoost = self._ServerBoosts[boostId]
	if not serverBoost then
		return
	end

	if serverBoost.ExpiryTime then
		if os.time() >= serverBoost.ExpiryTime then
			self:RemoveServerBoost(boostId)
		end
	end
end

function ServerBoostsService:GetServerBoost(serverBoostId)
	return self._ServerBoosts[serverBoostId]
end

function ServerBoostsService:GetServerBoostsOfType(boostType)
	local boosts = {}
	for _, boost in pairs(self._ServerBoosts) do
		local boostInfo = BoostsDef.GetBoostInfo(boost.Id)
		if not boostInfo then continue end
		if boostInfo.Type ~= boostType then continue end

		table.insert(boosts, TableUtils.Copy(boost))
	end

	return boosts
end

function ServerBoostsService:GetAddingBoostAmountOfType(boostType)
	return BoostUtils.GetAddingBoostAmountOfType(self._ServerBoosts, boostType)
end

function ServerBoostsService:GetMultiplyingBoostAmountOfType(boostType)
	return BoostUtils.GetMultiplyingBoostAmountOfType(self._ServerBoosts, boostType)
end

function ServerBoostsService:CreateNewServerBoost(serverBoost)
	-- serverBoost in format:
	-- {
	-- 	Id = BoostEnumId,
	-- 	Level = 1,
	-- 	Time = 60 -- seconds (optional)
	-- }
	if not serverBoost.Id then
		return
	end

	if not serverBoost.Level then
		return
	end

	local currentBoost = self._ServerBoosts[serverBoost.Id]
	if not currentBoost then
		local boostTable = {
			Id = serverBoost.Id,
			Level = serverBoost.Level
		}

		if serverBoost.Time then
			boostTable.ExpiryTime = os.time() + serverBoost.Time
		end

		self._ServerBoosts[serverBoost.Id] = boostTable

		self:_UpdateBoostForAllPlayers(serverBoost.Id)
		self.ServerBoostsUpdated:Fire()
	else
		local boostTable = {
			Level = serverBoost.Level,
		}

		if serverBoost.Time then
			boostTable.ExpiryTime = (currentBoost.ExpiryTime or os.time()) + serverBoost.Time
		end

		self:UpdateServerBoost(serverBoost.Id, boostTable)
	end
end

function ServerBoostsService:UpdateServerBoost(serverBoostId, boostNewInfo)
	local serverBoost = self._ServerBoosts[serverBoostId]
	if not serverBoost then
		return
	end

	local changed = false
	for key, data in pairs(boostNewInfo) do
		if not (serverBoost[key] == data) then
			serverBoost[key] = data
			changed = true
		end
	end

	if not changed then
		return
	end

	self:_UpdateBoostForAllPlayers(serverBoostId)
	self.ServerBoostsUpdated:Fire()
end

function ServerBoostsService:RemoveServerBoost(serverBoostId)
	self._ServerBoosts[serverBoostId] = nil

	for _, player in pairs(self._LifecycleService:GetInitializedPlayers()) do
		self._BoostsService:RemoveBoostForPlayer(player, serverBoostId)
	end

	self.ServerBoostsUpdated:Fire()
end

-- This function handles any boosts that are saved to the servers
-- data profile. For example: a player buys a server boost on a private
-- server, that boost will save in datastores (in the servers profile)
-- and can be loaded on server start-up
function ServerBoostsService:_LoadServerBoosts()
	self:_CheckExpiringBoostsInData() -- Remove all expired boosts first

	local serverBoostData = self._ServerDataService:GetServerData(SERVER_BOOSTS_KEY, SERVER_BOOSTS_DEFAULT_DATA)
	for _, boost in pairs(serverBoostData.Boosts) do
		local serverBoost = {
			Id = boost.Id,
			Level = boost.Level
		}

		local expiryTime = boost.ExpiryTime
		if expiryTime then
			local timeLeft = expiryTime - os.time()
			serverBoost.Time = timeLeft
		end

		self:CreateNewServerBoost(serverBoost)
	end
end

function ServerBoostsService:_CheckExpiringBoostsInData()
	local serverBoostData = self._ServerDataService:GetServerData(SERVER_BOOSTS_KEY, SERVER_BOOSTS_DEFAULT_DATA)

	local boosts = {}
	for _, boost in pairs(serverBoostData.Boosts) do
		table.insert(boosts, boost)
	end

	local changed = false
	for _, boost in pairs(boosts) do
		local expiryTime = boost.ExpiryTime

		if expiryTime and (os.time() >= expiryTime) then
			local index = table.find(serverBoostData.Boosts, boost)
			if index then
				table.remove(serverBoostData.Boosts, index)
			end

			changed = true
		end
	end

	if changed then
		self._ServerDataService:SetServerData(SERVER_BOOSTS_KEY, serverBoostData)
	end
end

function ServerBoostsService:GetPersistentServerBoost(boostId)
	local serverBoostData = self._ServerDataService:GetServerData(SERVER_BOOSTS_KEY, SERVER_BOOSTS_DEFAULT_DATA)
	for _, boost in pairs(serverBoostData.Boosts) do
		if boost.Id == boostId then
			return boost
		end
	end
end

function ServerBoostsService:CreatePersistentServerBoost(serverBoost)
	-- serverBoost in format:
	-- {
	-- 	Id = BoostEnumId,
	-- 	Level = 1,
	-- 	Time = 60 -- seconds (optional)
	-- }
	self:CreateNewServerBoost(serverBoost)

	local serverBoostData = self._ServerDataService:GetServerData(SERVER_BOOSTS_KEY, SERVER_BOOSTS_DEFAULT_DATA)

	local boost = self:GetPersistentServerBoost(serverBoost.Id)
	if boost then
		local expiryTime = boost.ExpiryTime
		if serverBoost.Time then
			expiryTime = (expiryTime or os.time()) + serverBoost.Time
		end

		self:UpdatePersistentServerBoost(serverBoost.Id, {
			Level = serverBoost.Level,
			ExpiryTime = expiryTime
		})
	else
		local expiryTime
		if serverBoost.Time then
			expiryTime = os.time() + serverBoost.Time
		end

		table.insert(serverBoostData.Boosts, {
			Id = serverBoost.Id,
			Level = serverBoost.Level,
			ExpiryTime = expiryTime
		})

		self._ServerDataService:SetServerData(SERVER_BOOSTS_KEY, serverBoostData)
	end
end

function ServerBoostsService:UpdatePersistentServerBoost(boostId, newBoostData)
	self:UpdateServerBoost(boostId, newBoostData)

	local serverBoostData = self._ServerDataService:GetServerData(SERVER_BOOSTS_KEY, SERVER_BOOSTS_DEFAULT_DATA)

	local boost = self:GetPersistentServerBoost(boostId)
	if not boost then return end

	for key, data in pairs(newBoostData) do
		if key == "Id" then continue end

		boost[key] = data
	end

	self._ServerDataService:SetServerData(SERVER_BOOSTS_KEY, serverBoostData)
end

function ServerBoostsService:RemovePersistentServerBoost(boostId)
	self:RemoveServerBoost(boostId)

	local serverBoostData = self._ServerDataService:GetServerData(SERVER_BOOSTS_KEY, SERVER_BOOSTS_DEFAULT_DATA)
	for index, boost in pairs(serverBoostData.Boosts) do
		if boost.Id == boostId then
			table.remove(serverBoostData.Boosts, index)
			self._ServerDataService:SetServerData(SERVER_BOOSTS_KEY, serverBoostData)
			return
		end
	end
end

return ServerBoostsService
