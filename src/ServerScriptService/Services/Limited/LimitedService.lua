local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local LimitedDef = require(ReplicatedConfigs:WaitForChild("LimitedDef"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local Knit = require(External:WaitForChild("Knit"))

local LIMITED_RESTRICTED = "Limited is either busy, expired, or sold out! Try again in a few seconds!"
local LimitedMemoryStoreMap = MemoryStoreService:GetSortedMap("Limiteds")
local LimitedDataStore = DataStoreService:GetDataStore("Limiteds")

local LimitedService = {
	Name = "LimitedService",
	Client = {
		LimitedCacheProperty = Knit.CreateProperty({})
	},
	_RewardsService = nil,
	_DebugService = nil,
	_LimitedCache = {},
	_LimitedBusy = {}
}

function LimitedService:KnitStart()
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)
	self._DebugService = require(ServerScriptService.Services.Debug.DebugService)

	-- for limitedId in pairs(LimitedDef.GetAllLimiteds()) do
	-- 	task.spawn(function()
	-- 		if RunService:IsStudio() and self._DebugService:IsDevPlace() then
	-- 			pcall(function()
	-- 				LimitedMemoryStoreMap:RemoveAsync(limitedId)
	-- 				LimitedDataStore:RemoveAsync(limitedId)
	-- 			end)
	-- 		end

	-- 		self:_ForceUpdateLimited(limitedId)
	-- 	end)
	-- end

	-- MessagingService:SubscribeAsync("LimitedUpdated", function(message)
	-- 	local limitedId = message.Data.Limited
	-- 	local jobId = message.Data.JobId
	-- 	if jobId == game.JobId then
	-- 		return
	-- 	end

	-- 	self:_ForceUpdateLimited(limitedId)
	-- end)
end

function LimitedService:IsLimitedAvailable(limitedId, announce, player)
	local available = true

	local limitedInfo = LimitedDef.GetLimitedInfo(limitedId)
	if not limitedInfo then
		return false
	end

	if limitedInfo.ExpiryTime then
		if os.time() >= limitedInfo.ExpiryTime then
			available = false
		end
	end

	if self._LimitedBusy[limitedId] then
		-- if the limited is being updated/recached by the server
		-- return false
		available = false
	end

	local currentAmount = self._LimitedCache[limitedId]
	if not currentAmount then
		-- we havent cached it yet, return false for now
		available = false
	end

	local limitedLeft = ((currentAmount or 0) < limitedInfo.Limit) and available

	if (not limitedLeft) and (announce) and (player) then
		self._RewardsService:AnnounceMessageToPlayer(player, LIMITED_RESTRICTED)
	end

	return limitedLeft
end

function LimitedService:IncrementLimited(limitedId)
	-- Async function to increment the limited (for example
	-- when a player buys a limited)
	local limitedInfo = LimitedDef.GetLimitedInfo(limitedId)
	if not limitedInfo then
		return
	end

	self._LimitedBusy[limitedId] = true

	-- UPDATE DATA STORE
	local success = false
	local tries = 0
	local value
	while (not success) and (tries <= 5) do
		tries += 1

		success, value = pcall(function()
			return LimitedDataStore:IncrementAsync(limitedId, 1)
		end)

		if success then
			break
		end

		task.wait(1)
	end

	if not success then
		self._LimitedBusy[limitedId] = nil
		return
	end

	-- UPDATE CACHE
	self:_SetLimitedCache(limitedId, value)

	-- UPDATE MEMORY STORE
	success = false
	tries = 0
	while (not success) and (tries <= 5) do
		tries += 1

		success, value = pcall(function()
			return LimitedMemoryStoreMap:SetAsync(limitedId, value, 3_888_000)
		end)

		if success then
			break
		end

		task.wait(1)
	end

	self._LimitedBusy[limitedId] = nil

	pcall(function()
		MessagingService:PublishAsync("LimitedUpdated", {
			Limited = limitedId,
			JobId = game.JobId
		})
	end)
end

function LimitedService:_SetLimitedCache(limitedId, value)
	self._LimitedCache[limitedId] = value

	self.Client.LimitedCacheProperty:Set(TableUtils.Copy(self._LimitedCache))
end

function LimitedService:_ForceUpdateLimited(limitedId)
	-- Async function to check a limited from the datastore/memorystore
	-- and then caches the value in _LimitedCache
	local limitedInfo = LimitedDef.GetLimitedInfo(limitedId)
	if not limitedInfo then
		return
	end

	if limitedInfo.ExpiryTime then
		if os.time() >= limitedInfo.ExpiryTime then
			return
		end
	end

	self._LimitedBusy[limitedId] = true

	-- First check the memorystore (fast)
	local success, value = pcall(function()
		return LimitedMemoryStoreMap:GetAsync(limitedId)
	end)

	if success and value then
		self:_SetLimitedCache(limitedId, value)

		self._LimitedBusy[limitedId] = nil

		return
	end

	-- If the value is not in the memory store, check datastore
	success, value = pcall(function()
		return LimitedDataStore:GetAsync(limitedId)
	end)

	self._LimitedBusy[limitedId] = nil

	if not success then
		task.spawn(function()
			self:_ForceUpdateLimited(limitedId)
		end)

		return
	end

	self:_SetLimitedCache(limitedId, value or 0)
end

return LimitedService