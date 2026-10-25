local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Knit = require(External:WaitForChild("Knit"))
local WeatherDef = require(ReplicatedConfigs:WaitForChild("WeatherDef"))

local GLOBAL_WEATHER_MAP = MemoryStoreService:GetSortedMap("GlobalWeather")
local GLOBAL_WEATHER_KEY = "Current"
local GLOBAL_WEATHER_TOPIC = "GlobalWeatherChanged"
local MAX_GLOBAL_WEATHER_DURATION = 24 * 60 * 60

local WeatherService = {
	Name = "WeatherService",
	Client = {
		WeatherChanged = Knit.CreateSignal()
	},
	_ServerBoostsService = nil,
	_RewardsService = nil,
	_CurrentWeather = nil,
	_ForcedWeather = nil,
	_GlobalWeather = nil,
	_LastGlobalWeatherIssuedAt = 0,
	_Revision = 0,
	_ActiveBoostIds = {}
}

function WeatherService:KnitStart()
	self._ServerBoostsService = require(ServerScriptService.Services.Boosts.ServerBoostsService)
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)

	task.defer(function()
		local subscribed, subscribeError = pcall(function()
			MessagingService:SubscribeAsync(GLOBAL_WEATHER_TOPIC, function(message)
				self:_ApplyGlobalWeather(message.Data)
			end)
		end)
		if not subscribed then
			warn("[WeatherService] Could not subscribe to global weather: " .. tostring(subscribeError))
		end

		while true do
			self:_SyncGlobalWeather()
			local now = DateTime.now().UnixTimestampMillis / 1000
			self:_UpdateWeather(math.floor(now))

			local nextTransition = WeatherDef.GetWeatherAtTime(now).EndsAt
			task.wait(math.max(math.min(nextTransition - now, 60), 1))
		end
	end)
end

function WeatherService:GetCurrentWeather()
	local now = os.time()
	self:_UpdateWeather(now)
	return self._CurrentWeather
end

function WeatherService:_ApplyGlobalWeather(data)
	if type(data) ~= "table" or not WeatherDef.GetWeatherInfo(data.Id)
		or type(data.StartsAt) ~= "number" or type(data.EndsAt) ~= "number"
		or type(data.IssuedAt) ~= "number" or data.EndsAt <= os.time() then
		return false
	end

	if data.IssuedAt < self._LastGlobalWeatherIssuedAt then return false end
	local current = self._GlobalWeather
	if current and current.Id == data.Id and current.StartsAt == data.StartsAt
		and current.EndsAt == data.EndsAt and current.IssuedAt == data.IssuedAt then
		return true
	end

	local globalWeather = {
		Id = data.Id,
		StartsAt = data.StartsAt,
		EndsAt = data.EndsAt,
		IssuedAt = data.IssuedAt
	}
	self._LastGlobalWeatherIssuedAt = data.IssuedAt
	self._GlobalWeather = globalWeather
	self:_UpdateWeather(os.time())

	task.delay(math.max(globalWeather.EndsAt - DateTime.now().UnixTimestampMillis / 1000, 0), function()
		if self._GlobalWeather == globalWeather then
			self:_UpdateWeather(os.time())
		end
	end)

	return true
end

function WeatherService:_SyncGlobalWeather()
	local success, data = pcall(function()
		return GLOBAL_WEATHER_MAP:GetAsync(GLOBAL_WEATHER_KEY)
	end)
	if not success then
		warn("[WeatherService] Could not read global weather: " .. tostring(data))
		return false
	end

	if data then
		self:_ApplyGlobalWeather(data)
	end
	return true
end

-- Server-only. Omit duration to use the scheduled event length.
function WeatherService:ForceWeather(weatherId, duration)
	if not WeatherDef.GetWeatherInfo(weatherId) then
		return false
	end

	duration = duration or WeatherDef.DurationSeconds
	if type(duration) ~= "number" or duration ~= duration or duration <= 0 or duration == math.huge then
		return false
	end

	duration = math.ceil(duration)
	local now = os.time()
	local forcedWeather = {
		Id = weatherId,
		StartsAt = now,
		EndsAt = now + duration
	}

	self._ForcedWeather = forcedWeather
	self:_UpdateWeather(now, true)

	task.delay(math.max(forcedWeather.EndsAt - DateTime.now().UnixTimestampMillis / 1000, 0), function()
		if self._ForcedWeather == forcedWeather then
			self:_UpdateWeather(os.time())
		end
	end)

	return true
end

-- Server-only. Starts the same weather in running and newly started servers.
function WeatherService:ForceGlobalWeather(weatherId, duration)
	if not WeatherDef.GetWeatherInfo(weatherId) then
		return false, "Unknown weather."
	end

	duration = duration or WeatherDef.DurationSeconds
	if type(duration) ~= "number" or duration ~= duration or duration < 1
		or duration == math.huge or duration > MAX_GLOBAL_WEATHER_DURATION then
		return false, "Duration must be between 1 second and 24 hours."
	end

	duration = math.ceil(duration)
	local issuedAt = DateTime.now().UnixTimestampMillis
	local startsAt = math.floor(issuedAt / 1000)
	local globalWeather = {
		Id = weatherId,
		StartsAt = startsAt,
		EndsAt = startsAt + duration,
		IssuedAt = issuedAt
	}

	local saved, saveError = pcall(function()
		GLOBAL_WEATHER_MAP:SetAsync(GLOBAL_WEATHER_KEY, globalWeather, duration + 60)
	end)
	if not saved then
		warn("[WeatherService] Could not save global weather: " .. tostring(saveError))
		return false, "Could not start global weather."
	end

	self:_ApplyGlobalWeather(globalWeather)

	local published, publishError = pcall(function()
		MessagingService:PublishAsync(GLOBAL_WEATHER_TOPIC, globalWeather)
	end)
	if not published then
		warn("[WeatherService] Could not broadcast global weather: " .. tostring(publishError))
	end

	return true
end

function WeatherService:_GetWeatherAtTime(now)
	local globalWeather = self._GlobalWeather
	if globalWeather and now < globalWeather.EndsAt then
		return {
			Id = globalWeather.Id,
			StartsAt = globalWeather.StartsAt,
			EndsAt = globalWeather.EndsAt,
			Forced = true,
			Global = true
		}
	end

	local forcedWeather = self._ForcedWeather
	if forcedWeather and now < forcedWeather.EndsAt then
		return {
			Id = forcedWeather.Id,
			StartsAt = forcedWeather.StartsAt,
			EndsAt = forcedWeather.EndsAt,
			Forced = true
		}
	end

	return WeatherDef.GetWeatherAtTime(now)
end

function WeatherService:_UpdateWeather(now, forceRefresh)
	if self._GlobalWeather and now >= self._GlobalWeather.EndsAt then
		self._GlobalWeather = nil
	end

	if self._ForcedWeather and now >= self._ForcedWeather.EndsAt then
		self._ForcedWeather = nil
	end

	local weather = self:_GetWeatherAtTime(now)
	local currentWeather = self._CurrentWeather

	if currentWeather and not forceRefresh
		and currentWeather.Id == weather.Id
		and currentWeather.StartsAt == weather.StartsAt
		and currentWeather.EndsAt == weather.EndsAt
		and currentWeather.Forced == weather.Forced
		and currentWeather.Global == weather.Global then
		return
	end

	self._Revision += 1
	weather.Revision = self._Revision
	self._CurrentWeather = weather
	self:_ApplyBoosts(weather)
	self.Client.WeatherChanged:FireAll(weather)

	if weather.Id then
		local weatherInfo = WeatherDef.GetWeatherInfo(weather.Id)
		local announcement = weatherInfo.Announcement
		if announcement then
			self._RewardsService:MakeAnnouncement(announcement, weatherInfo.AnnouncementColor)
		end
	end
end

function WeatherService:_ApplyBoosts(weather)
	local nextBoosts = {}
	if weather.Id then
		for _, boost in ipairs(WeatherDef.GetWeatherInfo(weather.Id).Boosts) do
			if boost.Id and boost.Level then
				nextBoosts[boost.Id] = boost
			else
				warn(`Weather {weather.Id} has a boost without an Id or Level`)
			end
		end
	end

	for boostId in pairs(self._ActiveBoostIds) do
		if not nextBoosts[boostId] then
			self._ServerBoostsService:RemoveServerBoost(boostId)
		end
	end

	local activeBoostIds = {}
	for boostId, boost in pairs(nextBoosts) do
		local currentBoost = self._ServerBoostsService:GetServerBoost(boostId)
		if self._ActiveBoostIds[boostId] or not currentBoost then
			if currentBoost then
				self._ServerBoostsService:UpdateServerBoost(boostId, {
					Level = boost.Level,
					ExpiryTime = weather.EndsAt
				})
			else
				self._ServerBoostsService:CreateNewServerBoost({
					Id = boostId,
					Level = boost.Level,
					Time = weather.EndsAt - os.time()
				})
				self._ServerBoostsService:UpdateServerBoost(boostId, {
					ExpiryTime = weather.EndsAt
				})
			end
			activeBoostIds[boostId] = true
		else
			warn(`Weather boost {boostId} already exists as a server boost`)
		end
	end

	self._ActiveBoostIds = activeBoostIds
end

function WeatherService.Client:GetCurrentWeather(_player)
	return self.Server:GetCurrentWeather()
end

return WeatherService
