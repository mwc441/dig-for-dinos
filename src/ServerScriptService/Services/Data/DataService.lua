local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local External = ReplicatedStorage:WaitForChild("External")
local ServerConfigs = ServerScriptService:WaitForChild("ServerConfigs")
local ProfileStore = require(External:WaitForChild("ProfileStore"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))
local InitialPlayerData = require(ServerConfigs:WaitForChild("InitialPlayerData"))

local CURRENT_DATASTORE_NAME = "PlayerData"

local DataService = {
	Name = "DataService",
	Client = {
		ProfileUpdatedRemote = Knit.CreateSignal(),
		ProfileKeyUpdatedRemote = Knit.CreateSignal()
	},
	_DebugService = nil,
	_LifecycleService = nil,
	_IapService = nil,
	_Profiles = {},
	_ProfileStore = ProfileStore.New(CURRENT_DATASTORE_NAME, InitialPlayerData),
	_ProfileLoadingSignals = {},
	_PlayerProfileDebounces = {},
	_PlayerProfileQueueDebounces = {},
	PlayerProfileUpdatedSignal = Signal.new()
}

function DataService:KnitStart()
	self._DebugService = require(ServerScriptService.Services.Debug.DebugService)
	self._LifecycleService = require(ServerScriptService.Services.LifeCycle.LifecycleService)
	self._IapService = require(ServerScriptService.Services.Iaps.IapService)

	self._LifecycleService.PlayerHasFullyInitialized:Connect(function(player)
		self:_HandleMessages(player)
	end)

	if RunService:IsStudio() then
		self._ProfileStore = self._ProfileStore.Mock
	end
end

function DataService:OnPlayerAdded(player)
	self._PlayerProfileDebounces[player] = {}
	self._PlayerProfileQueueDebounces[player] = {}
	self:_CreatePlayerProfile(player)
end

function DataService:OnPlayerRemoving(player)
	self._PlayerProfileDebounces[player] = nil
	self._PlayerProfileQueueDebounces[player] = nil
	self:_DestroyPlayerProfile(player)
end

function DataService:_CreateProfileLoadingSignal(player)
	if not player:IsDescendantOf(Players) then
		return
	end

	if self._ProfileLoadingSignals[player] == nil then
		self._ProfileLoadingSignals[player] = Signal.new()
	end

	return self._ProfileLoadingSignals[player]
end

function DataService:_FireLoadingSignalForPlayer(player, profile)
	local loadingSignal = self._ProfileLoadingSignals[player]

	if loadingSignal then
		self._ProfileLoadingSignals[player] = false -- Needs to be false not nil!
		loadingSignal:Fire(profile)
		loadingSignal:Destroy()
	end
end

function DataService:WaitForLoadingProfile(player)
	local profile
	local loadingSignal = self._ProfileLoadingSignals[player]
	if loadingSignal then
		profile = loadingSignal:Wait()
	elseif loadingSignal == nil then
		loadingSignal = self:_CreateProfileLoadingSignal(player)
		if not loadingSignal then
			return
		end

		profile = loadingSignal:Wait()
	end

	return profile
end

function DataService:_CreatePlayerProfile(player)
	local profile = self._ProfileStore:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return (not Players:IsAncestorOf(player))
		end
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from ProfileTemplate (optional)

		local connection
		connection = profile.OnSessionEnd:Connect(function()
			connection:Disconnect()

			self._Profiles[player] = nil
			self:_FireLoadingSignalForPlayer(player)

			if player:IsDescendantOf(Players) then
				self._ProfileLoadingSignals[player] = false
				player:Kick()
			end
		end)

		if player:IsDescendantOf(Players) == true then
			self._Profiles[player] = profile
			self:_FireLoadingSignalForPlayer(player, profile)
			self.Client.ProfileUpdatedRemote:Fire(player, profile.Data)
			self.PlayerProfileUpdatedSignal:Fire(player)
		else
			-- Player left before the profile loaded:
			profile:EndSession()
		end
	else
		-- The profile couldn't be loaded possibly due to other
		-- Roblox servers trying to load this profile at the same time:
		self:_FireLoadingSignalForPlayer(player)

		if player:IsDescendantOf(Players) then
			self._ProfileLoadingSignals[player] = false
			player:Kick()
		end
	end
end

function DataService:ForceSave(player)
	local profile = self:GetPlayerProfile(player)
	if not profile then
		return
	end

	while profile:IsActive() == true do
		local last_saved_data = profile.LastSavedData

		profile:Save()

		if profile.LastSavedData == last_saved_data then
			profile.OnAfterSave:Wait()
		end

		if profile:IsActive() and (profile.LastSavedData ~= last_saved_data) then
			return true
		end

		if profile:IsActive() == true then
			task.wait(1)
		end
	end
end

function DataService:_DestroyPlayerProfile(player)
	local profile = self:GetPlayerProfile(player)
	if profile then
		profile:EndSession()
	end

	self:_FireLoadingSignalForPlayer(player)

	self._Profiles[player] = nil
	self._ProfileLoadingSignals[player] = nil
end

function DataService:GetPlayerProfile(player)
	return self._Profiles[player]
end

function DataService:GetPlayerData(player, key, defaultData)
	-- This function will Yield if the profile hasn't been loaded yet
	local profile = self:GetPlayerProfile(player)
	if not profile then
		if self._ProfileLoadingSignals[player] or self._ProfileLoadingSignals[player] == nil then
			profile = self:WaitForLoadingProfile(player) -- Yields
			if not profile then
				if type(defaultData) == "table" then
					return TableUtils.Copy(defaultData)
				end

				return defaultData
			end
		else
			-- The profile has been loaded in the past but its still not in the profiles table
			if type(defaultData) == "table" then
				return TableUtils.Copy(defaultData)
			end

			return defaultData
		end
	end

	local value = profile.Data[key]
	if not value then
		value = self:SetPlayerData(player, key, defaultData)
	end

	return value
end

function DataService:SetPlayerData(player, key, value, queueRemotes)
	-- This function will Yield if the profile hasn't been loaded yet
	if type(key) ~= "string" then
		error("Profile Data Key is not a string")
	end

	local profile = self:GetPlayerProfile(player)
	if not profile then
		if self._ProfileLoadingSignals[player] or self._ProfileLoadingSignals[player] == nil then
			profile = self:WaitForLoadingProfile(player) -- Yields
			if not profile then
				return
			end
		else
			-- The profile has been loaded in the past but its still not in the profiles table
			return
		end
	end

	if type(value) == "table" then
		value = TableUtils.Copy(value)
	end

	profile.Data[key] = value

	if queueRemotes then
		local debounceTable = self._PlayerProfileDebounces[player] or {}
		local queueDebounceTable = self._PlayerProfileQueueDebounces[player] or {}

		if not debounceTable[key] then
			debounceTable[key] = true

			if type(value) == "table" then
				self.Client.ProfileKeyUpdatedRemote:Fire(player, key, TableUtils.Copy(value))
			else
				self.Client.ProfileKeyUpdatedRemote:Fire(player, key, value)
			end

			task.spawn(function()
				task.wait()

				if not Players:IsAncestorOf(player) then
					return
				end

				local playerProfile = self:GetPlayerProfile(player)
				if not playerProfile then
					return
				end

				value = playerProfile.Data[key]

				if queueDebounceTable[key] then
					if type(value) == "table" then
						self.Client.ProfileKeyUpdatedRemote:Fire(player, key, TableUtils.Copy(value))
					else
						self.Client.ProfileKeyUpdatedRemote:Fire(player, key, value)
					end
				end

				debounceTable[key] = nil
				queueDebounceTable[key] = nil
			end)
		else
			queueDebounceTable[key] = true
		end
	else
		if type(value) == "table" then
			self.Client.ProfileKeyUpdatedRemote:Fire(player, key, TableUtils.Copy(value))
		else
			self.Client.ProfileKeyUpdatedRemote:Fire(player, key, value)
		end
	end

	self.PlayerProfileUpdatedSignal:Fire(player)

	return value
end

function DataService:_HandleMessages(player)
	local profile = self:GetPlayerProfile(player)
	if not profile then
		return
	end

	if not profile:IsActive() then
		return
	end

	profile:MessageHandler(function(message, processedFunc)
		if message.IapId then
			self._IapService:GiftIap(player.UserId, message.IapId, message.GiftingPlayerUserId)
		end

		processedFunc()
	end)
end

function DataService:PushNewActiveUpdate(userId, updateData)
	if type(userId) ~= "number" then
		return
	end

	local profileKey = "Player_" .. userId

	task.spawn(function()
		self._ProfileStore:MessageAsync(profileKey, updateData)
	end)
end

return DataService