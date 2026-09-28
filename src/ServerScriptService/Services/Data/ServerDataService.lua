local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))
local ProfileStore = require(External:WaitForChild("ProfileStore"))
local Signal = require(External:WaitForChild("Signal"))
local TableUtils = require(External:WaitForChild("TableUtils"))

local PRIVATE_SERVER_ID = game.PrivateServerId
local DATA_STORE_NAME = "ServerData"

local ServerDataService = {
	Name = "ServerDataService",
	Client = {
		ServerData = Knit.CreateProperty({})
	},
	_ProfileStore = ProfileStore.New(DATA_STORE_NAME, {}),
	LoadingSignal = Signal.new()
}

function ServerDataService:KnitStart()
	-- Servers only have a persistent ID if they are private servers
	-- therefore, if its a public server, just throw the data out
	-- when the server ends (same as a mock data store)
	if PRIVATE_SERVER_ID == "" then
		self._ProfileStore = self._ProfileStore.Mock
	end

	task.spawn(function()
		self:_LoadServerData()
	end)
end

function ServerDataService:_LoadServerData()
	local key = (PRIVATE_SERVER_ID ~= "") and PRIVATE_SERVER_ID or HttpService:GenerateGUID(false)

	local profile = self._ProfileStore:StartSessionAsync(key)
	if profile ~= nil then
		self._Profile = profile

		self.Client.ServerData:Set(self._Profile.Data)
	end

	self._AttemptedLoading = true
	self.LoadingSignal:Fire(self._Profile)
end

function ServerDataService:GetServerData(key, defaultData)
	local profile = self._Profile
	if not profile then
		if not self._AttemptedLoading then
			profile = self.LoadingSignal:Wait()
			if not profile then
				if type(defaultData) == "table" then
					return TableUtils.Copy(defaultData)
				else
					return defaultData
				end
			end
		else
			if type(defaultData) == "table" then
				return TableUtils.Copy(defaultData)
			else
				return defaultData
			end
		end
	end

	local data = profile.Data[key]
	if data == nil then
		return self:SetServerData(key, defaultData)
	end

	return data
end

function ServerDataService:SetServerData(key, value)
	local profile = self._Profile
	if not profile then
		if not self._AttemptedLoading then
			profile = self.LoadingSignal:Wait()
			if not profile then
				return
			end
		else
			return
		end
	end

	local data
	if type(value) == "table" then
		data = TableUtils.Copy(value)
	else
		data = value
	end

	profile.Data[key] = data

	self.Client.ServerData:Set(profile.Data)

	return data
end

return ServerDataService